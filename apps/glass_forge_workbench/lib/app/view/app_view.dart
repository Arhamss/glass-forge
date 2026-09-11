import 'package:glass_forge_workbench/app/view/app_theme.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';

class AppView extends StatelessWidget {
  const AppView({super.key});

  /// Light glyphs on transparent bars: every screen is dark and draws beneath
  /// both bars.
  static const _systemBars = SystemUiOverlayStyle(
    statusBarColor: AppColors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: AppRouter.router,
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        Localization.update(AppLocalizations.of(context));
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: _systemBars,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
