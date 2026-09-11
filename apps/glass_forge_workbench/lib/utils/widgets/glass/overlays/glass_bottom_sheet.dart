import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/helpers/reduce_motion.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/house_glass.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';

/// Shows [builder]'s content on a floating glass sheet over the whole app.
///
/// Drag it down, or tap the dimmed app behind it, to dismiss.
Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    // Keeps a tall sheet, pushed up by the keyboard, clear of the status bar
    // and of a landscape notch.
    useSafeArea: true,
    backgroundColor: AppColors.transparent,
    elevation: 0,
    barrierColor: AppColors.black.withValues(alpha: 0.35),
    sheetAnimationStyle: context.reduceMotion
        ? AnimationStyle.noAnimation
        : null,
    builder: (context) => GlassBottomSheet(child: builder(context)),
  );
}

/// A glass sheet that floats off the screen's sides and bottom, so all four
/// corners are rounded.
///
/// Its content scrolls once it would pass 85% of the screen's height.
class GlassBottomSheet extends StatelessWidget {
  const GlassBottomSheet({required this.child, super.key});

  final Widget child;

  static const double _radius = 32;
  static const double _maxHeightFactor = 0.85;
  static const double _grabberWidth = 36;
  static const double _grabberHeight = 5;

  static const _shape = GlassSuperellipse(
    radius: BorderRadius.all(Radius.circular(_radius)),
  );

  @override
  Widget build(BuildContext context) {
    // With the keyboard up the safe-area padding reads zero, so the sheet
    // sits on the keyboard instead of adding the home indicator's gap too.
    final bottom =
        MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.paddingOf(context).bottom +
        AppSpacing.s8;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: AppSpacing.s8,
        end: AppSpacing.s8,
        bottom: bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * _maxHeightFactor,
        ),
        child: DecoratedBox(
          // Painted before the glass, so the glass bends it too and the
          // sheet reads as lifted off the dimmed app.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: const [
              BoxShadow(
                color: AppColors.glassShadow,
                blurRadius: 32,
                offset: Offset(0, 12),
                spreadRadius: -8,
              ),
            ],
          ),
          child: KitGlassLayer(
            priority: GlassPriority.overlay,
            material: HouseGlass.overlayOf(context),
            shape: _shape,
            child: ColoredBox(
              color: AppColors.glassMessageScrim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsetsDirectional.only(top: AppSpacing.s8),
                    child: Center(
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          shape: StadiumBorder(),
                          color: AppColors.hairlineStrong,
                        ),
                        child: SizedBox(
                          width: _grabberWidth,
                          height: _grabberHeight,
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.s20,
                        AppSpacing.s16,
                        AppSpacing.s20,
                        AppSpacing.s20,
                      ),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
