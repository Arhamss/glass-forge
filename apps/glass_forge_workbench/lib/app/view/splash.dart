import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:glass_forge_workbench/core/app_preferences/app_preferences.dart';
import 'package:glass_forge_workbench/core/di/injector.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/helpers/logger_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigate();
    });
  }

  void _navigate() {
    final authToken = Injector.resolve<AppPreferences>().getAuthToken();
    FlutterNativeSplash.remove();

    if ((authToken ?? '').isEmpty) {
      context.goNamed(AppRouteNames.loginScreen);
    } else {
      AppLogger.info('Auth token found');
      // No home route is wired in the generated app yet, so authenticated
      // users land on the login screen instead of a blank splash. Replace
      // this with your post-auth landing route once you add one (e.g.
      // context.goNamed(AppRouteNames.homeScreen)).
      // TODO(codeable): Point this at your real home/dashboard route.
      context.goNamed(AppRouteNames.loginScreen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
    );
  }
}
