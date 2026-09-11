import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/helpers/tab_geometry.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/glass_rim_painter.dart';

/// The selector's painted capsule at one moment: where it is, and how much
/// its speed stretches it.
class GlassTabSelectorCapsule extends StatelessWidget {
  const GlassTabSelectorCapsule({
    required this.alignment,
    required this.velocity,
    required this.count,
    required this.squash,
    super.key,
  });

  final double alignment;
  final double velocity;
  final int count;
  final double squash;

  static const _capsule = StadiumBorder();

  @override
  Widget build(BuildContext context) {
    final scale = TabGeometry.squashScale(velocity, squash: squash);
    return FractionallySizedBox(
      widthFactor: 1 / count,
      alignment: AlignmentDirectional(alignment, 0),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(scale.dx, scale.dy, 1),
        child: const CustomPaint(
          foregroundPainter: GlassRimPainter(border: _capsule, strength: 1.6),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: _capsule,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.glassSheen, AppColors.glassRimFade],
              ),
            ),
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
