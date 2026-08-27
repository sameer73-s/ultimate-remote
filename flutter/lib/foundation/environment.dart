/// Deployment environments supported by the client foundation.
enum RemoteEnvironment {
  development,
  staging,
  production,
}

/// Environment-aware, non-secret client configuration.
///
/// Endpoints are intentionally injected by the host/application layer. No
/// endpoint, credential, token, certificate, or private key is bundled here.
class RemoteEnvironmentConfig {
  RemoteEnvironmentConfig({
    required this.environment,
    this.apiEndpoint,
    this.rendezvousEndpoint,
    this.relayEndpoint,
    Map<String, bool> featureFlags = const <String, bool>{},
  }) : featureFlags = Map.unmodifiable(featureFlags);

  final RemoteEnvironment environment;
  final Uri? apiEndpoint;
  final Uri? rendezvousEndpoint;
  final Uri? relayEndpoint;
  final Map<String, bool> featureFlags;

  bool isFeatureEnabled(String name, {bool fallback = false}) {
    return featureFlags[name] ?? fallback;
  }

  /// Returns configuration problems without contacting any remote service.
  List<String> validate() {
    final errors = <String>[];
    final endpoints = <String, Uri?>{
      'api': apiEndpoint,
      'rendezvous': rendezvousEndpoint,
      'relay': relayEndpoint,
    };

    for (final entry in endpoints.entries) {
      final endpoint = entry.value;
      if (endpoint == null) {
        continue;
      }
      if (endpoint.userInfo.isNotEmpty) {
        errors.add('${entry.key} endpoint must not contain credentials');
      }
      if (environment == RemoteEnvironment.production &&
          endpoint.scheme != 'https') {
        errors.add('${entry.key} endpoint must use HTTPS in production');
      }
    }
    return List.unmodifiable(errors);
  }

  bool get isValid => validate().isEmpty;

  RemoteEnvironmentConfig copyWith({
    RemoteEnvironment? environment,
    Uri? apiEndpoint,
    Uri? rendezvousEndpoint,
    Uri? relayEndpoint,
    Map<String, bool>? featureFlags,
  }) {
    return RemoteEnvironmentConfig(
      environment: environment ?? this.environment,
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
      rendezvousEndpoint: rendezvousEndpoint ?? this.rendezvousEndpoint,
      relayEndpoint: relayEndpoint ?? this.relayEndpoint,
      featureFlags: featureFlags ?? this.featureFlags,
    );
  }
}
