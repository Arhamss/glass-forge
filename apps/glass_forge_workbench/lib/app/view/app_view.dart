import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glass_forge_workbench/constants/app_colors.dart';
import 'package:glass_forge_workbench/core/locale/cubit/locale_cubit.dart';
import 'package:glass_forge_workbench/go_router/exports.dart';
import 'package:glass_forge_workbench/l10n/gen/app_localizations.dart';
import 'package:glass_forge_workbench/l10n/localization_service.dart';
import 'package:toastification/toastification.dart';

class AppView extends StatefulWidget {
  const AppView({super.key});

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
  /// Android 15 (SDK 35) enforces edge-to-edge by default and ignores the
  /// system bar insets we used to rely on. Wrapping the app in [SafeArea]
  /// only on those builds preserves layout on older Android, iOS, and
  /// emulators while preventing content from being drawn under status/nav
  /// bars on Android 15+.
  bool _applySafeArea = false;

  @override
  void initState() {
    super.initState();
    _checkSafeArea();
  }

  Future<void> _checkSafeArea() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 35 && mounted) {
        setState(() => _applySafeArea = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, LocaleState>(
      buildWhen: (previous, current) => previous.locale != current.locale,
      builder: (context, state) {
        return ToastificationWrapper(
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
            child: MaterialApp.router(
              routerConfig: AppRouter.router,
              theme: ThemeData(
                appBarTheme: const AppBarTheme(
                  systemOverlayStyle: SystemUiOverlayStyle.light,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                ),
                scaffoldBackgroundColor: AppColors.background,
                canvasColor: AppColors.background,
                useMaterial3: true,
                pageTransitionsTheme: const PageTransitionsTheme(
                  builders: <TargetPlatform, PageTransitionsBuilder>{
                    TargetPlatform.android:
                        FadeForwardsPageTransitionsBuilder(
                          backgroundColor: Colors.transparent,
                        ),
                  },
                ),
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: AppColors.primary,
                  selectionColor:
                      AppColors.primary.withValues(alpha: 0.25),
                  selectionHandleColor: AppColors.primary,
                ),
              ),
              locale: DevicePreview.locale(context) ?? state.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              debugShowCheckedModeBanner: false,
              builder: (context, child) {
                Localization.update(AppLocalizations.of(context));
                final wrappedChild = DevicePreview.appBuilder(context, child);
                if (_applySafeArea) {
                  return SafeArea(child: wrappedChild);
                }
                return wrappedChild;
              },
            ),
          ),
        );
      },
    );
  }
}
