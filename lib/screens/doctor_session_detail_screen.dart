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

  static String _venueLabel(String? v) {
    final s = (v ?? '').toLowerCase();
    if (s == 'home') return 'Home visit';
    if (s == 'office') return 'Office / clinic';
    if (s.isEmpty) return '—';
    return v!;
  }

  static String _sessionTypeFromBooking(BookingDto? booking) {
    final t = (booking?.sessionType ?? '').toLowerCase().trim();
    if (t == 'video') return 'Video';
    if (t == 'audio') return 'Audio';
    if (t == 'physical') return 'Physical';
    return t.isEmpty ? '—' : t;
  }

  static String _displayStatus(SessionDto s) {
    final st = s.status.toLowerCase();
    if (st == 'completed') return 'Completed';
    if (st == 'cancelled') return 'Cancelled';
    if (st == 'no_show') return 'Missed';
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
    final type = _sessionTypeFromBooking(widget.booking);
    final status = _displayStatus(_session);
    final when = _formatDateTime(_session.scheduledAt);

    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        title: const Text('Session details'),
        backgroundColor: SmartAfyaPalette.scaffoldBg,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _Card(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: SmartAfyaPalette.softBlue,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.person_rounded, color: SmartAfyaPalette.primaryBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patient, style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText, fontSize: 17)),
                        const SizedBox(height: 4),
                        Text('$type session', style: const TextStyle(fontWeight: FontWeight.w700, color: SmartAfyaPalette.mutedText)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(when, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: SmartAfyaPalette.deepText)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StatusChip(label: status),
                    ],
                  ),
                ],
              ),
            ),
            if (_canDoctorMarkMissed || _canDoctorMarkCompleted) ...[
              const SizedBox(height: 12),
              if (_canDoctorMarkMissed && _canDoctorMarkCompleted)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _markNoShow,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB71C1C),
                          side: const BorderSide(color: Color(0xFFFFCDD2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Mark completed', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                )
              else if (_canDoctorMarkMissed)
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _busy ? null : _markNoShow,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB71C1C),
                      side: const BorderSide(color: Color(0xFFFFCDD2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canJoin ? () => _openMeeting(_session.meetingLink) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: SmartAfyaPalette.primaryBlue,
                  disabledBackgroundColor: const Color(0xFFCBD6E2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.videocam_rounded),
                label: const Text('Join session', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _openReport,
                style: FilledButton.styleFrom(
                  backgroundColor: SmartAfyaPalette.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Submit report', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _openTransferPatientFlow,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Transfer patient', style: TextStyle(fontWeight: FontWeight.w900)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.35)),
                  foregroundColor: SmartAfyaPalette.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_pendingTransferLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 3),
              )
            else if (_pendingTransferRequest != null) ...[
              _Card(
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top_rounded, color: Color(0xFFB8860B)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Transfer status',
                            style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Requested — waiting for patient approval.',
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
              const SizedBox(height: 12),
            ],
            if (_isPhysical) ...[
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Visit location', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(
                      (widget.booking?.physicalLocationAddress ?? '').trim().isEmpty
                          ? '—'
                          : widget.booking!.physicalLocationAddress!.trim(),
                      style: const TextStyle(color: SmartAfyaPalette.mutedText, height: 1.35, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Site: ${_venueLabel(widget.booking?.physicalVenue)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if ((widget.booking?.physicalNotes ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.booking!.physicalNotes!.trim(),
                        style: const TextStyle(color: SmartAfyaPalette.mutedText, height: 1.35),
                      ),
                    ],
                    if ((_session.meetingLink ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _openMeeting(_session.meetingLink),
                        icon: const Icon(Icons.map_rounded),
                        style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                        label: const Text('Open in Maps', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Visit timestamps', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(
                      'Check-in: ${_session.checkInAt ?? "—"}',
                      style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Check-out: ${_session.checkOutAt ?? "—"}',
                      style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy ? null : _physicalCheckIn,
                            child: const Text('Check in', style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy ? null : _physicalCheckOut,
                            style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryGreen),
                            child: const Text('Check out', style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notes / history', style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText)),
                  const SizedBox(height: 8),
                  Text(
                    (_session.notes ?? '').trim().isEmpty ? 'No notes yet.' : (_session.notes ?? '').trim(),
                    style: const TextStyle(color: SmartAfyaPalette.mutedText, height: 1.35, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Transfer history', style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText)),
                      ),
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
                                      style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      t.transferredAt == null ? 'Time: —' : 'Time: ${t.transferredAt}',
                                      style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600),
                                    ),
                                    if ((t.reason ?? '').trim().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Reason: ${t.reason}',
                                        style: const TextStyle(color: SmartAfyaPalette.mutedText, height: 1.25, fontWeight: FontWeight.w600),
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
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = label.trim();
    final isCompleted = s == 'Completed';
    final isMissed = s == 'Missed';
    final isOngoing = s == 'Ongoing';
    final isUpcoming = s == 'Upcoming' || s == 'Requested';
    final bg = isCompleted
        ? SmartAfyaPalette.primaryGreen.withValues(alpha: 0.12)
        : isMissed
            ? const Color(0xFFFFF3E0)
            : isOngoing
                ? SmartAfyaPalette.primaryBlue.withValues(alpha: 0.12)
                : isUpcoming
                    ? SmartAfyaPalette.primaryBlue.withValues(alpha: 0.10)
                    : const Color(0xFFF7FAFD);
    final fg = isCompleted
        ? SmartAfyaPalette.primaryGreen
        : isMissed
            ? const Color(0xFFE65100)
            : isOngoing || isUpcoming
                ? SmartAfyaPalette.primaryBlue
                : SmartAfyaPalette.mutedText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(s, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: fg)),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _DoctorSessionDetailScreenState._hairline),
        boxShadow: _DoctorSessionDetailScreenState._cardShadow,
      ),
      child: child,
    );
  }
}

