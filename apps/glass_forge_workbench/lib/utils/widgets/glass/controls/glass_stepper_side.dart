import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/app_svg_icon.dart';

/// One end of a `GlassStepper`: tap to step once, hold to keep stepping.
class GlassStepperSide extends StatelessWidget {
  const GlassStepperSide({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onStep,
    required this.onHoldStart,
    required this.onHoldEnd,
    super.key,
  });

  final String icon;
  final String label;
  final bool enabled;
  final VoidCallback onStep;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? onStep : null,
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onStep : null,
        onLongPressStart: enabled ? (_) => onHoldStart() : null,
        onLongPressEnd: (_) => onHoldEnd(),
        onLongPressCancel: onHoldEnd,
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: AppSvgIcon(
              icon,
              size: 18,
              color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
