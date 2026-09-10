import 'package:glass_forge_workbench/core/api_service/api_service.dart';
import 'package:glass_forge_workbench/features/onboarding/domain/repository/onboarding_repository.dart';
// TODO(codeable): Uncomment when you implement methods returning RepositoryResponse.
// import 'package:glass_forge_workbench/utils/helpers/repository_response.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  OnboardingRepositoryImpl({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  // ignore: unused_field — wired for DI; used once you add your first method.
  final ApiService _apiService;

  // EXAMPLE — wrap every call in execute<T>() so DioException / cancellation /
  // AppApiException are handled centrally. Do NOT hand-roll try/catch here.
  // Requires this import:
  //   import 'package:glass_forge_workbench/utils/response_data_model/api_response_parser.dart';
  //
  // Future<RepositoryResponse<bool>> login({
  //   required String email,
  //   required String password,
  // }) {
  //   return execute<bool>(() async {
  //     final response = await _apiService.post(
  //       endpoint: '/auth/login',
  //       data: {'email': email, 'password': password},
  //     );
  //     final token = ApiResponseParser.parseValue<String>(response, 'token');
  //     return token != null && token.isNotEmpty;
  //   });
  // }
}
