import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';
import 'doctor_home_dashboard.dart';
import 'doctor_session_detail_screen.dart';

/// Doctor schedule: calendar, day sessions, upcoming list, and mark time away.
class DoctorScheduleScreen extends StatefulWidget {
  const DoctorScheduleScreen({
    super.key,
    required this.sessions,
    required this.bookingsById,
    required this.isAvailable,
    required this.availabilityBusy,
    required this.onToggleAvailability,
    required this.onRefresh,
  });

  final List<SessionDto> sessions;
  final Map<String, BookingDto> bookingsById;
  final bool isAvailable;
  final bool availabilityBusy;
  final VoidCallback onToggleAvailability;
  final Future<void> Function() onRefresh;

  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  late DateTime _selectedDay;
  final _api = ApiService();

  static const _hairline = Color(0xFFE4EEF7);
  static const _cardShadow = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 6)),
  ];

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _selectedDay = DateTime(n.year, n.month, n.day);
  }

  static DateTime? _parseLocal(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    final dt = DateTime.tryParse(iso);
    return dt?.toLocal();
  }

  static String _formatTimeOnly(String? iso) {
    final dt = _parseLocal(iso);
    if (dt == null) return '—';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final am = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $am';
  }

  static int _compareSchedule(String? a, String? b) {
    final da = _parseLocal(a);
    final db = _parseLocal(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }

  List<SessionDto> _sessionsOnDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final list = widget.sessions.where((s) {
      final dt = _parseLocal(s.scheduledAt);
      if (dt == null) return false;
      return !dt.isBefore(start) && dt.isBefore(end);
    }).toList()
      ..sort((a, b) => _compareSchedule(a.scheduledAt, b.scheduledAt));
    return list;
  }

  List<SessionDto> _upcomingBookings() {
    final now = DateTime.now();
    return widget.sessions.where((s) {
      final st = s.status.toLowerCase().trim();
      if (st == 'completed' || st == 'cancelled') return false;
      final dt = _parseLocal(s.scheduledAt);
      if (dt == null) return false;
      return !dt.isBefore(now);
    }).toList()
      ..sort((a, b) => _compareSchedule(a.scheduledAt, b.scheduledAt));
  }

  Future<void> _openMarkTimeAway() async {
    DateTime? start = DateTime.now().add(const Duration(hours: 1));
    DateTime? end = DateTime.now().add(const Duration(hours: 3));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            Future<void> pickStart() async {
              final d = await showDatePicker(
                context: context,
                initialDate: start ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d == null) return;
              if (!context.mounted) return;
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(start ?? DateTime.now()),
              );
              if (t == null) return;
              setLocal(() {
                start = DateTime(d.year, d.month, d.day, t.hour, t.minute);
              });
            }

            Future<void> pickEnd() async {
              final base = end ?? start ?? DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate: base,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d == null) return;
              if (!context.mounted) return;
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(base),
              );
              if (t == null) return;
              setLocal(() {
                end = DateTime(d.year, d.month, d.day, t.hour, t.minute);
              });
            }

            return AlertDialog(
              title: const Text('Mark time away'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Patients with visits in this window can transfer or reschedule. Admin is notified.',
                      style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('From', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        start == null ? 'Tap to choose' : start!.toLocal().toString().split('.').first,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: pickStart,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Until', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        end == null ? 'Tap to choose' : end!.toLocal().toString().split('.').first,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: pickEnd,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryGreen),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || start == null || end == null) return;
    final startUtc = start!.toUtc();
    final endUtc = end!.toUtc();
    if (!endUtc.isAfter(startUtc)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End time must be after start.')));
      return;
    }

    try {
      final result = await _api
          .createDoctorUnavailabilityBlock(startsAtUtc: startUtc, endsAtUtc: endUtc)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      await NotificationService.physicalWorkflow(
        title: 'Time away recorded',
        body: '${result.affectedSessionCount} session(s) may need patient follow-up.',
      );
      await widget.onRefresh();
      if (mounted) setState(() {});
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDioException(e) ?? 'Could not save unavailability.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save unavailability.')));
    }
  }

  void _openSession(SessionDto s) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DoctorSessionDetailScreen(
          session: s,
          booking: widget.bookingsById[s.bookingId],
          onSessionUpdated: (_) => widget.onRefresh(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daySessions = _sessionsOnDay(_selectedDay);
    final upcoming = _upcomingBookings();

    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
        foregroundColor: SmartAfyaPalette.deepText,
        title: const Text('Schedule', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        color: SmartAfyaPalette.primaryBlue,
        onRefresh: widget.onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _hairline),
                boxShadow: _cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.isAvailable ? Icons.check_circle_rounded : Icons.pause_circle_outline_rounded,
                        color: widget.isAvailable ? SmartAfyaPalette.primaryGreen : SmartAfyaPalette.mutedText,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.isAvailable ? 'You are available for new bookings' : 'You are not accepting new bookings',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Matches the availability switch on your home screen.',
                    style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: widget.isAvailable,
                    onChanged: widget.availabilityBusy ? null : (_) => widget.onToggleAvailability(),
                    title: Text(
                      widget.availabilityBusy ? 'Updating…' : 'Available',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    activeThumbColor: SmartAfyaPalette.primaryGreen,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _hairline),
                boxShadow: _cardShadow,
              ),
              child: CalendarDatePicker(
                initialDate: _selectedDay,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                currentDate: DateTime.now(),
                onDateChanged: (d) => setState(() => _selectedDay = DateTime(d.year, d.month, d.day)),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _headingForSelectedDay(_selectedDay),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: SmartAfyaPalette.deepText),
            ),
            const SizedBox(height: 10),
            if (daySessions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _hairline),
                ),
                child: const Text(
                  'No sessions on this day.',
                  style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700),
                ),
              )
            else
              ...daySessions.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ScheduleSessionTile(
                    timeLabel: _formatTimeOnly(s.scheduledAt),
                    patientName: DoctorHomeDashboard.patientLabel(s.clientId),
                    status: DoctorHomeDashboard.displayStatusForSession(s),
                    onTap: () => _openSession(s),
                  ),
                );
              }),
            const SizedBox(height: 22),
            const Text(
              'Upcoming',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: SmartAfyaPalette.deepText),
            ),
            const SizedBox(height: 8),
            if (upcoming.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _hairline),
                ),
                child: const Text(
                  'No upcoming bookings.',
                  style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700),
                ),
              )
            else
              ...upcoming.take(20).map((s) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ScheduleSessionTile(
                    timeLabel: DoctorHomeDashboard.formatSessionWhen(s.scheduledAt),
                    patientName: DoctorHomeDashboard.patientLabel(s.clientId),
                    status: DoctorHomeDashboard.displayStatusForSession(s),
                    onTap: () => _openSession(s),
                  ),
                );
              }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openMarkTimeAway,
                icon: const Icon(Icons.event_busy_rounded),
                label: const Text('Mark time away', style: TextStyle(fontWeight: FontWeight.w900)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: SmartAfyaPalette.primaryGreen.withValues(alpha: 0.4)),
                  foregroundColor: SmartAfyaPalette.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _headingForSelectedDay(DateTime d) {
    final today = DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    final d0 = DateTime(d.year, d.month, d.day);
    if (d0 == t0) return "Today's sessions";
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[(d.month - 1).clamp(0, 11)]} ${d.day}, ${d.year}';
  }
}

class _ScheduleSessionTile extends StatelessWidget {
  const _ScheduleSessionTile({
    required this.timeLabel,
    required this.patientName,
    required this.status,
    required this.onTap,
  });

  final String timeLabel;
  final String patientName;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim();
    final isCompleted = normalized == 'Completed';
    final isOngoing = normalized == 'Ongoing';
    final isUpcoming = normalized == 'Upcoming' || normalized == 'Requested';
    final (badgeBg, badgeFg) = isCompleted
        ? (SmartAfyaPalette.primaryGreen.withValues(alpha: 0.12), SmartAfyaPalette.primaryGreen)
        : isOngoing
            ? (SmartAfyaPalette.primaryBlue.withValues(alpha: 0.12), SmartAfyaPalette.primaryBlue)
            : isUpcoming
                ? (SmartAfyaPalette.primaryBlue.withValues(alpha: 0.10), SmartAfyaPalette.primaryBlue)
                : (const Color(0xFFF7FAFD), SmartAfyaPalette.mutedText);

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
            border: Border.all(color: _DoctorScheduleScreenState._hairline),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  timeLabel,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText, fontSize: 13),
                ),
              ),
              Expanded(
                child: Text(
                  patientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(999)),
                child: Text(status, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: badgeFg)),
              ),
              const Icon(Icons.chevron_right_rounded, color: SmartAfyaPalette.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}
