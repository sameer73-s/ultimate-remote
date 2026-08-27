import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_hbb/api_contracts/backend_api.dart';
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
}
