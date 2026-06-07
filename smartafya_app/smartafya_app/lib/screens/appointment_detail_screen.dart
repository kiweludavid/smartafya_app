import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import 'app_palette.dart';
import 'chat_list_screen.dart';
import 'create_booking_screen.dart';
import 'home_screen_ui.dart' show PaymentsScreen;

/// Detailed read-only view of a single appointment with payment + cancel/reschedule actions.
///
/// Designed to be opened from both the home upcoming-session card and the
/// `AppointmentsScreen` list. The screen does its own data refresh on focus
/// (status / payment), so callers don't need to pre-hydrate everything —
/// they only pass what they already know to keep first paint instant.
class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({
    super.key,
    required this.session,
    this.booking,
    this.doctor,
    this.payment,
  });

  final SessionDto session;
  final BookingDto? booking;
  final DoctorDto? doctor;
  final PaymentDto? payment;

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  final _api = ApiService();

  late SessionDto _session;
  BookingDto? _booking;
  DoctorDto? _doctor;
  PaymentDto? _payment;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _booking = widget.booking;
    _doctor = widget.doctor;
    _payment = widget.payment;
    _refreshSilently();
  }

  Future<void> _refreshSilently() async {
    try {
      final freshSession = await _api.fetchSessionById(_session.id);
      PaymentDto? freshPayment = _payment;
      try {
        freshPayment = await _api.fetchPaymentForSession(_session.id);
      } catch (_) {}
      BookingDto? freshBooking = _booking;
      if (freshBooking == null && freshSession.bookingId.isNotEmpty) {
        try {
          freshBooking = await _api.fetchBookingById(freshSession.bookingId);
        } catch (_) {}
      }
      DoctorDto? freshDoctor = _doctor;
      if (freshDoctor == null && (freshSession.doctorId ?? '').trim().isNotEmpty) {
        try {
          final doctors = await _api.fetchDoctors();
          for (final d in doctors) {
            if (d.id == freshSession.doctorId) {
              freshDoctor = d;
              break;
            }
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _session = freshSession;
        _booking = freshBooking ?? _booking;
        _doctor = freshDoctor ?? _doctor;
        _payment = freshPayment;
      });
    } catch (_) {
      // Silent — original data still valid.
    }
  }

  bool get _paymentCompleted {
    final st = (_payment?.status ?? '').toLowerCase().trim();
    return st == 'paid' || st == 'completed' || st == 'success' || st == 'successful';
  }

  bool get _paymentInReview {
    final st = (_payment?.status ?? '').toLowerCase().trim();
    return st == 'in_review' ||
        st == 'in-review' ||
        st == 'pending_review' ||
        (_payment?.proofSubmittedAt != null &&
            (_payment!.proofSubmittedAt ?? '').isNotEmpty &&
            !_paymentCompleted);
  }

  bool get _needsPayment {
    final st = _session.status.toLowerCase().trim();
    final isLiveOrUpcoming = st == 'scheduled' || st == 'pending' || st == 'in_progress' || st == 'requested';
    return isLiveOrUpcoming && !_paymentCompleted && !_paymentInReview;
  }

  bool get _isMissed {
    final st = _session.status.toLowerCase().trim();
    return st == 'no_show' || st == 'no-show';
  }

  bool get _isJoinable {
    final st = _session.status.toLowerCase().trim();
    if (st == 'cancelled' || st == 'completed' || st == 'no_show' || st == 'no-show') return false;
    final link = (_session.meetingLink ?? '').trim();
    if (link.isEmpty) return false;
    final dt = _parseLocal(_session.scheduledAt);
    if (dt == null) return st == 'pending' || st == 'scheduled';
    final diff = dt.difference(DateTime.now());
    return diff.inMinutes <= 30 && diff.inMinutes >= -120;
  }

  bool get _canCancel {
    final st = _session.status.toLowerCase().trim();
    return st != 'completed' && st != 'cancelled' && st != 'no_show' && (_booking != null);
  }

  Future<void> _handlePay() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => PaymentsScreen(initialSessionId: _session.id),
      ),
    );
    if (!mounted) return;
    await _refreshSilently();
  }

  Future<void> _handleJoin() async {
    final link = (_session.meetingLink ?? '').trim();
    if (link.isEmpty) {
      _toast('Session link not available yet');
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri == null) {
      _toast('Session link not available yet');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _toast('Could not open the session link');
  }

  Future<void> _handleReschedule() async {
    final type = (_booking?.sessionType ?? '').trim().isEmpty ? 'video' : _booking!.sessionType;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CreateBookingScreen(
          initialSessionType: type,
          initialDurationMinutes: 60,
        ),
      ),
    );
    if (!mounted) return;
    await _refreshSilently();
  }

  Future<void> _handleGetHelp() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const ChatListScreen()),
    );
  }

  Future<void> _handleCancel() async {
    final booking = _booking;
    if (booking == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this appointment?'),
        content: const Text(
          'Your specialist will be notified. You can re-book any time afterwards.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
            child: const Text('Cancel appointment'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await _api.cancelBooking(booking.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('Could not cancel — please try again.');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dt = _parseLocal(_session.scheduledAt);
    final dateLabel = dt == null ? 'Time to be confirmed' : _formatDate(dt);
    final timeLabel = dt == null ? '' : _formatTime(dt);
    final typeLabel = _friendlyType(_booking?.sessionType);
    final typeIcon = _typeIcon(_booking?.sessionType);
    final statusInfo = _statusBadge(_session.status);
    final paymentInfo = _paymentBadge();
    final doctorName = (_doctor?.fullName.trim().isNotEmpty == true)
        ? _doctor!.fullName.trim()
        : ((_session.doctorId ?? '').trim().isNotEmpty
            ? 'Specialist assigned'
            : 'Specialist · pending assignment');
    final specialtyLabel = _doctor?.specialistLabel ?? 'Mental health specialist';
    final initials = _initialsFromName(_doctor?.fullName);

    final filteredNotes = _filterReadableNotes(_session.notes);
    final paymentInstructions = (_payment?.instructionsText ?? '').trim();

    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
        foregroundColor: SmartAfyaPalette.deepText,
        title: const Text('Appointment details', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: SmartAfyaPalette.primaryBlue,
          onRefresh: _refreshSilently,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // ─── Specialist profile summary ───
              _Card(
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: SmartAfyaPalette.primaryBlue,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doctorName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: SmartAfyaPalette.deepText,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            specialtyLabel,
                            style: const TextStyle(
                              color: SmartAfyaPalette.mutedText,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ─── Appointment details ───
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(label: 'Appointment'),
                    const SizedBox(height: 10),
                    _DetailRow(icon: Icons.event_rounded, label: 'Date', value: dateLabel),
                    if (timeLabel.isNotEmpty) _DetailRow(icon: Icons.schedule_rounded, label: 'Time', value: timeLabel),
                    _DetailRow(icon: typeIcon, label: 'Type', value: typeLabel),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const SizedBox(width: 28, child: Icon(Icons.flag_rounded, size: 18, color: SmartAfyaPalette.mutedText)),
                          const SizedBox(width: 10),
                          const Text('Status',
                              style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700, fontSize: 13)),
                          const Spacer(),
                          _Pill(label: statusInfo.label, color: statusInfo.color),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ─── Payment ───
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: _SectionTitle(label: 'Payment')),
                        _Pill(label: paymentInfo.label, color: paymentInfo.color),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _DetailRow(
                      icon: Icons.payments_rounded,
                      label: 'Amount',
                      value: _payment?.amount != null
                          ? 'TZS ${_payment!.amount!.toStringAsFixed(0)}'
                          : 'Set by admin',
                    ),
                    if (paymentInstructions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          paymentInstructions,
                          style: const TextStyle(
                            color: SmartAfyaPalette.deepText,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    if (_needsPayment) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF6E5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE2A8)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFB8740B)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Complete payment to confirm this session.',
                                style: TextStyle(
                                  color: Color(0xFF7A4D04),
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ─── Notes / instructions ───
              if (filteredNotes.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(label: 'Notes & instructions'),
                      const SizedBox(height: 10),
                      Text(
                        filteredNotes,
                        style: const TextStyle(
                          color: SmartAfyaPalette.deepText,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // ─── Primary actions ───
              if (_isMissed) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8F0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFE0B2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.event_busy_rounded, color: Color(0xFFE65100), size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You missed this session. Reschedule to keep your care plan on track, or chat with our team if you need help.',
                          style: TextStyle(
                            color: SmartAfyaPalette.deepText,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _PrimaryButton(
                  icon: Icons.event_repeat_rounded,
                  label: 'Reschedule',
                  onPressed: _busy ? null : _handleReschedule,
                ),
                const SizedBox(height: 10),
                _SecondaryButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Get help',
                  onPressed: _busy ? null : _handleGetHelp,
                ),
              ] else if (_needsPayment)
                _PrimaryButton(
                  icon: Icons.payments_rounded,
                  label: 'Pay & Confirm',
                  onPressed: _busy ? null : _handlePay,
                )
              else if (_isJoinable)
                _PrimaryButton(
                  icon: Icons.video_call_rounded,
                  label: 'Join Session',
                  onPressed: _busy ? null : _handleJoin,
                )
              else
                _PrimaryButton(
                  icon: Icons.lock_clock_rounded,
                  label: 'Session not yet joinable',
                  onPressed: null,
                ),

              if (_canCancel) ...[
                const SizedBox(height: 10),
                _SecondaryButton(
                  icon: Icons.close_rounded,
                  label: 'Cancel appointment',
                  onPressed: _busy ? null : _handleCancel,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── helpers ───

  ({String label, Color color}) _statusBadge(String status) {
    final s = status.toLowerCase().trim();
    if (s == 'completed') return (label: 'Completed', color: SmartAfyaPalette.primaryGreen);
    if (s == 'cancelled') return (label: 'Cancelled', color: const Color(0xFFB23A3A));
    if (s == 'no_show' || s == 'no-show') return (label: 'Missed', color: const Color(0xFFE65100));
    if (s == 'in_progress' || s == 'in-progress') return (label: 'In progress', color: SmartAfyaPalette.primaryBlue);
    if (s == 'scheduled') return (label: 'Scheduled', color: SmartAfyaPalette.primaryBlue);
    if (s == 'pending' || s == 'requested') return (label: 'Pending', color: const Color(0xFFD08600));
    return (label: status, color: SmartAfyaPalette.mutedText);
  }

  ({String label, Color color}) _paymentBadge() {
    if (_paymentCompleted) return (label: 'Confirmed', color: SmartAfyaPalette.primaryGreen);
    if (_paymentInReview) return (label: 'In review', color: SmartAfyaPalette.primaryBlue);
    return (label: 'Awaiting payment', color: const Color(0xFFD08600));
  }

  static String _initialsFromName(String? fullName) {
    final s = (fullName ?? '').trim();
    if (s.isEmpty) return '?';
    final parts = s.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static String _friendlyType(String? type) {
    final s = (type ?? '').toLowerCase().trim();
    if (s == 'video') return 'Video consultation';
    if (s == 'audio') return 'Audio consultation';
    if (s == 'physical') return 'In-person visit';
    if (s == 'online') return 'Online consultation';
    return 'Consultation';
  }

  static IconData _typeIcon(String? type) {
    final s = (type ?? '').toLowerCase().trim();
    if (s == 'video' || s == 'online') return Icons.videocam_rounded;
    if (s == 'audio') return Icons.call_rounded;
    if (s == 'physical') return Icons.place_rounded;
    return Icons.event_rounded;
  }

  static DateTime? _parseLocal(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    return DateTime.tryParse(iso)?.toLocal();
  }

  static String _formatDate(DateTime dt) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final wd = weekdays[(dt.weekday - 1).clamp(0, 6)];
    final mon = months[dt.month - 1];
    return '$wd, ${dt.day.toString().padLeft(2, '0')} $mon ${dt.year}';
  }

  static String _formatTime(DateTime dt) {
    final hour12 = (dt.hour % 12 == 0) ? 12 : dt.hour % 12;
    final hourStr = hour12.toString().padLeft(2, '0');
    final minStr = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hourStr:$minStr $ampm';
  }

  /// Strip internal control markers we use in `notes` (e.g. CONSULTATION_REPORT,
  /// FOLLOW_UP_*) so users only see human-readable text.
  static String _filterReadableNotes(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return '';
    final cleaned = s
        .split('\n')
        .where((line) {
          final t = line.trim();
          if (t.isEmpty) return false;
          if (t.startsWith('CONSULTATION_REPORT:')) return false;
          if (t.startsWith('FOLLOW_UP_')) return false;
          return true;
        })
        .join('\n')
        .trim();
    return cleaned;
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EEF7)),
        boxShadow: const [
          BoxShadow(color: Color(0x0F2A5F8A), blurRadius: 18, offset: Offset(0, 6)),
          BoxShadow(color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: SmartAfyaPalette.deepText,
        letterSpacing: -0.1,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(width: 28, child: Icon(icon, size: 18, color: SmartAfyaPalette.mutedText)),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700, fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: SmartAfyaPalette.deepText,
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: SmartAfyaPalette.primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.30),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: SmartAfyaPalette.deepText,
          side: const BorderSide(color: Color(0xFFE4EEF7)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: Icon(icon, size: 18, color: SmartAfyaPalette.deepText.withValues(alpha: 0.75)),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}
