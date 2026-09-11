import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/buttons/glass_button.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_circle_button.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';

/// The house material worn by three real components at once: a card, a
/// button and a circle.
class StudioComposition extends StatelessWidget {
  const StudioComposition({super.key});

  static const double _width = 300;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      width: _width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KitGlassLayer(
            priority: GlassPriority.content,
            shape: const GlassSuperellipse(
              radius: BorderRadius.all(Radius.circular(28)),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.demoCardTitle, style: context.title),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    l10n.demoCardBody,
                    style: context.calloutRegular.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Row(
            children: [
              Expanded(
                child: GlassButton.secondary(
                  label: l10n.demoContinue,
                  expand: true,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              GlassCircleButton(
                icon: AssetPaths.heart,
                semanticLabel: l10n.optionHeart,
                priority: GlassPriority.content,
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}
