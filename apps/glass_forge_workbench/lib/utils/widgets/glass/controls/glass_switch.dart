import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/helpers/haptic_helper.dart';
import 'package:glass_forge_workbench/utils/helpers/reduce_motion.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';

/// A glass knob riding a painted track. The knob is a lens: it bends the
/// track's edge and the accent fill beneath it as it slides.
class GlassSwitch extends StatelessWidget {
  const GlassSwitch({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.material,
    super.key,
  });

  static const double width = 56;
  static const double height = 34;
  static const double _knob = 28;
  static const double _inset = 3;

  final bool value;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  /// Null uses the house material.
  final GlassMaterial? material;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final duration = context.reduceMotion ? Duration.zero : AppMotion.select;
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      label: semanticLabel,
      onTap: onChanged == null ? null : () => onChanged(!value),
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null
            ? null
            : () {
                AppHaptics.toggle();
                onChanged(!value);
              },
        child: SizedBox(
          // The drawn switch is 34 pt tall; the target is not.
          width: width,
          height: 44,
          child: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: duration,
                      curve: AppMotion.selectCurve,
                      decoration: BoxDecoration(
                        color: value
                            ? AppColors.accent
                            : AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(height / 2),
                        border: Border.all(
                          color: value
                              ? AppColors.accent
                              : AppColors.hairlineStrong,
                        ),
                      ),
                    ),
                  ),
                  AnimatedAlign(
                    duration: duration,
                    curve: Curves.easeOutBack,
                    alignment: value
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(_inset),
                      child: SizedBox.square(
                        dimension: _knob,
                        child: KitGlassLayer(
                          priority: GlassPriority.content,
                          material: material,
                          insetTint: AppColors.white,
                          shape: const GlassOval(),
                          child: const SizedBox.expand(),
                        ),
                      ),
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
