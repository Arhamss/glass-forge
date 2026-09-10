class AppApiException implements Exception {
  AppApiException(
    this.message, {
    this.statusCode,
    this.errorCode,
    this.details,
  });

  final String message;
  final int? statusCode;
  final String? errorCode;
  final List<dynamic>? details;

  @override
  String toString() => message;
}

String extractApiErrorMessage(Object e, String fallback) {
  return e is AppApiException ? e.message : fallback;
}
