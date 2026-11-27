import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nova_vpn_app/services/api_service.dart';
import 'package:nova_vpn_app/storage/secure_storage_service.dart';

class _MemorySecureStorage extends SecureStorageService {
  String? token;
  String? deviceId;

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<void> writeAccessToken(String value) async {
    token = value;
  }

  @override
  Future<void> clearAccessToken() async {
    token = null;
  }

  @override
  Future<String?> readDeviceId() async => deviceId;

  @override
  Future<void> writeDeviceId(String value) async {
    deviceId = value;
  }

  @override
  Future<void> clearDeviceId() async {
    deviceId = null;
  }
}

void main() {
  group('ApiService', () {
    test('parses public server metadata', () async {
      final client = MockClient((request) async {
        expect(request.headers['cache-control'], 'no-store');
        if (request.url.path == '/api/v1/vox/locations') {
          return http.Response('{\"detail\":\"not configured\"}', 503);
        }
        expect(request.url.path, '/api/v1/servers');

        return http.Response(
          jsonEncode({
            'servers': [
              {
                'id': 'server-1',
                'name': 'Managed node',
                'protocol': 'VLESS',
                'country_code': null,
                'country_name_fa': null,
                'country_name_en': null,
                'location_verified': false,
              },
            ],
          }),
          200,
        );
      });

      final api = ApiService(
        client: client,
        baseUrl: 'https://vpn.example',
      );

      final servers = await api.fetchServers();

      expect(servers, hasLength(1));
      expect(servers.single.id, 'server-1');
      expect(servers.single.name, 'Managed node');
      api.close();
    });


    test('merges Vox locations into the server picker', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/servers') {
          return http.Response('{"servers":[]}', 200);
        }
        expect(request.url.path, '/api/v1/vox/locations');
        expect(request.url.queryParameters['protocol'], 'vless');
        return http.Response(
          jsonEncode({
            'locations': [
              {
                'id': 'de-frankfurt',
                'label': 'Germany (Frankfurt)',
                'country': 'DE',
                'country_name': 'Germany',
                'city': 'Frankfurt',
                'protocols': ['vless'],
              },
            ],
          }),
          200,
        );
      });
      final api = ApiService(client: client, baseUrl: 'https://vpn.example');
      final servers = await api.fetchServers();
      expect(servers, hasLength(1));
      expect(servers.single.id, 'vox:de-frankfurt');
      expect(servers.single.protocol, 'VLESS');
      expect(servers.single.countryCode, 'DE');
      expect(servers.single.locationNameEn, 'Frankfurt');
      api.close();
    });

    test('fetches a fresh Vox VLESS config using the protected backend route', () async {
      final storage = _MemorySecureStorage()..token = 'client-token';
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/vox/config');
        expect(request.url.queryParameters['location'], 'de-frankfurt');
        expect(request.url.queryParameters['protocol'], 'vless');
        expect(request.headers['authorization'], 'Bearer client-token');
        expect(request.headers['cache-control'], 'no-store');
        return http.Response(
          jsonEncode({'config': 'vless://fresh-vox-profile'}),
          200,
        );
      });
      final api = ApiService(
        client: client,
        storage: storage,
        baseUrl: 'https://vpn.example',
      );
      expect(await api.fetchServerConfig('vox:de-frankfurt'),
          'vless://fresh-vox-profile');
      api.close();
    });

    test('registers the device before requesting its VPN profile', () async {
      final storage = _MemorySecureStorage();
      var registered = false;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/client/register') {
          registered = true;
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), contains('device_id'));
          return http.Response(
            jsonEncode({'access_token': 'client-token'}),
            200,
          );
        }

        expect(registered, isTrue);
        expect(request.url.path, '/api/v1/servers/server-1/config');
        expect(request.headers['authorization'], 'Bearer client-token');
        expect(request.headers['cache-control'], 'no-store');
        return http.Response(
          jsonEncode({'config': 'vless://owner-controlled'}),
          200,
        );
      });

      final api = ApiService(
        client: client,
        storage: storage,
        baseUrl: 'https://vpn.example',
      );

      expect(
        await api.fetchServerConfig('server-1'),
        'vless://owner-controlled',
      );
      expect(storage.token, 'client-token');
      expect(storage.deviceId, hasLength(64));
      api.close();
    });

    test('reports pending administrator approval without requesting profile',
        () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/client/register');
        return http.Response(
          jsonEncode({'detail': 'pending approval'}),
          403,
        );
      });

      final api = ApiService(
        client: client,
        storage: _MemorySecureStorage(),
        baseUrl: 'https://vpn.example',
      );

      await expectLater(
        api.fetchServerConfig('server-1'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'status code', 403)
              .having(
                (error) => error.message,
                'approval message',
                contains('awaiting administrator approval'),
              ),
        ),
      );
      api.close();
    });

    test('does not expose failed response body in exception', () async {
      final storage = _MemorySecureStorage()..token = 'client-token';
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'detail': 'sensitive backend details'}),
          503,
        ),
      );

      final api = ApiService(
        client: client,
        storage: storage,
        baseUrl: 'https://vpn.example',
      );

      await expectLater(
        api.fetchServerConfig('server-1'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.toString(),
            'safe error',
            isNot(contains('sensitive backend details')),
          ),
        ),
      );
      api.close();
    });

    test('rejects non-HTTPS production API URL', () async {
      final api = ApiService(
        client: MockClient((_) async => http.Response('', 200)),
        baseUrl: 'http://vpn.example',
      );

      await expectLater(api.fetchServers(), throwsStateError);
      api.close();
    });

    test('allows emulator loopback HTTP for local development', () async {
      final api = ApiService(
        client: MockClient(
          (request) async => request.url.path == '/api/v1/servers'
            ? http.Response('{"servers":[]}', 200)
            : http.Response('{"detail":"not configured"}', 503),
        ),
        baseUrl: 'http://10.0.2.2:8000',
      );

      expect(await api.fetchServers(), isEmpty);
      api.close();
    });
  });
}
