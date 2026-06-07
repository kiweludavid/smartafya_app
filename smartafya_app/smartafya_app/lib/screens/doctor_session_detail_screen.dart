import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';
import 'doctor_consultation_report_screen.dart';
import 'doctor_home_dashboard.dart';

class DoctorSessionDetailScreen extends StatefulWidget {
  const DoctorSessionDetailScreen({
    super.key,
    required this.session,
    required this.booking,
    required this.onSessionUpdated,
    this.initialAction,
  });

  final SessionDto session;
  final BookingDto? booking;
  final void Function(SessionDto updated) onSessionUpdated;

  /// Optional deep-link: opens transfer flow when `'transfer'`.
  final String? initialAction;

  @override
  State<DoctorSessionDetailScreen> createState() => _DoctorSessionDetailScreenState();
}

class _DoctorSessionDetailScreenState extends State<DoctorSessionDetailScreen> {
  late SessionDto _session = widget.session;
  bool _busy = false;
  final _api = ApiService();
  List<TransferLogDto> _transferHistory = const [];
  bool _historyLoading = false;
  PatientTransferRequestDto? _pendingTransferRequest;
  bool _pendingTransferLoading = false;

  static const _hairline = Color(0xFFE4EEF7);
  static const _cardShadow = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 6)),
  ];

  bool get _isPhysical {
    final t = (widget.booking?.sessionType ?? '').toLowerCase().trim();
    return t == 'physical';
  }

  bool get _canJoin {
    if (_isPhysical) return false;
    final link = (_session.meetingLink ?? '').trim();
    if (link.isEmpty) return false;
    final st = _session.status.toLowerCase();
    return st != 'completed' && st != 'cancelled' && st != 'transferred' && st != 'no_show';
  }

  static DateTime? _parseLocal(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    final dt = DateTime.tryParse(iso);
    return dt?.toLocal();
  }

  static String _venueLabel(String? v) {
    final s = (v ?? '').toLowerCase();
    if (s == 'home') return 'Home visit';
    if (s == 'office') return 'Office / clinic';
    if (s.isEmpty) return '—';
    return v!;
  }

  static String _displayStatus(SessionDto s) => DoctorHomeDashboard.displayStatusForSession(s);

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

  static String _friendlyType(String? type) {
    final s = (type ?? '').toLowerCase().trim();
    if (s == 'video') return 'Video consultation';
    if (s == 'audio') return 'Audio consultation';
    if (s == 'physical') return 'In-person visit';
    return 'Consultation';
  }

  static IconData _typeIcon(String? type) {
    final s = (type ?? '').toLowerCase().trim();
    if (s == 'video') return Icons.videocam_rounded;
    if (s == 'audio') return Icons.call_rounded;
    if (s == 'physical') return Icons.place_rounded;
    return Icons.event_rounded;
  }

  static String _patientInitials(String clientId) {
    final id = clientId.trim();
    if (id.length >= 2) return id.substring(id.length - 2).toUpperCase();
    return 'PT';
  }

  static String _filterReadableNotes(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return '';
    return s
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
  }

  ({String label, Color color}) _statusBadge(String statusLabel) {
    final s = statusLabel.trim();
    if (s == 'Completed') return (label: s, color: SmartAfyaPalette.primaryGreen);
    if (s == 'Cancelled') return (label: s, color: const Color(0xFFB23A3A));
    if (s == 'Missed' || s == 'Overdue') return (label: s, color: const Color(0xFFE65100));
    if (s == 'Ongoing') return (label: s, color: SmartAfyaPalette.primaryBlue);
    if (s == 'Transferred') return (label: s, color: SmartAfyaPalette.mutedText);
    return (label: s.isEmpty ? '—' : s, color: SmartAfyaPalette.primaryBlue);
  }

  Future<void> _openMeeting(String? link) async {
    if (link == null || link.trim().isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTransferHistory();
    _loadPendingTransferRequest();
    _refreshSessionSilently();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final a = (widget.initialAction ?? '').toLowerCase().trim();
      if (a == 'transfer') {
        _openTransferPatientFlow();
        return;
      }
    });
  }

  /// Pull the latest session record so the screen never reflects stale data
  /// from a parent list cache (e.g. when returning to a sessions list and
  /// re-opening a session that was just changed).
  Future<void> _refreshSessionSilently() async {
    try {
      final fresh = await _api.fetchSessionById(_session.id).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (fresh.status != _session.status || (fresh.notes ?? '') != (_session.notes ?? '')) {
        setState(() => _session = fresh);
        widget.onSessionUpdated(fresh);
      }
    } catch (_) {
      // Silent — initial widget.session is still valid for display.
    }
  }

  Future<void> _loadPendingTransferRequest() async {
    setState(() => _pendingTransferLoading = true);
    try {
      final row = await _api.fetchPendingTransferRequest(_session.id).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() => _pendingTransferRequest = row);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingTransferRequest = null);
    } finally {
      if (mounted) setState(() => _pendingTransferLoading = false);
    }
  }

  Future<void> _loadTransferHistory() async {
    setState(() => _historyLoading = true);
    try {
      final history = await _api.fetchTransferHistory(_session.id).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      history.sort((a, b) => (b.transferredAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.transferredAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
      setState(() => _transferHistory = history);
    } catch (_) {
      if (!mounted) return;
      setState(() => _transferHistory = const []);
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<void> _openTransferPatientFlow() async {
    if (_busy) return;
    final me = await _api.fetchCurrentUser().timeout(const Duration(seconds: 8));
    if (!mounted) return;

    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Transfer patient'),
          content: TextField(
            controller: reasonController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Reason for transfer',
              hintText: 'Required — shared with patient and admin',
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final t = reasonController.text.trim();
                if (t.isEmpty) return;
                Navigator.pop(ctx, t);
              },
              style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
              child: const Text('Next'),
            ),
          ],
        );
      },
    );
    reasonController.dispose();
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _busy = true);
    List<DoctorDto> doctors;
    try {
      final spec = (me.specialistType ?? '').trim();
      doctors = await _api
          .fetchDoctors(
            availableOnly: true,
            specialistType: spec.isNotEmpty ? spec : null,
            excludeDoctorId: me.id,
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load specialists.')));
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (doctors.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No available specialists match your specialty.')));
      return;
    }

    if (!mounted) return;
    final toDoctorId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 10, 8, 12),
                child: Text('Select new specialist', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              ...doctors.map(
                (d) => ListTile(
                  leading: const Icon(Icons.medical_services_outlined, color: SmartAfyaPalette.primaryBlue),
                  title: Text(d.fullName.isNotEmpty ? d.fullName : 'Specialist', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    d.specialistLabel,
                    style: const TextStyle(color: SmartAfyaPalette.mutedText),
                  ),
                  trailing: const Icon(Icons.check_circle_rounded, color: SmartAfyaPalette.primaryGreen),
                  onTap: () => Navigator.pop(ctx, d.id),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (toDoctorId == null || toDoctorId.trim().isEmpty) return;

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Send request to patient?'),
          content: const Text(
            'The patient must accept or decline. Session notes and history stay on the case. Admin is notified automatically.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
              child: const Text('Send request'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await _api
          .requestPatientTransfer(sessionId: _session.id, toDoctorId: toDoctorId, reason: reason)
          .timeout(const Duration(seconds: 12));
      await _loadPendingTransferRequest();
      await _loadTransferHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer request sent. Awaiting patient approval.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDioException(e) ?? 'Transfer request failed.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer request failed.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _physicalCheckIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await _api.physicalCheckIn(_session.id).timeout(const Duration(seconds: 12));
      widget.onSessionUpdated(updated);
      if (mounted) setState(() => _session = updated);
      await NotificationService.physicalWorkflow(title: 'Checked in', body: 'Visit start time recorded for this session.');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-in recorded.')));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDioException(e) ?? 'Check-in failed.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _physicalCheckOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await _api.physicalCheckOut(_session.id).timeout(const Duration(seconds: 12));
      widget.onSessionUpdated(updated);
      if (mounted) setState(() => _session = updated);
      await NotificationService.physicalWorkflow(title: 'Checked out', body: 'Visit end time recorded.');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-out recorded.')));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDioException(e) ?? 'Check-out failed.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openReport() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => DoctorConsultationReportScreen(session: _session, booking: widget.booking),
      ),
    );
    if (ok == true) {
      final updated = await _api.patchSession(_session.id).timeout(const Duration(seconds: 10));
      widget.onSessionUpdated(updated);
      if (mounted) setState(() => _session = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted.')));
      }
    }
  }

  bool get _canDoctorMarkCompleted {
    final st = _session.status.toLowerCase();
    return st != 'completed' && st != 'cancelled' && st != 'no_show' && st != 'transferred';
  }

  /// Includes correcting an erroneous [completed] session when no consultation report exists.
  bool get _canDoctorMarkMissed {
    final st = _session.status.toLowerCase();
    if (st == 'cancelled' || st == 'no_show' || st == 'transferred') return false;
    if (st == 'completed') {
      final notes = _session.notes ?? '';
      return !notes.contains('CONSULTATION_REPORT:');
    }
    return true;
  }

  Future<void> _markCompleted() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await _api.patchSession(_session.id, status: 'completed').timeout(const Duration(seconds: 12));
      widget.onSessionUpdated(updated);
      if (mounted) setState(() => _session = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked completed.')));
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDioException(e) ?? 'Could not update session.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update session.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markNoShow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await _api.patchSession(_session.id, status: 'no_show').timeout(const Duration(seconds: 12));
      widget.onSessionUpdated(updated);
      if (mounted) setState(() => _session = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as missed (no-show).')));
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDioException(e) ?? 'Could not update session.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update session.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = DoctorHomeDashboard.patientLabel(_session.clientId);
    final initials = _patientInitials(_session.clientId);
    final statusLabel = _displayStatus(_session);
    final statusInfo = _statusBadge(statusLabel);
    final dt = _parseLocal(_session.scheduledAt);
    final dateLabel = dt == null ? 'Time to be confirmed' : _formatDate(dt);
    final timeLabel = dt == null ? '' : _formatTime(dt);
    final typeLabel = _friendlyType(widget.booking?.sessionType);
    final typeIcon = _typeIcon(widget.booking?.sessionType);
    final stateOfMind = (widget.booking?.mentalHealthDescription ?? '').trim();
    final filteredNotes = _filterReadableNotes(_session.notes);
    final bookingStatus = (widget.booking?.status ?? '').trim();

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
          onRefresh: _refreshSessionSilently,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
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
                            patient,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: SmartAfyaPalette.deepText,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            typeLabel,
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
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(label: 'Appointment'),
                    const SizedBox(height: 10),
                    _DetailRow(icon: Icons.event_rounded, label: 'Date', value: dateLabel),
                    if (timeLabel.isNotEmpty) _DetailRow(icon: Icons.schedule_rounded, label: 'Time', value: timeLabel),
                    _DetailRow(icon: typeIcon, label: 'Type', value: typeLabel),
                    if (bookingStatus.isNotEmpty)
                      _DetailRow(icon: Icons.assignment_rounded, label: 'Booking', value: bookingStatus),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 28,
                            child: Icon(Icons.flag_rounded, size: 18, color: SmartAfyaPalette.mutedText),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Status',
                            style: TextStyle(
                              color: SmartAfyaPalette.mutedText,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          _Pill(label: statusInfo.label, color: statusInfo.color),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (stateOfMind.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(label: 'State of mind'),
                      const SizedBox(height: 10),
                      Text(
                        stateOfMind,
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
              if (_canJoin)
                _PrimaryButton(
                  icon: Icons.videocam_rounded,
                  label: 'Join session',
                  onPressed: _busy ? null : () => _openMeeting(_session.meetingLink),
                )
              else if (!_isPhysical)
                _PrimaryButton(
                  icon: Icons.lock_clock_rounded,
                  label: 'Session not yet joinable',
                  onPressed: null,
                ),
              const SizedBox(height: 10),
              _PrimaryButton(
                icon: Icons.description_rounded,
                label: 'Submit report',
                onPressed: _busy ? null : _openReport,
                color: SmartAfyaPalette.primaryGreen,
              ),
              const SizedBox(height: 10),
              _SecondaryButton(
                icon: Icons.swap_horiz_rounded,
                label: 'Transfer patient',
                onPressed: _busy ? null : _openTransferPatientFlow,
              ),
              if (_canDoctorMarkMissed || _canDoctorMarkCompleted) ...[
                const SizedBox(height: 10),
                if (_canDoctorMarkMissed && _canDoctorMarkCompleted)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : _markNoShow,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB71C1C),
                            side: const BorderSide(color: Color(0xFFFFCDD2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Mark missed', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy ? null : _markCompleted,
                          style: FilledButton.styleFrom(
                            backgroundColor: SmartAfyaPalette.primaryGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Mark completed', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  )
                else if (_canDoctorMarkMissed)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _busy ? null : _markNoShow,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB71C1C),
                        side: const BorderSide(color: Color(0xFFFFCDD2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        _session.status.toLowerCase() == 'completed'
                            ? 'Correct to missed (no-show)'
                            : 'Mark missed',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
              ],
              if (_pendingTransferLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: LinearProgressIndicator(minHeight: 3),
                )
              else if (_pendingTransferRequest != null) ...[
                const SizedBox(height: 14),
                _Card(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.hourglass_top_rounded, color: Color(0xFFB8860B)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Transfer pending',
                              style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Waiting for patient approval.',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: SmartAfyaPalette.mutedText,
                                height: 1.3,
                              ),
                            ),
                            if (_pendingTransferRequest!.reason.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Reason: ${_pendingTransferRequest!.reason}',
                                style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_isPhysical) ...[
                const SizedBox(height: 14),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(label: 'Visit location'),
                      const SizedBox(height: 10),
                      _DetailRow(
                        icon: Icons.place_rounded,
                        label: 'Address',
                        value: (widget.booking?.physicalLocationAddress ?? '').trim().isEmpty
                            ? '—'
                            : widget.booking!.physicalLocationAddress!.trim(),
                      ),
                      _DetailRow(
                        icon: Icons.home_work_rounded,
                        label: 'Site',
                        value: _venueLabel(widget.booking?.physicalVenue),
                      ),
                      if ((widget.booking?.physicalNotes ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.booking!.physicalNotes!.trim(),
                          style: const TextStyle(
                            color: SmartAfyaPalette.mutedText,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if ((_session.meetingLink ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _SecondaryButton(
                          icon: Icons.map_rounded,
                          label: 'Open in Maps',
                          onPressed: _busy ? null : () => _openMeeting(_session.meetingLink),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(label: 'Visit check-in'),
                      const SizedBox(height: 10),
                      _DetailRow(
                        icon: Icons.login_rounded,
                        label: 'Check-in',
                        value: _session.checkInAt ?? '—',
                      ),
                      _DetailRow(
                        icon: Icons.logout_rounded,
                        label: 'Check-out',
                        value: _session.checkOutAt ?? '—',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy ? null : _physicalCheckIn,
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Check in', style: TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _busy ? null : _physicalCheckOut,
                              style: FilledButton.styleFrom(
                                backgroundColor: SmartAfyaPalette.primaryGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Check out', style: TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
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
              const SizedBox(height: 14),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: _SectionTitle(label: 'Transfer history')),
                        IconButton(
                          onPressed: _historyLoading ? null : _loadTransferHistory,
                          icon: const Icon(Icons.refresh_rounded, color: SmartAfyaPalette.mutedText),
                          tooltip: 'Refresh history',
                        ),
                      ],
                    ),
                    if (_historyLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: LinearProgressIndicator(minHeight: 3),
                      )
                    else if (_transferHistory.isEmpty)
                      const Text(
                        'No transfers for this session yet.',
                        style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600),
                      )
                    else
                      Column(
                        children: _transferHistory
                            .map(
                              (t) => Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7FAFD),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _hairline),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'From …${t.fromDoctorId.length > 6 ? t.fromDoctorId.substring(t.fromDoctorId.length - 6) : t.fromDoctorId} → To …${t.toDoctorId.length > 6 ? t.toDoctorId.substring(t.toDoctorId.length - 6) : t.toDoctorId}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: SmartAfyaPalette.deepText,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        t.transferredAt == null ? 'Time: —' : 'Time: ${t.transferredAt}',
                                        style: const TextStyle(
                                          color: SmartAfyaPalette.mutedText,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if ((t.reason ?? '').trim().isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Reason: ${t.reason}',
                                          style: const TextStyle(
                                            color: SmartAfyaPalette.mutedText,
                                            height: 1.25,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
          Text(
            label,
            style: const TextStyle(
              color: SmartAfyaPalette.mutedText,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
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
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = SmartAfyaPalette.primaryBlue,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.30),
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
          foregroundColor: SmartAfyaPalette.primaryBlue,
          side: BorderSide(color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
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
        border: Border.all(color: _DoctorSessionDetailScreenState._hairline),
        boxShadow: _DoctorSessionDetailScreenState._cardShadow,
      ),
      child: child,
    );
  }
}

