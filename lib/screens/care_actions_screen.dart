import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';

class CareActionsScreen extends StatefulWidget {
  const CareActionsScreen({super.key});

  @override
  State<CareActionsScreen> createState() => _CareActionsScreenState();
}

class _CareActionsScreenState extends State<CareActionsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  CareActionsDto? _data;
  String? _busyId;

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
      final d = await _api.fetchCareActions().timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = messageFromDioException(e) ?? 'Could not load actions.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load actions.';
      });
    }
  }

  int get _pendingCount {
    final d = _data;
    if (d == null) return 0;
    return d.pendingTransfers.length + d.unavailabilityImpacts.length;
  }

  Future<void> _respondTransfer(PendingTransferActionDto t, bool accept) async {
    if ((_busyId ?? '').isNotEmpty) return;
    setState(() => _busyId = t.id);
    try {
      await _api.respondToTransferRequest(requestId: t.id, accept: accept).timeout(const Duration(seconds: 12));
      await NotificationService.physicalWorkflow(
        title: 'Transfer updated',
        body: accept ? 'You accepted the transfer.' : 'You declined the transfer.',
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? 'Transfer accepted.' : 'Transfer declined.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDioException(e) ?? 'Could not save your choice.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your choice.')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _resolveImpactTransfer(UnavailabilityImpactActionDto imp) async {
    if ((_busyId ?? '').isNotEmpty) return;
    if (imp.suggestedDoctors.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No replacement specialists available right now.')));
      return;
    }

    final pickedDoctorId = await showModalBottomSheet<String>(
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
                child: Text('Transfer to another specialist', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              ...imp.suggestedDoctors.map(
                (d) => ListTile(
                  leading: const Icon(Icons.medical_services_outlined, color: SmartAfyaPalette.primaryBlue),
                  title: Text(d.fullName.isEmpty ? 'Specialist' : d.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    (d.specialistType ?? '').trim().isEmpty ? 'Specialist' : d.specialistType!.replaceAll('_', ' '),
                    style: const TextStyle(color: SmartAfyaPalette.mutedText),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(ctx, d.id),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (pickedDoctorId == null || pickedDoctorId.trim().isEmpty) return;

    setState(() => _busyId = imp.id);
    try {
      await _api
          .resolveUnavailabilityImpact(
            impactId: imp.id,
            resolution: 'transfer',
            toDoctorId: pickedDoctorId.trim(),
          )
          .timeout(const Duration(seconds: 12));
      await NotificationService.physicalWorkflow(
        title: 'Appointment updated',
        body: 'Your session was transferred to a new specialist.',
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer saved.')));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDioException(e) ?? 'Could not save transfer choice.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save transfer choice.')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _resolveImpactReschedule(UnavailabilityImpactActionDto imp) async {
    if ((_busyId ?? '').isNotEmpty) return;
    DateTime? pickedUtc;

    if (imp.suggestedSlots.isNotEmpty) {
      final pickedIso = await showModalBottomSheet<String>(
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
                  child: Text('Pick a new time', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                ...imp.suggestedSlots.map(
                  (s) => ListTile(
                    leading: const Icon(Icons.schedule_rounded, color: SmartAfyaPalette.primaryGreen),
                    title: Text(s.scheduledAt, style: const TextStyle(fontWeight: FontWeight.w800)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pop(ctx, s.scheduledAt),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
      if (pickedIso != null && pickedIso.trim().isNotEmpty) {
        pickedUtc = DateTime.tryParse(pickedIso.trim())?.toUtc();
      }
    }

    pickedUtc ??= await _pickDateTimeUtc();
    if (pickedUtc == null) return;

    setState(() => _busyId = imp.id);
    try {
      await _api
          .resolveUnavailabilityImpact(
            impactId: imp.id,
            resolution: 'reschedule',
            newScheduledAtUtc: pickedUtc,
          )
          .timeout(const Duration(seconds: 12));
      await NotificationService.physicalWorkflow(
        title: 'Reschedule saved',
        body: 'Your new appointment time was saved.',
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reschedule saved.')));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDioException(e) ?? 'Could not save reschedule choice.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save reschedule choice.')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<DateTime?> _pickDateTimeUtc() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (d == null) return null;
    if (!mounted) return null;
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (t == null) return null;
    final local = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    return local.toUtc();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;

    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        title: const Text('Action required'),
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        foregroundColor: SmartAfyaPalette.deepText,
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
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : d == null || _pendingCount == 0
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
                          children: const [
                            Center(
                              child: Text(
                                'No actions right now.',
                                style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText, fontSize: 16),
                              ),
                            ),
                            SizedBox(height: 6),
                            Center(
                              child: Text(
                                'If your specialist requests a transfer or becomes unavailable, it will appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700, height: 1.35),
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: [
                            if (d.pendingTransfers.isNotEmpty) ...[
                              const _SectionTitle(title: 'Transfer approvals'),
                              const SizedBox(height: 10),
                              ...d.pendingTransfers.map((t) => _TransferCard(
                                    transfer: t,
                                    busy: _busyId == t.id,
                                    onAccept: () => _respondTransfer(t, true),
                                    onDecline: () => _respondTransfer(t, false),
                                  )),
                              const SizedBox(height: 16),
                            ],
                            if (d.unavailabilityImpacts.isNotEmpty) ...[
                              const _SectionTitle(title: 'Specialist unavailable'),
                              const SizedBox(height: 10),
                              ...d.unavailabilityImpacts.map((imp) => _UnavailabilityCard(
                                    impact: imp,
                                    busy: _busyId == imp.id,
                                    onTransfer: () => _resolveImpactTransfer(imp),
                                    onReschedule: () => _resolveImpactReschedule(imp),
                                  )),
                            ],
                          ],
                        ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: SmartAfyaPalette.deepText),
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({
    required this.transfer,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final PendingTransferActionDto transfer;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EEF7)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'From ${transfer.fromDoctorName} → ${transfer.toDoctorName}',
            style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
          ),
          const SizedBox(height: 6),
          Text(
            (transfer.reason).trim().isEmpty ? 'Reason: —' : 'Reason: ${transfer.reason}',
            style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700, height: 1.3),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onDecline,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: SmartAfyaPalette.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Accept', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnavailabilityCard extends StatelessWidget {
  const _UnavailabilityCard({
    required this.impact,
    required this.busy,
    required this.onTransfer,
    required this.onReschedule,
  });

  final UnavailabilityImpactActionDto impact;
  final bool busy;
  final VoidCallback onTransfer;
  final VoidCallback onReschedule;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EEF7)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            impact.doctorName.trim().isEmpty ? 'Your specialist is unavailable' : '${impact.doctorName} is unavailable',
            style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
          ),
          const SizedBox(height: 6),
          Text(
            impact.message,
            style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700, height: 1.3),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onReschedule,
                  icon: const Icon(Icons.event_repeat_rounded),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SmartAfyaPalette.primaryGreen,
                    side: BorderSide(color: SmartAfyaPalette.primaryGreen.withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  label: const Text('Reschedule', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onTransfer,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  style: FilledButton.styleFrom(
                    backgroundColor: SmartAfyaPalette.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  label: busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Transfer', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

