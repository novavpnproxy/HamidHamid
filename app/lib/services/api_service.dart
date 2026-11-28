import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/vpn_server.dart';
import '../storage/secure_storage_service.dart';
import 'auth_service.dart';
import 'device_service.dart';

class ApiService {
  ApiService({
    http.Client? client,
    SecureStorageService? storage,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _storage = storage ?? const SecureStorageService(),
        _baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL') {
    _auth = AuthService(
      client: _client,
      deviceService: DeviceService(storage: _storage),
      storage: _storage,
      baseUrl: _baseUrl,
    );
  }

  final http.Client _client;
  final SecureStorageService _storage;
  final String _baseUrl;
  late final AuthService _auth;

  Uri _uri(String path) {
    if (_baseUrl.isEmpty) {
      throw StateError('API_BASE_URL is not configured.');
    }

    final base = Uri.tryParse(_baseUrl);
    if (base == null || !base.hasAuthority) {
      throw StateError('API_BASE_URL is invalid.');
    }

    const localHosts = {'localhost', '127.0.0.1', '10.0.2.2'};
    final localHttp = base.scheme == 'http' && localHosts.contains(base.host);

    if (base.scheme != 'https' && !localHttp) {
      throw StateError('The API must use HTTPS except for local development.');
    }

    return base.resolve(path);
  }

  Future<String> _clientToken() async {
    var token = await _storage.readAccessToken();
    if (token == null || token.trim().isEmpty) {
      try {
        token = await _auth.registerDevice();
      } on AuthException catch (error) {
        throw ApiException(error.message, statusCode: error.statusCode);
      }
    }
    return token;
  }

  Future<http.Response> _authorizedGet(String path) async {
    var token = await _clientToken();
    var response = await _client
        .get(
          _uri(path),
          headers: {
            'Authorization': 'Bearer $token',
            'Cache-Control': 'no-store',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401) {
      await _storage.clearAccessToken();
      try {
        token = await _auth.registerDevice();
      } on AuthException catch (error) {
        throw ApiException(error.message, statusCode: error.statusCode);
      }
      response = await _client
          .get(
            _uri(path),
            headers: {
              'Authorization': 'Bearer $token',
              'Cache-Control': 'no-store',
            },
          )
          .timeout(const Duration(seconds: 15));
    }
    return response;
  }

  Future<List<VpnServer>> fetchServers() async {
    final response = await _client
        .get(
          _uri('/api/v1/servers'),
          headers: const {'Cache-Control': 'no-store'},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw ApiException('Server list unavailable.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['servers'] is! List) {
      throw const FormatException('Invalid server-list response.');
    }

    final manualServers = (decoded['servers'] as List)
        .map((item) => VpnServer.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: true);

    // Vox locations are dynamic and are refreshed from the backend.
    // If Vox has not yet been configured, retain any manually managed servers.
    try {
      manualServers.addAll(await fetchVoxServers());
    } on ApiException catch (error) {
      if (error.statusCode != 503) rethrow;
    }

    return manualServers;
  }

  Future<List<VpnServer>> fetchVoxServers() async {
    // Location metadata is non-sensitive and can be shown before device approval.
    final response = await _client
        .get(
          _uri('/api/v1/vox/locations?protocol=vless'),
          headers: const {'Cache-Control': 'no-store'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw ApiException(
        'Vox locations unavailable (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['locations'] is! List) {
      throw const FormatException('Invalid Vox locations response.');
    }

    return (decoded['locations'] as List).map((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      final id = item['id'] as String;
      final label = (item['label'] as String?) ?? id;
      final countryCode = item['country'] as String?;
      final countryName = item['country_name'] as String?;
      final city = (item['city'] as String?) ?? label;
      return VpnServer(
        id: 'vox:$id',
        name: label,
        protocol: 'VLESS',
        countryCode: countryCode,
        countryNameFa: null,
        countryNameEn: countryName,
        locationNameFa: null,
        locationNameEn: city,
        locationVerified: countryCode != null && countryCode.length == 2,
      );
    }).toList(growable: false);
  }

  Future<HomeContent> fetchHomeContent() async {
    final response = await _client
        .get(_uri('/api/v1/home-content'), headers: const {'Cache-Control': 'no-store'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw ApiException('Home content unavailable (' + response.statusCode.toString() + ').', statusCode: response.statusCode);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Invalid home content response.');
    return HomeContent.fromJson(decoded);
  }

  Future<String> fetchServerConfig(String serverId) async {
    if (serverId.startsWith('vox:')) {
      return fetchVoxServerConfig(serverId.substring(4));
    }

    final path = '/api/v1/servers/${Uri.encodeComponent(serverId)}/config';
    final response = await _authorizedGet(path);

    if (response.statusCode == 403) {
      throw const ApiException(
        'Device access is blocked by the service administrator.',
        statusCode: 403,
      );
    }

    if (response.statusCode != 200) {
      throw ApiException(
        'Server profile unavailable (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['config'] is! String ||
        (decoded['config'] as String).trim().isEmpty) {
      throw const FormatException('Invalid profile response.');
    }

    return decoded['config'] as String;
  }

  Future<String> fetchVoxServerConfig(String locationId) async {
    final path = '/api/v1/vox/config?location=${Uri.encodeQueryComponent(locationId)}&protocol=vless';
    final response = await _authorizedGet(path);

    if (response.statusCode == 403) {
      throw const ApiException(
        'Device access is blocked by the service administrator.',
        statusCode: 403,
      );
    }
    if (response.statusCode != 200) {
      throw ApiException(
        'Vox profile unavailable (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['config'] is! String ||
        (decoded['config'] as String).trim().isEmpty) {
      throw const FormatException('Invalid Vox profile response.');
    }
    return decoded['config'] as String;
  }

  void close() => _client.close();
}

class HomeContent {
  const HomeContent({required this.adMode, required this.networkProvider, required this.networkZoneId, required this.networkCode, required this.ads, required this.announcements});
  final String adMode;
  final String? networkProvider;
  final String? networkZoneId;
  final String? networkCode;
  final List<HomeAd> ads;
  final List<HomeAnnouncement> announcements;
  factory HomeContent.fromJson(Map<String, dynamic> json) => HomeContent(
    adMode: json['ad_mode'] as String? ?? 'manual',
    networkProvider: json['network_provider'] as String?,
    networkZoneId: json['network_zone_id'] as String?,
    networkCode: json['network_code'] as String?,
    ads: (json['ads'] as List? ?? const []).map((e) => HomeAd.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false),
    announcements: (json['announcements'] as List? ?? const []).map((e) => HomeAnnouncement.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false),
  );
}

class HomeAd {
  const HomeAd({required this.id, required this.title, required this.description, required this.imageUrl, required this.targetUrl});
  final String id;
  final String title;
  final String? description;
  final String imageUrl;
  final String targetUrl;
  factory HomeAd.fromJson(Map<String, dynamic> json) => HomeAd(
    id: json['id'] as String, title: json['title'] as String,
    description: json['description'] as String?, imageUrl: json['image_url'] as String,
    targetUrl: json['target_url'] as String,
  );
}

class HomeAnnouncement {
  const HomeAnnouncement({required this.id, required this.message});
  final String id;
  final String message;
  factory HomeAnnouncement.fromJson(Map<String, dynamic> json) => HomeAnnouncement(id: json['id'] as String, message: json['message'] as String);
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
