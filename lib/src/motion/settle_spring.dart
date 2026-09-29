import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/design/glass_motion_defaults.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/motion/reduce_motion.dart';

/// The settle spring every control in this package lands its moving part
/// with — a switch knob, a segmented pill, a slider thumb's stretch, a text
/// field's focus — and the Reduce Motion jump that replaces it.
///
/// Internal: not exported.
extension SettleSpring on AnimationController {
  /// Springs to [target] on the theme's [GlassMotionRole.settle] spring, or
  /// jumps there under Reduce Motion.
  ///
  /// [pixelsPerUnit] is how many logical pixels one unit of this
  /// controller's value moves on screen: 1 for a controller that already
  /// counts pixels, the travel in pixels for one that runs 0 to 1. The
  /// motion's settle tolerance is stated in pixels and is divided by it.
  /// It is required on purpose: a pixel tolerance applied to a 0 to 1
  /// fraction reads 0.5 px as half the travel, and the spring stops well
  /// short of its target (a tapped segmented pill landed 20 px short, and a
  /// slider thumb stayed stretched after a fast drag).
  ///
  /// [velocity] is in this controller's units per second. A [pixelsPerUnit]
  /// of zero or less, which has no travel to spring across, jumps.
  void settleTo(
    BuildContext context,
    double target, {
    required double pixelsPerUnit,
    double velocity = 0,
  }) {
    if (GlassReduceMotion.instance.value || pixelsPerUnit <= 0) {
      value = target;
      return;
    }
    final motion = GlassTheme.motionOf(
      context,
      GlassMotionRole.settle,
    ).scaledTo(pixelsPerUnit);
    animateWith(
      SpringSimulation(
        motion.spring,
        value,
        target,
        velocity,
        tolerance: motion.tolerance,
        // Lands exactly on [target] once within tolerance, rather than
        // wherever the spring happened to be: a sub-pixel remainder is
        // invisible while moving, but a slider thumb left at a 1.008
        // stretch stays that way for good.
        snapToEnd: true,
      ),
    );
  }
}

/// Listens to [GlassReduceMotion] for the life of this [State], and calls
/// [didChangeReduceMotion] whenever it changes.
///
/// Every animated control has to handle Reduce Motion turning on *mid
/// travel* — not only a fresh transition started after it turns on, which
/// [SettleSpring.settleTo] already jumps — by landing whatever is moving
/// now, rather than letting it finish or freezing it half way.
///
/// Internal: not exported.
mixin ReduceMotionSnap<T extends StatefulWidget> on State<T> {
  bool _listening = false;

  /// Starts listening here rather than in `initState`: a state whose own
  /// `initState` throws after `super.initState()` (a failed assert on its
  /// widget's arguments) is never disposed, and a listener added before
  /// the throw would outlive it and fire into a half-built state.
  /// `didChangeDependencies` runs only once `initState` has finished.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_listening) {
      _listening = true;
      GlassReduceMotion.instance.addListener(_handleReduceMotion);
    }
  }

  @override
  void dispose() {
    if (_listening) {
      GlassReduceMotion.instance.removeListener(_handleReduceMotion);
    }
    super.dispose();
  }

  void _handleReduceMotion() => didChangeReduceMotion(
    reduceMotion: GlassReduceMotion.instance.value,
  );

  /// Called when Reduce Motion turns on or off. With [reduceMotion] true,
  /// land every animation that is still running.
  @protected
  void didChangeReduceMotion({required bool reduceMotion});
}
