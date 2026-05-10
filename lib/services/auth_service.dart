import 'package:dio/dio.dart';

import 'api_client.dart';

class AuthService {
  final ApiClient _client;

  AuthService({ApiClient? client}) : _client = client ?? ApiClient();

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final res = await _client.dio.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    final data = res.data;
    final token = (data is Map<String, dynamic>)
        ? (data['access_token']?.toString() ?? '')
        : '';

    if (token.isEmpty) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: 'Login succeeded but no token returned.',
      );
    }

    await _client.saveToken(token);
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    String role = 'client',
    String? specialistType,
  }) async {
    final payload = <String, dynamic>{
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'password': password,
      'role': role,
    };
    if (role == 'doctor' && specialistType != null && specialistType.trim().isNotEmpty) {
      payload['specialist_type'] = specialistType.trim();
    }
    await _client.dio.post(
      '/auth/register',
      data: payload,
    );
  }

  Future<void> logout() => _client.clearToken();
}

