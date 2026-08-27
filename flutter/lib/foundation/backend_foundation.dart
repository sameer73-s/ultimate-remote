import 'environment.dart';

class RemoteApiRequest {
  const RemoteApiRequest({
    required this.method,
    required this.path,
    this.body,
    this.headers = const <String, String>{},
  });

  final String method;
  final String path;
  final Object? body;
  final Map<String, String> headers;
}

class RemoteApiResponse {
  const RemoteApiResponse({
    required this.statusCode,
    this.body,
    this.headers = const <String, String>{},
  });

  final int statusCode;
  final Object? body;
  final Map<String, String> headers;

  bool get isSuccessful => statusCode >= 200 && statusCode < 300;
}

/// Testable and replaceable boundary for the future Ultimate Remote backend.
///
/// Implementations must be supplied by a later integration wave. This
/// contract deliberately contains no authentication transport or persistence.
abstract interface class RemoteBackendClient {
  RemoteEnvironmentConfig get environment;

  Future<RemoteApiResponse> send(RemoteApiRequest request);
}
