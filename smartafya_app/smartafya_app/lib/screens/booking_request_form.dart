import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/booking_session_lookup.dart';
import '../utils/dio_error_message.dart';
import '../utils/payment_status.dart';
import 'app_palette.dart';
import 'choose_practitioner_screen.dart';
import 'home_screen_ui.dart' show PaymentsScreen;

/// Full booking payload: mental health description, consent, optional specialist,
/// session type, duration, and at least 3 preferred datetimes (distinct days).
class BookingRequestForm extends StatefulWidget {
  const BookingRequestForm({
    super.key,
    this.initialDescription,
    this.initialSessionType, // audio|video|physical
    this.preferredSpecialistId,
    this.preferredSpecialistName,
    this.specialistLocked = false,
    this.initialDurationMinutes,
    this.sessionTypeLocked = false,
    this.durationLocked = false,
    this.requireAvailabilityConfirmation = false,
  });

  final String? initialDescription;
  final String? initialSessionType;
  final String? preferredSpecialistId;
  final String? preferredSpecialistName;
  final bool specialistLocked;
  final int? initialDurationMinutes;
  final bool sessionTypeLocked;
  final bool durationLocked;
  final bool requireAvailabilityConfirmation;

  @override
  State<BookingRequestForm> createState() => _BookingRequestFormState();
}

class _BookingRequestFormState extends State<BookingRequestForm> {
  final _api = ApiService();
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  bool _consent = false;
  DateTime? _consentTimestampUtc;
  String _sessionType = 'video';
  int _durationMinutes = 60;
  final List<DateTime> _preferredSlots = [];
  bool _submitting = false;
  bool _availabilityConfirmed = false;

  final _physicalStreetController = TextEditingController();
  final _physicalCityController = TextEditingController();
  String _physicalVenue = 'home';

  String? _draftBookingId;
  String? _draftSessionId;
  bool _paymentReady = false;

  PractitionerSelection? _selectedPractitioner;

  bool get _termsAccepted => _consent && _consentTimestampUtc != null;

  bool get _requiresPrePay => _sessionType == 'audio' || _sessionType == 'video';

  bool get _datesReady {
    if (_preferredSlots.length < 3) return false;
    final uniqueDays = _preferredSlots.map((d) => DateTime(d.year, d.month, d.day)).toSet().length;
    return uniqueDays >= 3;
  }

  bool get _canSubmitBooking {
    if (!_termsAccepted) return false;
    if (widget.requireAvailabilityConfirmation && !_availabilityConfirmed) return false;
    if (!_datesReady) return false;
    if (_requiresPrePay && !_paymentReady) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _descriptionController.text = (widget.initialDescription ?? '').trim();
    final initType = (widget.initialSessionType ?? '').trim().toLowerCase();
    if (initType == 'audio' || initType == 'video' || initType == 'physical') {
      _sessionType = initType;
    }
    final initId = (widget.preferredSpecialistId ?? '').trim();
    if (initId.isNotEmpty) {
      _selectedPractitioner = PractitionerSelection(
        specialistId: initId,
        specialistName: (widget.preferredSpecialistName ?? '').trim().isNotEmpty
            ? widget.preferredSpecialistName!.trim()
            : null,
      );
    }
    final initDur = widget.initialDurationMinutes;
    if (initDur == 30 || initDur == 60 || initDur == 45 || initDur == 90) {
      _durationMinutes = initDur!;
    }
    _restoreConsent();
  }

  Future<void> _restoreConsent() async {
    try {
      final given = await _storage.read(key: 'patient_consent_given');
      var ts = await _storage.read(key: 'patient_consent_timestamp_utc');
      if (given == 'true' && (ts == null || ts.isEmpty)) {
        final now = DateTime.now().toUtc().toIso8601String();
        await _storage.write(key: 'patient_consent_timestamp_utc', value: now);
        ts = now;
      }
      if (!mounted) return;
      final parsed = ts != null ? DateTime.tryParse(ts)?.toUtc() : null;
      setState(() {
        _consent = given == 'true';
        _consentTimestampUtc = parsed;
      });
    } catch (_) {
      // If secure storage fails, keep consent unchecked to be safe.
      if (!mounted) return;
      setState(() {
        _consent = false;
        _consentTimestampUtc = null;
      });
    }
  }

  Future<void> _setConsent(bool v) async {
    final ts = v ? (DateTime.now().toUtc()) : null;
    setState(() {
      _consent = v;
      _consentTimestampUtc = ts;
    });
    try {
      await _storage.write(key: 'patient_consent_given', value: v ? 'true' : 'false');
      if (ts != null) {
        await _storage.write(key: 'patient_consent_timestamp_utc', value: ts.toIso8601String());
      } else {
        await _storage.delete(key: 'patient_consent_timestamp_utc');
      }
    } catch (_) {
      // If we cannot persist, still block submit unless checkbox is checked.
    }
  }

  void _showTermsAndConditions() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Terms & Conditions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                const Text(
                  'By submitting this form, you confirm that the information you provide is accurate to the best of your knowledge. '
                  'Your responses may be reviewed by your assigned care team to help prepare for your session. '
                  'If you are experiencing an emergency, contact local emergency services immediately.',
                  style: TextStyle(color: SmartAfyaPalette.mutedText, height: 1.45),
                ),
                const SizedBox(height: 16),
                if (_consentTimestampUtc != null)
                  Text(
                    'Last accepted: ${_consentTimestampUtc!.toLocal().toString()}',
                    style: const TextStyle(color: SmartAfyaPalette.mutedText, fontSize: 12),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _setConsent(true);
                    },
                    style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                    child: const Text('Accept Terms & Continue'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _physicalStreetController.dispose();
    _physicalCityController.dispose();
    super.dispose();
  }

  Future<void> _openPractitionerPicker() async {
    final picked = await Navigator.of(context).push<PractitionerSelection?>(
      MaterialPageRoute(
        builder: (_) => ChoosePractitionerScreen(initialSelection: _selectedPractitioner),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedPractitioner = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Complete the details below. Your answers help us match you and prepare for your session.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: SmartAfyaPalette.mutedText,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 18),
          _sectionTitle('Terms & Conditions'),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _consent,
            onChanged: (v) => _setConsent(v ?? false),
            activeColor: SmartAfyaPalette.primaryBlue,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              _sessionType == 'physical'
                  ? 'I have read and accept the Terms & Conditions. I consent to share this information with my care team '
                      'and to an in-person visit at the location I provide. This is required before you can submit.'
                  : 'I have read and accept the Terms & Conditions. I consent to share this information with my care team. '
                      'This is required before you can submit.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: SmartAfyaPalette.deepText,
                    height: 1.35,
                  ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _showTermsAndConditions,
              child: const Text('View Terms & Conditions'),
            ),
          ),
          if (!_termsAccepted)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Accept the Terms & Conditions above to enable submission.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SmartAfyaPalette.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          if (widget.requireAvailabilityConfirmation) ...[
            const SizedBox(height: 18),
            _sectionTitle('Availability confirmation'),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _availabilityConfirmed,
              onChanged: (v) => setState(() => _availabilityConfirmed = v ?? false),
              activeColor: SmartAfyaPalette.primaryBlue,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'I confirm I can attend at the selected times.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SmartAfyaPalette.deepText,
                      height: 1.35,
                    ),
              ),
            ),
            if (!(_availabilityConfirmed))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Confirm availability to enable submission.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SmartAfyaPalette.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
          ],
          const SizedBox(height: 18),
          _sectionTitle('State of mind'),
          const SizedBox(height: 10),
          TextFormField(
            controller: _descriptionController,
            minLines: 4,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Describe your current concerns',
              filled: true,
              fillColor: SmartAfyaPalette.softBlue,
              prefixIcon: const Icon(Icons.edit_note_outlined, color: SmartAfyaPalette.primaryBlue),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0x96206FB5), width: 1.4),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
            ),
            validator: (v) {
              final text = (v ?? '').trim();
              if (text.length < 10) return 'Please add more detail (at least a short paragraph).';
              return null;
            },
          ),
          const SizedBox(height: 18),
          _sectionTitle('Who should attend you?'),
          const SizedBox(height: 6),
          const Text(
            'Pick a specific psychologist, psychiatrist, therapist, faith leader, or even a known mental-health '
            'influencer. Don\u2019t see your person? Use \u201CSpecial arrangement\u201D inside the picker.',
            style: TextStyle(color: SmartAfyaPalette.mutedText, height: 1.35, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          _practitionerPickerSection(),
          const SizedBox(height: 18),
          _sectionTitle('Session type'),
          const SizedBox(height: 10),
          _segmented<String>(
            value: _sessionType,
            items: const [
              ('audio', 'Audio'),
              ('video', 'Video'),
              ('physical', 'Physical'),
            ],
            onChanged: widget.sessionTypeLocked ? null : (v) => setState(() => _sessionType = v),
          ),
          if (_sessionType == 'physical') ...[
            const SizedBox(height: 18),
            _visitLocationCard(),
            const SizedBox(height: 18),
            _sectionTitle('Session type (visit site)'),
            const SizedBox(height: 10),
            _segmented<String>(
              value: _physicalVenue,
              items: const [
                ('home', 'Home visit'),
                ('office', 'Office / clinic'),
              ],
              onChanged: (v) => setState(() => _physicalVenue = v),
            ),
          ],
          const SizedBox(height: 18),
          _sectionTitle('Duration'),
          const SizedBox(height: 10),
          _segmented<int>(
            value: _durationMinutes,
            items: const [
              (30, '30 min'),
              (60, '1 hour'),
            ],
            onChanged: widget.durationLocked ? null : (v) => setState(() => _durationMinutes = v),
          ),
          const SizedBox(height: 10),
          Text(
            _priceHint(sessionType: _sessionType, durationMinutes: _durationMinutes),
            style: const TextStyle(color: SmartAfyaPalette.mutedText, height: 1.35),
          ),
          const SizedBox(height: 18),
          _sectionTitle('Preferred dates & times (at least 3)'),
          const SizedBox(height: 10),
          const Text(
            'Add at least 3 slots on different calendar days. Each slot uses your chosen duration as the session length.',
            style: TextStyle(color: SmartAfyaPalette.mutedText, height: 1.35),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._preferredSlots.map((dt) => _slotChip(dt)),
              ActionChip(
                label: const Text('Add slot'),
                avatar: const Icon(Icons.add, size: 18, color: SmartAfyaPalette.primaryBlue),
                onPressed: _pickSlot,
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFE4EEF7)),
              ),
            ],
          ),
          if (_datesReady && _requiresPrePay) ...[
            const SizedBox(height: 18),
            _paymentBeforeSubmitCard(),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (_submitting || !_canSubmitBooking) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: SmartAfyaPalette.primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: SmartAfyaPalette.mutedText.withValues(alpha: 0.35),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.9),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(
                      _submitButtonLabel(),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: SmartAfyaPalette.deepText,
      ),
    );
  }

  String? _combinedPhysicalAddress() {
    final street = _physicalStreetController.text.trim();
    final city = _physicalCityController.text.trim();
    if (street.isEmpty && city.isEmpty) return null;
    if (street.isEmpty) return city;
    if (city.isEmpty) return street;
    return '$street, $city';
  }

  InputDecoration _visitFieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        color: SmartAfyaPalette.deepText,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      hintStyle: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w500),
      filled: true,
      fillColor: const Color(0xFFF8FBFE),
      prefixIcon: Icon(icon, color: SmartAfyaPalette.primaryBlue, size: 22),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE4EEF7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0x96206FB5), width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    );
  }

  Widget _visitLocationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4EEF7)),
        boxShadow: [
          BoxShadow(
            color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEAF4FB), Color(0xFFF5FAFF)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFE4EEF7)),
                    boxShadow: [
                      BoxShadow(
                        color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.place_rounded, color: SmartAfyaPalette.primaryBlue, size: 26),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visit location',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: SmartAfyaPalette.deepText,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Where should your care team meet you?',
                        style: TextStyle(
                          color: SmartAfyaPalette.mutedText,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
            child: Column(
              children: [
                TextFormField(
                  controller: _physicalStreetController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _visitFieldDecoration(
                    label: 'Street',
                    hint: 'e.g. Masaki Peninsula, Plot 12',
                    icon: Icons.signpost_outlined,
                  ),
                  validator: (v) {
                    if (_sessionType != 'physical') return null;
                    if ((v ?? '').trim().length < 3) return 'Enter your street or area.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _physicalCityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _visitFieldDecoration(
                    label: 'City',
                    hint: 'e.g. Dar es Salaam',
                    icon: Icons.location_city_outlined,
                  ),
                  validator: (v) {
                    if (_sessionType != 'physical') return null;
                    if ((v ?? '').trim().length < 2) return 'Enter your city.';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _practitionerPickerSection() {
    if (widget.specialistLocked) {
      final lockedName = (widget.preferredSpecialistName ?? '').trim();
      final label = lockedName.isNotEmpty ? lockedName : 'Selected specialist';
      return _practitionerSummaryCard(
        title: label,
        subtitle: 'Locked for this booking',
        icon: Icons.lock_outline_rounded,
        tint: SmartAfyaPalette.primaryGreen,
        actionLabel: null,
        onAction: null,
      );
    }
    final sel = _selectedPractitioner;
    if (sel == null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openPractitionerPicker,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE4EEF7)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: SmartAfyaPalette.softBlue,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE4EEF7)),
                  ),
                  child: const Icon(Icons.person_search_rounded, color: SmartAfyaPalette.primaryBlue),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose your specialist',
                        style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText, fontSize: 15),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Browse psychologists, clerics, influencers and more \u2014 or let Smart Afya match you.',
                        style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600, height: 1.3, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: SmartAfyaPalette.mutedText),
              ],
            ),
          ),
        ),
      );
    }

    String title;
    String subtitle;
    IconData icon;
    Color tint;
    if (sel.isMatchAny) {
      title = 'Smart Afya match';
      subtitle = 'Next available specialist that fits your profile';
      icon = Icons.auto_awesome_rounded;
      tint = SmartAfyaPalette.primaryBlue;
    } else if (sel.isRegistered) {
      title = sel.specialistName ?? 'Selected specialist';
      subtitle = sel.specialistLabel ?? 'Smart Afya specialist';
      icon = Icons.verified_user_rounded;
      tint = SmartAfyaPalette.primaryBlue;
    } else if (sel.isSpecialArrangement) {
      title = sel.specialistName ?? 'Special arrangement';
      final type = sel.specialistLabel ?? sel.specialistType ?? 'Special arrangement';
      subtitle = '$type \u00b7 admin will coordinate';
      icon = Icons.workspace_premium_rounded;
      tint = SmartAfyaPalette.primaryGreen;
    } else {
      title = 'No preference';
      subtitle = 'Smart Afya will match you with anyone available';
      icon = Icons.help_outline_rounded;
      tint = SmartAfyaPalette.mutedText;
    }

    return _practitionerSummaryCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      tint: tint,
      actionLabel: 'Change',
      onAction: _openPractitionerPicker,
      onClear: () => setState(() => _selectedPractitioner = null),
    );
  }

  Widget _practitionerSummaryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color tint,
    required String? actionLabel,
    required VoidCallback? onAction,
    VoidCallback? onClear,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
        boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600, height: 1.3, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, color: SmartAfyaPalette.mutedText),
                ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.edit_outlined, size: 18, color: SmartAfyaPalette.primaryBlue),
                label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _slotChip(DateTime dt) {
    return InputChip(
      label: Text(_formatSlotRange(dt, durationMinutes: _durationMinutes)),
      onDeleted: () => setState(() => _preferredSlots.remove(dt)),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE4EEF7)),
      labelStyle: const TextStyle(color: SmartAfyaPalette.deepText, fontWeight: FontWeight.w600),
    );
  }

  static String _formatSlotRange(DateTime start, {required int durationMinutes}) {
    final end = start.add(Duration(minutes: durationMinutes));

    String fmtDate(DateTime dt) =>
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

    String fmtTime(DateTime dt) {
      final hour = (dt.hour % 12 == 0) ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm';
    }

    return '${fmtDate(start)} · ${fmtTime(start)}-${fmtTime(end)}';
  }

  Widget _segmented<T>({
    required T value,
    required List<(T, String)> items,
    required ValueChanged<T>? onChanged,
  }) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < items.length - 1 ? 8 : 0),
              child: OutlinedButton(
                onPressed: onChanged == null ? null : () => onChanged(items[i].$1),
                style: OutlinedButton.styleFrom(
                  backgroundColor: value == items[i].$1 ? SmartAfyaPalette.softBlue : Colors.white,
                  side: BorderSide(
                    color: value == items[i].$1 ? SmartAfyaPalette.primaryBlue : const Color(0xFFE4EEF7),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  items[i].$2,
                  style: TextStyle(
                    color: value == items[i].$1 ? SmartAfyaPalette.primaryBlue : SmartAfyaPalette.deepText,
                    fontWeight: value == items[i].$1 ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _priceHint({required String sessionType, required int durationMinutes}) {
    final base = durationMinutes == 30 ? 'TZS 20,000' : 'TZS 30,000';
    if (sessionType == 'physical') return 'Physical session price is negotiable (admin + client).';
    return 'Estimated price: $base';
  }

  String _submitButtonLabel() {
    if (!_termsAccepted) return 'Accept Terms to submit';
    if (widget.requireAvailabilityConfirmation && !_availabilityConfirmed) {
      return 'Confirm availability to submit';
    }
    if (!_datesReady) return 'Add 3 preferred dates to continue';
    if (_requiresPrePay && !_paymentReady) return 'Complete payment to submit';
    return 'Submit booking';
  }

  Widget _paymentBeforeSubmitCard() {
    final paid = _paymentReady;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EEF7)),
        boxShadow: [
          BoxShadow(
            color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                paid ? Icons.verified_rounded : Icons.payments_rounded,
                color: paid ? SmartAfyaPalette.primaryGreen : SmartAfyaPalette.primaryBlue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  paid ? 'Payment received' : 'Payment required',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            paid
                ? 'You can submit your booking request now. Admin will confirm and schedule.'
                : 'Pay ${_priceHint(sessionType: _sessionType, durationMinutes: _durationMinutes).replaceFirst('Estimated price: ', '')} before submitting. '
                    'Upload proof or complete mobile money / bank transfer.',
            style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600, height: 1.35),
          ),
          if (!paid) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submitting ? null : _goToPayment,
              style: FilledButton.styleFrom(
                backgroundColor: SmartAfyaPalette.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.payments_rounded),
              label: const Text('Pay now', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ],
      ),
    );
  }

  Future<bool> _validateBookingForm({bool showSnackbars = true}) async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return false;
    if (!_consent) {
      if (showSnackbars) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must accept Terms & Conditions before continuing.')),
        );
      }
      return false;
    }
    if (_consentTimestampUtc == null) {
      if (showSnackbars) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consent timestamp missing. Please accept Terms & Conditions again.')),
        );
      }
      return false;
    }
    if (widget.requireAvailabilityConfirmation && !_availabilityConfirmed) {
      if (showSnackbars) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please confirm your availability before continuing.')),
        );
      }
      return false;
    }
    if (!_datesReady) {
      if (showSnackbars) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least 3 preferred slots on different days.')),
        );
      }
      return false;
    }
    if (_sessionType == 'physical') {
      if (_physicalVenue != 'home' && _physicalVenue != 'office') {
        if (showSnackbars) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select home or office for the physical visit.')),
          );
        }
        return false;
      }
    }
    return true;
  }

  Future<void> _refreshDraftPayment() async {
    final sessionId = _draftSessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    try {
      final payment = await _api.fetchPaymentForSession(sessionId);
      if (!mounted) return;
      setState(() => _paymentReady = paymentReadyForBooking(payment));
    } catch (_) {}
  }

  Future<void> _ensureDraftBooking() async {
    if (_draftSessionId != null && _draftSessionId!.isNotEmpty) return;

    final preferredIso = _preferredSlots.map((d) => d.toUtc().toIso8601String()).toList();
    final booking = await _api.createBooking(
      mentalHealthDescription: _effectiveDescription(_descriptionController.text.trim()),
      consentGiven: true,
      sessionType: _sessionType,
      durationMinutes: _durationMinutes,
      preferredDates: preferredIso,
      preferredSpecialistId: _sessionType == 'physical' ? null : _effectiveSpecialistId(),
      preferredSpecialistType: _effectivePreferredSpecialistType(),
      physicalLocationAddress: _sessionType == 'physical' ? _combinedPhysicalAddress() : null,
      physicalLocationLat: null,
      physicalLocationLng: null,
      physicalVenue: _sessionType == 'physical' ? _physicalVenue : null,
      physicalNotes: null,
    );
    final sessionId = await sessionIdForBooking(_api, booking.id);
    if (!mounted) return;
    setState(() {
      _draftBookingId = booking.id;
      _draftSessionId = sessionId;
    });
    await _refreshDraftPayment();
  }

  Future<void> _goToPayment() async {
    if (!await _validateBookingForm()) return;
    setState(() => _submitting = true);
    try {
      await _ensureDraftBooking();
      final sessionId = _draftSessionId;
      if (sessionId == null || sessionId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start payment. Please try again.')),
        );
        return;
      }
      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(builder: (_) => PaymentsScreen(initialSessionId: sessionId)),
      );
      if (!mounted) return;
      await _refreshDraftPayment();
      if (!mounted) return;
      if (_paymentReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded. You can submit your booking now.')),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = messageFromDioException(e) ?? 'Could not start payment.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start payment.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickSlot() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (_preferredSlots.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 6 preferred slots.')),
      );
      return;
    }
    setState(() => _preferredSlots.add(dt));
  }

  String? _effectiveSpecialistId() {
    if (widget.specialistLocked) return widget.preferredSpecialistId;
    final sel = _selectedPractitioner;
    if (sel == null) return null;
    final id = (sel.specialistId ?? '').trim();
    return id.isEmpty ? null : id;
  }

  String? _effectivePreferredSpecialistType() {
    final sel = _selectedPractitioner;
    if (sel == null) return null;
    final t = (sel.specialistType ?? '').trim();
    return t.isEmpty ? null : t;
  }

  String _effectiveDescription(String description) {
    final sel = _selectedPractitioner;
    // Back-compat: include any extra note above the clinical description.
    final note = (sel?.specialArrangementNote ?? '').trim();
    if (note.isEmpty) return description;
    return '$note\n\n$description';
  }

  Future<void> _submit() async {
    if (!await _validateBookingForm()) return;
    if (!mounted) return;
    if (_requiresPrePay && !_paymentReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete payment before submitting your booking.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_draftBookingId == null) {
        await _ensureDraftBooking();
      }
      if (!mounted) return;
      if (_sessionType == 'physical') {
        await NotificationService.physicalWorkflow(
          title: 'Physical visit requested',
          body: 'Admin will assign a doctor and schedule your visit.',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking submitted. We will schedule your next consultation soon.')),
      );
      Navigator.pop(context, true);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = messageFromDioException(e) ?? 'Failed to submit booking.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit booking.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
