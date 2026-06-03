import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';
import 'doctor_home_dashboard.dart';
import 'doctor_session_detail_screen.dart';

enum _DoctorApptTab { upcoming, completed, missed }

/// Doctor-facing appointments list — patient-centric cards that open
/// [DoctorSessionDetailScreen] for the full appointment view.
class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  State<DoctorAppointmentsScreen> createState() => _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  final _api = ApiService();
  List<SessionDto> _sessions = [];
  Map<String, BookingDto> _bookingsById = {};
  bool _loading = true;
  String? _error;
  _DoctorApptTab _tab = _DoctorApptTab.upcoming;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _api.fetchCurrentUser();
      final allSessions = await _api.fetchSessions();
      final sessions = allSessions.where((s) => s.doctorId == user.id).toList();
      final bookingIds = sessions.map((s) => s.bookingId).where((id) => id.trim().isNotEmpty).toSet();
      final byId = <String, BookingDto>{};
      await Future.wait(
        bookingIds.map((id) async {
          try {
            final b = await _api.fetchBookingById(id).timeout(const Duration(seconds: 6));
            byId[id] = b;
          } catch (_) {}
        }),
      );
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _bookingsById = byId;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = messageFromDioException(e) ?? 'Failed to load appointments.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load appointments.';
      });
    }
  }

  bool _isUpcoming(SessionDto s) {
    final st = s.status.toLowerCase().trim();
    if (st == 'cancelled' || st == 'completed' || st == 'no_show' || st == 'no-show' || st == 'transferred') {
      return false;
    }
    final dt = DateTime.tryParse((s.scheduledAt ?? '').trim())?.toLocal();
    if (dt == null) return st == 'pending' || st == 'scheduled' || st == 'requested' || st == 'in_progress';
    return dt.isAfter(DateTime.now().subtract(const Duration(hours: 2)));
  }

  bool _isCompleted(SessionDto s) {
    final st = s.status.toLowerCase().trim();
    return st == 'completed' || st == 'done' || st == 'finished';
  }

  bool _isMissed(SessionDto s) {
    final st = s.status.toLowerCase().trim();
    return st == 'no_show' || st == 'no-show';
  }

  List<SessionDto> get _filtered {
    final list = switch (_tab) {
      _DoctorApptTab.upcoming => _sessions.where(_isUpcoming).toList(),
      _DoctorApptTab.completed => _sessions.where(_isCompleted).toList(),
      _DoctorApptTab.missed => _sessions.where(_isMissed).toList(),
    };
    list.sort((a, b) {
      final da = DateTime.tryParse((a.scheduledAt ?? '').trim())?.toLocal();
      final db = DateTime.tryParse((b.scheduledAt ?? '').trim())?.toLocal();
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return _tab == _DoctorApptTab.upcoming ? da.compareTo(db) : db.compareTo(da);
    });
    return list;
  }

  Future<void> _openSession(SessionDto s) async {
    final booking = _bookingsById[s.bookingId];
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DoctorSessionDetailScreen(
          session: s,
          booking: booking,
          onSessionUpdated: (_) => _load(),
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final upcomingCount = _sessions.where(_isUpcoming).length;
    final completedCount = _sessions.where(_isCompleted).length;
    final missedCount = _sessions.where(_isMissed).length;
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
        foregroundColor: SmartAfyaPalette.deepText,
        title: const Text('Appointments', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: SmartAfyaPalette.primaryBlue,
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: SmartAfyaPalette.primaryBlue))
              : _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _load,
                                style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _SegmentedTabs(
                          tab: _tab,
                          upcomingCount: upcomingCount,
                          completedCount: completedCount,
                          missedCount: missedCount,
                          onChanged: (t) => setState(() => _tab = t),
                        ),
                        const SizedBox(height: 14),
                        if (filtered.isEmpty)
                          _emptyState()
                        else
                          ...filtered.map((s) => _AppointmentCard(
                                session: s,
                                booking: _bookingsById[s.bookingId],
                                onTap: () => _openSession(s),
                              )),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    final isUpcoming = _tab == _DoctorApptTab.upcoming;
    final isMissed = _tab == _DoctorApptTab.missed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isUpcoming
                  ? Icons.event_available_rounded
                  : isMissed
                      ? Icons.event_busy_rounded
                      : Icons.check_circle_outline_rounded,
              color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.75),
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isUpcoming
                ? 'No upcoming appointments'
                : isMissed
                    ? 'No missed sessions'
                    : 'No completed appointments yet',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: SmartAfyaPalette.deepText.withValues(alpha: 0.78),
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isUpcoming
                ? 'Assigned sessions will appear here.'
                : isMissed
                    ? 'Sessions marked as no-show appear here.'
                    : 'Finished consultations appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SmartAfyaPalette.mutedText.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
              height: 1.35,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.session,
    required this.booking,
    required this.onTap,
  });

  final SessionDto session;
  final BookingDto? booking;
  final VoidCallback onTap;

  static String _initials(String clientId) {
    final id = clientId.trim();
    if (id.length >= 2) return id.substring(id.length - 2).toUpperCase();
    return 'PT';
  }

  static String _friendlyType(String? type) {
    final s = (type ?? '').toLowerCase().trim();
    if (s == 'video') return 'Video';
    if (s == 'audio') return 'Audio';
    if (s == 'physical') return 'In-person';
    return 'Consultation';
  }

  static IconData _typeIcon(String? type) {
    final s = (type ?? '').toLowerCase().trim();
    if (s == 'video') return Icons.videocam_rounded;
    if (s == 'audio') return Icons.call_rounded;
    if (s == 'physical') return Icons.place_rounded;
    return Icons.event_rounded;
  }

  static String _formatShortDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  static String _formatTime(DateTime dt) {
    final hour12 = (dt.hour % 12 == 0) ? 12 : dt.hour % 12;
    final minStr = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minStr $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final patient = DoctorHomeDashboard.patientLabel(session.clientId);
    final initials = _initials(session.clientId);
    final status = DoctorHomeDashboard.displayStatusForSession(session);
    final statusColor = _statusColor(status);
    final dt = DateTime.tryParse((session.scheduledAt ?? '').trim())?.toLocal();
    final dateLabel = dt == null ? 'TBD' : _formatShortDate(dt);
    final timeLabel = dt == null ? '' : _formatTime(dt);
    final typeLabel = _friendlyType(booking?.sessionType);
    final canJoin = (session.meetingLink ?? '').trim().isNotEmpty &&
        status != 'Completed' &&
        status != 'Cancelled' &&
        status != 'Missed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE4EEF7)),
              boxShadow: const [
                BoxShadow(color: Color(0x0D2A5F8A), blurRadius: 14, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: SmartAfyaPalette.primaryBlue,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: SmartAfyaPalette.deepText,
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            typeLabel,
                            style: const TextStyle(
                              color: SmartAfyaPalette.mutedText,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(label: status, color: statusColor),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _metaChip(Icons.event_rounded, dateLabel),
                    if (timeLabel.isNotEmpty) _metaChip(Icons.schedule_rounded, timeLabel),
                    _metaChip(_typeIcon(booking?.sessionType), typeLabel),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: SmartAfyaPalette.primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        icon: Icon(canJoin ? Icons.videocam_rounded : Icons.open_in_new_rounded, size: 16),
                        label: Text(
                          canJoin ? 'Join' : 'View details',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    if (status == 'Completed') return SmartAfyaPalette.primaryGreen;
    if (status == 'Missed' || status == 'Overdue') return const Color(0xFFE65100);
    if (status == 'Cancelled') return const Color(0xFFB23A3A);
    return SmartAfyaPalette.primaryBlue;
  }

  Widget _metaChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: SmartAfyaPalette.mutedText),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: SmartAfyaPalette.mutedText,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10.5),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.tab,
    required this.upcomingCount,
    required this.completedCount,
    required this.missedCount,
    required this.onChanged,
  });

  final _DoctorApptTab tab;
  final int upcomingCount;
  final int completedCount;
  final int missedCount;
  final ValueChanged<_DoctorApptTab> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget segment(_DoctorApptTab t, String label, int count) {
      final selected = tab == t;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onChanged(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: selected ? SmartAfyaPalette.primaryBlue.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Column(
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                    color: selected ? SmartAfyaPalette.primaryBlue : SmartAfyaPalette.mutedText,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      color: selected ? SmartAfyaPalette.primaryBlue : SmartAfyaPalette.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4EEF7)),
      ),
      child: Row(
        children: [
          segment(_DoctorApptTab.upcoming, 'Upcoming', upcomingCount),
          segment(_DoctorApptTab.completed, 'Completed', completedCount),
          segment(_DoctorApptTab.missed, 'Missed', missedCount),
        ],
      ),
    );
  }
}
