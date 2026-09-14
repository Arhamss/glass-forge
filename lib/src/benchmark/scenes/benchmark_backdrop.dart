import 'package:flutter/widgets.dart';

/// Keeps frames flowing for as long as a benchmark measurement window needs,
/// and gives the backdrop behind it something to change every frame.
///
/// A static glass scene stops producing frames once the first one lands --
/// Flutter does not re-render unless something asks it to -- so a
/// measurement window over a motionless scene would be one real frame
/// followed by silence, and `FrameTimeRecorder.summarize` would report
/// percentiles computed from a single sample. This repeats a one-second
/// `AnimationController` forever and paints a deterministic moving pattern
/// from its value, so every scene keeps rasterising for as long as the
/// runner samples it, and two runs of the same scene animate identically --
/// nothing here reads the wall clock or a random seed.
///
/// The animation drives backdrop *content*, never a glass shape's own
/// geometry. Moving the shape itself would conflate "cost of refraction"
/// with "cost of re-registering geometry every frame", which is a different
/// question -- `BenchmarkAxis.shapeCount` answers that one instead, by
/// varying shape count with the backdrop held to this same animation.
class AnimatedBenchmarkBackdrop extends StatefulWidget {
  /// Creates a backdrop of [size] behind [child].
  const AnimatedBenchmarkBackdrop({
    required this.size,
    required this.child,
    super.key,
  });

  /// The backdrop's fixed size, in logical pixels.
  final Size size;

  /// The glass content painted above the animated backdrop.
  final Widget child;

  @override
  State<AnimatedBenchmarkBackdrop> createState() =>
      _AnimatedBenchmarkBackdropState();
}

class _AnimatedBenchmarkBackdropState extends State<AnimatedBenchmarkBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) =>
                CustomPaint(painter: _SweepPainter(_controller.value)),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Paints a deterministic diagonal gradient sweep, phased by [t] in 0..1.
///
/// Deliberately not the sampling probe's 1-physical-pixel checkerboard
/// (`docs/reference/backdrop_sampling.md`) -- that pattern is designed to
/// alias to flat grey at anything but 1:1 pixel inspection, which is right
/// for a visual-artefact probe and wrong here. This backdrop only has to
/// give the raster thread real, changing pixels to blur and sample every
/// frame; it does not need to survive visual inspection.
class _SweepPainter extends CustomPainter {
  const _SweepPainter(this.t);

  final double t;

  static const List<Color> _colors = <Color>[
    Color(0xFF1B2735),
    Color(0xFF6B8CFF),
    Color(0xFFE84C88),
    Color(0xFF1B2735),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      colors: _colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      transform: _SlideGradient(t * size.width),
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(covariant _SweepPainter oldDelegate) => oldDelegate.t != t;
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);

  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}
