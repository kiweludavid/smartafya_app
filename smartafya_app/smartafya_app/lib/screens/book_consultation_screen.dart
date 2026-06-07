import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'create_booking_screen.dart';

/// Premium booking entry screen (backend-aligned).
///
/// Backend booking payload requires: session_type, duration_minutes, preferred_dates (picked in wizard),
/// consent, and a mental health description. Specialist is optional.
class BookConsultationScreen extends StatefulWidget {
  const BookConsultationScreen({super.key});

  @override
  State<BookConsultationScreen> createState() => _BookConsultationScreenState();
}

class _BookConsultationScreenState extends State<BookConsultationScreen> {
  String _sessionType = 'video'; // audio|video|physical
  int _durationMinutes = 60;

  @override
  void initState() {
    super.initState();
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
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            _primaryCard(
              title: 'Choose your consultation',
              subtitle: 'Select type and duration.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionTitle('Consultation type'),
                  const SizedBox(height: 10),
                  _segmented<String>(
                    value: _sessionType,
                    items: const [('audio', 'Audio'), ('video', 'Video'), ('physical', 'Physical')],
                    onChanged: (v) => setState(() => _sessionType = v),
                  ),
                  const SizedBox(height: 14),
                  _sectionTitle('Duration'),
                  const SizedBox(height: 10),
                  _segmented<int>(
                    value: _durationMinutes,
                    items: const [(30, '30 min'), (60, '1 hour')],
                    onChanged: (v) => setState(() => _durationMinutes = v),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SmartAfyaPalette.softBlue,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4EEF7)),
                    ),
                    child: Text(
                      _priceHint(sessionType: _sessionType, durationMinutes: _durationMinutes),
                      style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_sessionType == 'physical')
              _primaryCard(
                title: 'Physical visit',
                subtitle: 'You’ll provide location details in the next step. Admin will coordinate scheduling and payment.',
                child: const SizedBox.shrink(),
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
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _continue,
              style: FilledButton.styleFrom(
                backgroundColor: SmartAfyaPalette.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ),
    );
  }

  void _continue() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CreateBookingScreen(
          preferredSpecialistId: null,
          preferredSpecialistName: null,
          initialSessionType: _sessionType,
          sessionTypeLocked: true,
          initialDurationMinutes: _durationMinutes,
          durationLocked: true,
        ),
      ),
    );
  }

  Widget _primaryCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EEF7)),
        boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText, fontSize: 16)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600, height: 1.3)),
          if (child is! SizedBox) ...[
            const SizedBox(height: 16),
            child,
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
      );

  Widget _segmented<T>({
    required T value,
    required List<(T, String)> items,
    required ValueChanged<T> onChanged,
  }) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < items.length - 1 ? 8 : 0),
              child: OutlinedButton(
                onPressed: () => onChanged(items[i].$1),
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

  String _priceHint({required String sessionType, required int durationMinutes}) {
    if (sessionType == 'physical') return 'Physical session price is negotiated after scheduling.';
    final base = durationMinutes == 30 ? 'TZS 20,000' : 'TZS 30,000';
    return 'Estimated price: $base • Payment is requested after confirmation.';
  }

  // Specialist selection intentionally removed from this screen.
}
