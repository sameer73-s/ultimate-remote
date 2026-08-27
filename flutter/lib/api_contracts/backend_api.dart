import '../foundation/backend_foundation.dart';

class ApiError implements Exception {
  const ApiError({
    required this.code,
    required this.message,
    required this.requestId,
    this.statusCode,
  });

  final String code;
  final String message;
  final String requestId;
  final int? statusCode;

  factory ApiError.fromResponse(RemoteApiResponse response) {
    final body = response.body is Map
        ? Map<String, Object?>.from(response.body! as Map)
        : const <String, Object?>{};
    final error = body['error'] is Map
        ? Map<String, Object?>.from(body['error']! as Map)
        : const <String, Object?>{};
    return ApiError(
      code: (error['code'] as String?) ?? 'REQUEST_FAILED',
      message: (error['message'] as String?) ?? 'Request failed',
      requestId: (error['request_id'] as String?) ?? '',
      statusCode: response.statusCode,
    );
  }

  @override
  String toString() => '$code: $message';
}

class OrganizationContract {
  const OrganizationContract({
    required this.id,
    required this.name,
    required this.slug,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String slug;
  final DateTime createdAt;

  factory OrganizationContract.fromJson(Map<String, Object?> json) {
    return OrganizationContract(
      id: json['id']! as String,
      name: json['name']! as String,
      slug: json['slug']! as String,
      createdAt: DateTime.parse(json['created_at']! as String),
    );
  }
}

class UserContract {
  const UserContract({
    required this.id,
    required this.organizationId,
    required this.email,
    required this.displayName,
    required this.status,
    required this.roles,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
  });

  final String id;
  final String organizationId;
  final String email;
  final String displayName;
  final String status;
  final List<String> roles;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;

  factory UserContract.fromJson(Map<String, Object?> json) {
    return UserContract(
      id: json['id']! as String,
      organizationId: json['organization_id']! as String,
      email: json['email']! as String,
      displayName: json['display_name']! as String,
      status: json['status']! as String,
      roles: List<String>.from(json['roles']! as List),
      createdAt: DateTime.parse(json['created_at']! as String),
      updatedAt: DateTime.parse(json['updated_at']! as String),
      lastLoginAt: json['last_login_at'] == null
          ? null
          : DateTime.parse(json['last_login_at']! as String),
    );
  }
}

class DeviceContract {
  const DeviceContract({
    required this.id,
    required this.organizationId,
    required this.deviceIdentifier,
    required this.name,
    required this.platform,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.lastSeenAt,
  });

  final String id;
  final String organizationId;
  final String deviceIdentifier;
  final String name;
  final String platform;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSeenAt;

  factory DeviceContract.fromJson(Map<String, Object?> json) {
    return DeviceContract(
      id: json['id']! as String,
      organizationId: json['organization_id']! as String,
      deviceIdentifier: json['device_identifier']! as String,
      name: json['name']! as String,
      platform: json['platform']! as String,
      status: json['status']! as String,
      createdAt: DateTime.parse(json['created_at']! as String),
      updatedAt: DateTime.parse(json['updated_at']! as String),
      lastSeenAt: json['last_seen_at'] == null
          ? null
          : DateTime.parse(json['last_seen_at']! as String),
    );
  }
}

class SessionContract {
  const SessionContract({
    required this.id,
    required this.organizationId,
    required this.deviceId,
    required this.initiatedBy,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String organizationId;
  final String deviceId;
  final String initiatedBy;
  final String status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;

  factory SessionContract.fromJson(Map<String, Object?> json) {
    return SessionContract(
      id: json['id']! as String,
      organizationId: json['organization_id']! as String,
      deviceId: json['device_id']! as String,
      initiatedBy: json['initiated_by']! as String,
      status: json['status']! as String,
      createdAt: DateTime.parse(json['created_at']! as String),
      startedAt: json['started_at'] == null
          ? null
          : DateTime.parse(json['started_at']! as String),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.parse(json['ended_at']! as String),
    );
  }
}

class AuditEventContract {
  const AuditEventContract({
    required this.id,
    required this.organizationId,
    required this.eventType,
    required this.targetType,
    required this.timestamp,
    required this.metadata,
    this.actorUserId,
    this.targetId,
  });

  final String id;
  final String? organizationId;
  final String? actorUserId;
  final String eventType;
  final String targetType;
  final String? targetId;
  final DateTime timestamp;
  final Map<String, Object?> metadata;

  factory AuditEventContract.fromJson(Map<String, Object?> json) {
    return AuditEventContract(
      id: json['id']! as String,
      organizationId: json['organization_id'] as String?,
      actorUserId: json['actor_user_id'] as String?,
      eventType: json['event_type']! as String,
      targetType: json['target_type']! as String,
      targetId: json['target_id'] as String?,
      timestamp: DateTime.parse(json['timestamp']! as String),
      metadata: Map<String, Object?>.from(json['metadata']! as Map),
    );
  }
}

class AuthResponseContract {
  const AuthResponseContract({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final UserContract user;

  factory AuthResponseContract.fromJson(Map<String, Object?> json) {
    return AuthResponseContract(
      accessToken: json['access_token']! as String,
      refreshToken: json['refresh_token']! as String,
      tokenType: json['token_type']! as String,
      user: UserContract.fromJson(
        Map<String, Object?>.from(json['user']! as Map),
      ),
    );
  }
}

class BackendApiClient {
  BackendApiClient(this.backend);

  final RemoteBackendClient backend;

  Future<Map<String, Object?>> request(
    String method,
    String path, {
    Object? body,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final response = await backend.send(
      RemoteApiRequest(
        method: method,
        path: path,
        body: body,
        headers: headers,
      ),
    );
    if (!response.isSuccessful) {
      throw ApiError.fromResponse(response);
    }
    if (response.body is Map) {
      return Map<String, Object?>.from(response.body! as Map);
    }
    return const <String, Object?>{};
  }
}

class AuthRepository {
  const AuthRepository(this.client);
  final BackendApiClient client;

  Future<UserContract> currentUser() async {
    return UserContract.fromJson(
      await client.request('GET', '/api/v1/auth/me'),
    );
  }
}

class DeviceRepository {
  const DeviceRepository(this.client);
  final BackendApiClient client;

  Future<List<DeviceContract>> list() async {
    final response = await client.request('GET', '/api/v1/devices');
    final items = response['items'] as List? ?? const [];
    return items
        .map((item) =>
            DeviceContract.fromJson(Map<String, Object?>.from(item as Map)))
        .toList(growable: false);
  }
}

class SessionRepository {
  const SessionRepository(this.client);
  final BackendApiClient client;

  Future<List<SessionContract>> list() async {
    final response = await client.request('GET', '/api/v1/sessions');
    final items = response['items'] as List? ?? const [];
    return items
        .map((item) =>
            SessionContract.fromJson(Map<String, Object?>.from(item as Map)))
        .toList(growable: false);
  }
}
