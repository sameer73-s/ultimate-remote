enum RemoteSessionState {
  idle,
  connecting,
  authenticating,
  authorizing,
  connected,
  disconnecting,
  disconnected,
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
    this.state = RemoteSessionState.idle,
    this.permissions = const RemoteSessionPermissions(),
  });

  final String id;
  final String deviceId;
  final RemoteSessionState state;
  final RemoteSessionPermissions permissions;

  RemoteSession copyWith({
    String? id,
    String? deviceId,
    RemoteSessionState? state,
    RemoteSessionPermissions? permissions,
  }) {
    return RemoteSession(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      state: state ?? this.state,
      permissions: permissions ?? this.permissions,
    );
  }
}

/// Logical session boundary for future authorization and lifecycle adapters.
abstract interface class RemoteSessionRepository {
  Future<RemoteSession> createSession(String deviceId);

  Future<void> endSession(String sessionId);
}
