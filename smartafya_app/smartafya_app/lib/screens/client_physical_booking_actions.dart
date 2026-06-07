import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';

/// Cancellation and reschedule flow for physical bookings (client).
Future<void> showClientPhysicalBookingActions({
  required BuildContext context,
  required SessionDto session,
  required BookingDto booking,
  required ApiService api,
  required VoidCallback onDone,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Physical visit',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Session status: ${session.status}\nBooking status: ${booking.status}',
                style: const TextStyle(color: SmartAfyaPalette.mutedText, height: 1.35, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: booking.status.toLowerCase() == 'cancelled'
                    ? null
                    : () async {
                        final ok = await showDialog<bool>(
                          context: ctx,
                          builder: (dctx) => AlertDialog(
                            title: const Text('Cancel visit?'),
                            content: const Text(
                              'This cancels your booking and linked session. Admin and your doctor (if assigned) are notified through the system audit trail.',
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Keep')),
                              FilledButton(
                                onPressed: () => Navigator.pop(dctx, true),
                                style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                                child: const Text('Cancel booking'),
                              ),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        try {
                          await api.cancelBooking(booking.id);
                          await NotificationService.physicalWorkflow(
                            title: 'Booking cancelled',
                            body: 'Your physical visit request was cancelled.',
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          onDone();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Booking cancelled.')),
                            );
                          }
                        } on DioException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(messageFromDioException(e) ?? 'Could not cancel.')),
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel booking', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: booking.status.toLowerCase() == 'cancelled'
                    ? null
                    : () async {
                        final slots = <DateTime>[];
                        Future<void> pickOne(String label) async {
                          final now = DateTime.now();
                          final d = await showDatePicker(
                            context: ctx,
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 365)),
                            initialDate: now.add(Duration(days: slots.length + 1)),
                          );
                          if (!ctx.mounted) return;
                          if (d == null) return;
                          final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                          if (!ctx.mounted) return;
                          if (t == null) return;
                          slots.add(DateTime(d.year, d.month, d.day, t.hour, t.minute));
                        }

                        await pickOne('1');
                        if (slots.isEmpty) return;
                        await pickOne('2');
                        if (slots.length < 2) return;
                        await pickOne('3');
                        if (slots.length < 3) return;

                        if (!ctx.mounted) return;
                        final noteController = TextEditingController();
                        final go = await showDialog<bool>(
                          context: ctx,
                          builder: (dctx) => AlertDialog(
                            title: const Text('Reschedule note'),
                            content: TextField(
                              controller: noteController,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                hintText: 'Optional message to admin',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Back')),
                              FilledButton(
                                onPressed: () => Navigator.pop(dctx, true),
                                child: const Text('Submit'),
                              ),
                            ],
                          ),
                        );
                        if (go != true) {
                          noteController.dispose();
                          return;
                        }

                        try {
                          final iso = slots.map((e) => e.toUtc().toIso8601String()).toList();
                          await api.requestBookingReschedule(
                            bookingId: booking.id,
                            preferredDates: iso,
                            note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                          );
                          await NotificationService.physicalWorkflow(
                            title: 'Reschedule requested',
                            body: 'Admin will review your new preferred times.',
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          onDone();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reschedule request sent to admin.')),
                            );
                          }
                        } on DioException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(messageFromDioException(e) ?? 'Request failed.')),
                            );
                          }
                        } finally {
                          noteController.dispose();
                        }
                      },
                style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryGreen),
                icon: const Icon(Icons.event_repeat_rounded),
                label: const Text('Request reschedule (3 new slots)', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
    },
  );
}
