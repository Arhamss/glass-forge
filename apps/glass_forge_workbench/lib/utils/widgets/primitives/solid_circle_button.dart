import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/app_svg_icon.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/pressable_scale.dart';

/// A 40 pt solid disc in a 44 pt target, for tool screens where the specimen
/// must be the only glass on screen.
class SolidCircleButton extends StatelessWidget {
  const SolidCircleButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  static const double size = 40;
  static const double target = 44;

  final String icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onPressed,
      semanticLabel: semanticLabel,
      pressedScale: 0.92,
      child: SizedBox.square(
        dimension: target,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.hairlineStrong),
            ),
            alignment: Alignment.center,
            child: AppSvgIcon(icon, size: 20),
          ),
        ),
      ),
    );
  }
}
