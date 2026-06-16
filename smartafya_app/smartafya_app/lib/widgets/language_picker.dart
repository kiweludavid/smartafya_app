import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_extensions.dart';
import '../screens/app_palette.dart';
import '../state/locale_controller.dart';

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = context.watch<LocaleController>();
    final selected = controller.choice;

    if (compact) {
      return Align(
        alignment: Alignment.centerRight,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<LocaleChoice>(
            value: selected,
            icon: const Icon(Icons.language_rounded, color: SmartAfyaPalette.primaryBlue, size: 20),
            borderRadius: BorderRadius.circular(12),
            items: _items(l10n),
            onChanged: (choice) {
              if (choice == null) return;
              context.read<LocaleController>().setLocaleChoice(choice);
            },
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.languageTitle,
          style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
        ),
        const SizedBox(height: 12),
        SegmentedButton<LocaleChoice>(
          segments: [
            ButtonSegment(value: LocaleChoice.system, label: Text(l10n.languageSystem)),
            ButtonSegment(value: LocaleChoice.english, label: Text(l10n.languageEnglish)),
            ButtonSegment(value: LocaleChoice.swahili, label: Text(l10n.languageSwahili)),
          ],
          selected: {selected},
          onSelectionChanged: (values) {
            final choice = values.first;
            context.read<LocaleController>().setLocaleChoice(choice);
          },
        ),
      ],
    );
  }

  List<DropdownMenuItem<LocaleChoice>> _items(dynamic l10n) {
    return [
      DropdownMenuItem(value: LocaleChoice.system, child: Text(l10n.languageSystem)),
      DropdownMenuItem(value: LocaleChoice.english, child: Text(l10n.languageEnglish)),
      DropdownMenuItem(value: LocaleChoice.swahili, child: Text(l10n.languageSwahili)),
    ];
  }
}
