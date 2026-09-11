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
  // gradient edge.
  static const _blobs = [
    Alignment(-0.6, -0.7),
    Alignment(0.7, -0.2),
    Alignment(-0.2, 0.8),
    Alignment(0.9, 0.9),
  ];
  static const _blobColors = [
    Color(0xFF3B5A8C),
    Color(0xFF8C4A3B),
    Color(0xFF3B8C6E),
    Color(0xFF8C7A3B),
  ];
  static const _blobTransparent = [
    Color(0x003B5A8C),
    Color(0x008C4A3B),
    Color(0x003B8C6E),
    Color(0x008C7A3B),
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
                  radius: 1.2,
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
