enum RemoteErrorKind {
  network,
  authentication,
  authorization,
  session,
  configuration,
  platform,
  unknown,
}

class RemoteError {
  const RemoteError({
    required this.kind,
    required this.message,
    this.code,
    this.cause,
    this.retryable = false,
  });

  final RemoteErrorKind kind;
  final String message;
  final String? code;
  final Object? cause;
  final bool retryable;

  @override
  String toString() {
    final suffix = code == null ? '' : ' [$code]';
    return '${kind.name}$suffix: $message';
  }
}

class RemoteErrorAdapter {
  RemoteErrorAdapter._();

  static RemoteError from(Object error) {
    if (error is RemoteError) {
      return error;
    }
    return RemoteError(
      kind: RemoteErrorKind.unknown,
      message: 'An unexpected error occurred.',
      cause: error,
    );
  }
}
