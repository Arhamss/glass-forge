part of 'exports.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static BuildContext? get appContext =>
      _rootNavigatorKey.currentState?.context;

  static final router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    navigatorKey: _rootNavigatorKey,
    redirect: (context, state) {
      final isAuthenticated =
          Injector.resolve<AppPreferences>().isAuthenticated;

      // Routes that an unauthenticated user is allowed to view.
      // TODO(codeable): Add your own onboarding/auth routes (e.g. signup, forgot
      // password) to this list as you create them.
      const publicRoutes = <String>[
        AppRoutes.splash,
        AppRoutes.loginScreen,
      ];

      final location = state.matchedLocation;
      final isPublicRoute = publicRoutes.contains(location);

      // Not authenticated and trying to reach a protected route -> login.
      if (!isAuthenticated && !isPublicRoute) {
        return AppRoutes.loginScreen;
      }

      // Authenticated user landing on splash/login has no home route wired
      // yet, so allow splash to decide (see SplashScreen._navigate).
      // TODO(codeable): Once a post-auth home route exists, redirect authenticated
      // users away from splash/login to it here.

      // No redirect needed.
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
      // TODO(codeable): Add more routes here

      // TODO(codeable): Uncomment the StatefulShellRoute below when you are ready
      // to add bottom-tab navigation. Update the branches with your
      // actual screens and import AppNavigation in exports.dart.
      // Also uncomment the matching homeScreen/searchScreen/profileScreen
      // constants in AppRoutes and AppRouteNames below — they are
      // referenced here but defined ~50 lines down in this same file.
      //
      // StatefulShellRoute.indexedStack(
      //   branches: <StatefulShellBranch>[
      //     StatefulShellBranch(
      //       routes: [
      //         GoRoute(
      //           path: AppRoutes.homeScreen,
      //           name: AppRouteNames.homeScreen,
      //           builder: (context, state) => const Placeholder(), // TODO(codeable): Replace with HomeScreen()
      //         ),
      //       ],
      //     ),
      //     StatefulShellBranch(
      //       routes: [
      //         GoRoute(
      //           path: AppRoutes.searchScreen,
      //           name: AppRouteNames.searchScreen,
      //           builder: (context, state) => const Placeholder(), // TODO(codeable): Replace with SearchScreen()
      //         ),
      //       ],
      //     ),
      //     StatefulShellBranch(
      //       routes: [
      //         GoRoute(
      //           path: AppRoutes.profileScreen,
      //           name: AppRouteNames.profileScreen,
      //           builder: (context, state) => const Placeholder(), // TODO(codeable): Replace with ProfileScreen()
      //         ),
      //       ],
      //     ),
      //   ],
      //   builder: (context, state, shell) {
      //     return AppNavigation(shell: shell);
      //   },
      // ),
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
