import 'package:dio/dio.dart';

/// FastAPI often returns `detail` as a [String] or a [List] of validation objects.
String? messageFromDioException(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final detail = data['detail'];
    if (detail is String && detail.trim().isNotEmpty) return detail;
    if (detail is List) {
      final parts = <String>[];
      for (final item in detail) {
        if (item is Map && item['msg'] is String) {
          parts.add(item['msg'] as String);
        } else if (item is String) {
          parts.add(item);
        }
      }
      if (parts.isNotEmpty) return parts.join(' ');
    }
  }
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Request timed out. Is the API running on port 8000?';
    case DioExceptionType.connectionError:
      return 'Cannot reach the server. Start the API (port 8000) and check the URL.';
    default:
      return null;
  }
}
