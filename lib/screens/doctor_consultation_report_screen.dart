import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';
import 'doctor_home_dashboard.dart';

class DoctorConsultationReportScreen extends StatefulWidget {
  const DoctorConsultationReportScreen({
    super.key,
    required this.session,
    required this.booking,
  });

  final SessionDto session;
  final BookingDto? booking;

  @override
  State<DoctorConsultationReportScreen> createState() => _DoctorConsultationReportScreenState();
}

class _DoctorConsultationReportScreenState extends State<DoctorConsultationReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisController = TextEditingController();
  final _recommendationsController = TextEditingController();
  final _notesController = TextEditingController();
  bool _followUp = false;
  DateTime? _followUpDateLocal;
  TimeOfDay _followUpTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isSubmitting = false;
  final _api = ApiService();

  static const _hairline = Color(0xFFE4EEF7);
  static const _cardShadow = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 6)),
  ];

  @override
  void dispose() {
    _diagnosisController.dispose();
    _recommendationsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isPhysical {
    final t = (widget.booking?.sessionType ?? '').toLowerCase().trim();
    return t == 'physical';
  }

  String _buildNotes() {
    final buf = StringBuffer();
    buf.writeln('CONSULTATION_REPORT:');
    buf.writeln(_diagnosisController.text.trim());

    final rec = _recommendationsController.text.trim();
    if (rec.isNotEmpty) {
      buf.writeln('\nRECOMMENDATIONS:');
      buf.writeln(rec);
    }

    final notes = _notesController.text.trim();
    if (notes.isNotEmpty) {
      buf.writeln('\nNOTES:');
      buf.writeln(notes);
    }

    if (_followUp) {
      buf.writeln('\nFOLLOW_UP_REQUESTED: true');
      if (_followUpDateLocal != null) {
        final d = _followUpDateLocal!;
        final t = _followUpTime;
        final local = DateTime(d.year, d.month, d.day, t.hour, t.minute);
        buf.writeln('FOLLOW_UP_SUGGESTED_AT_UTC: ${local.toUtc().toIso8601String()}');
      }
    }

    if (_isPhysical) {
      buf.writeln('\nSESSION_TYPE: physical');
    }

    return buf.toString();
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    if (_followUp && _followUpDateLocal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a follow-up date.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final notes = _buildNotes();
      await _api.patchSession(widget.session.id, status: 'completed', notes: notes).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      Navigator.pop(context, true);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = messageFromDioException(e) ?? 'Could not submit report.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not submit report.')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionType = (widget.booking?.sessionType ?? '—').toUpperCase();
    final patient = DoctorHomeDashboard.patientLabel(widget.session.clientId);
    final status = (widget.session.status).toLowerCase().trim();
    final scheduledAt = DateTime.tryParse(widget.session.scheduledAt ?? '')?.toLocal();

    final canSubmit = status != 'pending' &&
        status != 'scheduled' &&
        (scheduledAt == null || scheduledAt.isBefore(DateTime.now().add(const Duration(minutes: 10))));

    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        title: const Text('Submit report'),
        backgroundColor: SmartAfyaPalette.scaffoldBg,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InfoCard(
                  title: patient,
                  subtitle: 'Session: $sessionType',
                ),
                if (!canSubmit) ...[
                  const SizedBox(height: 12),
                  _Card(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.info_outline_rounded, color: Color(0xFFB8860B)),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Reports are submitted after the session is completed.',
                            style: TextStyle(fontWeight: FontWeight.w700, color: SmartAfyaPalette.deepText, height: 1.25),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _TextCardField(
                  label: 'Diagnosis / Summary',
                  controller: _diagnosisController,
                  minLines: 4,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Please enter a summary/diagnosis.' : null,
                ),
                const SizedBox(height: 12),
                _TextCardField(
                  label: 'Recommendations',
                  controller: _recommendationsController,
                  minLines: 3,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Please enter recommendations.' : null,
                ),
                const SizedBox(height: 12),
                _TextCardField(
                  label: 'Notes',
                  controller: _notesController,
                  minLines: 3,
                  validator: (v) => null,
                ),
                const SizedBox(height: 14),
                _Card(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Recommend follow-up session',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: SmartAfyaPalette.deepText,
                              ),
                        ),
                      ),
                      Switch(
                        value: _followUp,
                        onChanged: _isSubmitting ? null : (v) => setState(() => _followUp = v),
                        activeThumbColor: SmartAfyaPalette.primaryGreen,
                      ),
                    ],
                  ),
                ),
                if (_followUp) ...[
                  const SizedBox(height: 12),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Follow-up date & time',
                          style: TextStyle(fontWeight: FontWeight.w800, color: SmartAfyaPalette.mutedText),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : () async {
                                        final now = DateTime.now();
                                        final picked = await showDatePicker(
                                          context: context,
                                          firstDate: now,
                                          lastDate: now.add(const Duration(days: 365)),
                                          initialDate: _followUpDateLocal ?? now.add(const Duration(days: 7)),
                                        );
                                        if (picked == null) return;
                                        if (!mounted) return;
                                        setState(() => _followUpDateLocal = DateTime(picked.year, picked.month, picked.day));
                                      },
                                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                                label: Text(
                                  _followUpDateLocal == null
                                      ? 'Date'
                                      : '${_followUpDateLocal!.year}-${_followUpDateLocal!.month.toString().padLeft(2, '0')}-${_followUpDateLocal!.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  side: const BorderSide(color: _hairline),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : () async {
                                        final t = await showTimePicker(
                                          context: context,
                                          initialTime: _followUpTime,
                                        );
                                        if (t == null) return;
                                        if (!mounted) return;
                                        setState(() => _followUpTime = t);
                                      },
                                icon: const Icon(Icons.schedule_rounded, size: 18),
                                label: Text(
                                  _followUpTime.format(context),
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  side: const BorderSide(color: _hairline),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'The client confirms and books the next session.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: SmartAfyaPalette.mutedText,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: (_isSubmitting || !canSubmit) ? null : _submit,
                    style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Submit report', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _DoctorConsultationReportScreenState._hairline),
        boxShadow: _DoctorConsultationReportScreenState._cardShadow,
      ),
      child: child,
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _Card(
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w700, color: SmartAfyaPalette.mutedText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TextCardField extends StatelessWidget {
  const _TextCardField({
    required this.label,
    required this.controller,
    required this.minLines,
    required this.validator,
  });

  final String label;
  final TextEditingController controller;
  final int minLines;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: SmartAfyaPalette.mutedText)),
          const SizedBox(height: 10),
          TextFormField(
            controller: controller,
            minLines: minLines,
            maxLines: 10,
            validator: validator,
            style: const TextStyle(fontWeight: FontWeight.w700, color: SmartAfyaPalette.deepText),
            decoration: InputDecoration(
              hintText: label,
              filled: true,
              fillColor: const Color(0xFFF7FAFD),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _DoctorConsultationReportScreenState._hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _DoctorConsultationReportScreenState._hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.6), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

