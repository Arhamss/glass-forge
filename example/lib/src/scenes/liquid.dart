import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/playground.dart';
import 'package:glass_forge_example/src/ui.dart';

/// Drops that orbit a bigger one and melt into it on each pass.
///
/// All four shapes are in one `GlassBlendGroup`, so where they come close
/// their distance fields smooth-min into a single surface instead of
/// overlapping. The blend width is the tuner's "Blend" slider. The middle
/// drop can be dragged, and springs home.
class LiquidScene extends StatefulWidget {
  const LiquidScene({super.key});

  @override
  State<LiquidScene> createState() => _LiquidSceneState();
}

class _LiquidSceneState extends State<LiquidScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _orbit
        ..stop()
        ..value = 0.18;
    } else if (!_orbit.isAnimating) {
      _orbit.repeat();
    }
  }

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blend = PlaygroundScope.of(context).blend;
    return SizedBox(
      width: 320,
      height: 320,
      child: GlassBlendGroup(
        blend: blend,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _Satellite(orbit: _orbit, size: 74, turns: 1, phase: 0, reach: 112),
            _Satellite(
              orbit: _orbit,
              size: 52,
              turns: -2,
              phase: 2.1,
              reach: 96,
            ),
            _Satellite(
              orbit: _orbit,
              size: 40,
              turns: 3,
              phase: 4.2,
              reach: 124,
            ),
            const Arrive(
              scale: 0.2,
              child: InteractiveGlass(
                drag: GlassDrag(overdrag: GlassOverdrag.none()),
                child: SizedBox.square(
                  dimension: 128,
                  child: Glass(shape: GlassOval()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A drop on an orbit whose radius breathes in and out, so it merges with
/// the centre and pulls free again once per lap.
class _Satellite extends StatelessWidget {
  const _Satellite({
    required this.orbit,
    required this.size,
    required this.turns,
    required this.phase,
    required this.reach,
  });

  final Animation<double> orbit;
  final double size;
  final int turns;
  final double phase;
  final double reach;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: orbit,
      builder: (context, child) {
        final t = orbit.value * 2 * math.pi;
        final angle = t * turns + phase;
        final radius = reach * (0.62 + 0.38 * math.sin(t * 2 + phase));
        return Transform.translate(
          offset: Offset(math.cos(angle), math.sin(angle)) * radius,
          child: child,
        );
      },
      child: SizedBox.square(
        dimension: size,
        child: const Glass(shape: GlassOval()),
      ),
    );
  }
}
