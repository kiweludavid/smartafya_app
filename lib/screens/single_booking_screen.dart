import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'booking_request_form.dart';

/// Single-screen booking experience (matches screenshot layout).
///
/// This is the recommended booking UI: mental health description + consent +
/// session type + duration + preferred dates in ONE screen, wired to `POST /bookings/`.
class SingleBookingScreen extends StatelessWidget {
  const SingleBookingScreen({
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
  Widget build(BuildContext context) {
    final locked = (preferredSpecialistId ?? '').trim().isNotEmpty;
    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
        foregroundColor: SmartAfyaPalette.deepText,
        title: const Text('Mental health & booking', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'help us match you and prepare for your session.',
                style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              BookingRequestForm(
                initialDescription: initialDescription,
                initialSessionType: initialSessionType,
                preferredSpecialistId: preferredSpecialistId,
                preferredSpecialistName: preferredSpecialistName,
                specialistLocked: locked,
                initialDurationMinutes: initialDurationMinutes,
                sessionTypeLocked: sessionTypeLocked,
                durationLocked: durationLocked || locked,
                requireAvailabilityConfirmation: requireAvailabilityConfirmation,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

