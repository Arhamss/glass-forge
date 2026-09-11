import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/helpers/haptic_helper.dart';
import 'package:glass_forge_workbench/utils/helpers/reduce_motion.dart';

/// Press feedback for anything tappable: a slight scale while the finger is
/// down, and a light haptic when the tap lands.
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.onTap,
    required this.child,
    this.pressedScale = 0.97,
    this.haptic = true,
    this.semanticLabel,
    this.isSelected,
    this.behavior = HitTestBehavior.opaque,
    super.key,
  });

  /// Null disables the control, which then reads as disabled to assistive
  /// technology instead of simply ignoring taps.
  final VoidCallback? onTap;
  final Widget child;
  final double pressedScale;
  final bool haptic;

  /// When given, replaces the child's own text as the control's label.
  final String? semanticLabel;

  /// For controls that are one option among several.
  final bool? isSelected;
  final HitTestBehavior behavior;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  final ValueNotifier<bool> _pressed = ValueNotifier<bool>(false);

  bool get _enabled => widget.onTap != null;

  @override
  void dispose() {
    _pressed.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.haptic) AppHaptics.tap();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = context.reduceMotion;
    return Semantics(
      button: true,
      enabled: _enabled ? null : false,
      selected: widget.isSelected,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      // The tap action lives on this node, not on the gesture detector below:
      // excluding the child's semantics would otherwise take the action with
      // it, and a screen reader could find the control but not press it.
      onTap: _enabled ? _handleTap : null,
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: widget.behavior,
        onTapDown: _enabled ? (_) => _pressed.value = true : null,
        onTapUp: _enabled ? (_) => _pressed.value = false : null,
        onTapCancel: _enabled ? () => _pressed.value = false : null,
        onTap: _enabled ? _handleTap : null,
        child: ValueListenableBuilder<bool>(
          valueListenable: _pressed,
          builder: (context, pressed, child) => AnimatedScale(
            scale: pressed && !reduceMotion ? widget.pressedScale : 1,
            duration: AppMotion.press,
            curve: AppMotion.pressCurve,
            child: child,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
