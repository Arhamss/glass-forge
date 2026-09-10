import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:glass_forge_workbench/utils/helpers/logger_helper.dart';

class LoggingInterceptor extends Interceptor {
  final _timestamps = <int, int>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      _timestamps[options.hashCode] = DateTime.now().millisecondsSinceEpoch;

      AppLogger.apiRequest(
        method: options.method,
        uri: options.uri,
        headers: options.headers,
        queryParams: options.queryParameters.isNotEmpty
            ? options.queryParameters
            : null,
        body: options.data,
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (kDebugMode) {
      AppLogger.apiResponse(
        method: response.requestOptions.method,
        path: response.requestOptions.uri.path,
        statusCode: response.statusCode ?? 0,
        elapsedMs: _elapsed(response.requestOptions.hashCode),
        body: response.data,
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      AppLogger.apiError(
        method: err.requestOptions.method,
        path: err.requestOptions.uri.path,
        statusCode: err.response?.statusCode ?? 0,
        elapsedMs: _elapsed(err.requestOptions.hashCode),
        body: err.response?.data,
        errorMessage: _extractMessage(err),
      );
    }
    handler.next(err);
  }

  int _elapsed(int hash) {
    final start = _timestamps.remove(hash);
    if (start == null) return 0;
    return DateTime.now().millisecondsSinceEpoch - start;
  }

  String? _extractMessage(DioException err) {
    final data = err.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) return error['message']?.toString();
      return data['message']?.toString();
    }
    if (data == null && err.message != null) return err.message;
    return null;
  }
}
