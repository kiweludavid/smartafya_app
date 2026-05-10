import '../services/api_service.dart';

/// Pure logic: pick what to show on the home "upcoming" card from API DTOs.
class UpcomingHighlight {
  const UpcomingHighlight({
    required this.headline,
    required this.detailLines,
    this.meetingLink,
    this.canJoin = false,
    this.sessionId,
    this.bookingId,
  });

  final String headline;
  final List<String> detailLines;
  final String? meetingLink;
  final bool canJoin;
  final String? sessionId;
  final String? bookingId;
}

DateTime? parseApiDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

bool _sessionJoinable(SessionDto s, DateTime now) {
  final st = s.status.toLowerCase();
  if (st == 'cancelled' || st == 'completed') return false;
  final link = s.meetingLink?.trim();
  if (link == null || link.isEmpty) return false;
  final sched = parseApiDate(s.scheduledAt);
  if (sched != null) {
    final diff = sched.difference(now);
    // Join only when session time is near (premium, low-friction gating).
    // Allow 30 minutes before start, and a 2-hour grace period after.
    return diff.inMinutes <= 30 && diff.inMinutes >= -120;
  }
  return st == 'pending' || st == 'scheduled';
}

UpcomingHighlight? resolveClientUpcoming({
  required List<SessionDto> sessions,
  required List<BookingDto> bookings,
  required Map<String, String> doctorNames,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();

  SessionDto? bestSession;
  DateTime? bestTime;
  for (final s in sessions) {
    final st = s.status.toLowerCase();
    if (st == 'cancelled' || st == 'completed') continue;
    final sched = parseApiDate(s.scheduledAt);
    if (sched != null && !sched.isBefore(n)) {
      if (bestTime == null || sched.isBefore(bestTime)) {
        bestTime = sched;
        bestSession = s;
      }
    }
  }

  if (bestSession != null && bestTime != null) {
    final doc = bestSession.doctorId != null
        ? (doctorNames[bestSession.doctorId!] ?? 'Your specialist')
        : 'Specialist (to be assigned)';
    return UpcomingHighlight(
      headline: 'Upcoming session',
      detailLines: [
        _formatDateTime(bestTime),
        'Status: ${bestSession.status}',
        'With: $doc',
      ],
      meetingLink: bestSession.meetingLink,
      canJoin: _sessionJoinable(bestSession, n),
      sessionId: bestSession.id,
    );
  }

  return _clientBookingFallback(bookings, n);
}

UpcomingHighlight? _clientBookingFallback(List<BookingDto> bookings, DateTime n) {
  BookingDto? best;
  DateTime? bestDt;
  for (final b in bookings) {
    final st = b.status.toLowerCase();
    if (st == 'cancelled') continue;
    final first = b.firstPreferredDateUtc;
    if (first != null && !first.isBefore(n)) {
      if (bestDt == null || first.isBefore(bestDt)) {
        bestDt = first;
        best = b;
      }
    }
  }
  if (best != null && bestDt != null) {
    return UpcomingHighlight(
      headline: 'Upcoming booking',
      detailLines: [
        _formatDateTime(bestDt),
        'Session format: ${best.sessionType}',
        'Booking status: ${best.status}',
      ],
      meetingLink: null,
      canJoin: false,
      bookingId: best.id,
    );
  }

  if (bookings.isNotEmpty) {
    final pendingList = bookings.where((b) => b.status.toLowerCase() == 'pending').toList();
    final pending = pendingList.isNotEmpty ? pendingList.first : bookings.first;
    return UpcomingHighlight(
      headline: 'Your bookings',
      detailLines: [
        'Status: ${pending.status}',
        'Session format: ${pending.sessionType}',
        if (pending.firstPreferredDateUtc != null)
          'Next preferred slot: ${_formatDateTime(pending.firstPreferredDateUtc!)}',
      ],
      canJoin: false,
      bookingId: pending.id,
    );
  }
  return null;
}

UpcomingHighlight? resolveDoctorUpcoming({
  required List<SessionDto> sessions,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  SessionDto? best;
  DateTime? bestTime;
  for (final s in sessions) {
    final st = s.status.toLowerCase();
    if (st == 'cancelled' || st == 'completed') continue;
    final sched = parseApiDate(s.scheduledAt);
    if (sched != null && !sched.isBefore(n)) {
      if (bestTime == null || sched.isBefore(bestTime)) {
        bestTime = sched;
        best = s;
      }
    }
  }
  if (best != null && bestTime != null) {
    return UpcomingHighlight(
      headline: 'Next session',
      detailLines: [
        _formatDateTime(bestTime),
        'Status: ${best.status}',
        if (best.meetingLink != null && best.meetingLink!.trim().isNotEmpty) 'Meeting link ready',
      ],
      meetingLink: best.meetingLink,
      canJoin: _sessionJoinable(best, n),
      sessionId: best.id,
    );
  }
  return null;
}

UpcomingHighlight? resolveAdminUpcoming({
  required List<BookingDto> bookings,
  required List<SessionDto> sessions,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final pending = bookings.where((b) => b.status.toLowerCase() == 'pending').length;
  final unassigned = sessions.where((s) {
    final st = s.status.toLowerCase();
    final noDoctor = s.doctorId == null || s.doctorId!.trim().isEmpty;
    return (st == 'pending' || st == 'scheduled' || st == 'requested') && noDoctor;
  }).length;

  if (pending == 0 && unassigned == 0) return null;

  return UpcomingHighlight(
    headline: 'Operations overview',
    detailLines: [
      '$pending booking(s) awaiting confirmation',
      if (unassigned > 0) '$unassigned session(s) need doctor assignment',
      _formatDateTime(n),
    ],
    canJoin: false,
  );
}

String _formatDateTime(DateTime dt) {
  final d = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  final t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  return '$d · $t';
}
