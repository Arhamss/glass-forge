import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/pressable_scale.dart';

/// A photograph with a glass caption floating over its lower edge, and an
/// optional glass chip in the top corner.
///
/// Only the photo is clipped. The glass sits beside it in the stack, never
/// under a clip, because a backdrop filter under a clip layer is one of the
/// arrangements that collapses to white on device.
class GlassMediaCard extends StatelessWidget {
  const GlassMediaCard({
    required this.image,
    required this.title,
    required this.subtitle,
    this.chip,
    this.trailing,
    this.onTap,
    this.aspectRatio = 4 / 5,
    super.key,
  });

  static const double _radius = 28;
  static const double _captionInset = AppSpacing.s8;

  /// An asset path.
  final String image;
  final String title;
  final String subtitle;

  /// A short reading for the top corner, such as a temperature.
  final String? chip;

  /// Usually a `GlassCircleButton`, drawn as an inset on the caption.
  final Widget? trailing;
  final VoidCallback? onTap;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final chip = this.chip;
    final trailing = this.trailing;
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.98,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(_radius),
              child: Image.asset(
                image,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                frameBuilder: (context, child, frame, wasSynchronous) =>
                    AnimatedOpacity(
                      opacity: wasSynchronous || frame != null ? 1 : 0,
                      duration: AppMotion.select,
                      child: child,
                    ),
              ),
            ),
            if (chip != null)
              PositionedDirectional(
                top: AppSpacing.s12,
                end: AppSpacing.s12,
                child: KitGlassLayer(
                  priority: GlassPriority.content,
                  shape: const GlassSuperellipse(
                    radius: BorderRadius.all(Radius.circular(14)),
                  ),
                  child: ColoredBox(
                    color: AppColors.glassChromeScrim,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: 6,
                      ),
                      child: Text(chip, style: context.monoSmall),
                    ),
                  ),
                ),
              ),
            PositionedDirectional(
              start: _captionInset,
              end: _captionInset,
              bottom: _captionInset,
              child: KitGlassLayer(
                priority: GlassPriority.content,
                shape: const GlassSuperellipse(
                  radius: BorderRadius.all(
                    Radius.circular(_radius - _captionInset),
                  ),
                ),
                child: ColoredBox(
                  color: AppColors.glassChromeScrim,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.s16,
                      AppSpacing.s12,
                      AppSpacing.s8,
                      AppSpacing.s12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.title,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.monoSmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (trailing != null) trailing,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
