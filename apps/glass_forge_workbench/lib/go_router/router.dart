part of 'exports.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static final router = GoRouter(
    initialLocation: AppRoutes.specimen,
    navigatorKey: _rootNavigatorKey,
    routes: [
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
}
