import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/controls/control_frame.dart';
import 'package:glass_forge/src/controls/disabled_glass.dart';
import 'package:glass_forge/src/design/glass_backdrop_sampler.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/motion/interactive_glass.dart';
import 'package:glass_forge/src/motion/settle_spring.dart';
import 'package:glass_forge/src/shapes/glass_shape_clipper.dart';
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
/// | Track | painted, around the knob | painted |
/// | Knob | `Glass` (`GlassMaterial.dome()`) | painted |
///
/// On content the painted parts leave a hole the shape of the glass
/// element and follow it as it moves, because a `GlassLayer` draws its
/// glass under whatever its subtree paints; see `GlassShapeClipper`.
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
/// Under [TextDirection.rtl] the switch mirrors, as `Switch` and
/// `CupertinoSwitch` do: "on" is the left side, and a drag toward it is a
/// drag to the left.
///
/// The switch always ends up showing [value]. A tap or a drag springs the
/// knob toward the new side at once, for feel, then reports it; if the
/// owner has not rebuilt with that value by the next frame — it declined
/// the change, or is still deciding — the knob springs back, and a later
/// rebuild with the new value moves it again. Semantics report [value]
/// throughout.
///
/// `onChanged: null` disables it: no tap, no drag, and the callback never
/// runs. Like every control in this package except `GlassTextField`, it
/// shares one internal frame for semantics, keyboard activation and the
/// 44 × 44 minimum hit target.
class GlassSwitch extends StatefulWidget {
  /// Creates a switch.
  const GlassSwitch({
    required this.value,
    required this.onChanged,
    this.activeTrackColor,
    this.backdrop,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value on activation. Null renders this switch
  /// disabled.
  final ValueChanged<bool>? onChanged;

  /// The track's colour when [value] is true.
  ///
  /// Null resolves to the theme's accent, `GlassControlColors.accent` for
  /// the scheme the switch resolves in — by default an approximation of
  /// Apple's own system green.
  final Color? activeTrackColor;

  /// What is behind this switch, for the same adaptation `GlassSurface`
  /// offers.
  final Color? backdrop;

  /// The accessible name read for this switch.
  final String? semanticLabel;

  /// Where keyboard focus for this control is tracked. Null owns one for
  /// this control's own lifetime.
  final FocusNode? focusNode;

  /// Whether this control takes keyboard focus as soon as it is inserted.
  final bool autofocus;

  @override
  State<GlassSwitch> createState() => _GlassSwitchState();
}

class _GlassSwitchState extends State<GlassSwitch>
    with SingleTickerProviderStateMixin, ReduceMotionSnap {
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

  /// The most recent build's reading direction, read by the drag handlers,
  /// which run outside `build`. [_position] always counts toward "on"; under
  /// [TextDirection.rtl] "on" is the left side, so both the knob and a drag
  /// run the other way.
  TextDirection _textDirection = TextDirection.ltr;

  /// +1 when "on" is to the right, -1 when it is to the left — what a
  /// horizontal pixel delta is multiplied by to move [_position].
  double get _direction => _textDirection == TextDirection.rtl ? -1 : 1;

  @override
  void initState() {
    super.initState();
    _target = widget.value ? _travel : 0;
    _position = AnimationController(
      vsync: this,
      value: _target,
      upperBound: _travel,
    );
  }

  @override
  void didUpdateWidget(GlassSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragging && widget.onChanged == null) {
      // Disabled under the finger. The drag recognizer is dropped without
      // an end or a cancel, so the drag is over here: the knob goes back
      // to [GlassSwitch.value], and nothing is reported.
      _dragging = false;
      _animateTo(widget.value ? _travel : 0);
    }
    _followValue();
  }

  /// Springs the knob to [GlassSwitch.value] unless a drag owns it or it is
  /// already heading there.
  void _followValue() {
    final desired = widget.value ? _travel : 0.0;
    if (!_dragging && desired != _target) {
      _animateTo(desired);
    }
  }

  /// Reports [next] to [GlassSwitch.onChanged], then checks after the next
  /// frame that the owner took it: an owner that declined, or has not
  /// rebuilt yet, has left [GlassSwitch.value] where it was, and the knob
  /// springs back to it.
  void _report(ValueChanged<bool> onChanged, bool next) {
    onChanged(next);
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) {
          _followValue();
        }
      })
      ..ensureVisualUpdate();
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  /// [AnimationController.value]'s setter calls `stop()` before
  /// assigning, so this both halts whatever spring is running and snaps to
  /// [_target] in the same step.
  @override
  void didChangeReduceMotion({required bool reduceMotion}) {
    if (reduceMotion && _position.isAnimating) {
      _position.value = _target;
    }
  }

  /// [_position] already counts pixels, so its tolerance needs no scaling.
  void _animateTo(double target, {double velocity = 0}) {
    _target = target;
    _position.settleTo(context, target, pixelsPerUnit: 1, velocity: velocity);
  }

  void _toggle() {
    final onChanged = widget.onChanged;
    if (onChanged == null) {
      return;
    }
    final next = !widget.value;
    _animateTo(next ? _travel : 0);
    _report(onChanged, next);
  }

  void _onDragStart(DragStartDetails details) {
    _dragging = true;
    _position.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _position.value =
        (_position.value + _direction * (details.primaryDelta ?? 0)).clamp(
          0,
          _travel,
        );
  }

  void _onDragEnd(DragEndDetails details) {
    _dragging = false;
    final settledOn = _position.value > _travel / 2;
    _animateTo(
      settledOn ? _travel : 0,
      velocity: _direction * details.velocity.pixelsPerSecond.dx,
    );
    final onChanged = widget.onChanged;
    if (onChanged != null && settledOn != widget.value) {
      _report(onChanged, settledOn);
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
    _textDirection = Directionality.of(context);
    return GlassControlFrame(
      onActivate: enabled ? _toggle : null,
      semanticLabel: widget.semanticLabel,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
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
        child: GlassBackdropBuilder(
          backdrop: widget.backdrop,
          builder: (context, backdrop) =>
              _body(context, backdrop, enabled: enabled),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    Color? backdrop, {
    required bool enabled,
  }) {
    final style = GlassTheme.surfaceOf(
      context,
      GlassSurfaceRole.control,
      size: const Size(_trackWidth, _trackHeight),
      backdrop: backdrop,
    );
    final onGlass = GlassHostScope.isOnGlass(context);
    final offColor = style.material.tint.withValues(
      alpha: style.material.tintOpacity,
    );
    final colors = GlassTheme.controlColorsOf(context, style.brightness);
    final onColor = widget.activeTrackColor ?? colors.accent;
    final knob = _knob(style: style, onGlass: onGlass, knobColor: colors.knob);

    final visual = AnimatedBuilder(
      animation: _position,
      builder: (context, child) {
        final trackColor = Color.lerp(
          offColor,
          onColor,
          _position.value / _travel,
        )!;
        // How far the knob sits from its leftmost place: [_position]
        // itself, or its mirror under RTL, where "on" is on the left.
        final offset = _textDirection == TextDirection.rtl
            ? _travel - _position.value
            : _position.value;
        final knobLeft = _knobInset + offset;
        return SizedBox(
          width: _trackWidth,
          height: _trackHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipPath(
                  // On content the knob is glass, which the layer draws
                  // under this track's paint: leave a hole where it is.
                  // See [GlassShapeClipper].
                  clipper: GlassShapeClipper(
                    style.shape,
                    hole: onGlass
                        ? null
                        : Rect.fromLTWH(
                            knobLeft,
                            _knobInset,
                            _knobWidth,
                            _knobHeight,
                          ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: trackColor),
                  ),
                ),
              ),
              Positioned(
                left: _knobInset,
                top: _knobInset,
                child: Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
      child: knob,
    );

    return enabled
        ? visual
        : Opacity(opacity: GlassControlFrame.disabledOpacity, child: visual);
  }

  Widget _knob({
    required GlassSurfaceStyle style,
    required bool onGlass,
    required Color knobColor,
  }) {
    if (onGlass) {
      return ClipPath(
        clipper: GlassShapeClipper(style.shape),
        child: DecoratedBox(
          decoration: BoxDecoration(color: knobColor),
          child: const SizedBox(width: _knobWidth, height: _knobHeight),
        ),
      );
    }
    return DisabledGlassPresence(
      disabled: widget.onChanged == null,
      child: Glass(
        shape: style.shape,
        material: GlassMaterial.dome(),
        child: const SizedBox(width: _knobWidth, height: _knobHeight),
      ),
    );
  }
}
