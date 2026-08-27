import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/foundation/authentication_foundation.dart';
import 'package:flutter_hbb/foundation/backend_foundation.dart';
import 'package:flutter_hbb/foundation/design_tokens.dart';
import 'package:flutter_hbb/foundation/device_foundation.dart';
import 'package:flutter_hbb/foundation/environment.dart';
import 'package:flutter_hbb/foundation/error_foundation.dart';
import 'package:flutter_hbb/foundation/localization_foundation.dart';
import 'package:flutter_hbb/foundation/logging_foundation.dart';
import 'package:flutter_hbb/foundation/product_identity.dart';
import 'package:flutter_hbb/foundation/session_foundation.dart';

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
}
