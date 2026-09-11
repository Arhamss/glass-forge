part of 'exports.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static final router = GoRouter(
    initialLocation: AppRoutes.showcase,
    navigatorKey: _rootNavigatorKey,
    routes: [
      // Branch order is WorkbenchTab's declaration order: the tab bar maps a
      // tab to its branch by index.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => WorkbenchShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.showcase,
                path: AppRoutes.showcase,
                builder: (context, state) => const ShowcaseView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.components,
                path: AppRoutes.components,
                builder: (context, state) => const ComponentsView(),
                routes: [
                  GoRoute(
                    name: AppRouteNames.playground,
                    path: AppRoutes.playground,
                    parentNavigatorKey: _rootNavigatorKey,
                    redirect: (context, state) =>
                        ComponentId.values.asNameMap().containsKey(
                          state.pathParameters['component'],
                        )
                        ? null
                        : AppRoutes.components,
                    builder: (context, state) => PlaygroundView(
                      component: ComponentId.values.byName(
                        state.pathParameters['component']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.material,
                path: AppRoutes.material,
                builder: (context, state) => const MaterialStudioView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.lab,
                path: AppRoutes.lab,
                builder: (context, state) => const LabView(),
                routes: [
                  GoRoute(
                    name: AppRouteNames.labTiers,
                    path: AppRoutes.labTiers,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => LabToolFrame(
                      title: LabTool.tiers.title,
                      child: const TiersView(),
                    ),
                  ),
                  GoRoute(
                    name: AppRouteNames.labBlend,
                    path: AppRoutes.labBlend,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => LabToolFrame(
                      title: LabTool.blend.title,
                      child: const BlendView(),
                    ),
                  ),
                  GoRoute(
                    name: AppRouteNames.labMotion,
                    path: AppRoutes.labMotion,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => LabToolFrame(
                      title: LabTool.motion.title,
                      child: const MotionView(),
                    ),
                  ),
                  GoRoute(
                    name: AppRouteNames.labSurfaces,
                    path: AppRoutes.labSurfaces,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => LabToolFrame(
                      title: LabTool.surfaces.title,
                      child: const GalleryView(),
                    ),
                  ),
                  GoRoute(
                    name: AppRouteNames.labSamplingProbe,
                    path: AppRoutes.labSamplingProbe,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const SamplingProbeView(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
