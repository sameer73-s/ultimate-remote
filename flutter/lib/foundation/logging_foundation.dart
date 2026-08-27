enum RemoteLogLevel {
  info,
  warning,
  error,
  security,
  session,
}

class RemoteLogSanitizer {
  RemoteLogSanitizer._();

  static const Set<String> sensitiveKeys = <String>{
    'password',
    'secret',
    'token',
    'access_token',
    'refresh_token',
    'private_key',
    'authorization',
    'credential',
  };

  static Map<String, Object?> fields(Map<String, Object?> input) {
    final sanitized = <String, Object?>{};
    input.forEach((key, value) {
      if (sensitiveKeys.contains(key.toLowerCase())) {
        sanitized[key] = '[REDACTED]';
      } else {
        sanitized[key] = value;
      }
    });
    return Map.unmodifiable(sanitized);
  }
}

class RemoteLogEvent {
  RemoteLogEvent({
    required this.level,
    required this.message,
    Map<String, Object?> fields = const <String, Object?>{},
    this.timestamp,
  }) : fields = RemoteLogSanitizer.fields(fields);

  final RemoteLogLevel level;
  final String message;
  final Map<String, Object?> fields;
  final DateTime? timestamp;
}

/// Replaceable logging boundary for UI, Rust hooks, and future telemetry.
abstract interface class RemoteLogger {
  void log(RemoteLogEvent event);

  void info(String message, {Map<String, Object?> fields});

  void warning(String message, {Map<String, Object?> fields});

  void error(String message, {Map<String, Object?> fields});

  void security(String message, {Map<String, Object?> fields});

  void session(String message, {Map<String, Object?> fields});
}

class NoopRemoteLogger implements RemoteLogger {
  const NoopRemoteLogger();

  @override
  void log(RemoteLogEvent event) {}

  @override
  void info(String message, {Map<String, Object?> fields = const {}}) {}

  @override
  void warning(String message, {Map<String, Object?> fields = const {}}) {}

  @override
  void error(String message, {Map<String, Object?> fields = const {}}) {}

  @override
  void security(String message, {Map<String, Object?> fields = const {}}) {}

  @override
  void session(String message, {Map<String, Object?> fields = const {}}) {}
}
