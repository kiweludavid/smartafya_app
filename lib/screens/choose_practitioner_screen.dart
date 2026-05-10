import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';

/// Result returned by [ChoosePractitionerScreen].
///
/// One of three shapes:
/// 1. Registered practitioner picked from the directory →
///    `specialistId`, `specialistName`, `specialistType`/`specialistLabel` set.
/// 2. "Match me with the next available specialist" →
///    `matchAny == true`; everything else null.
/// 3. Special arrangement (off-platform influencer / cleric / known person) →
///    `specialistId == null`, `specialistName` & `specialistType` set,
///    `specialArrangementNote` carries the patient's request and any handles.
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
  final _api = ApiService();
  final _searchController = TextEditingController();

  static const _hairline = Color(0xFFE4EEF7);
  // Same hue as palette `mutedText` (#8A9BB0) at ~80% alpha so descriptions
  // sit lighter on the page than headings, without changing the brand colour.
  static const _mutedSoft = Color(0xCC8A9BB0);
  // Soft elevation shared by every card/sheet on this screen.
  static const _softShadow = <BoxShadow>[
    BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
  // Gentle blue glow used for active/selected state on cards.
  static const _activeBlueGlow = <BoxShadow>[
    BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x141A5FA8), blurRadius: 22, offset: Offset(0, 8)),
  ];

  // Backend SpecialistType keys (smart_afya/app/models/user.py).
  static const _categories = <_PractitionerCategory>[
    _PractitionerCategory(
      key: 'all',
      label: 'All',
      icon: Icons.apps_rounded,
      backendKeys: <String>[],
    ),
    _PractitionerCategory(
      key: 'psychologist',
      label: 'Psychologist',
      icon: Icons.psychology_alt_rounded,
      backendKeys: <String>['psychologist'],
    ),
    _PractitionerCategory(
      key: 'psychiatrist',
      label: 'Psychiatrist',
      icon: Icons.medical_services_outlined,
      backendKeys: <String>['psychiatrist'],
    ),
    _PractitionerCategory(
      key: 'therapist',
      label: 'Therapist',
      icon: Icons.spa_outlined,
      backendKeys: <String>['therapist'],
    ),
    _PractitionerCategory(
      key: 'influencer',
      label: 'Influencer',
      icon: Icons.campaign_rounded,
      backendKeys: <String>['influencer'],
    ),
    _PractitionerCategory(
      key: 'cleric',
      label: 'Faith / Cleric',
      icon: Icons.menu_book_rounded,
      backendKeys: <String>['cleric'],
    ),
  ];

  String _activeCategoryKey = 'all';
  String _query = '';

  bool _loading = false;
  String? _loadError;
  List<DoctorDto> _doctors = const [];

  PractitionerSelection? _staged;

  @override
  void initState() {
    super.initState();
    _staged = widget.initialSelection;
    _searchController.addListener(() {
      final v = _searchController.text.trim();
      if (v == _query) return;
      setState(() => _query = v);
    });
    _loadDoctors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final list = await _api.fetchDoctors(availableOnly: false);
      if (!mounted) return;
      setState(() {
        _doctors = list.where((d) => d.id.isNotEmpty).toList();
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = messageFromDioException(e) ?? 'Could not load specialists.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load specialists.';
      });
    }
  }

  _PractitionerCategory get _activeCategory =>
      _categories.firstWhere((c) => c.key == _activeCategoryKey, orElse: () => _categories.first);

  List<DoctorDto> get _filteredDoctors {
    final cat = _activeCategory;
    final q = _query.toLowerCase();
    return _doctors.where((d) {
      if (cat.backendKeys.isNotEmpty) {
        final t = (d.specialistType ?? '').trim().toLowerCase();
        if (!cat.backendKeys.contains(t)) return false;
      }
      if (q.isEmpty) return true;
      final hay = '${d.fullName} ${d.specialistLabel}'.toLowerCase();
      return hay.contains(q);
    }).toList()
      ..sort((a, b) {
        if (a.isAvailable != b.isAvailable) return a.isAvailable ? -1 : 1;
        return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      });
  }

  bool _isStagedDoctor(DoctorDto d) =>
      _staged?.specialistId != null && _staged!.specialistId == d.id;

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
            _matchMeCard(),
            const SizedBox(height: 24),
            _searchField(),
            const SizedBox(height: 14),
            _categoryStrip(),
            const SizedBox(height: 20),
            _directorySection(),
            const SizedBox(height: 24),
            _specialArrangementSection(),
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
        boxShadow: _softShadow,
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
                  'Pick who attends to you',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: SmartAfyaPalette.deepText,
                    fontSize: 16,
                    letterSpacing: -0.1,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Choose your preferred mental health specialist.',
                  style: TextStyle(
                    color: _mutedSoft,
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

  Widget _matchMeCard() {
    final selected = _staged?.isMatchAny ?? false;
    return InkWell(
      onTap: () {
        setState(() {
          _staged = const PractitionerSelection(matchAny: true);
        });
      },
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? SmartAfyaPalette.softBlue : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? SmartAfyaPalette.primaryBlue : _hairline,
            width: selected ? 1.6 : 1.0,
          ),
          boxShadow: selected ? _activeBlueGlow : _softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: SmartAfyaPalette.primaryBlue),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Afya, match me',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: SmartAfyaPalette.deepText,
                      fontSize: 16,
                      letterSpacing: -0.1,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'We\u2019ll match you with the best available specialist.',
                    style: TextStyle(
                      color: _mutedSoft,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _selectionDot(selected),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: _softShadow,
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by name or specialty\u2026',
          prefixIcon: const Icon(Icons.search_rounded, color: SmartAfyaPalette.primaryBlue),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded, color: SmartAfyaPalette.mutedText),
                  onPressed: () => _searchController.clear(),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintStyle: const TextStyle(color: _mutedSoft, fontWeight: FontWeight.w500),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _hairline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: SmartAfyaPalette.primaryBlue, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _categoryStrip() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final selected = cat.key == _activeCategoryKey;
          return ChoiceChip(
            avatar: Icon(
              cat.icon,
              size: 18,
              color: selected ? SmartAfyaPalette.primaryBlue : SmartAfyaPalette.deepText,
            ),
            label: Text(cat.label),
            selected: selected,
            selectedColor: SmartAfyaPalette.softBlue,
            backgroundColor: Colors.white,
            elevation: selected ? 2 : 0,
            pressElevation: 0,
            shadowColor: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.25),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                color: selected ? SmartAfyaPalette.primaryBlue : _hairline,
                width: selected ? 1.4 : 1.0,
              ),
            ),
            labelStyle: TextStyle(
              color: selected ? SmartAfyaPalette.primaryBlue : SmartAfyaPalette.deepText,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
            ),
            onSelected: (_) => setState(() => _activeCategoryKey = cat.key),
          );
        },
      ),
    );
  }

  Widget _directorySection() {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        alignment: Alignment.center,
        child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_loadError != null) {
      return _emptyCard(
        icon: Icons.error_outline_rounded,
        title: 'Couldn\u2019t load specialists',
        subtitle: _loadError!,
        action: TextButton.icon(
          onPressed: _loadDoctors,
          icon: const Icon(Icons.refresh_rounded, size: 20, color: SmartAfyaPalette.primaryBlue),
          label: const Text('Retry'),
        ),
      );
    }

    final list = _filteredDoctors;
    if (list.isEmpty) {
      final hint = _query.isNotEmpty
          ? 'No specialists match \u201C$_query\u201D in this category.'
          : 'No registered ${_activeCategory.label.toLowerCase()} specialists yet. '
              'Use \u201CSpecial arrangement\u201D below to request someone you know.';
      return _emptyCard(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        subtitle: hint,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 12),
          child: Text(
            '${list.length} ${list.length == 1 ? "specialist" : "specialists"} available',
            style: const TextStyle(
              color: _mutedSoft,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              letterSpacing: 0.1,
            ),
          ),
        ),
        for (final d in list) ...[
          _DoctorCard(
            doctor: d,
            selected: _isStagedDoctor(d),
            onTap: () {
              setState(() {
                _staged = PractitionerSelection(
                  specialistId: d.id,
                  specialistName: d.fullName.isNotEmpty ? d.fullName : 'Selected specialist',
                  specialistType: d.specialistType,
                  specialistLabel: d.specialistLabel,
                );
              });
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _specialArrangementSection() {
    final selected = _staged?.isSpecialArrangement ?? false;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? SmartAfyaPalette.primaryGreen : _hairline,
          width: selected ? 1.4 : 1.0,
        ),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SmartAfyaPalette.primaryGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: SmartAfyaPalette.primaryGreen),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Special arrangement',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: SmartAfyaPalette.deepText,
                        fontSize: 16,
                        letterSpacing: -0.1,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Request a specific specialist or mentor.',
                      style: TextStyle(
                        color: _mutedSoft,
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
          if (selected) ...[
            const SizedBox(height: 16),
            _stagedSummary(_staged!),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openSpecialArrangementSheet,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: SmartAfyaPalette.primaryGreen.withValues(alpha: 0.6)),
                foregroundColor: SmartAfyaPalette.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: Text(
                selected ? 'Edit special arrangement' : 'Request a specific person',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSpecialArrangementSheet() async {
    final initial = _staged?.isSpecialArrangement == true ? _staged : null;
    final result = await showModalBottomSheet<PractitionerSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _SpecialArrangementSheet(initial: initial),
    );
    if (!mounted || result == null) return;
    setState(() => _staged = result);
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
    } else if (sel.isRegistered) {
      icon = Icons.verified_user_rounded;
      tint = SmartAfyaPalette.primaryBlue;
      title = sel.specialistName ?? 'Selected specialist';
      subtitle = sel.specialistLabel ?? 'Smart Afya specialist';
    } else if (sel.isSpecialArrangement) {
      icon = Icons.workspace_premium_rounded;
      tint = SmartAfyaPalette.primaryGreen;
      title = sel.specialistName ?? 'Special arrangement';
      final type = sel.specialistLabel ?? sel.specialistType ?? 'Special arrangement';
      subtitle = '$type \u00b7 admin will coordinate';
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

  Widget _selectionDot(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? SmartAfyaPalette.primaryBlue : Colors.white,
        border: Border.all(
          color: selected ? SmartAfyaPalette.primaryBlue : _hairline,
          width: 1.6,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _hairline),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SmartAfyaPalette.softBlue,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _hairline),
            ),
            child: Icon(icon, color: SmartAfyaPalette.primaryBlue),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600, height: 1.35),
          ),
          if (action != null) ...[const SizedBox(height: 8), action],
        ],
      ),
    );
  }
}

class _PractitionerCategory {
  const _PractitionerCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.backendKeys,
  });

  final String key;
  final String label;
  final IconData icon;

  /// Empty list = match all categories.
  final List<String> backendKeys;
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({
    required this.doctor,
    required this.selected,
    required this.onTap,
  });

  final DoctorDto doctor;
  final bool selected;
  final VoidCallback onTap;

  static const _hairline = Color(0xFFE4EEF7);

  static const _softShadow = <BoxShadow>[
    BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 5)),
  ];
  static const _activeBlueGlow = <BoxShadow>[
    BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 5)),
    BoxShadow(color: Color(0x141A5FA8), blurRadius: 22, offset: Offset(0, 8)),
  ];

  @override
  Widget build(BuildContext context) {
    final initials = _initials(doctor.fullName);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? SmartAfyaPalette.softBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? SmartAfyaPalette.primaryBlue : _hairline,
            width: selected ? 1.6 : 1.0,
          ),
          boxShadow: selected ? _activeBlueGlow : _softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _hairline),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: SmartAfyaPalette.primaryBlue,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.fullName.isNotEmpty ? doctor.fullName : 'Smart Afya specialist',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: SmartAfyaPalette.deepText,
                      fontSize: 15,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: SmartAfyaPalette.softBlue,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: _hairline),
                          ),
                          child: Text(
                            doctor.specialistLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: SmartAfyaPalette.primaryBlue,
                              fontWeight: FontWeight.w900,
                              fontSize: 11.5,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _availabilityBadge(doctor.isAvailable),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _SelectionDot(selected: selected),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      final first = parts.first;
      return first.length >= 2 ? first.substring(0, 2).toUpperCase() : first.toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _availabilityBadge(bool available) {
    final color = available ? SmartAfyaPalette.primaryGreen : SmartAfyaPalette.mutedText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            available ? 'Available' : 'Off-duty',
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected});
  final bool selected;

  static const _hairline = Color(0xFFE4EEF7);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? SmartAfyaPalette.primaryBlue : Colors.white,
        border: Border.all(
          color: selected ? SmartAfyaPalette.primaryBlue : _hairline,
          width: 1.6,
        ),
      ),
      child: selected ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
    );
  }
}

class _SpecialArrangementSheet extends StatefulWidget {
  const _SpecialArrangementSheet({this.initial});

  final PractitionerSelection? initial;

  @override
  State<_SpecialArrangementSheet> createState() => _SpecialArrangementSheetState();
}

class _SpecialArrangementSheetState extends State<_SpecialArrangementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _handleController = TextEditingController();
  final _notesController = TextEditingController();

  static const _kindOptions = <(String, String, IconData)>[
    ('influencer', 'Mental-health influencer', Icons.campaign_rounded),
    ('cleric', 'Faith leader / Cleric', Icons.menu_book_rounded),
    ('psychologist', 'Psychologist (off-platform)', Icons.psychology_alt_rounded),
    ('therapist', 'Therapist (off-platform)', Icons.spa_outlined),
    ('other', 'Other / Trusted person', Icons.person_outline_rounded),
  ];

  String _kind = 'influencer';

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null && init.isSpecialArrangement) {
      _nameController.text = init.specialistName ?? '';
      _kind = init.specialistType ?? 'influencer';
      // Reconstruct previous notes if user re-opens.
      _notesController.text = init.specialArrangementNote ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _labelForKind(String key) {
    return _kindOptions
        .firstWhere((t) => t.$1 == key, orElse: () => _kindOptions.last)
        .$2;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();
    final handle = _handleController.text.trim();
    final notes = _notesController.text.trim();
    final label = _labelForKind(_kind);

    final note = StringBuffer()
      ..writeln('Special arrangement requested.')
      ..writeln('Preferred attender: $name ($label).');
    if (handle.isNotEmpty) note.writeln('Contact / handle: $handle.');
    if (notes.isNotEmpty) {
      note.writeln('Why this person: $notes');
    }

    Navigator.pop(
      context,
      PractitionerSelection(
        specialistName: name,
        specialistType: _kind,
        specialistLabel: label,
        specialArrangementNote: note.toString().trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Special arrangement',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tell us who you\u2019d like to attend you. This is great for trusted faith leaders, '
                'mental-health influencers, or any specialist who isn\u2019t yet on Smart Afya. '
                'Admin will reach out and coordinate the session.',
                style: TextStyle(color: SmartAfyaPalette.mutedText, height: 1.45, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const Text('Who should attend you?', style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText, fontSize: 14)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration(
                  hint: 'Full name (e.g. Dr. Mwita Kasoga)',
                  icon: Icons.person_outline_rounded,
                ),
                validator: (v) {
                  if ((v ?? '').trim().length < 2) return 'Please enter the person\u2019s name.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              const Text('Their role', style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final opt in _kindOptions)
                    ChoiceChip(
                      avatar: Icon(opt.$3, size: 18, color: _kind == opt.$1 ? SmartAfyaPalette.primaryBlue : SmartAfyaPalette.deepText),
                      label: Text(opt.$2),
                      selected: _kind == opt.$1,
                      selectedColor: SmartAfyaPalette.softBlue,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: BorderSide(
                          color: _kind == opt.$1 ? SmartAfyaPalette.primaryBlue : const Color(0xFFE4EEF7),
                          width: _kind == opt.$1 ? 1.4 : 1.0,
                        ),
                      ),
                      labelStyle: TextStyle(
                        color: _kind == opt.$1 ? SmartAfyaPalette.primaryBlue : SmartAfyaPalette.deepText,
                        fontWeight: _kind == opt.$1 ? FontWeight.w900 : FontWeight.w800,
                      ),
                      onSelected: (_) => setState(() => _kind = opt.$1),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('How can we reach them? (optional)', style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText, fontSize: 14)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _handleController,
                decoration: _decoration(
                  hint: 'Phone, email, social handle, mosque/church, etc.',
                  icon: Icons.alternate_email_rounded,
                ),
              ),
              const SizedBox(height: 14),
              const Text('Why this person?', style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText, fontSize: 14)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                minLines: 3,
                maxLines: 6,
                decoration: _decoration(
                  hint: 'A short note for admin (faith preference, language, prior trust, etc.)',
                  icon: Icons.notes_rounded,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: SmartAfyaPalette.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text(
                    'Save special arrangement',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, color: SmartAfyaPalette.primaryBlue),
      filled: true,
      fillColor: SmartAfyaPalette.softBlue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: SmartAfyaPalette.primaryBlue, width: 1.4),
      ),
    );
  }
}
