import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:table_calendar/table_calendar.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/booking_session_lookup.dart';
import '../utils/dio_error_message.dart';
import '../utils/payment_status.dart';
import 'app_palette.dart';
import 'home_screen_ui.dart' show PaymentsScreen;

/// Premium, guided booking flow (wizard).
///
/// Backend contract: `POST /bookings/` requires:
/// - consent_given = true
/// - mental_health_description (min length enforced client-side)
/// - session_type: audio|video|physical
/// - duration_minutes
/// - preferred_dates: >=3 slots on distinct days (ISO-8601, UTC)
class ClientBookingFlowScreen extends StatefulWidget {
  const ClientBookingFlowScreen({
    super.key,
    this.preferredSpecialistId,
    this.preferredSpecialistName,
    this.initialDescription,
    this.initialSessionType,
    this.initialDurationMinutes,
    this.sessionTypeLocked = false,
    this.durationLocked = false,
    this.requireAvailabilityConfirmation = false,
  });

  final String? preferredSpecialistId;
  final String? preferredSpecialistName;
  final String? initialDescription;
  final String? initialSessionType; // audio|video|physical
  final int? initialDurationMinutes;
  final bool sessionTypeLocked;
  final bool durationLocked;
  final bool requireAvailabilityConfirmation;

  @override
  State<ClientBookingFlowScreen> createState() => _ClientBookingFlowScreenState();
}

class _ClientBookingFlowScreenState extends State<ClientBookingFlowScreen> {
  final _api = ApiService();
  final _storage = const FlutterSecureStorage();

  final _descriptionController = TextEditingController();

  int _step = 0;

  String _sessionType = 'video'; // audio|video|physical
  int _durationMinutes = 60;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _selectedTimeSlot;
  final List<DateTime> _selectedSlots = [];

  bool _consent = false;
  DateTime? _consentTimestampUtc;
  bool _availabilityConfirmed = false;

  final _physicalStreetController = TextEditingController();
  final _physicalCityController = TextEditingController();
  String _physicalVenue = 'home';

  String? _draftBookingId;
  String? _draftSessionId;
  bool _paymentReady = false;

  bool _submitting = false;
  String? _error;

  bool get _requiresPrePay => _sessionType == 'audio' || _sessionType == 'video';

  bool get _slotsReady {
    if (_selectedSlots.length < 3) return false;
    final uniqueDays = _selectedSlots.map((d) => DateTime(d.year, d.month, d.day)).toSet().length;
    return uniqueDays >= 3;
  }

  bool get _canConfirmBooking {
    if (!_termsAccepted) return false;
    if (!_slotsReady) return false;
    if (widget.requireAvailabilityConfirmation && !_availabilityConfirmed) return false;
    if (_requiresPrePay && !_paymentReady) return false;
    if (_sessionType == 'physical') {
      final street = _physicalStreetController.text.trim();
      final city = _physicalCityController.text.trim();
      if (street.length < 3 || city.length < 2) return false;
      if (_physicalVenue != 'home' && _physicalVenue != 'office') return false;
    }
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
    final initDur = widget.initialDurationMinutes;
    if (initDur == 30 || initDur == 60) _durationMinutes = initDur!;
    _restoreConsent();
    _selectedDay = DateTime.now().add(const Duration(days: 1));
    _focusedDay = _selectedDay!;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _physicalStreetController.dispose();
    _physicalCityController.dispose();
    super.dispose();
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
      setState(() {
        _consent = given == 'true';
        _consentTimestampUtc = ts != null ? DateTime.tryParse(ts)?.toUtc() : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _consent = false;
        _consentTimestampUtc = null;
      });
    }
  }

  Future<void> _setConsent(bool v) async {
    final ts = v ? DateTime.now().toUtc() : null;
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
    } catch (_) {}
  }

  bool get _termsAccepted => _consent && _consentTimestampUtc != null;

  String get _consultationTypeLabel {
    switch (_sessionType) {
      case 'audio':
        return 'Audio';
      case 'video':
        return 'Video';
      case 'physical':
        return 'Physical';
    }
    return 'Consultation';
  }

  String _priceLabel() {
    if (_sessionType == 'physical') return 'Negotiated (after scheduling)';
    if (_durationMinutes == 30) return 'TZS 20,000';
    return 'TZS 30,000';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
        foregroundColor: SmartAfyaPalette.deepText,
        title: const Text('Book consultation', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _topProgress(),
            Expanded(
              child: Stepper(
                type: StepperType.horizontal,
                currentStep: _step,
                elevation: 0,
                controlsBuilder: (context, details) => const SizedBox.shrink(),
                steps: [
                  Step(
                    title: const Text('Details'),
                    isActive: _step >= 0,
                    state: _step > 0 ? StepState.complete : StepState.indexed,
                    content: _stepType(),
                  ),
                  Step(
                    title: const Text('Duration'),
                    isActive: _step >= 1,
                    state: _step > 1 ? StepState.complete : StepState.indexed,
                    content: _stepDuration(),
                  ),
                  Step(
                    title: const Text('Availability'),
                    isActive: _step >= 2,
                    state: _step > 2 ? StepState.complete : StepState.indexed,
                    content: _stepAvailability(),
                  ),
                  Step(
                    title: const Text('Summary'),
                    isActive: _step >= 3,
                    state: StepState.indexed,
                    content: _stepSummary(),
                  ),
                ],
              ),
            ),
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
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _step == 0 ? () => Navigator.pop(context) : _prev,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFE4EEF7)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(_step == 0 ? 'Cancel' : 'Back', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitting
                          ? null
                          : (_step < 3 || _canConfirmBooking ? _primaryAction : null),
                      style: FilledButton.styleFrom(
                        backgroundColor: SmartAfyaPalette.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : Text(
                              _step < 3 ? 'Continue' : _confirmButtonLabel(),
                              style: const TextStyle(fontWeight: FontWeight.w900),
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

  Widget _topProgress() {
    final label = switch (_step) {
      0 => 'Appointment booking',
      1 => 'Select duration & price',
      2 => 'Pick your availability',
      _ => 'Review & confirm',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE4EEF7)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Premium guided booking · Step ${_step + 1} of 4',
                    style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: SmartAfyaPalette.softBlue,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE4EEF7)),
              ),
              child: Text(
                _consultationTypeLabel,
                style: const TextStyle(color: SmartAfyaPalette.primaryBlue, fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _prev() => setState(() {
        _error = null;
        _step = (_step - 1).clamp(0, 3);
      });

  Future<void> _primaryAction() async {
    setState(() => _error = null);
    if (_step == 0) {
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      // For physical sessions we collect location in summary.
      setState(() => _step = 2);
      return;
    }
    if (_step == 2) {
      final ok = _validateAvailability(showError: true);
      if (!ok) return;
      setState(() => _step = 3);
      if (_requiresPrePay && !_paymentReady && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complete payment before confirming your booking.')),
        );
      }
      return;
    }

    await _submit();
  }

  String _confirmButtonLabel() {
    if (!_termsAccepted) return 'Accept terms to confirm';
    if (!_slotsReady) return 'Add availability slots';
    if (_requiresPrePay && !_paymentReady) return 'Complete payment to confirm';
    return 'Confirm booking';
  }

  Widget _stepType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('State of mind'),
        const SizedBox(height: 10),
        TextField(
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
        ),
        const SizedBox(height: 18),
        _sectionTitle('Consent'),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _consent,
          onChanged: (v) => _setConsent(v ?? false),
          activeColor: SmartAfyaPalette.primaryBlue,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'I accept the Terms & Conditions and consent to share this information with my care team. Consent is required to submit.',
            style: TextStyle(color: SmartAfyaPalette.deepText, fontWeight: FontWeight.w600, height: 1.3),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _showTermsAndConditions,
            child: const Text('View Terms & Conditions'),
          ),
        ),
        const SizedBox(height: 14),
        _sectionTitle('Consultation type'),
        const SizedBox(height: 10),
        _segmented<String>(
          value: _sessionType,
          items: const [
            ('audio', 'Audio'),
            ('video', 'Video'),
            ('physical', 'Physical'),
          ],
          onChanged: widget.sessionTypeLocked
              ? null
              : (v) => setState(() {
                    _sessionType = v;
                    _error = null;
                  }),
        ),
        const SizedBox(height: 12),
        Text(
          _sessionType == 'physical'
              ? 'Physical consultations are coordinated by admin and may require location details.'
              : 'Online consultations are secure. You’ll receive your meeting link after confirmation.',
          style: const TextStyle(color: SmartAfyaPalette.mutedText, height: 1.35),
        ),
      ],
    );
  }

  Widget _stepDuration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Duration'),
        const SizedBox(height: 10),
        _segmented<int>(
          value: _durationMinutes,
          items: const [(30, '30 min'), (60, '1 hour')],
          onChanged: widget.durationLocked ? null : (v) => setState(() => _durationMinutes = v),
        ),
        const SizedBox(height: 12),
        _summaryCard(
          title: 'Dynamic pricing',
          lines: [
            'Type: $_consultationTypeLabel',
            'Duration: ${_durationMinutes == 30 ? "30 minutes" : "1 hour"}',
            'Price: ${_priceLabel()}',
          ],
        ),
      ],
    );
  }

  Widget _stepAvailability() {
    final day = _selectedDay;
    final slots = day == null ? <DateTime>[] : _generateSlotsForDay(day, durationMinutes: _durationMinutes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Pick dates & time slots'),
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
            ..._selectedSlots.map((dt) => _slotChip(dt)),
            ActionChip(
              label: const Text('Add slot'),
              avatar: const Icon(Icons.add, size: 18, color: SmartAfyaPalette.primaryBlue),
              onPressed: _pickSlot,
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE4EEF7)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Optional: use the calendar below to quickly choose a day, then tap a time slot.',
          style: TextStyle(color: SmartAfyaPalette.mutedText, height: 1.35),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4EEF7)),
          ),
          child: TableCalendar<void>(
            firstDay: DateTime.now(),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            selectedDayPredicate: (d) => day != null && _isSameDay(d, day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = DateTime(selected.year, selected.month, selected.day);
                _focusedDay = focused;
                _selectedTimeSlot = null;
                _error = null;
              });
            },
            onPageChanged: (focused) => setState(() => _focusedDay = focused),
            headerStyle: const HeaderStyle(titleCentered: true, formatButtonVisible: false),
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(color: SmartAfyaPalette.softBlue, shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: SmartAfyaPalette.primaryBlue, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _sectionTitle('Time slots'),
        const SizedBox(height: 10),
        if (day == null)
          const Text('Pick a day above to see time slots.', style: TextStyle(color: SmartAfyaPalette.mutedText))
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final dt in slots) _timeSlotChip(dt),
            ],
          ),
        const SizedBox(height: 10),
        const Text(
          'Tip: pick slots on at least 3 different days so we can schedule you faster.',
          style: TextStyle(color: SmartAfyaPalette.mutedText, height: 1.35),
        ),
      ],
    );
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
                const Text('Terms & Conditions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                const Text(
                  'By submitting this form, you confirm the information you provide is accurate to the best of your knowledge. '
                  'Your responses may be reviewed by your assigned care team to help prepare for your session. '
                  'If you are experiencing an emergency, contact local emergency services immediately.',
                  style: TextStyle(color: SmartAfyaPalette.mutedText, height: 1.45),
                ),
                const SizedBox(height: 16),
                if (_consentTimestampUtc != null)
                  Text(
                    'Last accepted: ${_consentTimestampUtc!.toLocal()}',
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

  Future<void> _pickSlot() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (!mounted) return;
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (!mounted) return;
    if (time == null) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    _addSlot(dt);
  }

  bool _validateAvailability({required bool showError}) {
    if (_selectedSlots.length < 3) {
      if (showError) setState(() => _error = 'Please select at least 3 availability slots.');
      return false;
    }
    final uniqueDays = _selectedSlots.map((d) => DateTime(d.year, d.month, d.day)).toSet().length;
    if (uniqueDays < 3) {
      if (showError) setState(() => _error = 'Please pick slots across at least 3 different calendar days.');
      return false;
    }
    if (widget.requireAvailabilityConfirmation && !_availabilityConfirmed) {
      if (showError) setState(() => _error = 'Please confirm your availability.');
      return false;
    }
    return true;
  }

  Widget _stepSummary() {
    final specialistName = (widget.preferredSpecialistName ?? '').trim();
    final specialistId = (widget.preferredSpecialistId ?? '').trim();
    final showSpecialist = specialistName.isNotEmpty || specialistId.isNotEmpty;
    final slotLines = _selectedSlots
      ..sort((a, b) => a.compareTo(b));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Booking summary'),
        const SizedBox(height: 10),
        _summaryCard(
          title: 'Your consultation',
          lines: [
            'Type: $_consultationTypeLabel',
            'Duration: ${_durationMinutes == 30 ? "30 min" : "1 hour"}',
            'Price: ${_priceLabel()}',
            if (showSpecialist) 'Specialist: ${specialistName.isNotEmpty ? specialistName : "Selected"}',
          ],
        ),
        const SizedBox(height: 12),
        _summaryCard(
          title: 'Availability',
          lines: slotLines.map((dt) => _formatSlotRange(dt, durationMinutes: _durationMinutes)).toList(),
        ),
        if (_requiresPrePay) ...[
          const SizedBox(height: 12),
          _paymentBeforeSubmitCard(),
        ],
        const SizedBox(height: 12),
        _sectionTitle('Payment method'),
        const SizedBox(height: 10),
        _paymentSummaryCard(),
        const SizedBox(height: 12),
        _sectionTitle('Notes for your specialist'),
        const SizedBox(height: 10),
        TextField(
          controller: _descriptionController,
          minLines: 4,
          maxLines: 8,
          decoration: InputDecoration(
            hintText: 'Briefly describe your concern (required)',
            filled: true,
            fillColor: SmartAfyaPalette.softBlue,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        _sectionTitle('Terms & Conditions'),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _consent,
          onChanged: (v) => _setConsent(v ?? false),
          activeColor: SmartAfyaPalette.primaryBlue,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'I accept the Terms & Conditions and consent to share this information with my care team.',
            style: TextStyle(color: SmartAfyaPalette.deepText, fontWeight: FontWeight.w600, height: 1.3),
          ),
        ),
        if (widget.requireAvailabilityConfirmation) ...[
          const SizedBox(height: 4),
          CheckboxListTile(
            value: _availabilityConfirmed,
            onChanged: (v) => setState(() => _availabilityConfirmed = v ?? false),
            activeColor: SmartAfyaPalette.primaryBlue,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'I confirm I can attend at the selected times.',
              style: TextStyle(color: SmartAfyaPalette.deepText, fontWeight: FontWeight.w600, height: 1.3),
            ),
          ),
        ],
        if (_sessionType == 'physical') ...[
          const SizedBox(height: 10),
          _visitLocationCard(),
          const SizedBox(height: 10),
          _segmented<String>(
            value: _physicalVenue,
            items: const [('home', 'Home visit'), ('office', 'Office / clinic')],
            onChanged: (v) => setState(() => _physicalVenue = v),
          ),
        ],
      ],
    );
  }

  Widget _paymentBeforeSubmitCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _paymentReady ? const Color(0xFFE8F8F0) : const Color(0xFFFFF6E5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _paymentReady ? const Color(0xFFB8E6C8) : const Color(0xFFFFE2A8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _paymentReady ? 'Payment received' : 'Payment required before confirming',
            style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
          ),
          const SizedBox(height: 6),
          Text(
            _paymentReady
                ? 'You can confirm your booking now.'
                : 'Pay ${_priceLabel()} and submit proof, then confirm your booking.',
            style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600, height: 1.35),
          ),
          if (!_paymentReady) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _submitting ? null : _goToPayment,
              style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
              icon: const Icon(Icons.payments_rounded),
              label: const Text('Pay now', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ],
      ),
    );
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

  Future<void> _ensureDraftBooking(String description) async {
    if (_draftSessionId != null && _draftSessionId!.isNotEmpty) return;
    final preferredIso = _selectedSlots.map((d) => d.toUtc().toIso8601String()).toList();
    final booking = await _api.createBooking(
      mentalHealthDescription: description,
      consentGiven: true,
      sessionType: _sessionType,
      durationMinutes: _durationMinutes,
      preferredDates: preferredIso,
      preferredSpecialistId: _sessionType == 'physical' ? null : widget.preferredSpecialistId,
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
    final description = _descriptionController.text.trim();
    if (description.length < 10) {
      setState(() => _error = 'Please add a bit more detail in your notes.');
      return;
    }
    if (!_termsAccepted) {
      setState(() => _error = 'Please accept Terms & Conditions.');
      return;
    }
    if (!_validateAvailability(showError: true)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _ensureDraftBooking(description);
      final sessionId = _draftSessionId;
      if (sessionId == null || sessionId.isEmpty) {
        setState(() => _error = 'Could not start payment. Please try again.');
        return;
      }
      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(builder: (_) => PaymentsScreen(initialSessionId: sessionId)),
      );
      if (!mounted) return;
      await _refreshDraftPayment();
    } on DioException catch (e) {
      setState(() => _error = messageFromDioException(e) ?? 'Could not start payment.');
    } catch (_) {
      setState(() => _error = 'Could not start payment.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _paymentSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EEF7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment summary', style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText)),
          const SizedBox(height: 8),
          Text(
            _sessionType == 'physical'
                ? 'Physical payments are negotiated after scheduling.'
                : 'You’ll pay ${_priceLabel()} via Mobile Money (Lipa Namba) or Bank.',
            style: const TextStyle(color: SmartAfyaPalette.mutedText, height: 1.35),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              _pill(icon: Icons.phone_iphone_rounded, label: 'Mobile money'),
              _pill(icon: Icons.account_balance_rounded, label: 'Bank'),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              await NotificationService.showPaymentRequest(
                title: 'Payment request ready',
                body: 'When your booking is confirmed, you’ll receive a payment prompt.',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment request notification triggered.')),
                );
              }
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE4EEF7)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.notifications_active_outlined, color: SmartAfyaPalette.primaryBlue),
            label: const Text('Trigger payment request notification', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _pill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: SmartAfyaPalette.softBlue,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4EEF7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: SmartAfyaPalette.primaryBlue),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.length < 10) {
      setState(() => _error = 'Please add a bit more detail in your notes (at least a short paragraph).');
      return;
    }
    if (!_termsAccepted) {
      setState(() => _error = 'Please accept Terms & Conditions to continue.');
      return;
    }
    if (!_validateAvailability(showError: true)) return;
    if (_requiresPrePay && !_paymentReady) {
      setState(() => _error = 'Complete payment before confirming your booking.');
      return;
    }

    if (_sessionType == 'physical') {
      final street = _physicalStreetController.text.trim();
      final city = _physicalCityController.text.trim();
      if (street.length < 3 || city.length < 2) {
        setState(() => _error = 'Please enter your street and city for the visit.');
        return;
      }
      if (_physicalVenue != 'home' && _physicalVenue != 'office') {
        setState(() => _error = 'Please select Home visit or Office/clinic.');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_draftBookingId == null) {
        await _ensureDraftBooking(description);
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
        const SnackBar(content: Text('Booking submitted. We’ll confirm your consultation soon.')),
      );
      Navigator.pop(context, true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = messageFromDioException(e) ?? 'Failed to submit booking.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to submit booking.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
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
      labelStyle: const TextStyle(color: SmartAfyaPalette.deepText, fontWeight: FontWeight.w700, fontSize: 13),
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
                TextField(
                  controller: _physicalStreetController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _visitFieldDecoration(
                    label: 'Street',
                    hint: 'e.g. Masaki Peninsula, Plot 12',
                    icon: Icons.signpost_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _physicalCityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _visitFieldDecoration(
                    label: 'City',
                    hint: 'e.g. Dar es Salaam',
                    icon: Icons.location_city_outlined,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({required String title, required List<String> lines}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EEF7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText)),
          const SizedBox(height: 10),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(l, style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600, height: 1.25)),
            ),
        ],
      ),
    );
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
                    fontWeight: value == items[i].$1 ? FontWeight.w900 : FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<DateTime> _generateSlotsForDay(DateTime day, {required int durationMinutes}) {
    // Premium default: business hours 08:00–18:00, step 30 min.
    final start = DateTime(day.year, day.month, day.day, 8);
    final end = DateTime(day.year, day.month, day.day, 18);
    final step = const Duration(minutes: 30);
    final out = <DateTime>[];
    for (var t = start; t.isBefore(end); t = t.add(step)) {
      out.add(t);
    }
    return out;
  }

  Widget _timeSlotChip(DateTime dt) {
    final selected = _selectedTimeSlot != null && dt == _selectedTimeSlot;
    final label = _formatTime(dt);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: SmartAfyaPalette.softBlue,
      onSelected: (_) {
        setState(() {
          _selectedTimeSlot = dt;
          _error = null;
        });
        _addSlot(dt);
      },
      labelStyle: TextStyle(
        color: selected ? SmartAfyaPalette.primaryBlue : SmartAfyaPalette.deepText,
        fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? SmartAfyaPalette.primaryBlue : const Color(0xFFE4EEF7)),
    );
  }

  void _addSlot(DateTime dt) {
    if (_selectedSlots.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can add up to 6 slots.')));
      return;
    }
    if (_selectedSlots.any((x) => x == dt)) return;
    setState(() => _selectedSlots.add(dt));
  }

  Widget _slotChip(DateTime dt) {
    return InputChip(
      label: Text(_formatSlotRange(dt, durationMinutes: _durationMinutes)),
      onDeleted: () => setState(() => _selectedSlots.remove(dt)),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE4EEF7)),
      labelStyle: const TextStyle(color: SmartAfyaPalette.deepText, fontWeight: FontWeight.w700),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _formatTime(DateTime dt) {
    final hour = (dt.hour % 12 == 0) ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  static String _formatSlotRange(DateTime start, {required int durationMinutes}) {
    final end = start.add(Duration(minutes: durationMinutes));
    String fmtDate(DateTime dt) =>
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    return '${fmtDate(start)} · ${_formatTime(start)}-${_formatTime(end)}';
  }
}

