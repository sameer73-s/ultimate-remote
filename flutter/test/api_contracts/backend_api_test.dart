import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_hbb/api_contracts/api_contracts.dart';
import 'package:flutter_hbb/foundation/backend_foundation.dart';
import 'package:flutter_hbb/foundation/environment.dart';

class FakeBackend implements RemoteBackendClient {
  FakeBackend(this.response);

  final RemoteApiResponse response;

  @override
  RemoteEnvironmentConfig get environment => RemoteEnvironmentConfig(
        environment: RemoteEnvironment.development,
        apiEndpoint: Uri.parse('http://localhost:8000'),
      );

  @override
  Future<RemoteApiResponse> send(RemoteApiRequest request) async => response;
}

void main() {
  final createdAt = DateTime.utc(2026, 1, 1);

  test('parses backend user contract', () {
    final user = UserContract.fromJson({
      'id': 'user-a',
      'organization_id': 'org-a',
      'email': 'a@example.com',
      'display_name': 'User A',
      'status': 'ACTIVE',
      'roles': ['ADMIN'],
      'created_at': createdAt.toIso8601String(),
      'updated_at': createdAt.toIso8601String(),
      'last_login_at': null,
    });
    expect(user.organizationId, 'org-a');
    expect(user.roles, ['ADMIN']);
  });

  test('device repository maps list response', () async {
    final body = {
      'items': [
        {
          'id': 'device-a',
          'organization_id': 'org-a',
          'device_identifier': 'host-a',
          'name': 'Host A',
          'platform': 'linux',
          'status': 'ONLINE',
          'created_at': createdAt.toIso8601String(),
          'updated_at': createdAt.toIso8601String(),
          'last_seen_at': null,
        },
      ],
      'meta': {'page': 1, 'page_size': 50, 'total': 1},
    };
    final repository = DeviceRepository(
      BackendApiClient(
        FakeBackend(RemoteApiResponse(statusCode: 200, body: body)),
      ),
    );
    final devices = await repository.list();
    expect(devices.single.name, 'Host A');
  });

  test('non-success responses become ApiError contracts', () async {
    final client = BackendApiClient(
      FakeBackend(
        const RemoteApiResponse(
          statusCode: 404,
          body: {
            'error': {
              'code': 'DEVICE_NOT_FOUND',
              'message': 'Device was not found',
              'request_id': 'request-a',
            },
          },
        ),
      ),
    );
    await expectLater(
      client.request('GET', '/api/v1/devices/missing'),
      throwsA(
        isA<ApiError>()
            .having((error) => error.code, 'code', 'DEVICE_NOT_FOUND')
            .having((error) => error.requestId, 'requestId', 'request-a'),
      ),
    );
  });
  transportTests();
}

String userJson() => jsonEncode({
      'id': 'user-a',
      'organization_id': 'org-a',
      'email': 'a@example.com',
      'display_name': 'User A',
      'status': 'ACTIVE',
      'roles': ['ADMIN'],
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
      'last_login_at': null,
    });

Map<String, dynamic> authJson(String access, String refresh) => {
      'access_token': access,
      'refresh_token': refresh,
      'token_type': 'bearer',
      'user': jsonDecode(userJson()),
    };

RemoteEnvironmentConfig testEnvironment() => RemoteEnvironmentConfig(
      environment: RemoteEnvironment.development,
      apiEndpoint: Uri.parse('http://127.0.0.1:8765/'),
    );

void transportTests() {
  test('HTTP adapter serializes JSON and required headers', () async {
    final requests = <http.Request>[];
    final adapter = HttpBackendClient(
      environment: testEnvironment(),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'x-request-id': 'response-id'},
        );
      }),
    );
    final response = await adapter.send(
      const RemoteApiRequest(
        method: 'POST',
        path: '/api/v1/devices',
        body: {'name': 'Laptop'},
        headers: {
          'Authorization': 'Bearer access-token',
          'X-Request-ID': 'request-id',
        },
      ),
    );
    expect(response.statusCode, 200);
    expect(response.body, {'ok': true});
    expect(requests.single.headers['authorization'], 'Bearer access-token');
    expect(requests.single.headers['x-request-id'], 'request-id');
    expect(requests.single.body, '{"name":"Laptop"}');
  });

  test('HTTP adapter maps network failures and timeouts', () async {
    final networkClient = HttpBackendClient(
      environment: testEnvironment(),
      httpClient: MockClient((request) async => throw StateError('offline')),
    );
    await expectLater(
      networkClient
          .send(const RemoteApiRequest(method: 'GET', path: '/health')),
      throwsA(isA<RemoteTransportException>().having(
        (error) => error.code,
        'code',
        'NETWORK_ERROR',
      )),
    );

    final timeoutClient = HttpBackendClient(
      environment: testEnvironment(),
      timeout: const Duration(milliseconds: 10),
      httpClient: MockClient(
        (request) async => Future<http.Response>.delayed(
          const Duration(milliseconds: 50),
          () => http.Response('{}', 200),
        ),
      ),
    );
    await expectLater(
      timeoutClient
          .send(const RemoteApiRequest(method: 'GET', path: '/health')),
      throwsA(isA<RemoteTransportException>().having(
        (error) => error.code,
        'code',
        'TIMEOUT',
      )),
    );
  });

  test('HTTP adapter and API client preserve backend error envelope', () async {
    final client = BackendApiClient(
      HttpBackendClient(
        environment: testEnvironment(),
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'DEVICE_NOT_FOUND',
                'message': 'Device was not found',
                'request_id': 'server-request',
              },
            }),
            404,
          );
        }),
      ),
    );
    await expectLater(
      client.request('GET', '/api/v1/devices/missing'),
      throwsA(isA<ApiError>()
          .having((error) => error.code, 'code', 'DEVICE_NOT_FOUND')
          .having((error) => error.statusCode, 'statusCode', 404)),
    );
  });

  test('auth lifecycle refreshes once, updates storage, then retries',
      () async {
    var meCalls = 0;
    final storage = MemorySecureTokenStorage();
    final client = BackendApiClient(
      HttpBackendClient(
        environment: testEnvironment(),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/auth/login')) {
            return http.Response(
                jsonEncode(authJson('access-1', 'refresh-1')), 200);
          }
          if (request.url.path.endsWith('/auth/refresh')) {
            return http.Response(
                jsonEncode(authJson('access-2', 'refresh-2')), 200);
          }
          if (request.url.path.endsWith('/auth/me')) {
            meCalls += 1;
            if (meCalls == 1) {
              return http.Response(
                jsonEncode({
                  'error': {
                    'code': 'EXPIRED',
                    'message': 'expired',
                    'request_id': 'r'
                  }
                }),
                401,
              );
            }
            return http.Response(userJson(), 200);
          }
          return http.Response('{}', 204);
        }),
      ),
    );
    final manager = AuthSessionManager(client: client, storage: storage);
    await manager.login('a@example.com', 'password-a');
    final response =
        await manager.authenticatedRequest('GET', '/api/v1/auth/me');
    expect(response['email'], 'a@example.com');
    expect((await storage.read())?.accessToken, 'access-2');
    expect(meCalls, 2);
  });

  test('refresh failure clears storage without retry loop', () async {
    final storage = MemorySecureTokenStorage();
    final client = BackendApiClient(
      HttpBackendClient(
        environment: testEnvironment(),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/auth/login')) {
            return http.Response(
                jsonEncode(authJson('access-1', 'refresh-1')), 200);
          }
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'UNAUTHORIZED',
                'message': 'invalid',
                'request_id': 'r'
              }
            }),
            401,
          );
        }),
      ),
    );
    final manager = AuthSessionManager(client: client, storage: storage);
    await manager.login('a@example.com', 'password-a');
    await expectLater(
      manager.authenticatedRequest('GET', '/api/v1/auth/me'),
      throwsA(isA<ApiError>()),
    );
    expect(await storage.read(), isNull);
  });

  test('logout clears secure token abstraction even when server rejects',
      () async {
    final storage = MemorySecureTokenStorage();
    await storage
        .write(const StoredTokens(accessToken: 'a', refreshToken: 'r'));
    final client = BackendApiClient(
      HttpBackendClient(
        environment: testEnvironment(),
        httpClient: MockClient((request) async => http.Response('{}', 204)),
      ),
    );
    await AuthSessionManager(client: client, storage: storage).logout();
    expect(await storage.read(), isNull);
  });
}
