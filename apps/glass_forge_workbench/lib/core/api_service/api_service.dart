import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:dio/dio.dart';
import 'package:glass_forge_workbench/config/flavor_config.dart';
import 'package:glass_forge_workbench/core/api_service/app_api_exception.dart';
import 'package:glass_forge_workbench/core/api_service/authentication_interceptor.dart';
import 'package:glass_forge_workbench/core/api_service/log_interceptor.dart';
import 'package:glass_forge_workbench/core/app_preferences/app_preferences.dart';
import 'package:glass_forge_workbench/core/di/injector.dart';
import 'package:glass_forge_workbench/core/endpoints/endpoints.dart';
import 'package:glass_forge_workbench/utils/helpers/logger_helper.dart';

class ApiService {
  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: '${Endpoints.baseUrl}/${Endpoints.apiVersion}/',
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(AuthInterceptor(_appPreferences, _dio));
    _dio.interceptors.add(LoggingInterceptor());
    if (FlavorConfig.isDev()) {
      _dio.interceptors.add(ChuckerDioInterceptor());
    }
  }

  static final ApiService _instance = ApiService._internal();

  late final Dio _dio;
  final AppPreferences _appPreferences = Injector.resolve<AppPreferences>();

  /// GET Request
  Future<Response<dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
  }) async {
    return _handleRequest(
      () => _dio.get(
        endpoint,
        queryParameters: queryParams,
        cancelToken: cancelToken,
      ),
    );
  }

  /// POST Request
  Future<Response<dynamic>> post({
    required String endpoint,
    dynamic data,
    CancelToken? cancelToken,
  }) async {
    return _handleRequest(
      () => _dio.post(endpoint, data: data, cancelToken: cancelToken),
    );
  }

  /// PUT Request
  Future<Response<dynamic>> put(
    String endpoint,
    dynamic data, {
    CancelToken? cancelToken,
  }) async {
    return _handleRequest(
      () => _dio.put(endpoint, data: data, cancelToken: cancelToken),
    );
  }

  /// PATCH Request
  Future<Response<dynamic>> patch(
    String endpoint,
    dynamic data, {
    CancelToken? cancelToken,
  }) async {
    return _handleRequest(
      () => _dio.patch(endpoint, data: data, cancelToken: cancelToken),
    );
  }

  Future<Response<dynamic>> patchMultipart(
    String endpoint,
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    final formData = FormData.fromMap(data);
    return _handleRequest(
      () => _dio.patch(endpoint, data: formData, cancelToken: cancelToken),
    );
  }

  /// DELETE Request
  Future<Response<dynamic>> delete(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
  }) async {
    return _handleRequest(
      () => _dio.delete(
        endpoint,
        data: data,
        queryParameters: queryParams,
        cancelToken: cancelToken,
      ),
    );
  }

  /// Handles Requests & Centralized Error Handling
  Future<Response<dynamic>> _handleRequest(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      throw _handleDioError(e);
    } catch (e, s) {
      AppLogger.error('Unhandled API error', e, s);
      throw AppApiException('Unexpected error occurred');
    }
  }

  AppApiException _handleDioError(DioException e) {
    var errorMessage = 'An unknown error occurred';
    int? statusCode;
    String? errorCode;
    List<dynamic>? details;

    if (e.response != null) {
      statusCode = e.response?.statusCode;
      final responseData = e.response?.data;

      var hasServerMessage = false;
      if (responseData is Map<String, dynamic>) {
        final error = responseData['error'] as Map<String, dynamic>?;
        final serverMessage = error?['message'];
        errorCode = error?['code'] as String?;
        final serverDetails = error?['details'];
        if (serverDetails is List) {
          details = serverDetails;
        }
        if (serverMessage is String && serverMessage.isNotEmpty) {
          errorMessage = serverMessage;
          hasServerMessage = true;
        }
      }

      if (!hasServerMessage) {
        switch (statusCode) {
          case 400:
            errorMessage = 'Bad request';
          case 401:
            errorMessage = 'Unauthorized';
          case 403:
            errorMessage = 'Forbidden';
          case 404:
            errorMessage = 'Not found';
          case 500:
            errorMessage = 'Internal server error';
          default:
            errorMessage = 'Unexpected error: ${e.response?.statusMessage}';
        }
      }
    } else {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          errorMessage = 'Connection timed out. Please try again.';
        case DioExceptionType.connectionError:
          errorMessage =
              'No internet connection. Please check your network and try again.';
        case DioExceptionType.cancel:
          errorMessage = 'Request was cancelled.';
        case DioExceptionType.badCertificate:
        case DioExceptionType.badResponse:
        case DioExceptionType.unknown:
          errorMessage = 'Something went wrong. Please try again.';
      }
    }

    AppLogger.error('API Error: $errorMessage');
    return AppApiException(
      errorMessage,
      statusCode: statusCode,
      errorCode: errorCode,
      details: details,
    );
  }
}
