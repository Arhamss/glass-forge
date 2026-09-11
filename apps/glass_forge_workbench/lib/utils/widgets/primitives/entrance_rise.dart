import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/helpers/reduce_motion.dart';

/// Lifts a list item into place when it first appears, a beat after the one
/// before it.
///
/// Translation only. Fading would put the item — and any glass on it —
/// inside an opacity layer.
class EntranceRise extends StatelessWidget {
  const EntranceRise({required this.index, required this.child, super.key});

  /// Position in the list; later items start later. Capped, so a long list
  /// never waits on its tail.
  final int index;
  final Widget child;

  static const _rise = Duration(milliseconds: 420);
  static const double _distance = 18;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child;
    final delay = AppMotion.stagger * index.clamp(0, 6);
    final total = _rise + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: AppMotion.selectCurve,
      ),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, (1 - t) * _distance),
        child: child,
      ),
      child: child,
    );
  }
}
