import 'package:dio/dio.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:glass_forge_workbench/core/app_preferences/app_preferences.dart';
import 'package:glass_forge_workbench/core/endpoints/endpoints.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/helpers/logger_helper.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._appPreferences, this._dio);

  final AppPreferences _appPreferences;
  final Dio _dio;
  bool _isRefreshing = false;
  bool _hasLoggedToken = false;
  bool _isLogoutInFlight = false;
  Future<String?>? _refreshTokenFuture;

  /// Endpoints that must never trigger a refresh. A 401 from any of these
  /// means the supplied credentials are wrong — not that the access token
  /// expired — so refreshing would either loop or force-logout a user who is
  /// simply typing the wrong password.
  ///
  /// Add every unauthenticated endpoint here as you build out auth
  /// (signup, forgot-password, verify-otp, reset-password, ...).
  static const _authEndpoints = [
    Endpoints.login,
    Endpoints.googleAuth,
    Endpoints.refresh,
  ];

  bool _isAuthEndpoint(String path) => _authEndpoints.any(path.endsWith);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = _appPreferences.getAuthToken();

    if (token != null) {
      if (!_hasLoggedToken) {
        _hasLoggedToken = true;
        AppLogger.authToken(token);
      }
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 &&
        !_isAuthEndpoint(err.requestOptions.path)) {
      // Prevent a refresh storm: if this request was already retried after a
      // refresh and still got a 401, give up instead of looping.
      if (err.requestOptions.extra['retried'] == true) {
        handler.next(err);
        return;
      }

      final newToken = await _handleTokenRefresh();

      if (newToken != null) {
        err.requestOptions.extra['retried'] = true;
        err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
        final retryResponse = await _dio.fetch<dynamic>(err.requestOptions);
        return handler.resolve(retryResponse);
      }
    }

    return handler.next(err);
  }

  /// Coalesces concurrent 401s onto a single refresh call so N in-flight
  /// requests trigger one network round-trip, not N.
  Future<String?> _handleTokenRefresh() async {
    if (_isRefreshing) {
      return _refreshTokenFuture;
    }

    _isRefreshing = true;
    _refreshTokenFuture = _refreshToken();

    try {
      return await _refreshTokenFuture;
    } finally {
      _isRefreshing = false;
      _refreshTokenFuture = null;
    }
  }

  Future<String?> _refreshToken() async {
    try {
      final refreshToken = _appPreferences.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _forceLogout();
        return null;
      }

      final response = await _dio.post<dynamic>(
        Endpoints.refresh,
        data: {'refresh_token': refreshToken},
      );

      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        await _forceLogout();
        return null;
      }

      final responseData = response.data;
      final data = responseData is Map<String, dynamic>
          ? responseData['data'] as Map<String, dynamic>?
          : null;
      final newToken = data?['access_token'] as String?;

      if (newToken == null || newToken.isEmpty) {
        await _forceLogout();
        return null;
      }

      await _appPreferences.setAuthToken(newToken);

      // Most backends rotate refresh tokens: each refresh returns a new one
      // and invalidates the previous. Persist it, otherwise the next refresh
      // replays a revoked token and the whole family gets revoked server-side.
      final rotatedRefreshToken = data?['refresh_token'] as String?;
      if (rotatedRefreshToken != null && rotatedRefreshToken.isNotEmpty) {
        await _appPreferences.setRefreshToken(rotatedRefreshToken);
      }

      _hasLoggedToken = false;
      return newToken;
    } catch (e, s) {
      AppLogger.error('Token refresh failed', e, s);
      await _forceLogout();
      return null;
    }
  }

  /// Clears the session and sends the user back to splash. Guarded so a burst
  /// of failing requests can't fire multiple logouts / rebirths.
  Future<void> _forceLogout() async {
    if (_isLogoutInFlight) return;
    _isLogoutInFlight = true;
    AppLogger.warning(
      'AuthInterceptor: forcing logout (invalid/expired token)',
    );
    await _appPreferences.clearAuthData();
    _hasLoggedToken = false;
    _navigateToSplash();
  }

  void _navigateToSplash() {
    // Defer to the next frame so we don't tear down the widget tree in the
    // middle of error handling. The GoRouter instance is static and survives
    // a Phoenix rebirth, so its location must be reset explicitly — otherwise
    // the rebuilt tree resumes on the previous (now unauthorised) route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = AppRouter.appContext;
      if (context == null) {
        AppLogger.error(
          'AuthInterceptor: could not navigate — appContext is null',
        );
        _isLogoutInFlight = false;
        return;
      }
      AppRouter.router.go(AppRoutes.splash);
      Phoenix.rebirth(context);
      _isLogoutInFlight = false;
    });
  }
}
