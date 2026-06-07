import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  /// Web / Windows / Linux / macOS → loopback. Android emulator → host machine.
  /// Physical phone/tablet: set your PC LAN IP (e.g. `http://192.168.1.10:8000/api/v1`).
  static String get baseUrl {
    final fromEnv = (dotenv.env['API_BASE_URL'] ?? '').trim();
    if (fromEnv.isNotEmpty) {
      // If you run the Flutter app on Android, "localhost/127.0.0.1" points to
      // the emulator/device itself (not your PC). For Android emulator, the host
      // machine is reachable via 10.0.2.2.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final parsed = Uri.tryParse(fromEnv);
        final host = parsed?.host.toLowerCase();
        if (parsed != null && (host == 'localhost' || host == '127.0.0.1')) {
          return parsed.replace(host: '10.0.2.2').toString();
        }
      }
      return fromEnv;
    }
    if (kIsWeb) return 'http://127.0.0.1:8000/api/v1';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000/api/v1';
      case TargetPlatform.iOS:
        return 'http://127.0.0.1:8000/api/v1';
      default:
        return 'http://127.0.0.1:8000/api/v1';
    }
  }

  final FlutterSecureStorage _storage;
  late final Dio dio;

  /// Called after clearing the token on HTTP 401 (e.g. navigate to login).
  static void Function()? onUnauthorized;

  ApiClient({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'access_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (err, handler) async {
          if (err.response?.statusCode == 401) {
            await _storage.delete(key: 'access_token');
            onUnauthorized?.call();
          }
          handler.next(err);
        },
      ),
    );
  }

  Future<void> saveToken(String token) =>
      _storage.write(key: 'access_token', value: token);

  Future<void> clearToken() => _storage.delete(key: 'access_token');
}

