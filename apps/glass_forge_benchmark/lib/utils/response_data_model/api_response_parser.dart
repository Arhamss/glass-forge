import 'package:dio/dio.dart';

class ApiResponseParser {
  ApiResponseParser._();

  static Map<String, dynamic>? _extractData(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final responseData = data['data'];
      if (responseData is Map<String, dynamic>) {
        return responseData;
      }
    }
    return null;
  }

  static T? parse<T>(
    Response<dynamic> response,
    T Function(Map<String, dynamic>) fromJson, {
    String? key,
  }) {
    final responseData = _extractData(response);
    if (responseData == null) return null;

    if (key != null) {
      final nested = responseData[key];
      if (nested is Map<String, dynamic>) return fromJson(nested);
      return null;
    }

    return fromJson(responseData);
  }

  static List<T> parseList<T>(
    Response<dynamic> response,
    T Function(Map<String, dynamic>) fromJson, {
    String? key,
  }) {
    final responseData = _extractData(response);

    List<dynamic>? list;

    if (key != null) {
      list = responseData?[key] as List<dynamic>?;
    } else {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final raw = data['data'];
        if (raw is List) list = raw;
      }
    }

    if (list == null) return [];

    return list
        .whereType<Map<String, dynamic>>()
        .map((e) {
          try {
            return fromJson(e);
          } catch (_) {
            return null;
          }
        })
        .whereType<T>()
        .toList();
  }

  static T? parseValue<T>(Response<dynamic> response, String key) {
    final responseData = _extractData(response);
    return responseData?[key] as T?;
  }
}
