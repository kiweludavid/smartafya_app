import '../services/api_service.dart';

/// Resolves the session linked to a booking (created together on `POST /bookings/`).
Future<String?> sessionIdForBooking(ApiService api, String bookingId) async {
  for (var attempt = 0; attempt < 6; attempt++) {
    final sessions = await api.fetchSessions();
    for (final s in sessions) {
      if (s.bookingId == bookingId) return s.id;
    }
    if (attempt < 5) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }
  return null;
}
