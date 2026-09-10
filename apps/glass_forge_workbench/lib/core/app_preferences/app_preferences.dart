import 'package:glass_forge_workbench/core/app_preferences/base_storage.dart';
import 'package:glass_forge_workbench/utils/helpers/logger_helper.dart';

class AppPreferences extends BaseStorage {
  AppPreferences() {
    init('app-storage');
  }

  final String _authTokenKey = 'auth_token';
  final String _refreshTokenKey = 'refresh_token';
  final String _userIdKey = 'user_id';
  final String _appLocale = 'app_locale';

  /// App Locale
  Future<void> setAppLocale(String locale) async {
    await store<String>(_appLocale, locale);
  }

  String? getAppLocale() {
    return retrieve<String>(_appLocale);
  }

  void clearAppLocale() {
    remove(_appLocale);
  }

  /// Auth Tokens
  Future<void> setAuthToken(String token) async {
    await store<String>(_authTokenKey, token);
  }

  String? getAuthToken() {
    return retrieve<String>(_authTokenKey);
  }

  void removeAuthToken() {
    remove(_authTokenKey);
  }

  /// Refresh Tokens
  Future<void> setRefreshToken(String token) async {
    await store<String>(_refreshTokenKey, token);
  }

  String? getRefreshToken() {
    return retrieve<String>(_refreshTokenKey);
  }

  void removeRefreshToken() {
    remove(_refreshTokenKey);
  }

  /// User ID
  Future<void> setUserId(String userId) async {
    await store<String>(_userIdKey, userId);
  }

  String? getUserId() {
    return retrieve<String>(_userIdKey);
  }

  void removeUserId() {
    remove(_userIdKey);
  }

  /// Check if user is authenticated
  bool get isAuthenticated {
    final token = getAuthToken();
    return token != null && token.isNotEmpty;
  }

  /// Clear all auth data
  Future<void> clearAuthData() async {
    await remove(_authTokenKey);
    await remove(_refreshTokenKey);
    await remove(_userIdKey);
  }

  /// Clear all data
  Future<void> clearAll() {
    return removeAll();
  }

  /// Print a masked preview of the ID token (for debugging).
  ///
  /// Never logs the full bearer token — only a short prefix and suffix so it
  /// cannot be reused if it leaks into logs.
  void printIdToken() {
    final token = getAuthToken();
    if (token != null && token.isNotEmpty) {
      final masked = token.length <= 12
          ? '****'
          : '${token.substring(0, 6)}…${token.substring(token.length - 4)}';
      AppLogger.info('=== ID TOKEN (masked) ===');
      AppLogger.info(masked);
      AppLogger.info('=========================');
    } else {
      AppLogger.warning('No ID token found');
    }
  }
}
