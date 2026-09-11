part of 'exports.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static BuildContext? get appContext =>
      _rootNavigatorKey.currentState?.context;

  static final router = GoRouter(
    initialLocation: AppRoutes.motion,
    debugLogDiagnostics: true,
    navigatorKey: _rootNavigatorKey,
    redirect: (context, state) {
      final isAuthenticated =
          Injector.resolve<AppPreferences>().isAuthenticated;

      // The workbench has nothing behind a login. Every section is public;
      // the auth scaffolding stays because the app template ships with it.
      const publicRoutes = <String>[
        AppRoutes.splash,
        AppRoutes.loginScreen,
        AppRoutes.gallery,
        AppRoutes.specimen,
        AppRoutes.blend,
        AppRoutes.tiers,
        AppRoutes.motion,
        AppRoutes.samplingProbe,
      ];

      final location = state.matchedLocation;
      final isPublicRoute = publicRoutes.contains(location);

      if (!isAuthenticated && !isPublicRoute) {
        return AppRoutes.loginScreen;
      }

      return null;
    },
    routes: [
      GoRoute(
        name: AppRouteNames.splash,
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        name: AppRouteNames.loginScreen,
        path: AppRoutes.loginScreen,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        name: AppRouteNames.samplingProbe,
        path: AppRoutes.samplingProbe,
        builder: (context, state) => const SamplingProbeView(),
      ),
      // Branch order is WorkbenchSection's declaration order — the rail
      // maps a tab to a branch by enum index.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => WorkbenchShell(shell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.gallery,
                path: AppRoutes.gallery,
                builder: (context, state) => const GalleryView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.specimen,
                path: AppRoutes.specimen,
                builder: (context, state) => const SpecimenView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.blend,
                path: AppRoutes.blend,
                builder: (context, state) => const BlendView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.tiers,
                path: AppRoutes.tiers,
                builder: (context, state) => const TiersView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.motion,
                path: AppRoutes.motion,
                builder: (context, state) => const MotionView(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  static String getCurrentLocation() {
    final lastMatch = router.routerDelegate.currentConfiguration.last;
    return lastMatch.matchedLocation;
  }

  static bool isCurrentRoute(String routeName) {
    return getCurrentLocation() == routeName;
  }
}
