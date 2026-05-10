import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';
import 'appointment_detail_screen.dart';
import 'care_actions_screen.dart';
import 'client_physical_booking_actions.dart';
import 'client_session_feedback_screen.dart';
import 'create_booking_screen.dart';
import 'home_screen_ui.dart' show PaymentsScreen;

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

enum _AppointmentsTab { upcoming, completed, missed }

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _api = ApiService();
  CurrentUserDto? _user;
  List<SessionDto> _sessions = [];
  List<BookingDto> _bookings = [];
  CareActionsDto? _careActions;
  Map<String, DoctorDto> _doctorsById = const {};
  Map<String, PaymentDto> _paymentsBySessionId = const {};
  bool _loading = true;
  String? _error;

  _AppointmentsTab _tab = _AppointmentsTab.upcoming;

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
      List<SessionDto> sess = [];
      List<BookingDto> books = [];
      if (user.isDoctor) {
        sess = await _api.fetchSessions();
        books = await _api.fetchAllBookings();
      } else {
        sess = await _api.fetchSessions();
        if (user.isClient) {
          books = await _api.fetchMyBookings();
        }
      }
      CareActionsDto? actions;
      if (user.isClient) {
        try {
          actions = await _api.fetchCareActions().timeout(const Duration(seconds: 8));
        } catch (_) {
          actions = null;
        }
      }

      final needsDirectory = sess.any((s) => (s.doctorId ?? '').trim().isNotEmpty);
      Map<String, DoctorDto> doctorMap = const {};
      if (needsDirectory) {
        try {
          final docs = await _api.fetchDoctors().timeout(const Duration(seconds: 6));
          doctorMap = {for (final d in docs) d.id: d};
        } catch (_) {}
      }

      // Fetch payments only for upcoming-style sessions (don't waste calls
      // on completed history items — payment is already settled).
      final upcomingForPayments = sess.where((s) {
        final st = s.status.toLowerCase().trim();
        return st == 'scheduled' || st == 'pending' || st == 'in_progress' || st == 'requested';
      }).toList();
      final paymentMap = <String, PaymentDto>{};
      if (upcomingForPayments.isNotEmpty) {
        final payResults = await Future.wait(upcomingForPayments.map((s) async {
          try {
            final p = await _api.fetchPaymentForSession(s.id).timeout(const Duration(seconds: 6));
            return MapEntry<String, PaymentDto?>(s.id, p);
          } catch (_) {
            return MapEntry<String, PaymentDto?>(s.id, null);
          }
        }));
        for (final e in payResults) {
          final p = e.value;
          if (p != null) paymentMap[e.key] = p;
        }
      }

      if (!mounted) return;
      setState(() {
        _user = user;
        _sessions = sess;
        _bookings = books;
        _careActions = actions;
        _doctorsById = doctorMap;
        _paymentsBySessionId = paymentMap;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = messageFromDioException(e) ?? 'Failed to load.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load.';
      });
    }
  }

  bool _paymentCompleted(PaymentDto? p) {
    final st = (p?.status ?? '').toLowerCase().trim();
    return st == 'paid' || st == 'completed' || st == 'success' || st == 'successful';
  }

  bool _paymentInReview(PaymentDto? p) {
    final st = (p?.status ?? '').toLowerCase().trim();
    final hasProof = (p?.proofSubmittedAt ?? '').trim().isNotEmpty;
    return st == 'in_review' ||
        st == 'in-review' ||
        st == 'pending_review' ||
        (hasProof && !_paymentCompleted(p));
  }

  bool _isJoinable(SessionDto s) {
    final st = s.status.toLowerCase().trim();
    if (st == 'cancelled' || st == 'completed' || st == 'no_show' || st == 'no-show') return false;
    final link = (s.meetingLink ?? '').trim();
    if (link.isEmpty) return false;
    final dt = DateTime.tryParse((s.scheduledAt ?? '').trim())?.toLocal();
    if (dt == null) return st == 'pending' || st == 'scheduled';
    final diff = dt.difference(DateTime.now());
    return diff.inMinutes <= 30 && diff.inMinutes >= -120;
  }

  Future<void> _openDetail(SessionDto s, BookingDto? b) async {
    final doctor = (s.doctorId ?? '').isNotEmpty ? _doctorsById[s.doctorId!] : null;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => AppointmentDetailScreen(
          session: s,
          booking: b,
          doctor: doctor,
          payment: _paymentsBySessionId[s.id],
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) await _load();
  }

  Future<void> _openPay(SessionDto s) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => PaymentsScreen(initialSessionId: s.id)),
    );
    if (!mounted) return;
    await _load();
  }

  bool _isUpcomingSession(SessionDto s) {
    final st = s.status.toLowerCase().trim();
    if (st == 'cancelled' || st == 'completed' || st == 'no_show' || st == 'no-show') {
      return false;
    }
    final dt = DateTime.tryParse((s.scheduledAt ?? '').trim())?.toLocal();
    if (dt == null) {
      return st == 'pending' || st == 'scheduled' || st == 'requested' || st == 'in_progress';
    }
    return dt.isAfter(DateTime.now().subtract(const Duration(hours: 2)));
  }

  bool _isCompletedSession(SessionDto s) {
    final st = s.status.toLowerCase().trim();
    return st == 'completed' || st == 'done' || st == 'finished';
  }

  bool _isMissedSession(SessionDto s) {
    final st = s.status.toLowerCase().trim();
    return st == 'no_show' || st == 'no-show';
  }

  List<SessionDto> get _filteredSessions {
    final List<SessionDto> list;
    if (_tab == _AppointmentsTab.upcoming) {
      list = _sessions.where(_isUpcomingSession).toList();
    } else if (_tab == _AppointmentsTab.completed) {
      list = _sessions.where(_isCompletedSession).toList();
    } else {
      list = _sessions.where(_isMissedSession).toList();
    }

    list.sort((a, b) {
      final da = DateTime.tryParse((a.scheduledAt ?? '').trim())?.toLocal();
      final db = DateTime.tryParse((b.scheduledAt ?? '').trim())?.toLocal();
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return _tab == _AppointmentsTab.upcoming ? da.compareTo(db) : db.compareTo(da);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final care = _careActions;
    final careCount = (care == null)
        ? 0
        : (care.pendingTransfers.length + care.unavailabilityImpacts.length);
    final followUpSessions = (user?.isClient == true)
        ? _sessions.where((s) {
            if (s.clientId != user!.id) return false;
            final notes = (s.notes ?? '');
            if (!notes.contains('FOLLOW_UP_REQUESTED')) return false;
            final st = (s.status).toLowerCase().trim();
            return st == 'completed';
          }).toList()
        : const <SessionDto>[];

    final upcomingCount = _sessions.where(_isUpcomingSession).length;
    final completedCount = _sessions.where(_isCompletedSession).length;
    final missedCount = _sessions.where(_isMissedSession).length;
    final filtered = _filteredSessions;

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
                      children: [
                        if (user?.isClient == true && careCount > 0) ...[
                          _tile(
                            context,
                            title: 'Action required ($careCount)',
                            subtitle:
                                'Your specialist requested a transfer or is unavailable.\nTap to choose: transfer or reschedule.',
                            onTap: () async {
                              await Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(builder: (_) => const CareActionsScreen()),
                              );
                              await _load();
                            },
                            actionHint: 'Tap to resolve transfer/reschedule',
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (followUpSessions.isNotEmpty) ...[
                          Text(
                            'Follow-up requested',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: SmartAfyaPalette.deepText,
                                ),
                          ),
                          const SizedBox(height: 10),
                          ...followUpSessions.map((s) {
                            final dateUtc = _parseFollowUpSuggestedDateUtc(s.notes);
                            final dateLabel = (dateUtc == null)
                                ? 'Suggested date: —'
                                : 'Suggested date: ${dateUtc.toLocal().year}-${dateUtc.toLocal().month.toString().padLeft(2, '0')}-${dateUtc.toLocal().day.toString().padLeft(2, '0')}';
                            return _tile(
                              context,
                              title: 'Doctor recommended another session',
                              subtitle: '$dateLabel\nTap to choose your availability & proceed.',
                              onTap: () async {
                                final ok = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute<bool>(
                                    builder: (_) => CreateBookingScreen(
                                      preferredSpecialistId: (s.doctorId ?? '').trim().isEmpty ? null : s.doctorId,
                                      initialDescription: 'Follow-up session requested by doctor.',
                                      initialDurationMinutes: null,
                                      durationLocked: false,
                                      requireAvailabilityConfirmation: true,
                                    ),
                                  ),
                                );
                                if (ok == true && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Follow-up booking submitted.')),
                                  );
                                  await _load();
                                }
                              },
                              actionHint: 'Tap to choose availability & proceed',
                            );
                          }),
                          const SizedBox(height: 16),
                        ],
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
                          ...filtered.map((s) {
                            final b = _bookingForSession(s);
                            return _sessionTile(s, b);
                          }),
                        if (_tab == _AppointmentsTab.upcoming && _bookings.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Text(
                            _user?.isDoctor == true ? 'All bookings (coordination)' : 'Pending requests',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: SmartAfyaPalette.deepText,
                                ),
                          ),
                          const SizedBox(height: 8),
                          ..._bookings
                              .where((b) {
                                final st = b.status.toLowerCase().trim();
                                return st != 'cancelled';
                              })
                              .map((b) => _tile(
                                    context,
                                    title: 'Booking · ${b.status}',
                                    subtitle:
                                        'Type: ${_friendlyType(b.sessionType)}\nPreferred: ${b.preferredDatesRaw.length > 40 ? "${b.preferredDatesRaw.substring(0, 40)}…" : b.preferredDatesRaw}',
                                  )),
                        ],
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    final isUpcoming = _tab == _AppointmentsTab.upcoming;
    final isMissed = _tab == _AppointmentsTab.missed;
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
                ? 'Book a consultation to get started.'
                : isMissed
                    ? 'When a session is marked missed, it will appear here. You can reschedule anytime.'
                    : 'Finished consultations appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SmartAfyaPalette.mutedText.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
              height: 1.35,
              fontSize: 12.5,
            ),
          ),
          if (isUpcoming && _user?.isClient == true) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(
                    builder: (_) => const CreateBookingScreen(
                      initialSessionType: 'video',
                      initialDurationMinutes: 60,
                    ),
                  ),
                );
                if (ok == true && mounted) await _load();
              },
              style: FilledButton.styleFrom(
                backgroundColor: SmartAfyaPalette.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Book a consultation', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sessionTile(SessionDto s, BookingDto? b) {
    final isClientPhysical =
        _user?.isClient == true && (b?.sessionType ?? '').toLowerCase().trim() == 'physical';
    final stNorm = s.status.toLowerCase().trim();
    final isCompleted = stNorm == 'completed';
    final isMissed = stNorm == 'no_show' || stNorm == 'no-show';
    final notes = s.notes ?? '';
    final hasReport = notes.contains('CONSULTATION_REPORT:');

    final dt = DateTime.tryParse((s.scheduledAt ?? '').trim())?.toLocal();
    final dateLabel = dt == null ? 'TBD' : _formatShortDate(dt);
    final timeLabel = dt == null ? '' : _formatTime(dt);
    final typeLabel = _friendlyType(b?.sessionType);
    final statusInfo = _statusBadge(s.status);

    final doctor = (s.doctorId ?? '').isNotEmpty ? _doctorsById[s.doctorId!] : null;
    final specialistName = (doctor?.fullName.trim().isNotEmpty == true)
        ? doctor!.fullName.trim()
        : ((s.doctorId ?? '').isNotEmpty ? 'Specialist assigned' : 'Awaiting specialist');
    final specialtyLabel = doctor?.specialistLabel ?? 'Mental health specialist';
    final initials = _initials(doctor?.fullName);

    final payment = _paymentsBySessionId[s.id];
    final paymentDone = _paymentCompleted(payment);
    final paymentReview = _paymentInReview(payment);

    final isUpcomingTab = _tab == _AppointmentsTab.upcoming;
    final needsPayment = isUpcomingTab && !paymentDone && !paymentReview && !isCompleted && !isMissed;
    final joinable = isUpcomingTab && _isJoinable(s);

    // Decide the per-row CTA label/icon/handler.
    String ctaLabel;
    IconData ctaIcon;
    VoidCallback? ctaOnPressed;

    if (isClientPhysical && b != null && isUpcomingTab) {
      ctaLabel = 'View';
      ctaIcon = Icons.arrow_forward_rounded;
      ctaOnPressed = () => showClientPhysicalBookingActions(
            context: context,
            session: s,
            booking: b,
            api: _api,
            onDone: _load,
          );
    } else if (isMissed && _user?.isClient == true) {
      ctaLabel = 'Reschedule';
      ctaIcon = Icons.event_repeat_rounded;
      ctaOnPressed = () async {
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const CreateBookingScreen(
              initialSessionType: 'video',
              initialDurationMinutes: 60,
            ),
          ),
        );
        await _load();
      };
    } else if (needsPayment) {
      ctaLabel = 'Pay';
      ctaIcon = Icons.payments_rounded;
      ctaOnPressed = () => _openPay(s);
    } else if (joinable) {
      ctaLabel = 'Join';
      ctaIcon = Icons.video_call_rounded;
      ctaOnPressed = () => _openDetail(s, b);
    } else if (isCompleted && hasReport && _user?.isClient == true) {
      ctaLabel = 'Feedback';
      ctaIcon = Icons.rate_review_rounded;
      ctaOnPressed = () async {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute<bool>(builder: (_) => ClientSessionFeedbackScreen(session: s)),
        );
        await _load();
      };
    } else {
      ctaLabel = 'View';
      ctaIcon = Icons.arrow_forward_rounded;
      ctaOnPressed = () => _openDetail(s, b);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openDetail(s, b),
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
                // Specialist row + status pill
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
                            specialistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: SmartAfyaPalette.deepText,
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            specialtyLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: SmartAfyaPalette.mutedText,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusPillTile(label: statusInfo.label, color: statusInfo.color),
                  ],
                ),
                const SizedBox(height: 12),
                // Meta row: date · time · type
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _metaChip(Icons.event_rounded, dateLabel),
                    if (timeLabel.isNotEmpty) _metaChip(Icons.schedule_rounded, timeLabel),
                    _metaChip(_typeIcon(b?.sessionType), _shortType(typeLabel)),
                    if (isUpcomingTab && payment != null)
                      _metaChip(
                        Icons.payments_rounded,
                        paymentDone ? 'Paid' : (paymentReview ? 'In review' : 'Pay needed'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Per-row contextual action button
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: ctaOnPressed,
                        style: FilledButton.styleFrom(
                          backgroundColor: SmartAfyaPalette.primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        icon: Icon(ctaIcon, size: 16),
                        label: Text(ctaLabel,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
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

  static String _initials(String? fullName) {
    final s = (fullName ?? '').trim();
    if (s.isEmpty) return '?';
    final parts = s.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static String _shortType(String full) {
    if (full.toLowerCase().contains('video')) return 'Online';
    if (full.toLowerCase().contains('audio')) return 'Audio';
    if (full.toLowerCase().contains('in-person') || full.toLowerCase().contains('physical')) {
      return 'In-person';
    }
    return 'Online';
  }

  static String _formatShortDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  static String _formatTime(DateTime dt) {
    final hour12 = (dt.hour % 12 == 0) ? 12 : dt.hour % 12;
    final hourStr = hour12.toString().padLeft(2, '0');
    final minStr = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hourStr:$minStr $ampm';
  }

  BookingDto? _bookingForSession(SessionDto s) {
    for (final b in _bookings) {
      if (b.id == s.bookingId) return b;
    }
    return null;
  }

  Widget _tile(
    BuildContext context, {
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    String? actionHint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE4EEF7)),
              boxShadow: const [
                BoxShadow(color: Color(0x0D2A5F8A), blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText))),
                    if (onTap != null)
                      const Icon(Icons.chevron_right_rounded,
                          color: SmartAfyaPalette.mutedText, size: 22),
                  ],
                ),
                const SizedBox(height: 6),
                Text(subtitle,
                    style: const TextStyle(
                        color: SmartAfyaPalette.mutedText, height: 1.35, fontSize: 13)),
                if (onTap != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      actionHint ?? 'Tap for cancel / reschedule',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: SmartAfyaPalette.primaryBlue),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
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

  static ({String label, Color color}) _statusBadge(String status) {
    final s = status.toLowerCase().trim();
    if (s == 'completed') {
      return (label: 'Completed', color: SmartAfyaPalette.primaryGreen);
    }
    if (s == 'no_show' || s == 'no-show') {
      return (label: 'Missed', color: const Color(0xFFC45C5C));
    }
    if (s == 'cancelled') {
      return (label: 'Cancelled', color: const Color(0xFFB23A3A));
    }
    if (s == 'in_progress' || s == 'in-progress') {
      return (label: 'In progress', color: SmartAfyaPalette.primaryBlue);
    }
    if (s == 'scheduled') {
      return (label: 'Scheduled', color: SmartAfyaPalette.primaryBlue);
    }
    if (s == 'pending' || s == 'requested') {
      return (label: 'Pending', color: const Color(0xFFD08600));
    }
    return (label: status, color: SmartAfyaPalette.mutedText);
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

  final _AppointmentsTab tab;
  final int upcomingCount;
  final int completedCount;
  final int missedCount;
  final ValueChanged<_AppointmentsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4EEF7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segment(
              context,
              label: 'Upcoming',
              count: upcomingCount,
              selected: tab == _AppointmentsTab.upcoming,
              onTap: () => onChanged(_AppointmentsTab.upcoming),
            ),
          ),
          Expanded(
            child: _segment(
              context,
              label: 'Completed',
              count: completedCount,
              selected: tab == _AppointmentsTab.completed,
              onTap: () => onChanged(_AppointmentsTab.completed),
            ),
          ),
          Expanded(
            child: _segment(
              context,
              label: 'Missed',
              count: missedCount,
              selected: tab == _AppointmentsTab.missed,
              onTap: () => onChanged(_AppointmentsTab.missed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? SmartAfyaPalette.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : SmartAfyaPalette.deepText,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.22)
                    : const Color(0xFFE9F1FA),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : SmartAfyaPalette.primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPillTile extends StatelessWidget {
  const _StatusPillTile({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

DateTime? _parseFollowUpSuggestedDateUtc(String? notes) {
  final s = (notes ?? '');
  final m = RegExp(r'FOLLOW_UP_SUGGESTED_(?:DATE|AT)_UTC:\s*([^\s]+)').firstMatch(s);
  if (m == null) return null;
  return DateTime.tryParse(m.group(1) ?? '')?.toUtc();
}
