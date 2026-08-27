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
    this.name,
    this.platform,
    this.metadata = const <String, String>{},
  });

  final String id;
  final RemoteDeviceStatus status;
  final String? name;
  final String? platform;
  final Map<String, String> metadata;

  RemoteDevice copyWith({
    String? id,
    RemoteDeviceStatus? status,
    String? name,
    String? platform,
    Map<String, String>? metadata,
  }) {
    return RemoteDevice(
      id: id ?? this.id,
      status: status ?? this.status,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Replaceable boundary for future control-plane device APIs.
abstract interface class RemoteDeviceRepository {
  Future<List<RemoteDevice>> listDevices();

  Future<RemoteDevice?> getDevice(String deviceId);
}
