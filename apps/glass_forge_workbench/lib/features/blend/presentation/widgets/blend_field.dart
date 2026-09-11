import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';

/// Places the blend group's shapes around the middle of the stage.
///
/// Laid out rather than transformed: a real layout offset is what
/// `RenderGlassShape` registers with the group, so what the fold sees and
/// what the gap readout claims are the same geometry.
class BlendField extends StatelessWidget {
  /// Creates the field.
  const BlendField({
    required this.centres,
    required this.diameter,
    super.key,
  });

  /// Each shape's centre, relative to the middle of the field.
  final List<Offset> centres;

  /// How wide each shape is, in logical pixels.
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final radius = diameter / 2;
        final middleX = constraints.maxWidth / 2;
        final middleY = constraints.maxHeight / 2;
        return Stack(
          children: [
            for (final centre in centres)
              PositionedDirectional(
                start: middleX + centre.dx - radius,
                top: middleY + centre.dy - radius,
                width: diameter,
                height: diameter,
                child: const Glass(shape: GlassOval()),
              ),
          ],
        );
      },
    );
  }
}
