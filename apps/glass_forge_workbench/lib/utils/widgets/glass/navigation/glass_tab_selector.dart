import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_tab_selector_capsule.dart';
import 'package:motor/motor.dart';

/// The capsule that slides under the selected tab.
///
/// Painted, never glass. A second backdrop pass over the bar's own is exactly
/// the arrangement that washes out white on physical iPhones (flutter#187820),
/// so the lens is suggested with a sheen and a lit rim instead. It keeps
/// everything that makes it feel liquid: a bouncy spring, and a stretch that
/// follows its speed.
class GlassTabSelector extends StatelessWidget {
  const GlassTabSelector({
    required this.alignment,
    required this.count,
    required this.squash,
    required this.duration,
    required this.animate,
    super.key,
  });

  /// Logical alignment, -1 (start) to 1 (end).
  final double alignment;
  final int count;
  final double squash;
  final Duration duration;

  /// False snaps straight to [alignment], for Reduce Motion.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (!animate) {
      return GlassTabSelectorCapsule(
        alignment: alignment,
        velocity: 0,
        count: count,
        squash: squash,
      );
    }
    return VelocityMotionBuilder<double>(
      value: alignment,
      motion: Motion.bouncySpring(duration: duration, snapToEnd: true),
      converter: const SingleMotionConverter(),
      builder: (context, value, velocity, _) => GlassTabSelectorCapsule(
        alignment: value,
        velocity: velocity,
        count: count,
        squash: squash,
      ),
    );
  }
}
