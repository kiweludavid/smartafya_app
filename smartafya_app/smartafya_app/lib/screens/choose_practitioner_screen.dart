import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Result returned by [ChoosePractitionerScreen].
///
/// In the client flow we only capture the **profession** (specialist type).
class PractitionerSelection {
  const PractitionerSelection({
    this.specialistId,
    this.specialistName,
    this.specialistType,
    this.specialistLabel,
    this.specialArrangementNote,
    this.matchAny = false,
  });

  final String? specialistId;
  final String? specialistName;
  final String? specialistType;
  final String? specialistLabel;
  final String? specialArrangementNote;
  final bool matchAny;

  bool get isMatchAny => matchAny;
  bool get isSpecialArrangement =>
      (specialistId == null || specialistId!.isEmpty) &&
      (specialArrangementNote ?? '').trim().isNotEmpty;
  bool get isRegistered => (specialistId ?? '').trim().isNotEmpty;

  String displayName() {
    if (isMatchAny) return 'Smart Afya match';
    if (isRegistered) {
      final name = (specialistName ?? '').trim();
      return name.isNotEmpty ? name : 'Selected specialist';
    }
    if (isSpecialArrangement) {
      final name = (specialistName ?? '').trim();
      return name.isNotEmpty ? name : 'Special arrangement';
    }
    return 'No preference';
  }
}

/// Premium picker that lets a patient choose who attends them, including
/// special arrangement for psychologist-influencers and clerics that may not
/// yet be on the Smart Afya directory.
class ChoosePractitionerScreen extends StatefulWidget {
  const ChoosePractitionerScreen({
    super.key,
    this.initialSelection,
  });

  final PractitionerSelection? initialSelection;

  @override
  State<ChoosePractitionerScreen> createState() => _ChoosePractitionerScreenState();
}

class _ChoosePractitionerScreenState extends State<ChoosePractitionerScreen> {
  static const _hairline = Color(0xFFE4EEF7);

  PractitionerSelection? _staged;
  String? _profession; // backend keys: psychologist|psychiatrist|cleric|therapist

  @override
  void initState() {
    super.initState();
    _staged = widget.initialSelection;
    _profession = _staged?.specialistType;
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _setProfession(String? key) {
    final k = (key ?? '').trim();
    if (k.isEmpty) {
      setState(() {
        _profession = null;
        _staged = null;
      });
      return;
    }
    final label = _professionLabel(k);
    setState(() {
      _profession = k;
      _staged = PractitionerSelection(
        specialistType: k,
        specialistLabel: label,
      );
    });
  }

  String _professionLabel(String key) {
    switch (key) {
      case 'psychologist':
        return 'Psychologist';
      case 'psychiatrist':
        return 'Psychiatrist';
      case 'cleric':
        return 'Cleric';
      case 'therapist':
        return 'Therapist';
      default:
        return 'Specialist';
    }
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _staged != null;
    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
        foregroundColor: SmartAfyaPalette.deepText,
        title: const Text(
          'Choose your specialist',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _intro(),
            const SizedBox(height: 20),
            _professionDropdown(),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_staged != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _stagedSummary(_staged!),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: _hairline),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: canConfirm
                            ? [
                                BoxShadow(
                                  color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.22),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : const [],
                      ),
                      child: FilledButton(
                        onPressed: canConfirm ? () => Navigator.pop(context, _staged) : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: SmartAfyaPalette.primaryBlue,
                          disabledBackgroundColor: SmartAfyaPalette.mutedText.withValues(alpha: 0.35),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text(
                          'Confirm selection',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _intro() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SmartAfyaPalette.softBlue,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _hairline),
            ),
            child: const Icon(Icons.handshake_rounded, color: SmartAfyaPalette.primaryBlue),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose a profession',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: SmartAfyaPalette.deepText,
                    fontSize: 16,
                    letterSpacing: -0.1,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Select the professional type you prefer. A doctor will be assigned after your booking is reviewed.',
                  style: TextStyle(
                    color: SmartAfyaPalette.mutedText,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _professionDropdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Profession',
            style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _profession,
            decoration: InputDecoration(
              filled: true,
              fillColor: SmartAfyaPalette.softBlue,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            hint: const Text('Select profession'),
            items: const [
              DropdownMenuItem(value: 'psychologist', child: Text('Psychologist')),
              DropdownMenuItem(value: 'psychiatrist', child: Text('Psychiatrist')),
              DropdownMenuItem(value: 'cleric', child: Text('Cleric')),
              DropdownMenuItem(value: 'therapist', child: Text('Therapist')),
            ],
            onChanged: _setProfession,
          ),
          const SizedBox(height: 10),
          const Text(
            'Once you select a profession, Smart Afya will assign an available doctor from that profession after review.',
            style: TextStyle(color: SmartAfyaPalette.mutedText, height: 1.35, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _stagedSummary(PractitionerSelection sel) {
    IconData icon;
    Color tint;
    String title;
    String subtitle;
    if (sel.isMatchAny) {
      icon = Icons.auto_awesome_rounded;
      tint = SmartAfyaPalette.primaryBlue;
      title = 'Smart Afya match';
      subtitle = 'We\u2019ll pick the best available specialist for you.';
    } else if ((sel.specialistType ?? '').trim().isNotEmpty) {
      icon = Icons.work_outline_rounded;
      tint = SmartAfyaPalette.primaryBlue;
      title = sel.specialistLabel ?? 'Selected profession';
      subtitle = 'We\u2019ll assign an available professional.';
    } else {
      icon = Icons.help_outline_rounded;
      tint = SmartAfyaPalette.mutedText;
      title = 'No selection';
      subtitle = 'Pick a specialist or use match-me.';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SmartAfyaPalette.softBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: tint, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: SmartAfyaPalette.mutedText, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear selection',
            onPressed: () => setState(() => _staged = null),
            icon: const Icon(Icons.close_rounded, color: SmartAfyaPalette.mutedText),
          ),
        ],
      ),
    );
  }

}
