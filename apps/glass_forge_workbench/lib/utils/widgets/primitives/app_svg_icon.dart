import 'package:flutter_svg/flutter_svg.dart';
import 'package:glass_forge_workbench/exports.dart';

/// The one way an icon reaches the screen: a bundled Phosphor SVG, tinted.
class AppSvgIcon extends StatelessWidget {
  const AppSvgIcon(
    this.asset, {
    this.size = 24,
    this.color = AppColors.textPrimary,
    this.semanticLabel,
    super.key,
  });

  final String asset;
  final double size;
  final Color color;

  /// Only for an icon that carries meaning on its own. An icon beside a label
  /// stays silent, or a screen reader says everything twice.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
