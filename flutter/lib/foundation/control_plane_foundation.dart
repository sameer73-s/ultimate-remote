import 'backend_foundation.dart';
import 'device_foundation.dart';
import 'error_foundation.dart';
import 'session_foundation.dart';

class RemoteControlPlaneException implements Exception {
  const RemoteControlPlaneException(this.error);

  final RemoteError error;

  @override
  String toString() => error.toString();
}

/// Backend control-plane adapter. It only handles authorized API contracts;
/// FFI receives a session context, never refresh tokens or credentials.
class RemoteControlPlaneClient
    implements RemoteDeviceRepository, RemoteSessionRepository {
  const RemoteControlPlaneClient(this.client);

  final RemoteBackendClient client;

  @override
  Future<List<RemoteDevice>> listDevices() async {
    final body = await _request(
        const RemoteApiRequest(method: 'GET', path: '/api/v1/devices'));
    final items = body['items'];
    if (items is! List) {
      throw const RemoteControlPlaneException(
        RemoteError(
          kind: RemoteErrorKind.unknown,
          code: 'INVALID_DEVICE_RESPONSE',
          message: 'The backend returned an invalid device response.',
        ),
      );
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(RemoteDevice.fromBackendJson)
        .toList(growable: false);
  }

  @override
  Future<RemoteDevice?> getDevice(String deviceId) async {
    final response = await client.send(
      RemoteApiRequest(method: 'GET', path: '/api/v1/devices/$deviceId'),
    );
    if (response.statusCode == 404) return null;
    final body = await _responseBody(response);
    return RemoteDevice.fromBackendJson(body);
  }

  @override
  Future<RemoteSession> createSession(
    String deviceId, {
    String? sourceDeviceId,
  }) async {
    final payload = <String, Object?>{'device_id': deviceId};
    if (sourceDeviceId != null) payload['source_device_id'] = sourceDeviceId;
    final body = await _request(
      RemoteApiRequest(method: 'POST', path: '/api/v1/sessions', body: payload),
    );
    return RemoteSession.fromBackendJson(body);
  }

  @override
  Future<RemoteSession> getSession(String sessionId) async {
    final body = await _request(
      RemoteApiRequest(method: 'GET', path: '/api/v1/sessions/$sessionId'),
    );
    return RemoteSession.fromBackendJson(body);
  }

  @override
  Future<RemoteSession> startSession(String sessionId) async {
    final body = await _request(
      RemoteApiRequest(
          method: 'POST', path: '/api/v1/sessions/$sessionId/start'),
    );
    return RemoteSession.fromBackendJson(body);
  }

  @override
  Future<RemoteSession> stopSession(
    String sessionId, {
    String reason = 'client_requested',
  }) async {
    final body = await _request(
      RemoteApiRequest(
        method: 'POST',
        path: '/api/v1/sessions/$sessionId/stop',
        body: <String, Object?>{'reason': reason},
      ),
    );
    return RemoteSession.fromBackendJson(body);
  }

  @override
  Future<void> endSession(String sessionId) async {
    await stopSession(sessionId);
  }

  Future<Map<String, dynamic>> _request(RemoteApiRequest request) async {
    return _responseBody(await client.send(request));
  }

  static Future<Map<String, dynamic>> _responseBody(
    RemoteApiResponse response,
  ) async {
    if (!response.isSuccessful) {
      final body = response.body;
      final map = body is Map
          ? Map<String, dynamic>.from(body)
          : const <String, dynamic>{};
      final error = map['error'];
      final errorMap = error is Map
          ? Map<String, dynamic>.from(error)
          : const <String, dynamic>{};
      final kind = response.statusCode == 401
          ? RemoteErrorKind.authentication
          : response.statusCode == 403 || response.statusCode == 404
              ? RemoteErrorKind.authorization
              : RemoteErrorKind.network;
      throw RemoteControlPlaneException(
        RemoteError(
          kind: kind,
          code: errorMap['code'] as String? ?? 'BACKEND_ERROR',
          message: 'The backend request could not be completed.',
          retryable: response.statusCode >= 500,
        ),
      );
    }
    final body = response.body;
    if (body is! Map) {
      throw const RemoteControlPlaneException(
        RemoteError(
          kind: RemoteErrorKind.unknown,
          code: 'INVALID_BACKEND_RESPONSE',
          message: 'The backend returned an invalid response.',
        ),
      );
    }
    return Map<String, dynamic>.from(body);
  }
}
