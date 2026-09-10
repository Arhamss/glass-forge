import 'package:glass_forge_workbench/config/env/app_env.dart';

class Endpoints {
  Endpoints._();

  static String get baseUrl => AppEnv.baseUrl;

  static String get apiVersion => AppEnv.apiVersion;

  /// Authentication
  static const refresh = 'auth/refresh';
  static const login = 'auth/login';
  static const logout = 'auth/logout';
  static const googleAuth = 'auth/google';

  /// Profile
  static const profile = 'users/profile';
}
