import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../utils/person_name.dart';
import 'app_palette.dart';
import 'doctor_session_detail_screen.dart';

/// Doctor-only home dashboard: consultation workflow (next → today → actions).
class DoctorHomeDashboard extends StatelessWidget {
  const DoctorHomeDashboard({
    super.key,
    required this.user,
    required this.sessions,
    required this.bookingsById,
    required this.isAvailable,
    required this.availabilityBusy,
    required this.onToggleAvailability,
    required this.onRefresh,
    required this.onOpenSchedule,
    required this.onOpenSessionsAndReports,
    required this.pendingTransferRequestsCount,
    required this.pendingUnavailabilityImpactsCount,
    required this.messageThreadsCount,
    this.onOpenMessages,
  });

  final CurrentUserDto user;
  final List<SessionDto> sessions;
  final Map<String, BookingDto> bookingsById;
  final bool isAvailable;
  final bool availabilityBusy;
  final VoidCallback onToggleAvailability;
  final Future<void> Function() onRefresh;
  final void Function() onOpenSchedule;
  final void Function() onOpenSessionsAndReports;
  final int pendingTransferRequestsCount;
  final int pendingUnavailabilityImpactsCount;
  final int messageThreadsCount;
  final VoidCallback? onOpenMessages;

  static const _hairline = Color(0xFFE4EEF7);
  static const List<BoxShadow> _shadow = [
    BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const _cardShadow = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 6)),
  ];

  /// Stronger elevation for the primary "next session" focus card.
  static const List<BoxShadow> _nextSessionShadow = [
    BoxShadow(color: Color(0x12000000), blurRadius: 22, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  String get _specialistLabel {
    final s = (user.specialistType ?? '').trim();
    if (s.isEmpty) return 'Mental health specialist';
    return s
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    bool isToday(SessionDto s) {
      final dt = _parseLocal(s.scheduledAt);
      if (dt == null) return false;
      return !dt.isBefore(startOfDay) && dt.isBefore(endOfDay);
    }

    final todaySessions = sessions.where(isToday).toList()
      ..sort((a, b) => _compareSchedule(a.scheduledAt, b.scheduledAt));

    final now = DateTime.now();
    final scheduledUpcoming = sessions.where((s) {
      final st = s.status.toLowerCase().trim();
      if (st == 'completed' || st == 'cancelled' || st == 'no_show' || st == 'no-show' || st == 'transferred') {
        return false;
      }
      final dt = _parseLocal(s.scheduledAt);
      if (dt == null) return false;
      return dt.isAfter(now);
    }).toList()
      ..sort((a, b) => _compareSchedule(a.scheduledAt, b.scheduledAt));

    final greetingFirst = firstNameFromFullName(user.fullName);
    void handleSessionUpdated(SessionDto _) {
      onRefresh();
    }

    final ongoingSessions = sessions.where((s) => _displayStatus(s) == 'Ongoing').toList()
      ..sort((a, b) => _compareSchedule(a.scheduledAt, b.scheduledAt));
    final SessionDto? ongoing = ongoingSessions.isNotEmpty ? ongoingSessions.first : null;

    final SessionDto? nextSession = ongoing ?? (scheduledUpcoming.isNotEmpty ? scheduledUpcoming.first : null);
    final int reportsPendingCount = sessions.where((s) {
      final st = _displayStatus(s);
      if (st == 'Completed' || st == 'Missed' || st == 'Cancelled' || st == 'Transferred') return false;
      final dt = _parseLocal(s.scheduledAt);
      if (dt == null) return false;
      return dt.isBefore(now);
    }).length;

    void openSessionDetails(SessionDto s) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DoctorSessionDetailScreen(
            session: s,
            booking: bookingsById[s.bookingId],
            onSessionUpdated: handleSessionUpdated,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: SmartAfyaPalette.primaryBlue,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _DoctorHeader(
            greetingFirstName: greetingFirst,
            specialistLabel: _specialistLabel,
            onPrimaryAction: onOpenSchedule,
          ),
          const SizedBox(height: 18),
          _NextSessionCard(
            session: nextSession,
            patientName: nextSession == null ? null : patientLabel(nextSession.clientId),
            timeLabel: nextSession == null ? null : _formatDateTime(nextSession.scheduledAt),
            statusLabel: nextSession == null ? null : _displayStatus(nextSession),
            onJoin: (nextSession != null) ? () => _openMeeting(nextSession.meetingLink) : null,
            onOpenDetails: nextSession == null ? null : () => openSessionDetails(nextSession),
            onViewSchedule: onOpenSchedule,
            elevatedShadow: _nextSessionShadow,
          ),
          const SizedBox(height: 12),
          _WorkflowStatusStrip(
            reportsPendingCount: reportsPendingCount,
            pendingTransferRequestsCount: pendingTransferRequestsCount,
            pendingUnavailabilityImpactsCount: pendingUnavailabilityImpactsCount,
          ),
          const SizedBox(height: 22),
          if (todaySessions.isNotEmpty) ...[
            const _SectionTitle(title: "Today's sessions"),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _hairline),
                boxShadow: _shadow,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < todaySessions.length; i++) ...[
                    SessionListItem(
                      session: todaySessions[i],
                      patientName: patientLabel(todaySessions[i].clientId),
                      timeLabel: _formatTimeOnly(todaySessions[i].scheduledAt),
                      status: _displayStatus(todaySessions[i]),
                      onTap: () => openSessionDetails(todaySessions[i]),
                    ),
                    if (i != todaySessions.length - 1) const Divider(height: 1, thickness: 1, color: _hairline),
                  ],
                ],
              ),
            ),
          ] else ...[
            const _SectionTitle(title: "Today's sessions"),
            const SizedBox(height: 12),
            const _TodaySessionsEmptyCard(),
          ],
          const SizedBox(height: 22),
          const _SectionTitle(title: 'Actions'),
          const SizedBox(height: 12),
          _ActionsCard(
            availabilityBusy: availabilityBusy,
            isAvailable: isAvailable,
            onOpenSessionsAndReports: onOpenSessionsAndReports,
            onOpenMessages: onOpenMessages,
            onToggleAvailability: onToggleAvailability,
            sessionsBadgeCount: reportsPendingCount,
            messagesBadgeCount: messageThreadsCount,
          ),
          const SizedBox(height: 26),
        ],
      ),
    );
  }

  int _compareSchedule(String? a, String? b) {
    final da = _parseLocal(a);
    final db = _parseLocal(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }

  static DateTime? _parseLocal(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    final dt = DateTime.tryParse(iso);
    return dt?.toLocal();
  }

  static String patientLabel(String clientId) {
    final id = clientId.trim();
    if (id.length <= 8) return 'Patient';
    return 'Patient · …${id.substring(id.length - 6)}';
  }


  Future<void> _openMeeting(String? link) async {
    if (link == null || link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static String _sessionTypeFromBooking(BookingDto? b) {
    final t = (b?.sessionType ?? '').trim();
    if (t.isEmpty) return '—';
    return t[0].toUpperCase() + t.substring(1);
  }

  static String _displayStatus(SessionDto s) {
    final st = s.status.toLowerCase();
    if (st == 'completed') return 'Completed';
    if (st == 'cancelled') return 'Cancelled';
    if (st == 'no_show' || st == 'no-show') return 'Missed';
    if (st == 'transferred') return 'Transferred';
    if (st == 'requested') return 'Requested';
    if (st == 'pending') return 'Upcoming';
    if (st == 'scheduled') {
      final dt = _parseLocal(s.scheduledAt);
      if (dt == null) return 'Upcoming';
      final now = DateTime.now();
      if (dt.isBefore(now.add(const Duration(minutes: 15))) && dt.add(const Duration(hours: 2)).isAfter(now)) {
        return 'Ongoing';
      }
      if (dt.isBefore(now)) return 'Ongoing';
      return 'Upcoming';
    }
    return st.isEmpty ? '—' : st;
  }

  static String displayStatusForSession(SessionDto s) => _displayStatus(s);

  static String formatSessionWhen(String? iso) => _formatDateTime(iso);

  static String _formatDateTime(String? iso) {
    final dt = _parseLocal(iso);
    if (dt == null) return 'To be scheduled';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = months[(dt.month - 1).clamp(0, 11)];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final am = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$m ${dt.day}, ${dt.year} · $hour:$min $am';
  }

  static String _formatTimeOnly(String? iso) {
    final dt = _parseLocal(iso);
    if (dt == null) return 'Time TBD';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final am = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $am';
  }
}

class _DoctorHeader extends StatelessWidget {
  const _DoctorHeader({
    required this.greetingFirstName,
    required this.specialistLabel,
    required this.onPrimaryAction,
  });

  final String greetingFirstName;
  final String specialistLabel;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final first = greetingFirstName.trim();
    final now = TimeOfDay.now();
    final hr = now.hour;
    final timeGreeting = (hr < 12)
        ? 'Good morning'
        : (hr < 17)
            ? 'Good afternoon'
            : 'Good evening';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeGreeting,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: SmartAfyaPalette.mutedText,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                first.isEmpty ? 'Doctor' : first,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: SmartAfyaPalette.deepText,
                  height: 1.1,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              _SpecialistPill(label: specialistLabel),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 44,
          child: FilledButton.icon(
            onPressed: onPrimaryAction,
            style: FilledButton.styleFrom(
              backgroundColor: SmartAfyaPalette.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: const Text('Schedule', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}

class _SpecialistPill extends StatelessWidget {
  const _SpecialistPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.psychology_rounded, size: 14, color: SmartAfyaPalette.primaryBlue),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
                color: SmartAfyaPalette.primaryBlue,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionListTile extends StatelessWidget {
  const _SessionListTile({
    required this.session,
    required this.booking,
    required this.onTap,
  });

  final SessionDto session;
  final BookingDto? booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DoctorHomeDashboard._hairline),
            boxShadow: DoctorHomeDashboard._shadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DoctorHomeDashboard.patientLabel(session.clientId),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: SmartAfyaPalette.deepText),
                    ),
                    Text(
                      '${DoctorHomeDashboard._sessionTypeFromBooking(booking)} · ${DoctorHomeDashboard._displayStatus(session)}',
                      style: const TextStyle(fontSize: 12.5, color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Text(
                DoctorHomeDashboard._formatDateTime(session.scheduledAt),
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: SmartAfyaPalette.mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Kept for potential reuse (not currently used by the dashboard layout).
enum HeroCardState { ongoing, next, empty }

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: SmartAfyaPalette.deepText,
            letterSpacing: -0.2,
          ),
    );
  }
}

class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.state,
    required this.onPrimary,
    this.onSecondary,
    this.patientName,
    this.timeLabel,
  });

  final HeroCardState state;
  final String? patientName;
  final String? timeLabel;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, primaryText, secondaryText, icon, accent) = switch (state) {
      HeroCardState.ongoing => (
          'Ongoing Session',
          patientName ?? 'Patient',
          'Join Now',
          'Submit Report',
          Icons.videocam_rounded,
          SmartAfyaPalette.primaryBlue,
        ),
      HeroCardState.next => (
          'Next Session',
          '${patientName ?? 'Patient'} · ${timeLabel ?? 'Time TBD'}',
          'Prepare',
          'View Details',
          Icons.schedule_rounded,
          SmartAfyaPalette.primaryBlue,
        ),
      HeroCardState.empty => (
          'No sessions today',
          "You're all caught up",
          'View Schedule',
          null,
          Icons.calendar_month_rounded,
          SmartAfyaPalette.primaryGreen,
        ),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DoctorHomeDashboard._hairline),
        boxShadow: DoctorHomeDashboard._cardShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16.5,
                        color: SmartAfyaPalette.deepText,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: SmartAfyaPalette.mutedText,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onPrimary,
                  style: FilledButton.styleFrom(
                    backgroundColor: SmartAfyaPalette.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(primaryText, style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              if (secondaryText != null && onSecondary != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSecondary,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.28)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(secondaryText, style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class SessionListItem extends StatelessWidget {
  const SessionListItem({
    super.key,
    required this.session,
    required this.patientName,
    required this.timeLabel,
    required this.status,
    required this.onTap,
  });

  final SessionDto session;
  final String patientName;
  final String timeLabel;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim();
    final isOngoing = normalized == 'Ongoing';
    final isUpcoming = normalized == 'Upcoming' || normalized == 'Requested';
    final isCompleted = normalized == 'Completed';
    final isMissed = normalized == 'Missed';

    final (badgeText, badgeBg, badgeFg) = (isCompleted)
        ? ('Completed', SmartAfyaPalette.primaryGreen.withValues(alpha: 0.12), SmartAfyaPalette.primaryGreen)
        : (isMissed)
            ? ('Missed', const Color(0xFFFFF3E0), const Color(0xFFE65100))
            : (isOngoing)
                ? ('Ongoing', SmartAfyaPalette.primaryBlue.withValues(alpha: 0.12), SmartAfyaPalette.primaryBlue)
                : (isUpcoming)
                    ? ('Upcoming', SmartAfyaPalette.primaryBlue.withValues(alpha: 0.10), SmartAfyaPalette.primaryBlue)
                    : ('—', const Color(0xFFF7FAFD), SmartAfyaPalette.mutedText);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  timeLabel,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  patientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: SmartAfyaPalette.deepText),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(badgeText, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: badgeFg)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: SmartAfyaPalette.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({
    required this.session,
    required this.patientName,
    required this.timeLabel,
    required this.statusLabel,
    required this.onJoin,
    required this.onOpenDetails,
    required this.onViewSchedule,
    required this.elevatedShadow,
  });

  final SessionDto? session;
  final String? patientName;
  final String? timeLabel;
  final String? statusLabel;
  final VoidCallback? onJoin;
  final VoidCallback? onOpenDetails;
  final VoidCallback onViewSchedule;
  final List<BoxShadow> elevatedShadow;

  @override
  Widget build(BuildContext context) {
    final has = session != null;
    final st = (statusLabel ?? '').trim();
    final canJoin = has && (session!.meetingLink ?? '').trim().isNotEmpty;
    final isOngoing = st == 'Ongoing';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DoctorHomeDashboard._hairline),
        boxShadow: elevatedShadow,
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.schedule_rounded, color: SmartAfyaPalette.primaryBlue, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Next session',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: SmartAfyaPalette.deepText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (has) ...[
            Text(
              patientName ?? 'Patient',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: SmartAfyaPalette.deepText),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    timeLabel ?? 'Time TBD',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: SmartAfyaPalette.mutedText, height: 1.25),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOngoing
                        ? SmartAfyaPalette.primaryBlue.withValues(alpha: 0.12)
                        : SmartAfyaPalette.softBlue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    st.isEmpty ? '—' : st,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: isOngoing ? SmartAfyaPalette.primaryBlue : SmartAfyaPalette.mutedText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canJoin ? onJoin : onOpenDetails,
                style: FilledButton.styleFrom(
                  backgroundColor: SmartAfyaPalette.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: Icon(canJoin ? Icons.videocam_rounded : Icons.open_in_new_rounded, size: 20),
                label: Text(
                  canJoin ? 'Join session' : 'Open session',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ] else ...[
            const Text(
              'No upcoming sessions',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: SmartAfyaPalette.deepText),
            ),
            const SizedBox(height: 8),
            Text(
              'When you have a booking, it will show up here.',
              style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600, height: 1.35, fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton(
                onPressed: onViewSchedule,
                style: FilledButton.styleFrom(
                  backgroundColor: SmartAfyaPalette.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('View schedule', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodaySessionsEmptyCard extends StatelessWidget {
  const _TodaySessionsEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DoctorHomeDashboard._hairline),
        boxShadow: DoctorHomeDashboard._shadow,
      ),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.today_outlined, color: SmartAfyaPalette.primaryBlue),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No sessions today',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: SmartAfyaPalette.deepText),
                ),
                SizedBox(height: 6),
                Text(
                  'Your calendar is clear for today.',
                  style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowStatusStrip extends StatelessWidget {
  const _WorkflowStatusStrip({
    required this.reportsPendingCount,
    required this.pendingTransferRequestsCount,
    required this.pendingUnavailabilityImpactsCount,
  });

  final int reportsPendingCount;
  final int pendingTransferRequestsCount;
  final int pendingUnavailabilityImpactsCount;

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, String label, int count, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text('$label: $count', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: color)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DoctorHomeDashboard._hairline),
        boxShadow: DoctorHomeDashboard._shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Workflow status',
            style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip(Icons.description_rounded, 'Reports', reportsPendingCount, SmartAfyaPalette.primaryBlue),
              chip(Icons.swap_horiz_rounded, 'Transfers', pendingTransferRequestsCount, SmartAfyaPalette.primaryBlue),
              chip(Icons.event_busy_rounded, 'Time-away', pendingUnavailabilityImpactsCount, SmartAfyaPalette.primaryGreen),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.availabilityBusy,
    required this.isAvailable,
    required this.onOpenSessionsAndReports,
    required this.onOpenMessages,
    required this.onToggleAvailability,
    required this.sessionsBadgeCount,
    required this.messagesBadgeCount,
  });

  final bool availabilityBusy;
  final bool isAvailable;
  final VoidCallback onOpenSessionsAndReports;
  final VoidCallback? onOpenMessages;
  final VoidCallback onToggleAvailability;
  final int sessionsBadgeCount;
  final int messagesBadgeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DoctorHomeDashboard._hairline),
        boxShadow: DoctorHomeDashboard._shadow,
      ),
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.folder_special_rounded,
            iconBg: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.10),
            iconColor: SmartAfyaPalette.primaryBlue,
            title: 'Sessions & reports',
            subtitle: 'All sessions and documentation',
            onTap: onOpenSessionsAndReports,
            badgeCount: sessionsBadgeCount,
          ),
          const Divider(height: 1, thickness: 1, color: DoctorHomeDashboard._hairline),
          _ActionRow(
            icon: Icons.chat_bubble_rounded,
            iconBg: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.10),
            iconColor: SmartAfyaPalette.primaryBlue,
            title: 'Messages',
            subtitle: 'Inbox',
            enabled: onOpenMessages != null,
            onTap: onOpenMessages,
            badgeCount: messagesBadgeCount,
          ),
          const Divider(height: 1, thickness: 1, color: DoctorHomeDashboard._hairline),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              value: isAvailable,
              onChanged: availabilityBusy ? null : (_) => onToggleAvailability(),
              title: const Text('Availability', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(
                availabilityBusy ? 'Updating…' : (isAvailable ? 'Accepting new sessions' : 'Not accepting new sessions'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              secondary: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isAvailable ? SmartAfyaPalette.primaryGreen : SmartAfyaPalette.mutedText).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isAvailable ? Icons.verified_user_rounded : Icons.do_not_disturb_on_rounded,
                  color: isAvailable ? SmartAfyaPalette.primaryGreen : SmartAfyaPalette.mutedText,
                ),
              ),
              activeThumbColor: SmartAfyaPalette.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeCount = 0,
    this.enabled = true,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final int badgeCount;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: enabled ? iconBg : SmartAfyaPalette.softBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: enabled ? iconColor : SmartAfyaPalette.mutedText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: enabled ? SmartAfyaPalette.deepText : SmartAfyaPalette.mutedText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: enabled ? SmartAfyaPalette.mutedText : SmartAfyaPalette.mutedText.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: SmartAfyaPalette.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: enabled ? SmartAfyaPalette.mutedText : SmartAfyaPalette.mutedText.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickActionCard extends StatefulWidget {
  const QuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;

  @override
  State<QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<QuickActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? SmartAfyaPalette.primaryBlue;
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: SizedBox(
        height: 124,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: DoctorHomeDashboard._hairline),
                boxShadow: DoctorHomeDashboard._cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: accent, size: 24),
                  ),
                  const Spacer(),
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: SmartAfyaPalette.deepText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.8,
                      fontWeight: FontWeight.w700,
                      color: SmartAfyaPalette.mutedText,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full list of sessions assigned to the doctor (from home / API refresh).
class DoctorSessionsScreen extends StatelessWidget {
  const DoctorSessionsScreen({
    super.key,
    required this.sessions,
    required this.bookingsById,
    this.initialFilterIndex = 2,
    this.onSessionUpdated,
  });

  final List<SessionDto> sessions;
  final Map<String, BookingDto> bookingsById;
  /// 0=All, 1=Today, 2=Upcoming, 3=Completed (finished consultations), 4=Missed
  final int initialFilterIndex;

  /// Called when a session is updated from the detail screen so the parent
  /// can re-fetch and avoid showing stale data when the user navigates back.
  final ValueChanged<SessionDto>? onSessionUpdated;

  @override
  Widget build(BuildContext context) {
    final sorted = [...sessions]..sort((a, b) => _cmp(a.scheduledAt, b.scheduledAt));

    return _DoctorSessionsFiltered(
      sessions: sorted,
      bookingsById: bookingsById,
      initialFilterIndex: initialFilterIndex,
      onSessionUpdated: onSessionUpdated,
    );
  }

  static int _cmp(String? a, String? b) {
    DateTime? p(String? iso) {
      if (iso == null || iso.trim().isEmpty) return null;
      return DateTime.tryParse(iso)?.toLocal();
    }

    final da = p(a);
    final db = p(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }
}

class _DoctorSessionsFiltered extends StatefulWidget {
  const _DoctorSessionsFiltered({
    required this.sessions,
    required this.bookingsById,
    required this.initialFilterIndex,
    this.onSessionUpdated,
  });

  final List<SessionDto> sessions;
  final Map<String, BookingDto> bookingsById;
  final int initialFilterIndex;
  final ValueChanged<SessionDto>? onSessionUpdated;

  @override
  State<_DoctorSessionsFiltered> createState() => _DoctorSessionsFilteredState();
}

class _DoctorSessionsFilteredState extends State<_DoctorSessionsFiltered> {
  int _filterIndex = 2;

  @override
  void initState() {
    super.initState();
    _filterIndex = widget.initialFilterIndex.clamp(0, 4);
  }

  List<SessionDto> _applyFilter(List<SessionDto> all) {
    if (_filterIndex == 0) return all;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    bool isToday(SessionDto s) {
      final dt = DateTime.tryParse(s.scheduledAt ?? '')?.toLocal();
      if (dt == null) return false;
      return !dt.isBefore(startOfDay) && dt.isBefore(endOfDay);
    }

    bool isUpcoming(SessionDto s) {
      final st = (s.status).toLowerCase().trim();
      if (st == 'completed' || st == 'cancelled' || st == 'no_show' || st == 'no-show' || st == 'transferred') {
        return false;
      }
      final dt = DateTime.tryParse(s.scheduledAt ?? '')?.toLocal();
      if (dt == null) return false;
      return dt.isAfter(now);
    }

    bool isCompleted(SessionDto s) {
      final st = (s.status).toLowerCase().trim();
      return st == 'completed' || st == 'done' || st == 'finished';
    }

    bool isMissed(SessionDto s) {
      final st = (s.status).toLowerCase().trim();
      return st == 'no_show' || st == 'no-show';
    }

    if (_filterIndex == 1) return all.where(isToday).toList();
    if (_filterIndex == 2) return all.where(isUpcoming).toList();
    if (_filterIndex == 3) return all.where(isCompleted).toList();
    if (_filterIndex == 4) return all.where(isMissed).toList();
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilter(widget.sessions);

    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
        foregroundColor: SmartAfyaPalette.deepText,
        title: const Text('Sessions & reports', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _Segmented(
              index: _filterIndex,
              onChanged: (i) => setState(() => _filterIndex = i),
              labels: const ['All', 'Today', 'Upcoming', 'Completed', 'Missed'],
            ),
          ),
        ),
      ),
      body: filtered.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No assigned sessions yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final s = filtered[i];
                final b = widget.bookingsById[s.bookingId];
                return _SessionListTile(
                  session: s,
                  booking: b,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DoctorSessionDetailScreen(
                          session: s,
                          booking: b,
                          onSessionUpdated: (updated) {
                            widget.onSessionUpdated?.call(updated);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.index,
    required this.onChanged,
    required this.labels,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4EEF7)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == index ? SmartAfyaPalette.primaryBlue.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: labels.length > 4 ? 10.5 : 12.5,
                        color: i == index ? SmartAfyaPalette.primaryBlue : SmartAfyaPalette.mutedText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (i != labels.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}
