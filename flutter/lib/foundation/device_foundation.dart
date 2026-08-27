enum RemoteDeviceStatus {
  online,
  offline,
  restricted,
  quarantined,
  unknown,
}

class RemoteDevice {
  const RemoteDevice({
    required this.id,
    required this.status,
    this.deviceIdentifier,
    this.organizationId,
    this.name,
    this.platform,
    this.metadata = const <String, String>{},
    this.createdAt,
    this.updatedAt,
    this.lastSeenAt,
  });

  final String id;
  final String? deviceIdentifier;
  final String? organizationId;
  final RemoteDeviceStatus status;
  final String? name;
  final String? platform;
  final Map<String, String> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastSeenAt;

  factory RemoteDevice.fromBackendJson(Map<String, dynamic> json) {
    return RemoteDevice(
      id: json['id'] as String,
      deviceIdentifier: json['device_identifier'] as String?,
      organizationId: json['organization_id'] as String?,
      status: _statusFromBackendValue(json['status'] as String?),
      name: json['name'] as String?,
      platform: json['platform'] as String?,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      lastSeenAt: _date(json['last_seen_at']),
    );
  }

  static RemoteDeviceStatus _statusFromBackendValue(String? value) {
    switch (value?.toUpperCase()) {
      case 'ONLINE':
        return RemoteDeviceStatus.online;
      case 'OFFLINE':
        return RemoteDeviceStatus.offline;
      case 'RESTRICTED':
        return RemoteDeviceStatus.restricted;
      case 'QUARANTINED':
        return RemoteDeviceStatus.quarantined;
      default:
        return RemoteDeviceStatus.unknown;
    }
  }

  static DateTime? _date(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  RemoteDevice copyWith({
    String? id,
    String? deviceIdentifier,
    String? organizationId,
    RemoteDeviceStatus? status,
    String? name,
    String? platform,
    Map<String, String>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSeenAt,
  }) {
    return RemoteDevice(
      id: id ?? this.id,
      deviceIdentifier: deviceIdentifier ?? this.deviceIdentifier,
      organizationId: organizationId ?? this.organizationId,
      status: status ?? this.status,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}

/// Replaceable boundary for future control-plane device APIs.
abstract interface class RemoteDeviceRepository {
  Future<List<RemoteDevice>> listDevices();

  Future<RemoteDevice?> getDevice(String deviceId);
}
