import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';

/// Client-side feedback form for a completed session.
/// (Payment is intentionally out of scope, per backend/API availability.)
class ClientSessionFeedbackScreen extends StatefulWidget {
  const ClientSessionFeedbackScreen({super.key, required this.session});

  final SessionDto session;

  @override
  State<ClientSessionFeedbackScreen> createState() => _ClientSessionFeedbackScreenState();
}

class _ClientSessionFeedbackScreenState extends State<ClientSessionFeedbackScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  int? _treatmentRating;
  int? _appRating;
  final _doctorFeedbackController = TextEditingController();
  final _appFeedbackController = TextEditingController();
  final _suggestionsController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _doctorFeedbackController.dispose();
    _appFeedbackController.dispose();
    _suggestionsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_treatmentRating == null) {
      setState(() => _error = 'Please choose a rating.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _api.submitFeedback(
        sessionId: widget.session.id,
        treatmentRating: _treatmentRating,
        doctorFeedback: _doctorFeedbackController.text.trim(),
        appRating: _appRating,
        appFeedback: _appFeedbackController.text.trim(),
        suggestions: _suggestionsController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback submitted.')));
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = messageFromDioException(e) ?? 'Could not submit feedback.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not submit feedback.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final whenLabel = widget.session.scheduledAt != null && widget.session.scheduledAt!.isNotEmpty
        ? DateTime.tryParse(widget.session.scheduledAt!)?.toLocal().toString() ?? widget.session.scheduledAt!
        : '—';

    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        title: const Text('Submit feedback', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Session completed.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'When: $whenLabel',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SmartAfyaPalette.mutedText),
                ),
                const SizedBox(height: 18),

                Text(
                  'Doctor rating',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800, color: SmartAfyaPalette.deepText),
                ),
                const SizedBox(height: 10),
                _StarRating(
                  value: _treatmentRating ?? 0,
                  onChanged: (v) => setState(() => _treatmentRating = v),
                ),

                const SizedBox(height: 18),

                TextFormField(
                  controller: _doctorFeedbackController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Share your experience with the doctor (optional)',
                    filled: true,
                    fillColor: SmartAfyaPalette.softBlue,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  'App experience',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800, color: SmartAfyaPalette.deepText),
                ),
                const SizedBox(height: 10),
                _StarRating(
                  value: _appRating ?? 0,
                  onChanged: (v) => setState(() => _appRating = v),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _appFeedbackController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'What can we improve in the app? (optional)',
                    filled: true,
                    fillColor: SmartAfyaPalette.softBlue,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: _suggestionsController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Any suggestions for improvements or next steps?',
                    filled: true,
                    fillColor: SmartAfyaPalette.softBlue,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
                  ),
                ],

                const SizedBox(height: 22),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SmartAfyaPalette.primaryBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: SmartAfyaPalette.mutedText.withValues(alpha: 0.35),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text('Submit feedback', style: TextStyle(fontWeight: FontWeight.w900)),
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

class _StarRating extends StatelessWidget {
  const _StarRating({required this.value, required this.onChanged});

  final int value; // 0..5
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            onPressed: () => onChanged(i),
            icon: Icon(
              i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              color: i <= value ? const Color(0xFFFFB000) : SmartAfyaPalette.mutedText.withValues(alpha: 0.6),
            ),
            tooltip: '$i / 5',
          ),
        const SizedBox(width: 6),
        Text(
          value == 0 ? 'Tap to rate' : '$value/5',
          style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

