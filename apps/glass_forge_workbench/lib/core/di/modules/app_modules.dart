import 'package:get_it/get_it.dart';
import 'package:glass_forge_workbench/core/api_service/api_service.dart';
import 'package:glass_forge_workbench/core/app_preferences/app_preferences.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Workbench DI.
///
/// The workbench is an offline visual tool: it renders local scenes and has no
/// backend. Sockets, notifications, permissions and Firebase are removed from
/// the standard template rather than left registered and unused.
abstract class AppModule {
  static late final GetIt _container;

  static Future<void> setup(GetIt container) async {
    _container = container;
    await _setupHive();
    await _setupAppPreferences();
    await _setupAPIService();
  }

  static Future<void> _setupHive() async {
    await Hive.initFlutter();
  }

  static Future<void> _setupAppPreferences() async {
    final appPreferences = AppPreferences();
    await appPreferences.init('workbench-storage');
    _container.registerSingleton<AppPreferences>(appPreferences);
  }

  static Future<void> _setupAPIService() async {
    final apiService = ApiService();
    _container.registerSingleton<ApiService>(apiService);
  }
}
