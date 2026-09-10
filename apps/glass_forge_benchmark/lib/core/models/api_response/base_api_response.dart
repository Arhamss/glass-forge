import 'package:glass_forge_benchmark/core/models/api_response/api_error.dart';

class BaseApiResponse<T> {
  BaseApiResponse({
    required this.statusCode,
    this.error,
    this.data,
  });

  factory BaseApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parser,
  ) {
    final statusCode = (json['statusCode'] as num?)?.toInt() ?? 0;
    final errorJson = json['error'] as Map<String, dynamic>?;
    final error = errorJson != null ? ApiError.fromJson(errorJson) : null;

    T? parsedData;
    final dataJson = json['data'] as Map<String, dynamic>?;
    if (dataJson != null && error == null) {
      parsedData = parser(dataJson);
    }

    return BaseApiResponse<T>(
      statusCode: statusCode,
      error: error,
      data: parsedData,
    );
  }

  final int statusCode;
  final ApiError? error;
  final T? data;

  bool get hasError => error != null;
}
