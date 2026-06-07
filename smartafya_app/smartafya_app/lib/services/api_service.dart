import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_client.dart';

/// Production API layer for Smart Afya — uses [ApiClient] (Dio + secure JWT).
class ApiService {
  ApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Dio get _dio => _client.dio;

  // ——— User ———

  Future<CurrentUserDto> fetchCurrentUser() async {
    final res = await _dio.get('/users/me');
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return CurrentUserDto.fromJson(Map<String, dynamic>.from(data));
  }

  /// Updates profile fields allowed by `PATCH /users/me` ([UserUpdate] on backend).
  Future<CurrentUserDto> patchCurrentUser({
    String? fullName,
    String? phone,
    String? specialistType,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName.trim();
    if (phone != null) {
      final t = phone.trim();
      body['phone'] = t.isEmpty ? null : t;
    }
    if (specialistType != null) {
      final t = specialistType.trim();
      body['specialist_type'] = t.isEmpty ? null : t;
    }
    final res = await _dio.patch('/users/me', data: body);
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return CurrentUserDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> updateDoctorAvailability({required bool isAvailable}) async {
    await _dio.patch('/users/me/availability', data: {'is_available': isAvailable});
  }

  Future<List<DoctorDto>> fetchDoctors({
    bool availableOnly = false,
    String? specialistType,
    String? excludeDoctorId,
  }) async {
    final qp = <String, dynamic>{'available_only': availableOnly};
    if (specialistType != null && specialistType.trim().isNotEmpty) {
      qp['specialist_type'] = specialistType.trim();
    }
    if (excludeDoctorId != null && excludeDoctorId.trim().isNotEmpty) {
      qp['exclude_doctor_id'] = excludeDoctorId.trim();
    }
    final res = await _dio.get(
      '/users/doctors',
      queryParameters: qp,
    );
    final data = res.data;
    if (data is! List) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return data
        .whereType<Map>()
        .map((e) => DoctorDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ——— Bookings ———

  Future<BookingDto> createBooking({
    required String mentalHealthDescription,
    required bool consentGiven,
    required String sessionType, // 'audio' | 'video' | 'physical'
    required int durationMinutes,
    required List<String> preferredDates, // at least 3 ISO strings
    String? preferredSpecialistId,
    String? preferredSpecialistType,
    String? physicalLocationAddress,
    double? physicalLocationLat,
    double? physicalLocationLng,
    String? physicalVenue, // 'home' | 'office'
    String? physicalNotes,
  }) async {
    final body = <String, dynamic>{
      'mental_health_description': mentalHealthDescription,
      'consent_given': consentGiven,
      'session_type': sessionType,
      'duration_minutes': durationMinutes,
      'preferred_dates': preferredDates,
      'preferred_specialist_id': preferredSpecialistId,
      'preferred_specialist_type': preferredSpecialistType?.trim(),
      'physical_location_address': physicalLocationAddress?.trim(),
      'physical_location_lat': physicalLocationLat,
      'physical_location_lng': physicalLocationLng,
      'physical_venue': physicalVenue?.trim(),
      'physical_notes': physicalNotes?.trim(),
    };
    body.removeWhere((_, v) => v == null || (v is String && v.trim().isEmpty));
    final res = await _dio.post(
      '/bookings/',
      data: body,
    );
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return BookingDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<BookingDto>> fetchMyBookings() async {
    final res = await _dio.get('/bookings/my');
    return _parseBookingList(res);
  }

  Future<BookingDto> fetchBookingById(String bookingId) async {
    final res = await _dio.get('/bookings/$bookingId');
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return BookingDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<SessionDto> patchSession(
    String sessionId, {
    String? status,
    String? meetingLink,
    String? scheduledAt,
    String? notes,
  }) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status;
    if (meetingLink != null) body['meeting_link'] = meetingLink;
    if (scheduledAt != null) body['scheduled_at'] = scheduledAt;
    if (notes != null) body['notes'] = notes;
    final res = await _dio.patch('/sessions/$sessionId', data: body);
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return SessionDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<BookingDto>> fetchAllBookings() async {
    final res = await _dio.get('/bookings/');
    return _parseBookingList(res);
  }

  Future<BookingDto> cancelBooking(String bookingId) async {
    final res = await _dio.post('/bookings/$bookingId/cancel');
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return BookingDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<BookingDto> requestBookingReschedule({
    required String bookingId,
    required List<String> preferredDates,
    String? note,
  }) async {
    final res = await _dio.post(
      '/bookings/$bookingId/reschedule-request',
      data: {
        'preferred_dates': preferredDates,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return BookingDto.fromJson(Map<String, dynamic>.from(data));
  }

  List<BookingDto> _parseBookingList(Response res) {
    final data = res.data;
    if (data is! List) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return data
        .whereType<Map>()
        .map((e) => BookingDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ——— Sessions ———

  Future<List<SessionDto>> fetchSessions() async {
    final res = await _dio.get('/sessions/');
    final data = res.data;
    if (data is! List) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return data
        .whereType<Map>()
        .map((e) => SessionDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Admin: create a new session with full scheduling details.
  ///
  /// Expected backend: `POST /sessions/` returning a Session JSON object.
  Future<SessionDto> createSessionAdmin({
    required String clientId,
    required String doctorId,
    required String scheduledAtIsoUtc,
    required int durationMinutes,
    required String sessionType, // 'online' | 'physical'
    required String status, // 'scheduled'
    String? meetingLink,
    String? notes,
  }) async {
    final res = await _dio.post(
      '/sessions/',
      data: {
        'client_id': clientId,
        'doctor_id': doctorId,
        'scheduled_at': scheduledAtIsoUtc,
        'duration_minutes': durationMinutes,
        'session_type': sessionType,
        'status': status,
        if (meetingLink != null && meetingLink.trim().isNotEmpty) 'meeting_link': meetingLink.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return SessionDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<SessionDto> fetchSessionById(String sessionId) async {
    final res = await _dio.get('/sessions/$sessionId');
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return SessionDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<MarkUnavailableResult> markSessionUnavailable(String sessionId) async {
    final res = await _dio.post('/sessions/$sessionId/unavailable');
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return MarkUnavailableResult.fromJson(Map<String, dynamic>.from(data));
  }

  Future<DoctorUnavailabilityBlockResultDto> createDoctorUnavailabilityBlock({
    required DateTime startsAtUtc,
    required DateTime endsAtUtc,
  }) async {
    final res = await _dio.post(
      '/care-actions/doctor/unavailability-block',
      data: {
        'starts_at': startsAtUtc.toUtc().toIso8601String(),
        'ends_at': endsAtUtc.toUtc().toIso8601String(),
      },
    );
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return DoctorUnavailabilityBlockResultDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<DoctorDashboardSummaryDto> fetchDoctorDashboardSummary() async {
    final res = await _dio.get('/care-actions/doctor/summary');
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return DoctorDashboardSummaryDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<CareActionsDto> fetchCareActions() async {
    final res = await _dio.get('/care-actions/me');
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return CareActionsDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> respondToTransferRequest({required String requestId, required bool accept}) async {
    await _dio.post(
      '/transfers/patient-requests/$requestId/respond',
      data: {'accept': accept},
    );
  }

  Future<void> resolveUnavailabilityImpact({
    required String impactId,
    required String resolution, // 'transfer' | 'reschedule'
    String? toDoctorId,
    DateTime? newScheduledAtUtc,
  }) async {
    await _dio.post(
      '/care-actions/unavailability-impacts/$impactId/resolve',
      data: {
        'resolution': resolution,
        if (toDoctorId != null && toDoctorId.trim().isNotEmpty) 'to_doctor_id': toDoctorId.trim(),
        if (newScheduledAtUtc != null) 'new_scheduled_at': newScheduledAtUtc.toUtc().toIso8601String(),
      },
    );
  }

  Future<PatientTransferRequestDto> requestPatientTransfer({
    required String sessionId,
    required String toDoctorId,
    required String reason,
  }) async {
    final res = await _dio.post(
      '/transfers/sessions/$sessionId',
      data: {
        'to_doctor_id': toDoctorId,
        'reason': reason.trim(),
      },
    );
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return PatientTransferRequestDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<PatientTransferRequestDto?> fetchPendingTransferRequest(String sessionId) async {
    final res = await _dio.get('/transfers/sessions/$sessionId/pending-request');
    if (res.data == null) return null;
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    if (data.isEmpty) return null;
    return PatientTransferRequestDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<SessionDto> assignSessionDoctor({
    required String sessionId,
    required String doctorId,
    required String scheduledAtIso,
    String? meetingLink,
  }) async {
    final res = await _dio.post(
      '/sessions/$sessionId/assign',
      data: {
        'doctor_id': doctorId,
        'scheduled_at': scheduledAtIso,
        if (meetingLink != null && meetingLink.trim().isNotEmpty) 'meeting_link': meetingLink.trim(),
      },
    );
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return SessionDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<SessionDto> physicalCheckIn(String sessionId) async {
    final res = await _dio.post('/sessions/$sessionId/physical/check-in');
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return SessionDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<SessionDto> physicalCheckOut(String sessionId) async {
    final res = await _dio.post('/sessions/$sessionId/physical/check-out');
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return SessionDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<TransferLogDto>> fetchTransferHistory(String sessionId) async {
    final res = await _dio.get('/transfers/sessions/$sessionId/history');
    final data = res.data;
    if (data is! List) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return data
        .whereType<Map>()
        .map((e) => TransferLogDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ——— Chat ———

  Future<List<ChatConversationDto>> fetchChatConversations() async {
    final res = await _dio.get('/chat/conversations');
    final data = res.data;
    if (data is! List) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return data
        .whereType<Map>()
        .map((e) => ChatConversationDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ChatMessageDto>> fetchChatMessages(String conversationId) async {
    final res = await _dio.get('/chat/conversations/$conversationId/messages');
    final data = res.data;
    if (data is! List) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return data
        .whereType<Map>()
        .map((e) => ChatMessageDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ChatMessageDto> sendChatMessage(String conversationId, String body) async {
    final res = await _dio.post(
      '/chat/conversations/$conversationId/messages',
      data: {'body': body},
    );
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return ChatMessageDto.fromJson(Map<String, dynamic>.from(data));
  }

  // ——— Payments ———

  Future<PaymentDto?> fetchPaymentForSession(String sessionId) async {
    try {
      final res = await _dio.get('/payments/session/$sessionId');
      final data = res.data;
      if (data is! Map) return null;
      return PaymentDto.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<PaymentDto>> fetchAllPayments() async {
    final res = await _dio.get('/payments/');
    final data = res.data;
    if (data is! List) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return data
        .whereType<Map>()
        .map((e) => PaymentDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<PaymentDto> createPaymentRecord({
    required String sessionId,
    double? amount,
    String paymentType = 'negotiated',
    String? reference,
    String? instructionsText,
  }) async {
    final body = <String, dynamic>{
      'session_id': sessionId,
      'amount': amount,
      'payment_type': paymentType,
      'reference': reference?.trim(),
      'instructions_text': instructionsText?.trim(),
    };
    body.removeWhere((_, v) => v == null || (v is String && v.trim().isEmpty));
    final res = await _dio.post(
      '/payments/',
      data: body,
    );
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return PaymentDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<PaymentDto> patchPayment(
    String paymentId, {
    String? status,
    double? amount,
    String? reference,
    String? instructionsText,
  }) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status;
    if (amount != null) body['amount'] = amount;
    if (reference != null) body['reference'] = reference;
    if (instructionsText != null) body['instructions_text'] = instructionsText;
    final res = await _dio.patch('/payments/$paymentId', data: body);
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return PaymentDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<PaymentDto> submitPaymentProof({
    required String paymentId,
    required String proofBase64,
    String? filename,
  }) async {
    final res = await _dio.patch(
      '/payments/$paymentId/proof',
      data: {
        'proof_base64': proofBase64,
        if (filename != null && filename.trim().isNotEmpty) 'filename': filename.trim(),
      },
    );
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return PaymentDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<DoctorDto> adminSetDoctorBaseLocation({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    final res = await _dio.patch(
      '/users/$userId/doctor-base-location',
      data: {'base_latitude': latitude, 'base_longitude': longitude},
    );
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return DoctorDto.fromJson(Map<String, dynamic>.from(data));
  }

  // ——— Admin users ———

  Future<List<AdminUserDto>> fetchAllUsersForAdmin() async {
    final res = await _dio.get('/users/');
    final data = res.data;
    if (data is! List) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return data.whereType<Map>().map((e) => AdminUserDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // ——— Feedback ———

  Future<void> submitFeedback({
    required String sessionId,
    int? treatmentRating,
    String? doctorFeedback,
    int? appRating,
    String? appFeedback,
    String? suggestions,
    int? familyRating,
    String? familyComments,
  }) async {
    final body = <String, dynamic>{
      'session_id': sessionId,
      'treatment_rating': treatmentRating,
      'doctor_feedback': doctorFeedback?.trim(),
      'app_rating': appRating,
      'app_feedback': appFeedback?.trim(),
      'suggestions': suggestions?.trim(),
      'family_rating': familyRating,
      'family_comments': familyComments?.trim(),
    };
    body.removeWhere((_, v) => v == null || (v is String && v.trim().isEmpty));
    await _dio.post(
      '/feedback/',
      data: body,
    );
  }

  Future<List<FeedbackDto>> fetchMyFeedback() async {
    final res = await _dio.get('/feedback/my');
    final data = res.data;
    if (data is! List) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return data.whereType<Map>().map((e) => FeedbackDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Admin: list feedback items for monitoring/QA.
  ///
  /// Backend contract assumption: `GET /feedback/` returns a list for admins.
  Future<List<FeedbackDto>> fetchFeedbackForAdmin() async {
    final res = await _dio.get('/feedback/');
    final data = res.data;
    if (data is! List) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return data.whereType<Map>().map((e) => FeedbackDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Admin: update QA fields on a feedback item.
  ///
  /// Backend contract assumption: `PATCH /feedback/{id}` accepts these optional fields.
  Future<FeedbackDto> patchFeedback(
    String feedbackId, {
    bool? reviewed,
    bool? flagged,
    String? internalNote,
  }) async {
    final body = <String, dynamic>{};
    if (reviewed != null) body['reviewed'] = reviewed;
    if (flagged != null) body['flagged'] = flagged;
    if (internalNote != null) body['internal_note'] = internalNote;

    final res = await _dio.patch('/feedback/$feedbackId', data: body);
    final data = res.data;
    if (data is! Map) {
      throw DioException(requestOptions: res.requestOptions, type: DioExceptionType.badResponse);
    }
    return FeedbackDto.fromJson(Map<String, dynamic>.from(data));
  }

}

// ——— DTOs ———

class CurrentUserDto {
  CurrentUserDto({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.specialistType,
    required this.isActive,
    required this.isAvailable,
    this.phone,
    this.isVerified = false,
    this.baseLatitude,
    this.baseLongitude,
    this.createdAt,
    this.sessionCreditBalance = 0,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final String? specialistType;
  final bool isActive;
  final bool isAvailable;
  final String? phone;
  final bool isVerified;
  final double? baseLatitude;
  final double? baseLongitude;
  final DateTime? createdAt;
  final double sessionCreditBalance;

  factory CurrentUserDto.fromJson(Map<String, dynamic> json) {
    final rawRole = _stripEnum(json['role']).trim().toLowerCase();
    DateTime? created;
    final rawCreated = json['created_at'];
    if (rawCreated != null) {
      created = DateTime.tryParse(rawCreated.toString())?.toLocal();
    }
    return CurrentUserDto(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: rawRole.isEmpty ? 'client' : rawRole,
      specialistType: json['specialist_type'] != null ? _stripEnum(json['specialist_type']) : null,
      isActive: json['is_active'] == true,
      isAvailable: json['is_available'] == true,
      phone: _parseOptionalPhone(json['phone']),
      isVerified: json['is_verified'] == true,
      baseLatitude: (json['base_latitude'] is num) ? (json['base_latitude'] as num).toDouble() : null,
      baseLongitude: (json['base_longitude'] is num) ? (json['base_longitude'] as num).toDouble() : null,
      createdAt: created,
      sessionCreditBalance: (json['session_credit_balance'] is num)
          ? (json['session_credit_balance'] as num).toDouble()
          : double.tryParse(json['session_credit_balance']?.toString() ?? '') ?? 0,
    );
  }

  bool get isClient => role == 'client';
  bool get isDoctor => role == 'doctor';
}

class DoctorDto {
  DoctorDto({
    required this.id,
    required this.fullName,
    required this.email,
    this.specialistType,
    required this.isAvailable,
    this.baseLatitude,
    this.baseLongitude,
  });

  final String id;
  final String fullName;
  final String email;
  final String? specialistType;
  final bool isAvailable;
  final double? baseLatitude;
  final double? baseLongitude;

  factory DoctorDto.fromJson(Map<String, dynamic> json) {
    return DoctorDto(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      specialistType: json['specialist_type'] != null ? _stripEnum(json['specialist_type']) : null,
      isAvailable: json['is_available'] == true,
      baseLatitude: (json['base_latitude'] is num) ? (json['base_latitude'] as num).toDouble() : null,
      baseLongitude: (json['base_longitude'] is num) ? (json['base_longitude'] as num).toDouble() : null,
    );
  }

  String get specialistLabel {
    final s = specialistType;
    if (s == null || s.isEmpty) return 'Mental health specialist';
    final words = s
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}');
    return words.join(' ');
  }
}

class AdminUserDto {
  AdminUserDto({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.isAvailable,
    this.specialistType,
  });

  final String id;
  final String fullName;
  final String email;
  final String role; // 'client' | 'doctor'
  final bool isActive;
  final bool isAvailable;
  final String? specialistType;

  factory AdminUserDto.fromJson(Map<String, dynamic> json) {
    return AdminUserDto(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: _stripEnum(json['role']).toLowerCase().trim(),
      isActive: json['is_active'] == true,
      isAvailable: json['is_available'] == true,
      specialistType: json['specialist_type'] != null ? _stripEnum(json['specialist_type']) : null,
    );
  }

  bool get isClient => role == 'client';
  bool get isDoctor => role == 'doctor';
}

class MarkUnavailableResult {
  MarkUnavailableResult({
    required this.message,
    required this.options,
    required this.sessionId,
  });

  final String message;
  final List<String> options;
  final String sessionId;

  factory MarkUnavailableResult.fromJson(Map<String, dynamic> json) {
    final raw = json['options'];
    final opts = (raw is List) ? raw.map((e) => e.toString()).toList() : <String>[];
    return MarkUnavailableResult(
      message: json['message']?.toString() ?? '',
      options: opts,
      sessionId: json['session_id']?.toString() ?? '',
    );
  }
}

class PatientTransferRequestDto {
  PatientTransferRequestDto({
    required this.id,
    required this.sessionId,
    required this.fromDoctorId,
    required this.toDoctorId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String sessionId;
  final String fromDoctorId;
  final String toDoctorId;
  final String reason;
  final String status;
  final String createdAt;
  final String? updatedAt;

  factory PatientTransferRequestDto.fromJson(Map<String, dynamic> json) {
    return PatientTransferRequestDto(
      id: json['id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      fromDoctorId: json['from_doctor_id']?.toString() ?? '',
      toDoctorId: json['to_doctor_id']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      status: _stripEnum(json['status']),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

class DoctorSuggestionDto {
  DoctorSuggestionDto({required this.id, required this.fullName, this.specialistType});

  final String id;
  final String fullName;
  final String? specialistType;

  factory DoctorSuggestionDto.fromJson(Map<String, dynamic> json) {
    return DoctorSuggestionDto(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      specialistType: json['specialist_type'] != null ? _stripEnum(json['specialist_type']) : null,
    );
  }
}

class TimeSlotSuggestionDto {
  TimeSlotSuggestionDto({required this.scheduledAt});

  final String scheduledAt;

  factory TimeSlotSuggestionDto.fromJson(Map<String, dynamic> json) {
    return TimeSlotSuggestionDto(scheduledAt: json['scheduled_at']?.toString() ?? '');
  }
}

class UnavailabilityImpactActionDto {
  UnavailabilityImpactActionDto({
    required this.id,
    required this.sessionId,
    required this.blockStartsAt,
    required this.blockEndsAt,
    required this.doctorName,
    this.sessionScheduledAt,
    required this.message,
    required this.suggestedDoctors,
    required this.suggestedSlots,
  });

  final String id;
  final String sessionId;
  final String blockStartsAt;
  final String blockEndsAt;
  final String doctorName;
  final String? sessionScheduledAt;
  final String message;
  final List<DoctorSuggestionDto> suggestedDoctors;
  final List<TimeSlotSuggestionDto> suggestedSlots;

  factory UnavailabilityImpactActionDto.fromJson(Map<String, dynamic> json) {
    final docs = (json['suggested_doctors'] is List)
        ? (json['suggested_doctors'] as List)
            .whereType<Map>()
            .map((e) => DoctorSuggestionDto.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <DoctorSuggestionDto>[];
    final slots = (json['suggested_slots'] is List)
        ? (json['suggested_slots'] as List)
            .whereType<Map>()
            .map((e) => TimeSlotSuggestionDto.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <TimeSlotSuggestionDto>[];
    return UnavailabilityImpactActionDto(
      id: json['id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      blockStartsAt: json['block_starts_at']?.toString() ?? '',
      blockEndsAt: json['block_ends_at']?.toString() ?? '',
      doctorName: json['doctor_name']?.toString() ?? '',
      sessionScheduledAt: json['session_scheduled_at']?.toString(),
      message: json['message']?.toString() ?? '',
      suggestedDoctors: docs,
      suggestedSlots: slots,
    );
  }
}

class PendingTransferActionDto {
  PendingTransferActionDto({
    required this.id,
    required this.sessionId,
    required this.fromDoctorName,
    required this.toDoctorName,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  final String fromDoctorName;
  final String toDoctorName;
  final String reason;
  final String createdAt;

  factory PendingTransferActionDto.fromJson(Map<String, dynamic> json) {
    return PendingTransferActionDto(
      id: json['id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      fromDoctorName: json['from_doctor_name']?.toString() ?? '',
      toDoctorName: json['to_doctor_name']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class CareActionsDto {
  CareActionsDto({required this.pendingTransfers, required this.unavailabilityImpacts});

  final List<PendingTransferActionDto> pendingTransfers;
  final List<UnavailabilityImpactActionDto> unavailabilityImpacts;

  factory CareActionsDto.fromJson(Map<String, dynamic> json) {
    final pt = (json['pending_transfers'] is List)
        ? (json['pending_transfers'] as List)
            .whereType<Map>()
            .map((e) => PendingTransferActionDto.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <PendingTransferActionDto>[];
    final ui = (json['unavailability_impacts'] is List)
        ? (json['unavailability_impacts'] as List)
            .whereType<Map>()
            .map((e) => UnavailabilityImpactActionDto.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <UnavailabilityImpactActionDto>[];
    return CareActionsDto(pendingTransfers: pt, unavailabilityImpacts: ui);
  }
}

class DoctorUnavailabilityBlockResultDto {
  DoctorUnavailabilityBlockResultDto({
    required this.blockId,
    required this.affectedSessionCount,
    required this.affectedSessionIds,
    required this.message,
  });

  final String blockId;
  final int affectedSessionCount;
  final List<String> affectedSessionIds;
  final String message;

  factory DoctorUnavailabilityBlockResultDto.fromJson(Map<String, dynamic> json) {
    final ids = json['affected_session_ids'];
    return DoctorUnavailabilityBlockResultDto(
      blockId: json['block_id']?.toString() ?? '',
      affectedSessionCount: (json['affected_session_count'] is num) ? (json['affected_session_count'] as num).toInt() : 0,
      affectedSessionIds: (ids is List) ? ids.map((e) => e.toString()).toList() : <String>[],
      message: json['message']?.toString() ?? '',
    );
  }
}

class DoctorDashboardSummaryDto {
  DoctorDashboardSummaryDto({
    required this.pendingTransferRequestsCount,
    required this.pendingUnavailabilityImpactsCount,
    required this.totalNeedingPatientAction,
  });

  final int pendingTransferRequestsCount;
  final int pendingUnavailabilityImpactsCount;
  final int totalNeedingPatientAction;

  factory DoctorDashboardSummaryDto.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return DoctorDashboardSummaryDto(
      pendingTransferRequestsCount: asInt(json['pending_transfer_requests_count']),
      pendingUnavailabilityImpactsCount: asInt(json['pending_unavailability_impacts_count']),
      totalNeedingPatientAction: asInt(json['total_needing_patient_action']),
    );
  }
}

class ChatConversationDto {
  ChatConversationDto({
    required this.id,
    required this.kind,
    required this.title,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.expiresAt,
    required this.isExpired,
    this.sessionId,
  });

  final String id;
  final String kind; // 'session' | 'admin'
  final String title;
  final String? lastMessagePreview;
  final String? lastMessageAt;
  final String? expiresAt;
  final bool isExpired;
  final String? sessionId;

  factory ChatConversationDto.fromJson(Map<String, dynamic> json) {
    return ChatConversationDto(
      id: json['id']?.toString() ?? '',
      kind: _stripEnum(json['kind']),
      title: json['title']?.toString() ?? 'Chat',
      lastMessagePreview: json['last_message_preview']?.toString(),
      lastMessageAt: json['last_message_at']?.toString(),
      expiresAt: json['expires_at']?.toString(),
      isExpired: json['is_expired'] == true,
      sessionId: json['session_id']?.toString(),
    );
  }
}

class ChatMessageDto {
  ChatMessageDto({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final String createdAt;

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) {
    return ChatMessageDto(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class TransferLogDto {
  TransferLogDto({
    required this.id,
    required this.sessionId,
    required this.fromDoctorId,
    required this.toDoctorId,
    this.reason,
    required this.transferredAt,
  });

  final String id;
  final String sessionId;
  final String fromDoctorId;
  final String toDoctorId;
  final String? reason;
  final DateTime? transferredAt;

  factory TransferLogDto.fromJson(Map<String, dynamic> json) {
    return TransferLogDto(
      id: json['id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      fromDoctorId: json['from_doctor_id']?.toString() ?? '',
      toDoctorId: json['to_doctor_id']?.toString() ?? '',
      reason: json['reason']?.toString(),
      transferredAt: DateTime.tryParse(json['transferred_at']?.toString() ?? '')?.toLocal(),
    );
  }
}

class BookingDto {
  BookingDto({
    required this.id,
    required this.clientId,
    required this.mentalHealthDescription,
    required this.consentGiven,
    this.consentTimestamp,
    required this.sessionType,
    required this.status,
    required this.preferredDatesRaw,
    this.firstPreferredDateUtc,
    this.createdAtUtc,
    this.physicalLocationAddress,
    this.physicalLocationLat,
    this.physicalLocationLng,
    this.physicalVenue,
    this.physicalNotes,
    this.rescheduleRequestDatesRaw,
    this.rescheduleRequestNote,
    this.rescheduleRequestedAt,
  });

  final String id;
  final String clientId;
  final String? mentalHealthDescription;
  final bool consentGiven;
  final String? consentTimestamp;
  final String sessionType;
  final String status;
  final String preferredDatesRaw;
  final DateTime? firstPreferredDateUtc;
  final DateTime? createdAtUtc;
  final String? physicalLocationAddress;
  final double? physicalLocationLat;
  final double? physicalLocationLng;
  final String? physicalVenue;
  final String? physicalNotes;
  final String? rescheduleRequestDatesRaw;
  final String? rescheduleRequestNote;
  final String? rescheduleRequestedAt;

  factory BookingDto.fromJson(Map<String, dynamic> json) {
    final raw = json['preferred_dates']?.toString() ?? '[]';
    DateTime? first;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List && decoded.isNotEmpty) {
        first = DateTime.tryParse(decoded.first.toString())?.toUtc();
      }
    } catch (_) {}
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '')?.toUtc();

    return BookingDto(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      mentalHealthDescription: json['mental_health_description']?.toString(),
      consentGiven: json['consent_given'] == true,
      consentTimestamp: json['consent_timestamp']?.toString(),
      sessionType: _stripEnum(json['session_type']),
      status: _stripEnum(json['status']),
      preferredDatesRaw: raw,
      firstPreferredDateUtc: first,
      createdAtUtc: createdAt,
      physicalLocationAddress: json['physical_location_address']?.toString(),
      physicalLocationLat: (json['physical_location_lat'] is num) ? (json['physical_location_lat'] as num).toDouble() : null,
      physicalLocationLng: (json['physical_location_lng'] is num) ? (json['physical_location_lng'] as num).toDouble() : null,
      physicalVenue: json['physical_venue'] != null ? _stripEnum(json['physical_venue']) : null,
      physicalNotes: json['physical_notes']?.toString(),
      rescheduleRequestDatesRaw: json['reschedule_request_dates']?.toString(),
      rescheduleRequestNote: json['reschedule_request_note']?.toString(),
      rescheduleRequestedAt: json['reschedule_requested_at']?.toString(),
    );
  }
}

class SessionDto {
  SessionDto({
    required this.id,
    required this.bookingId,
    required this.clientId,
    this.doctorId,
    required this.status,
    this.meetingLink,
    this.scheduledAt,
    this.notes,
    this.checkInAt,
    this.checkOutAt,
  });

  final String id;
  final String bookingId;
  final String clientId;
  final String? doctorId;
  final String status;
  final String? meetingLink;
  final String? scheduledAt;
  final String? notes;
  final String? checkInAt;
  final String? checkOutAt;

  factory SessionDto.fromJson(Map<String, dynamic> json) {
    return SessionDto(
      id: json['id']?.toString() ?? '',
      bookingId: json['booking_id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      doctorId: json['doctor_id']?.toString(),
      status: _stripEnum(json['status']),
      meetingLink: json['meeting_link']?.toString(),
      scheduledAt: json['scheduled_at']?.toString(),
      notes: json['notes']?.toString(),
      checkInAt: json['check_in_at']?.toString(),
      checkOutAt: json['check_out_at']?.toString(),
    );
  }
}

class PaymentDto {
  PaymentDto({
    required this.id,
    required this.sessionId,
    required this.status,
    this.amount,
    required this.paymentType,
    this.instructionsText,
    this.proofSubmittedAt,
    this.proofFilename,
    this.confirmedAt,
  });

  final String id;
  final String sessionId;
  final String status;
  final double? amount;
  final String paymentType;
  final String? instructionsText;
  final String? proofSubmittedAt;
  final String? proofFilename;
  final String? confirmedAt;

  factory PaymentDto.fromJson(Map<String, dynamic> json) {
    return PaymentDto(
      id: json['id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      status: _stripEnum(json['status']),
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : null,
      paymentType: _stripEnum(json['payment_type']),
      instructionsText: json['instructions_text']?.toString(),
      proofSubmittedAt: json['proof_submitted_at']?.toString(),
      proofFilename: json['proof_filename']?.toString(),
      confirmedAt: json['confirmed_at']?.toString(),
    );
  }
}

class FeedbackDto {
  FeedbackDto({
    required this.id,
    required this.sessionId,
    this.clientId,
    this.doctorId,
    this.createdAtUtc,
    this.treatmentRating,
    this.doctorFeedback,
    this.appRating,
    this.appFeedback,
    this.suggestions,
    this.familyRating,
    this.familyComments,
    required this.reviewed,
    required this.flagged,
    this.internalNote,
  });

  final String id;
  final String sessionId;
  final String? clientId;
  final String? doctorId;
  final DateTime? createdAtUtc;

  final int? treatmentRating;
  final String? doctorFeedback;

  final int? appRating;
  final String? appFeedback;

  final String? suggestions;

  final int? familyRating;
  final String? familyComments;

  final bool reviewed;
  final bool flagged;
  final String? internalNote;

  factory FeedbackDto.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['created_at']?.toString() ?? '')?.toUtc();
    return FeedbackDto(
      id: json['id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      clientId: json['client_id']?.toString(),
      doctorId: json['doctor_id']?.toString(),
      createdAtUtc: created,
      treatmentRating: (json['treatment_rating'] is num) ? (json['treatment_rating'] as num).toInt() : int.tryParse(json['treatment_rating']?.toString() ?? ''),
      doctorFeedback: json['doctor_feedback']?.toString(),
      appRating: (json['app_rating'] is num) ? (json['app_rating'] as num).toInt() : int.tryParse(json['app_rating']?.toString() ?? ''),
      appFeedback: json['app_feedback']?.toString(),
      suggestions: json['suggestions']?.toString(),
      familyRating: (json['family_rating'] is num) ? (json['family_rating'] as num).toInt() : int.tryParse(json['family_rating']?.toString() ?? ''),
      familyComments: json['family_comments']?.toString(),
      reviewed: json['reviewed'] == true,
      flagged: json['flagged'] == true,
      internalNote: json['internal_note']?.toString(),
    );
  }

  int? get rating => treatmentRating ?? appRating ?? familyRating;

  String get primaryComment {
    final s1 = (doctorFeedback ?? '').trim();
    if (s1.isNotEmpty) return s1;
    final s2 = (appFeedback ?? '').trim();
    if (s2.isNotEmpty) return s2;
    final s3 = (suggestions ?? '').trim();
    if (s3.isNotEmpty) return s3;
    final s4 = (familyComments ?? '').trim();
    if (s4.isNotEmpty) return s4;
    return '';
  }
}

String? _parseOptionalPhone(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

String _stripEnum(dynamic v) {
  if (v == null) return '';
  final s = v.toString();
  final i = s.indexOf('.');
  return i >= 0 ? s.substring(i + 1) : s;
}
