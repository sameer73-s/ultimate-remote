import 'device_foundation.dart';
import 'session_foundation.dart';

class RemoteConnectionIntent {
  const RemoteConnectionIntent({
    required this.sessionId,
    required this.targetDeviceId,
    required this.correlationId,
    required this.deadlineAt,
    this.sourceDeviceId,
    this.allowedPaths = const <RemoteConnectionPath>[
      RemoteConnectionPath.direct,
      RemoteConnectionPath.natTraversal,
      RemoteConnectionPath.relay,
    ],
  });

  final String sessionId;
  final String targetDeviceId;
  final String? sourceDeviceId;
  final String correlationId;
  final DateTime deadlineAt;
  final List<RemoteConnectionPath> allowedPaths;

  factory RemoteConnectionIntent.fromBackendJson(Map<String, dynamic> json) {
    final paths = (json['allowed_paths'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .map(RemoteConnectionPath.fromBackendValue)
        .whereType<RemoteConnectionPath>()
        .toList(growable: false);
    return RemoteConnectionIntent(
      sessionId: json['session_id'] as String,
      targetDeviceId: json['target_device_id'] as String,
      sourceDeviceId: json['source_device_id'] as String?,
      correlationId: json['correlation_id'] as String,
      deadlineAt: DateTime.parse(json['deadline_at'] as String),
      allowedPaths: paths.isEmpty
          ? const <RemoteConnectionPath>[
              RemoteConnectionPath.direct,
              RemoteConnectionPath.natTraversal,
              RemoteConnectionPath.relay,
            ]
          : paths,
    );
  }
}

enum RemoteConnectionPath {
  direct,
  natTraversal,
  relay;

  static RemoteConnectionPath? fromBackendValue(String value) {
    switch (value.toUpperCase()) {
      case 'DIRECT':
        return RemoteConnectionPath.direct;
      case 'NAT_TRAVERSAL':
        return RemoteConnectionPath.natTraversal;
      case 'RELAY':
        return RemoteConnectionPath.relay;
      default:
        return null;
    }
  }
}

enum RemoteConnectionState {
  resolving,
  connectingDirect,
  directFailed,
  connectingNat,
  natFailed,
  connectingRelay,
  connected,
  disconnected,
  failed,
  cancelled;

  static RemoteConnectionState fromValue(String value) {
    switch (value.toUpperCase()) {
      case 'RESOLVING':
        return RemoteConnectionState.resolving;
      case 'CONNECTING_DIRECT':
        return RemoteConnectionState.connectingDirect;
      case 'DIRECT_FAILED':
        return RemoteConnectionState.directFailed;
      case 'CONNECTING_NAT':
        return RemoteConnectionState.connectingNat;
      case 'NAT_FAILED':
        return RemoteConnectionState.natFailed;
      case 'CONNECTING_RELAY':
        return RemoteConnectionState.connectingRelay;
      case 'CONNECTED':
        return RemoteConnectionState.connected;
      case 'DISCONNECTED':
        return RemoteConnectionState.disconnected;
      case 'CANCELLED':
        return RemoteConnectionState.cancelled;
      default:
        return RemoteConnectionState.failed;
    }
  }
}

class RemoteConnectionEvent {
  const RemoteConnectionEvent({
    required this.sessionId,
    required this.targetDeviceId,
    required this.correlationId,
    required this.state,
    this.connectionId,
    this.path,
    this.failureCode,
    this.relayUsed = false,
  });

  final String sessionId;
  final String targetDeviceId;
  final String correlationId;
  final String? connectionId;
  final RemoteConnectionState state;
  final RemoteConnectionPath? path;
  final String? failureCode;
  final bool relayUsed;

  factory RemoteConnectionEvent.fromJson(Map<String, dynamic> json) {
    return RemoteConnectionEvent(
      sessionId: json['session_id'] as String,
      targetDeviceId: json['target_device_id'] as String,
      correlationId: json['correlation_id'] as String,
      connectionId: json['connection_id'] as String?,
      state: RemoteConnectionState.fromValue(json['state'] as String),
      path: _path(json['connection_path'] as String?),
      failureCode: json['failure_reason'] as String?,
      relayUsed: json['relay_used'] as bool? ?? false,
    );
  }

  static RemoteConnectionPath? _path(String? value) {
    if (value == null) return null;
    return RemoteConnectionPath.fromBackendValue(value);
  }
}

class RemoteConnectionError {
  const RemoteConnectionError({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  final String code;
  final String message;
  final bool retryable;
}

/// Networking controller boundary. Authorization is completed by the backend
/// before this interface receives a RemoteConnectionIntent.
abstract interface class RemoteNetworkingController {
  Future<RemoteConnectionIntent> getIntent(RemoteSession session);

  Stream<RemoteConnectionEvent> connect(
    RemoteSession session,
    RemoteConnectionIntent intent,
  );

  Future<void> disconnect(RemoteSession session);
}

/// Keeps device identity available to networking-facing clients without
/// exposing the underlying RustDesk peer structures.
class RemoteNetworkingDevice {
  const RemoteNetworkingDevice(this.device);

  final RemoteDevice device;
}
