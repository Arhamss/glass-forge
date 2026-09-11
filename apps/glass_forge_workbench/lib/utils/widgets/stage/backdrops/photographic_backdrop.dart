import 'dart:math' as math;

import 'package:glass_forge_workbench/exports.dart';

/// Proves glass reads correctly against realistic image content.
///
/// The other four backdrops are synthetic stress tests; this one stands in
/// for an actual photograph, since there's no bundled photo and no network
/// access in this environment. It needs genuine mid-frequency detail —
/// overlapping colour plus a noise field — because a flat gradient behind
/// the specimen would refract into nothing and prove nothing about how the
/// glass samples real content.
class PhotographicBackdrop extends StatelessWidget {
  /// Creates the backdrop.
  const PhotographicBackdrop({super.key});

  // Backdrop content, not UI chrome — deliberately outside AppColors, the
  // same way a photograph's pixels would be. Colours carry transparent
  // stops so each blob fades into the ground rather than showing a hard
  // gradient edge. One blob sits near the frame's centre with a tight
  // radius — where a specimen usually lands — so refraction always has a
  // real, high-contrast edge to bend rather than a smooth average.
  static const _blobs = [
    Alignment(-0.65, -0.75),
    Alignment(0.75, -0.35),
    Alignment(-0.05, -0.05),
    Alignment(0.55, 0.6),
    Alignment(-0.75, 0.65),
    Alignment(0.15, 0.95),
  ];
  static const _blobRadii = [0.9, 0.85, 0.45, 0.8, 0.85, 0.9];
  static const _blobColors = [
    Color(0xFF2E5AA8),
    Color(0xFFD9502B),
    Color(0xFF2E9E7A),
    Color(0xFFC9832E),
    Color(0xFF7A3EB1),
    Color(0xFFC23B6B),
  ];
  static const _blobTransparent = [
    Color(0x002E5AA8),
    Color(0x00D9502B),
    Color(0x002E9E7A),
    Color(0x00C9832E),
    Color(0x007A3EB1),
    Color(0x00C23B6B),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.stageGround,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < _blobs.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: _blobs[i],
                  radius: _blobRadii[i],
                  colors: [_blobColors[i], _blobTransparent[i]],
                ),
              ),
            ),
          const SizedBox.expand(
            child: CustomPaint(painter: PhotographicNoisePainter()),
          ),
        ],
      ),
    );
  }
}

/// Paints [PhotographicBackdrop]'s subtle noise field over the gradients.
class PhotographicNoisePainter extends CustomPainter {
  /// Creates the painter.
  const PhotographicNoisePainter();

  static const _grainCount = 2200;
  static const _seed = 7719;

  // Backdrop content, not UI chrome — see [PhotographicBackdrop]'s note.
  static const _grainLight = Color(0xFFFFFFFF);
  static const _grainDark = Color(0xFF000000);

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(_seed);
    final paint = Paint();
    for (var i = 0; i < _grainCount; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final isLight = random.nextBool();
      paint.color = (isLight ? _grainLight : _grainDark).withValues(
        alpha: 0.04 + random.nextDouble() * 0.04,
      );
      canvas.drawCircle(Offset(dx, dy), 0.6 + random.nextDouble(), paint);
    }
  }

  @override
  bool shouldRepaint(covariant PhotographicNoisePainter oldDelegate) => false;
}
