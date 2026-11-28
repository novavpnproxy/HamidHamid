import 'dart:convert';

import 'package:http/http.dart' as http;

import '../storage/secure_storage_service.dart';
import 'device_service.dart';

class AuthService {
  AuthService({
    http.Client? client,
    DeviceService? deviceService,
    SecureStorageService? storage,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _deviceService = deviceService ?? DeviceService(),
        _storage = storage ?? const SecureStorageService(),
        _baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL');

  final http.Client _client;
  final DeviceService _deviceService;
  final SecureStorageService _storage;
  final String _baseUrl;

  Future<String> registerDevice() async {
    if (_baseUrl.isEmpty) {
      throw StateError('API_BASE_URL is not configured.');
    }

    final base = Uri.parse(_baseUrl);
    final localHosts = {'localhost', '127.0.0.1', '10.0.2.2'};
    final localHttp = base.scheme == 'http' && localHosts.contains(base.host);

    if (base.scheme != 'https' && !localHttp) {
      throw StateError('API must use HTTPS except for local development.');
    }

    final deviceId = await _deviceService.getOrCreateDeviceId();
    final response = await _client
        .post(
          base.resolve('/api/v1/client/register'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'device_id': deviceId}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AuthException(
        response.statusCode == 403
            ? 'Device registration was rejected.'
            : 'Device registration failed.',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['access_token'] is! String) {
      throw const FormatException('Invalid authentication response.');
    }

    final token = decoded['access_token'] as String;
    await _storage.writeAccessToken(token);
    return token;
  }

  Future<String?> getAccessToken() => _storage.readAccessToken();

  Future<void> logout() => _storage.clearAccessToken();

  void close() => _client.close();
}

class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
