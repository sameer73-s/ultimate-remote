enum RemoteSessionState {
  idle,
  requested,
  authorized,
  connecting,
  authenticating,
  authorizing,
  connected,
  disconnecting,
  disconnected,
  closed,
  failed,
}

class RemoteSessionPermissions {
  const RemoteSessionPermissions({
    this.viewOnly = false,
    this.input = false,
    this.clipboard = false,
    this.fileTransfer = false,
    this.terminal = false,
  });

  final bool viewOnly;
  final bool input;
  final bool clipboard;
  final bool fileTransfer;
  final bool terminal;
}

class RemoteSession {
  const RemoteSession({
    required this.id,
    required this.deviceId,
    this.sourceDeviceId,
    this.organizationId,
    this.userId,
    this.correlationId,
    this.state = RemoteSessionState.idle,
    this.authorizationState = 'UNKNOWN',
    this.permissions = const RemoteSessionPermissions(),
    this.createdAt,
    this.deadlineAt,
    this.startedAt,
    this.endedAt,
    this.terminationReason,
    this.errorCode,
  });

  final String id;
  final String deviceId;
  final String? sourceDeviceId;
  final String? organizationId;
  final String? userId;
  final String? correlationId;
  final RemoteSessionState state;
  final String authorizationState;
  final RemoteSessionPermissions permissions;
  final DateTime? createdAt;
  final DateTime? deadlineAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? terminationReason;
  final String? errorCode;

  factory RemoteSession.fromBackendJson(Map<String, dynamic> json) {
    final status = (json['status'] as String? ?? '').toUpperCase();
    return RemoteSession(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      sourceDeviceId: json['source_device_id'] as String?,
      organizationId: json['organization_id'] as String?,
      userId: json['initiated_by'] as String?,
      correlationId: json['correlation_id'] as String?,
      state: _stateFromBackendStatus(status),
      authorizationState: json['authorization_state'] as String? ?? 'UNKNOWN',
      createdAt: _date(json['created_at']),
      deadlineAt: _date(json['deadline_at']),
      startedAt: _date(json['started_at']),
      endedAt: _date(json['ended_at']),
      terminationReason: json['termination_reason'] as String?,
      errorCode: json['error_code'] as String?,
    );
  }

  static RemoteSessionState _stateFromBackendStatus(String status) {
    switch (status) {
      case 'REQUESTED':
        return RemoteSessionState.requested;
      case 'AUTHORIZED':
        return RemoteSessionState.authorized;
      case 'CONNECTING':
        return RemoteSessionState.connecting;
      case 'CONNECTED':
      case 'ACTIVE':
        return RemoteSessionState.connected;
      case 'DISCONNECTED':
        return RemoteSessionState.disconnected;
      case 'ENDED':
      case 'CLOSED':
      case 'CANCELLED':
        return RemoteSessionState.closed;
      case 'FAILED':
        return RemoteSessionState.failed;
      default:
        return RemoteSessionState.idle;
    }
  }

  static DateTime? _date(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  RemoteSession copyWith({
    String? id,
    String? deviceId,
    String? sourceDeviceId,
    String? organizationId,
    String? userId,
    String? correlationId,
    RemoteSessionState? state,
    String? authorizationState,
    RemoteSessionPermissions? permissions,
    DateTime? createdAt,
    DateTime? deadlineAt,
    DateTime? startedAt,
    DateTime? endedAt,
    String? terminationReason,
    String? errorCode,
  }) {
    return RemoteSession(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      sourceDeviceId: sourceDeviceId ?? this.sourceDeviceId,
      organizationId: organizationId ?? this.organizationId,
      userId: userId ?? this.userId,
      correlationId: correlationId ?? this.correlationId,
      state: state ?? this.state,
      authorizationState: authorizationState ?? this.authorizationState,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      deadlineAt: deadlineAt ?? this.deadlineAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      terminationReason: terminationReason ?? this.terminationReason,
      errorCode: errorCode ?? this.errorCode,
    );
  }
}

/// Control-plane lifecycle boundary. It never carries refresh tokens into FFI.
abstract interface class RemoteSessionRepository {
  Future<RemoteSession> createSession(String deviceId,
      {String? sourceDeviceId});

  Future<RemoteSession> getSession(String sessionId);

  Future<RemoteSession> startSession(String sessionId);

  Future<RemoteSession> stopSession(
    String sessionId, {
    String reason = 'client_requested',
  });

  Future<void> endSession(String sessionId);
}
