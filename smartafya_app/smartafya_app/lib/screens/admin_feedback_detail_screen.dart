import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';

class AdminFeedbackDetailScreen extends StatefulWidget {
  const AdminFeedbackDetailScreen({
    super.key,
    required this.feedback,
    required this.clientName,
    required this.doctorName,
    required this.sessionWhenLabel,
  });

  final FeedbackDto feedback;
  final String clientName;
  final String doctorName;
  final String sessionWhenLabel;

  @override
  State<AdminFeedbackDetailScreen> createState() => _AdminFeedbackDetailScreenState();
}

class _AdminFeedbackDetailScreenState extends State<AdminFeedbackDetailScreen> {
  final _api = ApiService();
  late FeedbackDto _f = widget.feedback;

  bool _saving = false;
  bool _edited = false;
  late bool _reviewed = _f.reviewed;
  late bool _flagged = _f.flagged;
  final _internalNote = TextEditingController();

  @override
  void initState() {
    super.initState();
    _internalNote.text = (_f.internalNote ?? '').trim();
  }

  @override
  void dispose() {
    _internalNote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rating = _f.rating;
    final comment = _f.primaryComment;
    final created = _f.createdAtUtc?.toLocal();
    final createdLabel = created == null ? '—' : '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
        foregroundColor: SmartAfyaPalette.deepText,
        title: const Text('Feedback', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          TextButton(
            onPressed: _saving ? null : () async => _save(),
            child: Text(_saving ? 'Saving…' : 'Save', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.clientName,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: SmartAfyaPalette.deepText),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatusPill(reviewed: _reviewed, flagged: _flagged),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Doctor: ${widget.doctorName}',
                    style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Session: ${widget.sessionWhenLabel}',
                    style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Submitted: $createdLabel',
                    style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Card(
              title: 'Rating',
              child: Row(
                children: [
                  _Stars(rating: rating ?? 0),
                  const SizedBox(width: 10),
                  Text(
                    rating == null ? '—' : '$rating / 5',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Card(
              title: 'Full comment',
              child: Text(
                comment.isEmpty ? '—' : comment,
                style: const TextStyle(color: SmartAfyaPalette.deepText, fontWeight: FontWeight.w600, height: 1.35),
              ),
            ),
            const SizedBox(height: 12),
            _Card(
              title: 'Actions',
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _reviewed,
                    onChanged: _saving
                        ? null
                        : (v) {
                            setState(() {
                              _reviewed = v;
                              _edited = true;
                            });
                          },
                    title: const Text('Mark as reviewed', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _flagged,
                    onChanged: _saving
                        ? null
                        : (v) {
                            setState(() {
                              _flagged = v;
                              _edited = true;
                            });
                          },
                    title: const Text('Flag issue', style: TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: const Text('Use for quality/safety follow-up.'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Card(
              title: 'Internal note',
              child: TextField(
                controller: _internalNote,
                enabled: !_saving,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Add internal notes (visible to admins only)…',
                  filled: true,
                  fillColor: Color(0xFFF7FAFD),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide.none),
                ),
                onChanged: (_) => setState(() => _edited = true),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : () async => _save(popAfter: true),
              style: FilledButton.styleFrom(
                backgroundColor: SmartAfyaPalette.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Save & Close', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save({bool popAfter = false}) async {
    final note = _internalNote.text.trim();
    if (!_edited) {
      if (popAfter && mounted) Navigator.pop(context, _f);
      return;
    }
    try {
      setState(() => _saving = true);
      final updated = await _api.patchFeedback(
        _f.id,
        reviewed: _reviewed,
        flagged: _flagged,
        internalNote: note,
      );
      if (!mounted) return;
      setState(() {
        _f = updated;
        _saving = false;
        _edited = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback updated.')));
      if (popAfter && mounted) Navigator.pop(context, _f);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDioException(e) ?? 'Could not update feedback.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update feedback.')));
    }
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.title});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText)),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    final r = rating.clamp(0, 5);
    return Row(
      children: [
        for (int i = 1; i <= 5; i++)
          Icon(
            i <= r ? Icons.star_rounded : Icons.star_border_rounded,
            size: 18,
            color: i <= r ? const Color(0xFFFFC107) : SmartAfyaPalette.mutedText,
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.reviewed, required this.flagged});
  final bool reviewed;
  final bool flagged;

  @override
  Widget build(BuildContext context) {
    final label = flagged
        ? 'Flagged'
        : reviewed
            ? 'Reviewed'
            : 'Not reviewed';
    final bg = flagged
        ? const Color(0xFFFFF4E5)
        : reviewed
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFF3F6F9);
    final fg = flagged
        ? const Color(0xFFB8860B)
        : reviewed
            ? SmartAfyaPalette.primaryGreen
            : SmartAfyaPalette.mutedText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: fg)),
    );
  }
}

