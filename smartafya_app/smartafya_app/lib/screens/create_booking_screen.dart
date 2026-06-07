import 'package:flutter/material.dart';

import 'single_booking_screen.dart';

/// Opens the single-screen booking experience, optionally with a pre-selected specialist.
class CreateBookingScreen extends StatelessWidget {
  const CreateBookingScreen({
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
    return SingleBookingScreen(
      initialDescription: initialDescription,
      preferredSpecialistId: preferredSpecialistId,
      preferredSpecialistName: preferredSpecialistName,
      initialSessionType: initialSessionType,
      initialDurationMinutes: initialDurationMinutes,
      sessionTypeLocked: sessionTypeLocked,
      durationLocked: durationLocked,
      requireAvailabilityConfirmation: requireAvailabilityConfirmation,
    );
  }
}
