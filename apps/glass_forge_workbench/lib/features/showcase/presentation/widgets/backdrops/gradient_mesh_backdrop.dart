import 'package:glass_forge_workbench/exports.dart';

/// Proves how the glass tints and saturates against smooth colour, with no
/// texture to distract from it.
///
/// The photographic and stripe backdrops are about geometry and sampling;
/// this one removes texture and noise entirely so a smooth field of
/// overlapping hues is the only thing left to read — the cleanest way to
/// see whether the specimen's tint sits right and whether saturation
/// blows out under refraction.
class GradientMeshBackdrop extends StatelessWidget {
  /// Creates the backdrop.
  const GradientMeshBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.stageGround,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.8, -0.9),
                radius: 1.4,
                colors: [Color(0xFF2DD4BF), Color(0x002DD4BF)],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.9, -0.6),
                radius: 1.3,
                colors: [Color(0xFFF97316), Color(0x00F97316)],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.4, 1),
                radius: 1.5,
                colors: [Color(0xFFE11D48), Color(0x00E11D48)],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.9, 0.8),
                radius: 1.2,
                colors: [Color(0xFF6366F1), Color(0x006366F1)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
