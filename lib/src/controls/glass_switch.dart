import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/controls/control_frame.dart';
import 'package:glass_forge/src/design/glass_motion_defaults.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/motion/interactive_glass.dart';
import 'package:glass_forge/src/motion/reduce_motion.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_host_scope.dart';

/// A two-state toggle: a capsule track and a knob that drags, flicks and
/// settles to whichever side it ends up past.
///
/// Resolves `GlassSurfaceRole.control` for its material and motion, the same
/// as `GlassButton`. Unlike a button, the track is **always painted** — real
/// glass on a 64 × 28 capsule this thin would read as a smear, not a
/// control — and only the knob, "Apple's one lens-profile element" per the
/// design doc, becomes real glass, and only on content:
///
/// | | On content | On a glass surface |
/// |---|---|---|
/// | Track | painted | painted |
/// | Knob | `Glass` (`GlassMaterial.dome()`) | painted |
///
/// That keeps the same "never glass on glass" rule `GlassButton` follows —
/// see [GlassHostScope] — while still giving the one part of a switch that
/// is worth a lens its lens.
///
/// The knob does not use [InteractiveGlass]: that widget reports its
/// travel only through the render tree's paint transform, with no callback
/// for where a drag ends, which is exactly the information a switch needs
/// to decide which side it settled on. Instead this widget tracks the
/// drag itself and springs the knob home on the theme's
/// `GlassMotionRole.settle` spring, still reaching the glass only through a
/// paint-time `Transform.translate` — never by rebuilding the knob's own
/// `Glass` each frame, which is why [AnimatedBuilder.child] carries it
/// unchanged through every tick.
///
/// ```dart
/// GlassSwitch(
///   value: enabled,
///   onChanged: (next) => setState(() => enabled = next),
/// )
/// ```
///
/// `onChanged: null` disables it: no tap, no drag, and the callback never
/// runs — see [GlassControlFrame], which every control in this package
/// shares for semantics, keyboard activation and the 44 × 44 minimum hit
/// target.
class GlassSwitch extends StatefulWidget {
  /// Creates a switch.
  const GlassSwitch({
    required this.value,
    required this.onChanged,
    this.activeTrackColor,
    this.backdrop,
    this.semanticLabel,
    super.key,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value on activation. Null renders this switch
  /// disabled.
  final ValueChanged<bool>? onChanged;

  /// The track's colour when [value] is true.
  ///
  /// Null resolves to an approximation of Apple's own system green — this
  /// package has no accent-colour system of its own yet, so this is the one
  /// hard-coded colour in this widget, the same way `CupertinoSwitch`
  /// hard-codes its own default rather than deriving one.
  final Color? activeTrackColor;

  /// What is behind this switch, for the same adaptation `GlassSurface`
  /// offers.
  final Color? backdrop;

  /// The accessible name read for this switch.
  final String? semanticLabel;

  @override
  State<GlassSwitch> createState() => _GlassSwitchState();
}

class _GlassSwitchState extends State<GlassSwitch>
    with SingleTickerProviderStateMixin {
  // Track 64 × 28, knob 38 × 24, both iOS 26/27 proportions. No capture was
  // available while building this widget to confirm against — see the plan
  // for this task — so these are the plan's own numbers, kept as-is rather
  // than guessed at again here.
  static const double _trackWidth = 64;
  static const double _trackHeight = 28;
  static const double _knobWidth = 38;
  static const double _knobHeight = 24;
  static const double _knobInset = (_trackHeight - _knobHeight) / 2;

  /// How far the knob's left edge travels between off and on.
  static const double _travel = _trackWidth - _knobWidth - 2 * _knobInset;

  /// Apple's system green, light and dark. See [GlassSwitch.activeTrackColor].
  static const Color _activeTrackColorLight = Color(0xFF34C759);
  static const Color _activeTrackColorDark = Color(0xFF30D158);

  /// The knob's own colour, painted under [GlassHostScope]. Always white,
  /// in both schemes — the one part of a real iOS switch that never flips.
  static const Color _knobColor = Color(0xFFFFFFFF);

  static const double _disabledOpacity = 0.4;

  /// The knob's left-edge offset from [_knobInset], in logical pixels: the
  /// spring's own domain, chosen so `GlassMotion`'s pixel-stated tolerance
  /// (`GlassMotion.settleDistance`, `GlassMotion.settleVelocity`) means what
  /// it says. Ranges 0 (off) to [_travel] (on).
  late final AnimationController _position;

  /// Where [_position] is springing toward: 0 or [_travel]. Compared
  /// against [GlassSwitch.value] in [didUpdateWidget] so an external value
  /// change and this widget's own settle — which calls [_toggle] or an
  /// `onChanged` from a drag, then waits for the same value to come back
  /// down through the constructor — don't fight over the same spring.
  late double _target;

  /// Whether a drag is currently driving [_position] directly.
  ///
  /// [didUpdateWidget] does not re-target the spring while this is true: a
  /// live drag already owns [_position], and re-targeting it mid-gesture
  /// would fight the finger.
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _target = widget.value ? _travel : 0;
    _position = AnimationController(
      vsync: this,
      value: _target,
      upperBound: _travel,
    );
    GlassReduceMotion.instance.addListener(_onReduceMotionChanged);
  }

  @override
  void didUpdateWidget(GlassSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    final desired = widget.value ? _travel : 0.0;
    if (!_dragging && desired != _target) {
      _animateTo(desired);
    }
  }

  @override
  void dispose() {
    GlassReduceMotion.instance.removeListener(_onReduceMotionChanged);
    _position.dispose();
    super.dispose();
  }

  /// Reduce Motion turning on mid-travel must land the knob instantly, not
  /// only a fresh transition started after it turns on. [AnimationController
  /// .value]'s setter calls `stop()` before assigning, so this both halts
  /// whatever spring is running and snaps to [_target] in the same step.
  void _onReduceMotionChanged() {
    if (GlassReduceMotion.instance.value && _position.isAnimating) {
      _position.value = _target;
    }
  }

  void _animateTo(double target, {double velocity = 0}) {
    _target = target;
    if (GlassReduceMotion.instance.value) {
      _position.value = target;
      return;
    }
    final motion = GlassTheme.motionOf(context, GlassMotionRole.settle);
    _position.animateWith(
      SpringSimulation(
        motion.spring,
        _position.value,
        target,
        velocity,
        tolerance: motion.tolerance,
      ),
    );
  }

  void _toggle() {
    final onChanged = widget.onChanged;
    if (onChanged == null) {
      return;
    }
    final next = !widget.value;
    _animateTo(next ? _travel : 0);
    onChanged(next);
  }

  void _onDragStart(DragStartDetails details) {
    _dragging = true;
    _position.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _position.value = (_position.value + (details.primaryDelta ?? 0)).clamp(
      0,
      _travel,
    );
  }

  void _onDragEnd(DragEndDetails details) {
    _dragging = false;
    final settledOn = _position.value > _travel / 2;
    _animateTo(
      settledOn ? _travel : 0,
      velocity: details.velocity.pixelsPerSecond.dx,
    );
    final onChanged = widget.onChanged;
    if (onChanged != null && settledOn != widget.value) {
      onChanged(settledOn);
    }
  }

  void _onDragCancel() {
    _dragging = false;
    final settledOn = _position.value > _travel / 2;
    _animateTo(settledOn ? _travel : 0);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    return GlassControlFrame(
      onActivate: enabled ? _toggle : null,
      semanticLabel: widget.semanticLabel,
      toggled: widget.value,
      button: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // `down`, not the default `start`: with `start`, the distance spent
        // clearing the touch-slop threshold moves *where the drag is
        // considered to have begun* and is never reported through
        // `onHorizontalDragUpdate` at all — dropped, not merely delayed.
        // `kTouchSlop` is 18 logical pixels and this knob's whole travel is
        // 22, so on a touch pointer that would swallow most of the track
        // before the knob ever visibly moved. `down` reports the entire
        // raw pointer movement instead, so the knob tracks the finger from
        // first contact.
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: enabled ? _onDragStart : null,
        onHorizontalDragUpdate: enabled ? _onDragUpdate : null,
        onHorizontalDragEnd: enabled ? _onDragEnd : null,
        onHorizontalDragCancel: enabled ? _onDragCancel : null,
        child: _body(context, enabled: enabled),
      ),
    );
  }

  Widget _body(BuildContext context, {required bool enabled}) {
    final style = GlassTheme.surfaceOf(
      context,
      GlassSurfaceRole.control,
      size: const Size(_trackWidth, _trackHeight),
      backdrop: widget.backdrop,
    );
    final onGlass = GlassHostScope.isOnGlass(context);
    final offColor = style.material.tint.withValues(
      alpha: style.material.tintOpacity,
    );
    final onColor =
        widget.activeTrackColor ??
        (style.brightness == Brightness.dark
            ? _activeTrackColorDark
            : _activeTrackColorLight);
    final knob = _knob(style: style, onGlass: onGlass);

    final visual = AnimatedBuilder(
      animation: _position,
      builder: (context, child) {
        final trackColor = Color.lerp(
          offColor,
          onColor,
          _position.value / _travel,
        )!;
        return ClipPath(
          clipper: _SwitchShapeClipper(style.shape),
          child: DecoratedBox(
            decoration: BoxDecoration(color: trackColor),
            child: SizedBox(
              width: _trackWidth,
              height: _trackHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: _knobInset,
                    top: _knobInset,
                    child: Transform.translate(
                      offset: Offset(_position.value, 0),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: knob,
    );

    return enabled ? visual : Opacity(opacity: _disabledOpacity, child: visual);
  }

  Widget _knob({required GlassSurfaceStyle style, required bool onGlass}) {
    if (onGlass) {
      return ClipPath(
        clipper: _SwitchShapeClipper(style.shape),
        child: const DecoratedBox(
          decoration: BoxDecoration(color: _knobColor),
          child: SizedBox(width: _knobWidth, height: _knobHeight),
        ),
      );
    }
    return Glass(
      shape: style.shape,
      material: GlassMaterial.dome(),
      child: const SizedBox(width: _knobWidth, height: _knobHeight),
    );
  }
}

/// Clips to [shape] at the real, laid-out size.
///
/// A local copy of the same clipper `GlassButton` carries under a different
/// name — see that file's own doc comment for why this is not shared: the
/// package's real clip lives on `Glass` itself and is `@visibleForTesting`
/// for that widget's own tests, not for other widgets in this package to
/// paint with.
class _SwitchShapeClipper extends CustomClipper<Path> {
  const _SwitchShapeClipper(this.shape);

  final GlassShape shape;

  @override
  Path getClip(Size size) =>
      shape.toBorder(size).getOuterPath(Offset.zero & size);

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) =>
      oldClipper is! _SwitchShapeClipper || oldClipper.shape != shape;
}
