import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../foundation/backend_foundation.dart';
import '../foundation/environment.dart';
import 'backend_api.dart';

class RemoteTransportException implements Exception {
  const RemoteTransportException(this.code, this.message, {this.cause});

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => '$code: $message';
}

class HttpBackendClient implements RemoteBackendClient {
  HttpBackendClient({
    required this.environment,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
  }) : _httpClient = httpClient ?? http.Client();

  @override
  final RemoteEnvironmentConfig environment;
  final http.Client _httpClient;
  final Duration timeout;

  @override
  Future<RemoteApiResponse> send(RemoteApiRequest request) async {
    final uri = _resolve(request.path);
    final requestId = request.headers['X-Request-ID'] ?? _requestId();
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-Request-ID': requestId,
      ...request.headers,
    };
    if (request.body != null) {
      headers.putIfAbsent('Content-Type', () => 'application/json');
    }
    final encodedBody = request.body == null ? null : jsonEncode(request.body);
    late http.Response response;
    try {
      response = await _sendHttp(request.method, uri, headers, encodedBody)
          .timeout(timeout);
    } on TimeoutException catch (error) {
      throw RemoteTransportException('TIMEOUT', 'Backend request timed out',
          cause: error);
    } on Object catch (error) {
      throw RemoteTransportException(
        'NETWORK_ERROR',
        'Backend request failed',
        cause: error,
      );
    }

    Object? body;
    if (response.bodyBytes.isNotEmpty) {
      final text = utf8.decode(response.bodyBytes);
      try {
        body = jsonDecode(text);
      } on FormatException {
        body = <String, Object?>{
          'error': <String, Object?>{
            'code': 'INVALID_RESPONSE',
            'message': 'Backend returned invalid JSON',
            'request_id': response.headers['x-request-id'] ?? requestId,
          },
        };
      }
    }
    return RemoteApiResponse(
      statusCode: response.statusCode,
      body: body,
      headers: response.headers,
    );
  }

  Uri _resolve(String path) {
    final base = environment.apiEndpoint;
    if (base == null) {
      throw const RemoteTransportException(
        'CONFIGURATION_ERROR',
        'Backend API endpoint is not configured',
      );
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return base.resolve(normalizedPath);
  }

  Future<http.Response> _sendHttp(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) {
    switch (method.toUpperCase()) {
      case 'GET':
        return _httpClient.get(uri, headers: headers);
      case 'POST':
        return _httpClient.post(uri, headers: headers, body: body);
      case 'PATCH':
        return _httpClient.patch(uri, headers: headers, body: body);
      case 'DELETE':
        return _httpClient.delete(uri, headers: headers, body: body);
      default:
        throw const RemoteTransportException(
            'UNSUPPORTED_METHOD', 'HTTP method is not supported');
    }
  }

  String _requestId() => 'flutter-${DateTime.now().microsecondsSinceEpoch}';
}

class StoredTokens {
  const StoredTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

abstract interface class SecureTokenStorage {
  Future<StoredTokens?> read();
  Future<void> write(StoredTokens tokens);
  Future<void> clear();
}

/// In-memory implementation for tests; platform secure storage must provide the production one.
class MemorySecureTokenStorage implements SecureTokenStorage {
  StoredTokens? _tokens;

  @override
  Future<StoredTokens?> read() async => _tokens;

  @override
  Future<void> write(StoredTokens tokens) async {
    _tokens = tokens;
  }

  @override
  Future<void> clear() async {
    _tokens = null;
  }
}

class AuthSessionManager {
  AuthSessionManager({required this.client, required this.storage});

  final BackendApiClient client;
  final SecureTokenStorage storage;

  Future<AuthResponseContract> login(String email, String password) async {
    final response = await client.request(
      'POST',
      '/api/v1/auth/login',
      body: <String, Object?>{'email': email, 'password': password},
    );
    final auth = AuthResponseContract.fromJson(response);
    await storage.write(
      StoredTokens(
          accessToken: auth.accessToken, refreshToken: auth.refreshToken),
    );
    return auth;
  }

  Future<Map<String, Object?>> authenticatedRequest(
    String method,
    String path, {
    Object? body,
  }) async {
    final tokens = await storage.read();
    if (tokens == null) {
      throw const ApiError(
        code: 'UNAUTHENTICATED',
        message: 'No authenticated session',
        requestId: '',
      );
    }
    try {
      return await client.request(
        method,
        path,
        body: body,
        headers: <String, String>{
          'Authorization': 'Bearer ${tokens.accessToken}'
        },
      );
    } on ApiError catch (error) {
      if (error.statusCode != 401) rethrow;
      final refreshed = await _refreshOrClear(tokens.refreshToken);
      return client.request(
        method,
        path,
        body: body,
        headers: <String, String>{
          'Authorization': 'Bearer ${refreshed.accessToken}'
        },
      );
    }
  }

  Future<AuthResponseContract> refresh() async {
    final tokens = await storage.read();
    if (tokens == null) {
      throw const ApiError(
        code: 'UNAUTHENTICATED',
        message: 'No refresh token',
        requestId: '',
      );
    }
    return _refreshOrClear(tokens.refreshToken);
  }

  Future<AuthResponseContract> _refreshOrClear(String refreshToken) async {
    try {
      final response = await client.request(
        'POST',
        '/api/v1/auth/refresh',
        body: <String, Object?>{'refresh_token': refreshToken},
      );
      final auth = AuthResponseContract.fromJson(response);
      await storage.write(
        StoredTokens(
            accessToken: auth.accessToken, refreshToken: auth.refreshToken),
      );
      return auth;
    } on Object {
      await storage.clear();
      rethrow;
    }
  }

  Future<void> logout() async {
    final tokens = await storage.read();
    try {
      if (tokens != null) {
        await client.request(
          'POST',
          '/api/v1/auth/logout',
          headers: <String, String>{
            'Authorization': 'Bearer ${tokens.accessToken}'
          },
        );
      }
    } finally {
      await storage.clear();
    }
  }
}
