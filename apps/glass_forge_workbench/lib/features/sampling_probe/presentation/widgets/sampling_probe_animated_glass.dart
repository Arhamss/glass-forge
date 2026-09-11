import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';

/// The one glass shape under test, drifting slowly left-to-right and back.
///
/// Slow, continuous motion is deliberate: texel snapping shows up as a
/// stepping shimmer in the refracted backdrop as the shape crosses texel
/// boundaries, which a fast sweep would blur past and a static shape would
/// never trigger at all.
///
/// Positioned inside a `Stack`, not `Align`ed — `Glass` registers its
/// geometry with the enclosing `GlassLayer` from `performLayout`, and only
/// `Positioned`'s left/top changing actually triggers a new layout pass each
/// frame. `Align` only repositions at paint time, which leaves the
/// registered geometry frozen at the shape's very first frame forever.
class SamplingProbeAnimatedGlass extends StatefulWidget {
  /// Creates the animated glass shape.
  const SamplingProbeAnimatedGlass({super.key});

  @override
  State<SamplingProbeAnimatedGlass> createState() =>
      _SamplingProbeAnimatedGlassState();
}

class _SamplingProbeAnimatedGlassState extends State<SamplingProbeAnimatedGlass>
    with SingleTickerProviderStateMixin {
  static const _shapeExtent = 180.0;
  static const _sweepDuration = Duration(seconds: 7);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _sweepDuration,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final travel = (constraints.maxWidth - _shapeExtent).clamp(
          0.0,
          double.infinity,
        );
        final top = (constraints.maxHeight - _shapeExtent) / 2;
        return Stack(
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = Curves.easeInOutSine.transform(_controller.value);
                return Positioned(
                  left: travel * t,
                  top: top,
                  width: _shapeExtent,
                  height: _shapeExtent,
                  child: child!,
                );
              },
              child: const Glass(
                shape: GlassRoundedRectangle(
                  radius: BorderRadius.all(Radius.circular(32)),
                ),
                child: SizedBox(width: _shapeExtent, height: _shapeExtent),
              ),
            ),
          ],
        );
      },
    );
  }
}
