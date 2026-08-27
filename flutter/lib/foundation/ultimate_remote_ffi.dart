import 'dart:convert';

import '../generated_bridge.dart';
import 'error_foundation.dart';
import 'session_foundation.dart';

abstract interface class UltimateRemoteFfiApi {
  Future<String> apiVersion();

  String initialize();

  String createSession(String contextJson);

  String startSession(String sessionId);

  String stopSession(String sessionId);

  String drainEvents();

  String shutdown();
}

class GeneratedUltimateRemoteFfiApi implements UltimateRemoteFfiApi {
  const GeneratedUltimateRemoteFfiApi(this.binding);

  final Rustdesk binding;

  @override
  Future<String> apiVersion() => binding.ultimateRemoteApiVersion();

  @override
  String initialize() => binding.ultimateRemoteInitialize();

  @override
  String createSession(String contextJson) =>
      binding.ultimateRemoteSessionCreate(contextJson: contextJson);

  @override
  String startSession(String sessionId) =>
      binding.ultimateRemoteSessionStart(sessionId: sessionId);

  @override
  String stopSession(String sessionId) =>
      binding.ultimateRemoteSessionStop(sessionId: sessionId);

  @override
  String drainEvents() => binding.ultimateRemoteDrainEvents();

  @override
  String shutdown() => binding.ultimateRemoteShutdown();
}

/// Narrow local-core boundary. The backend remains the authorization control plane.
class UltimateRemoteFfiSessionController {
  UltimateRemoteFfiSessionController(this.api);

  final UltimateRemoteFfiApi api;
  bool _initialized = false;
  bool _shutdown = false;

  Future<String> apiVersion() => api.apiVersion();

  void initialize() {
    _ensureNotShutdown();
    _expectSuccess(api.initialize());
    _initialized = true;
  }

  RemoteSession createSession(RemoteSession session) {
    _ensureReady();
    if (session.authorizationState.toUpperCase() != 'AUTHORIZED') {
      throw const RemoteControlException(
        RemoteError(
          kind: RemoteErrorKind.authorization,
          code: 'BACKEND_AUTHORIZATION_REQUIRED',
          message: 'A backend-authorized session is required before FFI.',
        ),
      );
    }
    final context = <String, Object?>{
      'session_id': session.id,
      'organization_id': session.organizationId,
      'user_id': session.userId,
      'source_device_id': session.sourceDeviceId,
      'target_device_id': session.deviceId,
      'correlation_id': session.correlationId,
      'backend_authorized': true,
    };
    final value = _expectSuccess(
      api.createSession(jsonEncode(context)),
    );
    _assertSessionIdentity(value, session.id);
    return session.copyWith(state: RemoteSessionState.authorized);
  }

  RemoteSession startSession(RemoteSession session) {
    _ensureReady();
    final value = _expectSuccess(api.startSession(session.id));
    _assertSessionIdentity(value, session.id);
    return session.copyWith(state: RemoteSessionState.connected);
  }

  RemoteSession stopSession(RemoteSession session) {
    _ensureReady();
    final value = _expectSuccess(api.stopSession(session.id));
    _assertSessionIdentity(value, session.id);
    return session.copyWith(state: RemoteSessionState.closed);
  }

  List<Map<String, dynamic>> drainEvents() {
    _ensureReady();
    final value = _expectSuccess(api.drainEvents());
    if (value is! List) {
      throw const RemoteControlException(
        RemoteError(
          kind: RemoteErrorKind.platform,
          code: 'INVALID_FFI_EVENTS',
          message: 'The FFI event payload was invalid.',
        ),
      );
    }
    return value
        .whereType<Map>()
        .map((event) => Map<String, dynamic>.from(event))
        .toList(growable: false);
  }

  void shutdown() {
    if (_shutdown) return;
    _ensureReady();
    _expectSuccess(api.shutdown());
    _shutdown = true;
    _initialized = false;
  }

  Object? _expectSuccess(String raw) {
    final decoded = _decode(raw);
    if (decoded['ok'] != true) {
      final error = decoded['error'];
      final errorMap =
          error is Map ? Map<String, dynamic>.from(error) : const {};
      throw RemoteControlException(
        RemoteError(
          kind: _errorKind(errorMap['code'] as String?),
          code: errorMap['code'] as String? ?? 'FFI_ERROR',
          message: 'The local session operation could not be completed.',
        ),
      );
    }
    return decoded['value'];
  }

  static Map<String, dynamic> _decode(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is Map) return Map<String, dynamic>.from(value);
    } on FormatException {
      // Fall through to the safe error below.
    }
    throw const RemoteControlException(
      RemoteError(
        kind: RemoteErrorKind.platform,
        code: 'INVALID_FFI_RESPONSE',
        message: 'The FFI returned an invalid response.',
      ),
    );
  }

  static void _assertSessionIdentity(Object? value, String expectedId) {
    if (value is! Map) {
      throw const RemoteControlException(
        RemoteError(
          kind: RemoteErrorKind.session,
          code: 'INVALID_FFI_SESSION',
          message: 'The FFI returned an invalid session.',
        ),
      );
    }
    final context = value['context'];
    final actualId = context is Map ? context['session_id'] : null;
    if (actualId != expectedId) {
      throw const RemoteControlException(
        RemoteError(
          kind: RemoteErrorKind.authorization,
          code: 'FFI_SESSION_ID_MISMATCH',
          message:
              'The FFI session identity did not match the authorized session.',
        ),
      );
    }
  }

  static RemoteErrorKind _errorKind(String? code) {
    final value = code?.toUpperCase() ?? '';
    if (value.contains('AUTHORIZATION')) return RemoteErrorKind.authorization;
    if (value.contains('SESSION')) return RemoteErrorKind.session;
    if (value.contains('INITIALIZATION')) return RemoteErrorKind.platform;
    return RemoteErrorKind.unknown;
  }

  void _ensureReady() {
    _ensureNotShutdown();
    if (!_initialized) {
      throw const RemoteControlException(
        RemoteError(
          kind: RemoteErrorKind.platform,
          code: 'FFI_NOT_INITIALIZED',
          message: 'The FFI boundary is not initialized.',
        ),
      );
    }
  }

  void _ensureNotShutdown() {
    if (_shutdown) {
      throw const RemoteControlException(
        RemoteError(
          kind: RemoteErrorKind.platform,
          code: 'FFI_SHUTDOWN',
          message: 'The FFI boundary has been shut down.',
        ),
      );
    }
  }
}

class RemoteControlException implements Exception {
  const RemoteControlException(this.error);

  final RemoteError error;

  @override
  String toString() => error.toString();
}
