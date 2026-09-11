import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/helpers/reduce_motion.dart';

/// Brings a newly selected tab up out of the ground.
///
/// Fades a plain overlay away rather than fading the tab itself: an opacity
/// layer around live glass would put a backdrop filter inside a save layer,
/// which is one of the arrangements that collapses to white on device.
class ShellFadeThrough extends StatefulWidget {
  const ShellFadeThrough({required this.index, required this.child, super.key});

  /// The selected tab. A change starts the fade.
  final int index;
  final Widget child;

  @override
  State<ShellFadeThrough> createState() => _ShellFadeThroughState();
}

class _ShellFadeThroughState extends State<ShellFadeThrough>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.fadeThrough,
    value: 1,
  );

  @override
  void didUpdateWidget(ShellFadeThrough oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && !context.reduceMotion) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = Curves.easeOut.transform(_controller.value);
              if (t >= 1) return const SizedBox.shrink();
              return ColoredBox(
                color: AppColors.ground.withValues(alpha: 1 - t),
              );
            },
          ),
        ),
      ],
    );
  }
}
