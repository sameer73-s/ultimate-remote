/// Opaque access token carried by an authentication adapter.
///
/// This object is in-memory only. Persistence, rotation, and revocation belong
/// to a future secure adapter; the foundation never writes the token to disk
/// or logs its value.
class RemoteAuthToken {
  RemoteAuthToken.fromValue(String value)
      : assert(value != '', 'An authentication token cannot be empty'),
        _value = value;

  final String _value;

  /// Exposes the token only to the adapter that is responsible for transport.
  String get value => _value;

  String get redacted => '[REDACTED]';

  @override
  String toString() => 'RemoteAuthToken($redacted)';
}

class RemoteAuthUser {
  const RemoteAuthUser({
    required this.id,
    this.displayName,
    this.email,
  });

  final String id;
  final String? displayName;
  final String? email;
}

class RemoteAuthSession {
  const RemoteAuthSession({
    required this.user,
    required this.token,
    this.expiresAt,
  });

  final RemoteAuthUser user;
  final RemoteAuthToken token;
  final DateTime? expiresAt;

  bool isExpired([DateTime? now]) {
    final expiry = expiresAt;
    return expiry != null && !expiry.isAfter(now ?? DateTime.now());
  }
}

/// Replaceable boundary for a future backend/OIDC/MFA implementation.
abstract interface class RemoteAuthenticationService {
  Future<RemoteAuthSession> login({
    required String identifier,
    required String secret,
  });

  Future<void> logout();

  Future<RemoteAuthSession?> currentSession();
}
