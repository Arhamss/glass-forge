import 'package:get_it/get_it.dart';
import 'package:glass_forge_benchmark/core/app_preferences/app_preferences.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Benchmark harness DI.
///
/// Deliberately minimal. Every service initialised before `runApp` shows up in
/// the first frames we are trying to measure, so this registers only what the
/// harness itself needs: a preferences store for run configuration.
///
/// Do not add networking, sockets, notifications, permissions or Firebase
/// here. If a benchmark scenario needs one of those, it belongs in that
/// scenario's setup, after measurement has started, not in bootstrap.
abstract class AppModule {
  static late final GetIt _container;

  static Future<void> setup(GetIt container) async {
    _container = container;
    await _setupHive();
    await _setupAppPreferences();
  }

  static Future<void> _setupHive() async {
    await Hive.initFlutter();
  }

  static Future<void> _setupAppPreferences() async {
    final appPreferences = AppPreferences();
    await appPreferences.init('benchmark-storage');
    _container.registerSingleton<AppPreferences>(appPreferences);
  }
}
