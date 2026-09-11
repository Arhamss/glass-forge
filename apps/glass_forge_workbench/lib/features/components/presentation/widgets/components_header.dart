import 'dart:ui';

import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/presentation/cubit/components_catalog_cubit.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/enums/component_id.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_search_bar.dart';

/// Title and search, over a blurred band of photograph that gives the
/// search bar's glass something to bend.
class ComponentsHeader extends StatelessWidget {
  const ComponentsHeader({super.key});

  static const double _bandHeight = 280;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _bandHeight,
          child: IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
                  child: Image.asset(
                    AssetPaths.photoNorthernLights,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.ground.withValues(alpha: 0.35),
                        AppColors.ground,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.gutter,
              AppSpacing.s24,
              AppSpacing.gutter,
              AppSpacing.s8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(l10n.componentsTitle, style: context.display),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  l10n.componentsSubtitle('${ComponentId.values.length}'),
                  style: context.body.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.s20),
                GlassSearchBar(
                  hint: l10n.componentsSearchHint,
                  clearLabel: l10n.clearSearch,
                  onChanged: context.read<ComponentsCatalogCubit>().setQuery,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
