import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/foundation/authentication_foundation.dart';
import 'package:flutter_hbb/foundation/backend_foundation.dart';
import 'package:flutter_hbb/foundation/control_plane_foundation.dart';
import 'package:flutter_hbb/foundation/design_tokens.dart';
import 'package:flutter_hbb/foundation/device_foundation.dart';
import 'package:flutter_hbb/foundation/environment.dart';
import 'package:flutter_hbb/foundation/error_foundation.dart';
import 'package:flutter_hbb/foundation/localization_foundation.dart';
import 'package:flutter_hbb/foundation/logging_foundation.dart';
import 'package:flutter_hbb/foundation/product_identity.dart';
import 'package:flutter_hbb/foundation/networking_foundation.dart';
import 'package:flutter_hbb/foundation/session_foundation.dart';
import 'package:flutter_hbb/foundation/ultimate_remote_ffi.dart';

void main() {
  group('product identity and design tokens', () {
    test('uses the proposed identity without hiding upstream attribution', () {
      expect(ProductIdentity.productName, 'Ultimate Remote');
      expect(ProductIdentity.legalProductName, 'Ultimate Solutions Remote');
      expect(ProductIdentity.attributionNotice,
          contains(ProductIdentity.upstreamProjectName));
      expect(ProductIdentity.windowTitle(context: 'Settings'),
          'Settings - Ultimate Remote');
    });

    test('exposes light and dark semantic theme extensions', () {
      expect(UltimateThemeExtension.light.background, const Color(0xFFF6F8FB));
      expect(UltimateThemeExtension.dark.background, const Color(0xFF0B1320));
      expect(UltimateDesignTokens.spacingLg, 16);
      expect(UltimateDesignTokens.radiusMd, 10);
      expect(UltimateDesignTokens.motionStandard,
          const Duration(milliseconds: 200));
    });
  });

  group('environment and localization', () {
    test('defines an environment-aware backend boundary', () {
      final config = RemoteEnvironmentConfig(
        environment: RemoteEnvironment.staging,
        apiEndpoint: Uri.parse('https://staging.example.test/api'),
      );
      const request = RemoteApiRequest(method: 'GET', path: '/devices');
      const response = RemoteApiResponse(statusCode: 200);

      expect(config.isValid, isTrue);
      expect(request.path, '/devices');
      expect(response.isSuccessful, isTrue);
    });

    test('rejects credentials in endpoints and insecure production transport',
        () {
      final config = RemoteEnvironmentConfig(
        environment: RemoteEnvironment.production,
        apiEndpoint: Uri.parse('http://user:password@example.test/api'),
      );

      expect(config.isValid, isFalse);
      expect(config.validate(),
          contains('api endpoint must not contain credentials'));
      expect(config.validate(),
          contains('api endpoint must use HTTPS in production'));
    });

    test('resolves Arabic and exposes RTL direction', () {
      expect(RemoteLocalization.directionFor(RemoteLocalization.arabic),
          TextDirection.rtl);
      expect(RemoteLocalization.directionFor(RemoteLocalization.english),
          TextDirection.ltr);
      expect(
        RemoteLocalization.resolve(
          const Locale('ar', 'EG'),
          RemoteLocalization.coreLocales,
        ),
        RemoteLocalization.arabic,
      );
    });
  });

  group('auth, device, session, and errors', () {
    test('redacts tokens and detects expired sessions', () {
      final token = RemoteAuthToken.fromValue('test-token');
      final session = RemoteAuthSession(
        user: const RemoteAuthUser(id: 'user-1'),
        token: token,
        expiresAt: DateTime.utc(2020),
      );

      expect(token.toString(), isNot(contains('test-token')));
      expect(token.redacted, '[REDACTED]');
      expect(session.isExpired(DateTime.utc(2021)), isTrue);
    });

    test('keeps device and session state as logical models', () {
      const device = RemoteDevice(
        id: 'device-1',
        status: RemoteDeviceStatus.online,
        platform: 'linux',
      );
      final session = RemoteSession(
        id: 'session-1',
        deviceId: device.id,
        state: RemoteSessionState.authorizing,
      );

      expect(device.id, 'device-1');
      expect(session.deviceId, device.id);
      expect(session.state, RemoteSessionState.authorizing);
    });

    test('provides a stable error kind and adapter fallback', () {
      const error = RemoteError(
        kind: RemoteErrorKind.authorization,
        message: 'Access denied',
        code: 'denied',
      );
      final adapted = RemoteErrorAdapter.from(StateError('unexpected'));

      expect(error.toString(), contains('authorization'));
      expect(error.toString(), contains('denied'));
      expect(adapted.kind, RemoteErrorKind.unknown);
      expect(adapted.message, isNotEmpty);
    });
  });

  test('sanitizes sensitive logging fields', () {
    final event = RemoteLogEvent(
      level: RemoteLogLevel.security,
      message: 'Authentication attempt',
      fields: const <String, Object?>{
        'user_id': 'user-1',
        'token': 'secret-value',
        'password': 'secret-password',
      },
    );

    expect(event.fields['user_id'], 'user-1');
    expect(event.fields['token'], '[REDACTED]');
    expect(event.fields['password'], '[REDACTED]');
  });

  _registerPhase17Tests();
}

class _FakeFfiApi implements UltimateRemoteFfiApi {
  bool initialized = false;
  bool stopped = false;
  int networkCalls = 0;
  String? createdSessionId;
  String? networkResponse;

  @override
  Future<String> apiVersion() async => '1.0.0';

  @override
  String initialize() {
    initialized = true;
    return '{"ok":true,"value":null}';
  }

  @override
  String createSession(String contextJson) {
    final context = jsonDecode(contextJson) as Map<String, dynamic>;
    createdSessionId = context['session_id'] as String;
    return jsonEncode({
      'ok': true,
      'value': {
        'context': {'session_id': createdSessionId},
        'state': 'Authorized',
      },
    });
  }

  @override
  String startSession(String sessionId) => jsonEncode({
        'ok': true,
        'value': {
          'context': {'session_id': sessionId},
          'state': 'Connected',
        },
      });

  @override
  String stopSession(String sessionId) {
    stopped = true;
    return jsonEncode({
      'ok': true,
      'value': {
        'context': {'session_id': sessionId},
        'state': 'Closed',
      },
    });
  }

  @override
  String drainEvents() => '{"ok":true,"value":[{"kind":"Connected"}]}';

  @override
  String shutdown() {
    initialized = false;
    return '{"ok":true,"value":null}';
  }

  @override
  Future<String> networkApiVersion() async => '1.0.0';

  @override
  String networkConnect({
    required String intentJson,
    required int nowMs,
    required bool cancelled,
  }) {
    networkCalls += 1;
    if (networkResponse != null) return networkResponse!;
    final intent = jsonDecode(intentJson) as Map<String, dynamic>;
    return jsonEncode({
      'ok': true,
      'events': [
        {
          'session_id': intent['session_id'],
          'target_device_id': intent['target_device_id'],
          'correlation_id': intent['correlation_id'],
          'state': 'CONNECTED',
          'connection_path': 'DIRECT',
          'relay_used': false,
        },
      ],
      'connection': null,
      'error': null,
    });
  }
}

void _addFfiFoundationTests() {
  group('PHASE 17 control-plane and FFI foundation', () {
    test('parses backend device and session contracts', () {
      final device = RemoteDevice.fromBackendJson({
        'id': 'device-1',
        'organization_id': 'tenant-1',
        'device_identifier': 'stable-device-1',
        'name': 'Linux host',
        'platform': 'linux',
        'status': 'ONLINE',
      });
      final session = RemoteSession.fromBackendJson({
        'id': 'session-1',
        'organization_id': 'tenant-1',
        'device_id': device.id,
        'source_device_id': 'source-1',
        'initiated_by': 'user-1',
        'status': 'AUTHORIZED',
        'authorization_state': 'AUTHORIZED',
        'correlation_id': 'correlation-1',
        'created_at': '2026-08-27T00:00:00Z',
      });

      expect(device.organizationId, 'tenant-1');
      expect(device.status, RemoteDeviceStatus.online);
      expect(session.state, RemoteSessionState.authorized);
      expect(session.sourceDeviceId, 'source-1');
      expect(session.correlationId, 'correlation-1');
    });

    test('requires backend authorization and protects FFI lifecycle', () {
      final fake = _FakeFfiApi();
      final controller = UltimateRemoteFfiSessionController(fake);
      final unauthorized = const RemoteSession(
        id: 'session-1',
        deviceId: 'device-1',
      );
      expect(
        () => controller.createSession(unauthorized),
        throwsA(isA<RemoteControlException>()),
      );

      controller.initialize();
      final authorized = const RemoteSession(
        id: 'session-1',
        deviceId: 'device-1',
        organizationId: 'tenant-1',
        userId: 'user-1',
        correlationId: 'correlation-1',
        authorizationState: 'AUTHORIZED',
      );
      expect(controller.createSession(authorized).state,
          RemoteSessionState.authorized);
      expect(controller.startSession(authorized).state,
          RemoteSessionState.connected);
      expect(
          controller.stopSession(authorized).state, RemoteSessionState.closed);
      expect(controller.drainEvents(), hasLength(1));
      controller.shutdown();
      expect(fake.stopped, isTrue);
      expect(() => controller.shutdown(), returnsNormally);
    });

    test('maps an authorized backend connection intent', () async {
      final controlPlane = RemoteControlPlaneClient(_FakeBackendClient());
      final session = const RemoteSession(
        id: 'session-1',
        deviceId: 'device-1',
      );
      final intent = await controlPlane.getConnectionIntent(session);
      expect(intent.sessionId, session.id);
      expect(intent.targetDeviceId, session.deviceId);
      expect(intent.allowedPaths, <RemoteConnectionPath>[
        RemoteConnectionPath.direct,
        RemoteConnectionPath.natTraversal,
        RemoteConnectionPath.relay,
      ]);
    });

    test('rejects a mismatched network intent before native invocation', () {
      final fake = _FakeFfiApi();
      final controller = UltimateRemoteFfiSessionController(fake);
      controller.initialize();
      const session = RemoteSession(
        id: 'session-1',
        deviceId: 'device-1',
        organizationId: 'tenant-1',
        userId: 'user-1',
        correlationId: 'correlation-1',
        authorizationState: 'AUTHORIZED',
      );
      controller.createSession(session);
      final intent = RemoteConnectionIntent(
        sessionId: 'session-1',
        targetDeviceId: 'other-device',
        correlationId: 'correlation-1',
        deadlineAt: DateTime(2026, 8, 27),
      );
      expect(
        () => controller.connectNetwork(session, intent),
        throwsA(isA<RemoteControlException>().having(
          (error) => error.error.code,
          'code',
          'NETWORK_INTENT_MISMATCH',
        )),
      );
      expect(fake.networkCalls, 0);
    });

    test('maps direct, NAT, and relay events and preserves relay usage', () {
      final fake = _FakeFfiApi()
        ..networkResponse = jsonEncode({
          'ok': true,
          'events': [
            {
              'session_id': 'session-1',
              'target_device_id': 'device-1',
              'correlation_id': 'correlation-1',
              'state': 'DIRECT_FAILED',
              'connection_path': 'DIRECT',
              'relay_used': false,
            },
            {
              'session_id': 'session-1',
              'target_device_id': 'device-1',
              'correlation_id': 'correlation-1',
              'state': 'NAT_FAILED',
              'connection_path': 'NAT_TRAVERSAL',
              'relay_used': false,
            },
            {
              'session_id': 'session-1',
              'target_device_id': 'device-1',
              'correlation_id': 'correlation-1',
              'state': 'CONNECTED',
              'connection_path': 'RELAY',
              'relay_used': true,
            },
          ],
          'connection': null,
          'error': null,
        });
      final controller = UltimateRemoteFfiSessionController(fake);
      controller.initialize();
      const session = RemoteSession(
        id: 'session-1',
        deviceId: 'device-1',
        organizationId: 'tenant-1',
        userId: 'user-1',
        correlationId: 'correlation-1',
        authorizationState: 'AUTHORIZED',
      );
      controller.createSession(session);
      final intent = RemoteConnectionIntent(
        sessionId: 'session-1',
        targetDeviceId: 'device-1',
        correlationId: 'correlation-1',
        deadlineAt: DateTime(2026, 8, 27),
      );
      final events = controller.connectNetwork(session, intent);
      expect(events.map((event) => event.path), [
        RemoteConnectionPath.direct,
        RemoteConnectionPath.natTraversal,
        RemoteConnectionPath.relay,
      ]);
      expect(events.map((event) => event.state), [
        RemoteConnectionState.directFailed,
        RemoteConnectionState.natFailed,
        RemoteConnectionState.connected,
      ]);
      expect(events.last.relayUsed, isTrue);
    });

    test('maps network failures to a generic safe Flutter error', () {
      final fake = _FakeFfiApi()
        ..networkResponse =
            '{"ok":false,"events":[],"error":{"code":"RENDEZVOUS_UNAVAILABLE","message":"internal detail"}}';
      final controller = UltimateRemoteFfiSessionController(fake);
      controller.initialize();
      const session = RemoteSession(
        id: 'session-1',
        deviceId: 'device-1',
        organizationId: 'tenant-1',
        userId: 'user-1',
        correlationId: 'correlation-1',
        authorizationState: 'AUTHORIZED',
      );
      controller.createSession(session);
      final intent = RemoteConnectionIntent(
        sessionId: 'session-1',
        targetDeviceId: 'device-1',
        correlationId: 'correlation-1',
        deadlineAt: DateTime(2026, 8, 27),
      );
      expect(
        () => controller.connectNetwork(session, intent),
        throwsA(isA<RemoteControlException>().having(
          (error) => error.error.message,
          'message',
          isNot(contains('internal detail')),
        )),
      );
      expect(fake.networkCalls, 1);
    });

    test('completes the local control-plane to FFI core flow', () async {
      final controlPlane = RemoteControlPlaneClient(_FakeBackendClient());
      final devices = await controlPlane.listDevices();
      expect(devices.single.id, 'device-1');
      final backendSession = await controlPlane.createSession(
        devices.single.id,
        sourceDeviceId: 'source-1',
      );
      final intent = await controlPlane.getConnectionIntent(backendSession);

      final ffi = UltimateRemoteFfiSessionController(_FakeFfiApi());
      ffi.initialize();
      final localSession = ffi.createSession(backendSession);
      expect(localSession.state, RemoteSessionState.authorized);
      final networkEvents = ffi.connectNetwork(localSession, intent);
      expect(networkEvents.single.state, RemoteConnectionState.connected);
      expect(networkEvents.single.path, RemoteConnectionPath.direct);
      expect(
          ffi.startSession(localSession).state, RemoteSessionState.connected);
      expect(ffi.stopSession(localSession).state, RemoteSessionState.closed);
      ffi.shutdown();
    });
  });
}

void _registerPhase17Tests() {
  _addFfiFoundationTests();
}

class _FakeBackendClient implements RemoteBackendClient {
  @override
  RemoteEnvironmentConfig get environment => RemoteEnvironmentConfig(
        environment: RemoteEnvironment.development,
        apiEndpoint: Uri.parse('http://localhost:8080/api'),
      );

  @override
  Future<RemoteApiResponse> send(RemoteApiRequest request) async {
    if (request.method == 'GET' && request.path == '/api/v1/devices') {
      return const RemoteApiResponse(
        statusCode: 200,
        body: <String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'id': 'device-1',
              'organization_id': 'tenant-1',
              'device_identifier': 'stable-device-1',
              'name': 'Target',
              'platform': 'linux',
              'status': 'ONLINE',
            },
          ],
        },
      );
    }
    if (request.method == 'POST' && request.path == '/api/v1/sessions') {
      return const RemoteApiResponse(
        statusCode: 201,
        body: <String, Object?>{
          'id': 'session-1',
          'organization_id': 'tenant-1',
          'device_id': 'device-1',
          'source_device_id': 'source-1',
          'initiated_by': 'user-1',
          'status': 'REQUESTED',
          'authorization_state': 'AUTHORIZED',
          'correlation_id': 'correlation-1',
          'created_at': '2026-08-27T00:00:00Z',
        },
      );
    }
    if (request.method == 'GET' &&
        request.path.endsWith('/connection-intent')) {
      return const RemoteApiResponse(
        statusCode: 200,
        body: <String, Object?>{
          'session_id': 'session-1',
          'target_device_id': 'device-1',
          'source_device_id': 'source-1',
          'correlation_id': 'correlation-1',
          'deadline_at': '2026-08-27T01:00:00Z',
          'allowed_paths': <Object?>['DIRECT', 'NAT_TRAVERSAL', 'RELAY'],
        },
      );
    }
    if (request.path.endsWith('/start')) {
      return const RemoteApiResponse(
        statusCode: 200,
        body: <String, Object?>{
          'id': 'session-1',
          'organization_id': 'tenant-1',
          'device_id': 'device-1',
          'initiated_by': 'user-1',
          'status': 'CONNECTING',
          'authorization_state': 'AUTHORIZED',
          'correlation_id': 'correlation-1',
          'created_at': '2026-08-27T00:00:00Z',
        },
      );
    }
    return const RemoteApiResponse(
      statusCode: 200,
      body: <String, Object?>{
        'id': 'session-1',
        'organization_id': 'tenant-1',
        'device_id': 'device-1',
        'initiated_by': 'user-1',
        'status': 'CLOSED',
        'authorization_state': 'AUTHORIZED',
        'correlation_id': 'correlation-1',
        'created_at': '2026-08-27T00:00:00Z',
      },
    );
  }
}
