import 'package:dio/dio.dart';
import 'package:glass_forge_workbench/core/api_service/app_api_exception.dart';
import 'package:glass_forge_workbench/l10n/localization_service.dart';
import 'package:glass_forge_workbench/utils/helpers/logger_helper.dart';

class RepositoryResponse<T> {
  RepositoryResponse({
    required this.isSuccess,
    this.data,
    this.message,
    this.details,
    this.isCancelled = false,
  });

  final bool isSuccess;
  final T? data;
  final String? message;
  final List<dynamic>? details;
  final bool isCancelled;
}

Future<RepositoryResponse<T>> execute<T>(
  Future<T> Function() action,
) async {
  try {
    final data = await action();
    return RepositoryResponse(isSuccess: true, data: data);
  } on DioException catch (e, s) {
    if (e.type == DioExceptionType.cancel) {
      return RepositoryResponse(isSuccess: false, isCancelled: true);
    }
    AppLogger.error('Dio error', e, s);
    return RepositoryResponse(
      isSuccess: false,
      message: extractApiErrorMessage(e, Localization.somethingWentWrong),
    );
  } on AppApiException catch (e) {
    return RepositoryResponse(
      isSuccess: false,
      message: e.message,
      details: e.details,
    );
  } catch (e, s) {
    AppLogger.error('Unexpected error', e, s);
    return RepositoryResponse(
      isSuccess: false,
      message: Localization.somethingWentWrong,
    );
  }
}
