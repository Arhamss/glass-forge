import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/presentation/cubit/components_catalog_cubit.dart';
import 'package:glass_forge_workbench/features/components/presentation/cubit/components_catalog_state.dart';
import 'package:glass_forge_workbench/features/components/presentation/widgets/component_group.dart';
import 'package:glass_forge_workbench/features/components/presentation/widgets/components_header.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/layout/shell_insets.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/empty_state.dart';

/// Every glass component, grouped by family and searchable.
class ComponentsView extends StatelessWidget {
  const ComponentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ComponentsCatalogCubit(),
      child: Scaffold(
        backgroundColor: AppColors.ground,
        resizeToAvoidBottomInset: false,
        body: BlocBuilder<ComponentsCatalogCubit, ComponentsCatalogState>(
          buildWhen: (previous, current) => previous.query != current.query,
          builder: (context, state) {
            final groups = state.groups;
            final l10n = context.l10n;
            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: ComponentsHeader()),
                if (groups.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: EmptyState(
                        icon: AssetPaths.magnifyingGlass,
                        title: l10n.componentsEmptyTitle,
                        body: l10n.componentsEmptyBody,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.gutter,
                      AppSpacing.s16,
                      AppSpacing.gutter,
                      0,
                    ),
                    sliver: SliverList.separated(
                      itemCount: groups.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.s24),
                      itemBuilder: (context, index) => ComponentGroup(
                        family: groups[index].$1,
                        components: groups[index].$2,
                        onOpen: (component) => context.pushNamed(
                          AppRouteNames.playground,
                          pathParameters: {'component': component.name},
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(height: ShellInsets.bottomClearance(context)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
