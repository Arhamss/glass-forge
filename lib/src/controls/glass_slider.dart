import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/controls/control_frame.dart';
import 'package:glass_forge/src/controls/track_cutout.dart';
import 'package:glass_forge/src/design/glass_motion_defaults.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/motion/glass_jiggle.dart';
import 'package:glass_forge/src/motion/reduce_motion.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_host_scope.dart';

/// A continuous value between [min] and [max]: a painted track and fill,
/// under a thumb that is real glass on content and paint on a glass surface.
///
/// | | On content | On a glass surface |
/// |---|---|---|
/// | Track and fill | painted, around the thumb | painted |
/// | Thumb | `Glass` | painted |
///
/// On content the painted parts leave a hole the shape of the glass
/// element and follow it as it moves, because a `GlassLayer` draws its
/// glass under whatever its subtree paints; see [TrackCutoutClipper].
///
/// Dragging anywhere in the 44-point-tall hit area — not only on the thumb
/// itself — sets the value under the finger; a plain tap jumps straight to
/// that position, inside a scroll view too, where a vertical drag still
/// scrolls. [divisions], when given, snaps both to evenly spaced
/// steps. The thumb stretches along the track while it is dragged fast,
/// through [GlassJiggle], the same deformation `InteractiveGlass` reads off
/// its own live velocity — this widget has no render-tree velocity to read,
/// so it times its own drag deltas instead. Reduce Motion removes it, same
/// as everywhere else in this package.
///
/// ```dart
/// GlassSlider(
///   value: volume,
///   onChanged: (next) => setState(() => volume = next),
/// )
/// ```
///
/// The thumb follows the finger while a drag is down, for feel, and after a
/// tap or a keyboard step moves at once; once the gesture or step is over,
/// it shows [value]. An owner that declined the change, or has not rebuilt
/// with it by the next frame, gets the thumb back where [value] says, and
/// semantics report [value] throughout.
///
/// `onChanged: null` disables it: no tap, no drag, no keyboard step, and the
/// callback never runs. Focus and the increase/decrease semantics actions
/// come from [GlassControlFrame] — the left/right (or down/up) arrow keys
/// step by one [divisions] or, without divisions, by a tenth of the range.
///
/// Under [TextDirection.rtl] the slider mirrors, as `Slider` does: [min] is
/// on the right, the fill grows leftward from it, a drag or tap measures
/// from the right edge, and the left arrow key increases the value.
class GlassSlider extends StatefulWidget {
  /// Creates a slider.
  const GlassSlider({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeStart,
    this.onChangeEnd,
    this.backdrop,
    this.semanticLabel,
    this.semanticValue,
    super.key,
  }) : assert(min <= max, 'min must be less than or equal to max'),
       assert(
         divisions == null || divisions > 0,
         'divisions must be positive',
       );

  /// The current value. Clamped to [min]..[max] by every code path that
  /// sets it; a caller passing something outside that range is a caller
  /// bug this widget does not paper over.
  final double value;

  /// Called with the new value as it changes, during a drag, on a tap, and
  /// on a keyboard step. Null renders this slider disabled.
  final ValueChanged<double>? onChanged;

  /// The value at the far (leading) end of the track.
  final double min;

  /// The value at the far (trailing) end of the track.
  ///
  /// [min] equal to [max] is a fixed slider — see the class doc — and never
  /// divides by the zero-width range that would otherwise result.
  final double max;

  /// The number of discrete steps between [min] and [max], or null for a
  /// continuous value.
  final int? divisions;

  /// Called once, with the value at that moment, when a drag begins or a
  /// tap lands.
  final ValueChanged<double>? onChangeStart;

  /// Called once, with the final value, when a drag ends or is cancelled,
  /// or after a tap has set the value.
  final ValueChanged<double>? onChangeEnd;

  /// What is behind this slider, for the same adaptation `GlassSurface`
  /// offers.
  final Color? backdrop;

  /// The accessible name read for this slider.
  final String? semanticLabel;

  /// Formats [value] for screen readers. Null resolves to a plain number,
  /// whole when [value] lands on an integer and to two decimal places
  /// otherwise.
  final String Function(double value)? semanticValue;

  @override
  State<GlassSlider> createState() => _GlassSliderState();
}

class _GlassSliderState extends State<GlassSlider>
    with TickerProviderStateMixin {
  static const double _trackHeight = 6;
  static const double _thumbSize = 28;

  /// The thumb's own colour, painted under [GlassHostScope]. Always white,
  /// the same reasoning — and the same lack of a capture to confirm against
  /// — as `GlassSwitch._knobColor`.
  static const Color _thumbColor = Color(0xFFFFFFFF);

  static const double _disabledOpacity = 0.4;

  static const GlassJiggle _jiggle = GlassJiggle();

  /// The thumb's position as a fraction of the track's travel, 0 to 1.
  ///
  /// A fraction, not a pixel offset: the track's own width is only known at
  /// build time (it fills whatever width this slider is given), where a
  /// pixel-offset domain like `GlassSwitch._position` would have to be
  /// re-based on every layout change. A fraction needs no re-basing.
  late final AnimationController _position;

  /// The thumb's live stretch ratio along the track axis, 1 at rest.
  late final AnimationController _stretch;

  /// Whether a drag is currently driving [_position] directly — see
  /// `GlassSwitch._dragging`, the same reason.
  bool _dragging = false;

  /// The most recent build's track width, read by the drag handlers, which
  /// run outside `build` and have no constraints of their own to ask.
  double _trackWidth = 0;

  /// The most recent build's reading direction, read by the drag handlers
  /// for the same reason as [_trackWidth]. [_position] always counts from
  /// [GlassSlider.min]; under [TextDirection.rtl] that end is on the right.
  TextDirection _textDirection = TextDirection.ltr;

  Duration? _lastTimestamp;
  double _lastX = 0;

  @override
  void initState() {
    super.initState();
    _position = AnimationController(
      vsync: this,
      value: _fractionOf(widget.value),
    );
    _stretch = AnimationController(
      vsync: this,
      value: 1,
      lowerBound: 1,
      upperBound: _jiggle.maxStretch,
    );
    GlassReduceMotion.instance.addListener(_onReduceMotionChanged);
  }

  @override
  void didUpdateWidget(GlassSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragging && widget.onChanged == null) {
      // Disabled under the finger. The drag recognizer is dropped without
      // an end or a cancel, so the drag is over here: the thumb goes back
      // to [GlassSlider.value] and relaxes. `onChangeEnd` is not called —
      // this runs during the owner's build, which a callback that sets
      // state would throw from.
      _dragging = false;
      _animateStretchTo(1);
    }
    _followValue();
  }

  /// Puts the thumb at [GlassSlider.value] unless a drag owns it.
  void _followValue() {
    if (_dragging) {
      return;
    }
    final desired = _fractionOf(widget.value);
    if (desired != _position.value) {
      _position.value = desired;
    }
  }

  /// After the next frame, puts the thumb back at [GlassSlider.value] if
  /// the owner did not rebuild with what a gesture or step just reported.
  void _followValueAfterFrame() {
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
    GlassReduceMotion.instance.removeListener(_onReduceMotionChanged);
    _position.dispose();
    _stretch.dispose();
    super.dispose();
  }

  void _onReduceMotionChanged() {
    if (GlassReduceMotion.instance.value && _stretch.isAnimating) {
      _stretch.value = 1;
    }
  }

  double get _range => widget.max - widget.min;

  /// The value [_position]'s current fraction represents.
  double get _currentValue => _valueOf(_position.value);

  /// [value] as a fraction of the track, 0 to 1. [_range] at or below zero
  /// — [GlassSlider.min] equal to [GlassSlider.max] — resolves to a fixed 0
  /// rather than dividing by it.
  double _fractionOf(double value) {
    if (_range <= 0) {
      return 0;
    }
    return ((value - widget.min) / _range).clamp(0.0, 1.0);
  }

  double _valueOf(double fraction) => widget.min + fraction * _range;

  /// One keyboard or semantics step: one [GlassSlider.divisions]-th of the
  /// range, or a tenth of it without divisions. Zero, not a division by
  /// zero, when [_range] is zero.
  double get _stepSize {
    if (_range <= 0) {
      return 0;
    }
    final divisions = widget.divisions;
    if (divisions != null) {
      return _range / divisions;
    }
    return _range * 0.1;
  }

  /// [fraction], snapped to the nearest of [GlassSlider.divisions] evenly
  /// spaced steps. Unchanged without divisions.
  double _snap(double fraction) {
    final divisions = widget.divisions;
    if (divisions == null) {
      return fraction;
    }
    final step = 1 / divisions;
    return ((fraction / step).round() * step).clamp(0.0, 1.0);
  }

  String _formatValue(double value) {
    final formatter = widget.semanticValue;
    if (formatter != null) {
      return formatter(value);
    }
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(2);
  }

  void _step(double direction) {
    final stepSize = _stepSize;
    if (stepSize == 0) {
      return;
    }
    final next = (_currentValue + direction * stepSize).clamp(
      widget.min,
      widget.max,
    );
    _position.value = _fractionOf(next);
    widget.onChanged?.call(next);
    _followValueAfterFrame();
  }

  void _increase() => _step(1);

  void _decrease() => _step(-1);

  void _onDragStart(DragStartDetails details) {
    _dragging = true;
    _lastTimestamp = details.sourceTimeStamp;
    _lastX = details.localPosition.dx;
    _position.stop();
    widget.onChangeStart?.call(_currentValue);
    _updateFromLocalX(details.localPosition.dx);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _updateStretch(details);
    _updateFromLocalX(details.localPosition.dx);
  }

  void _onDragEnd(DragEndDetails details) {
    _dragging = false;
    widget.onChangeEnd?.call(_currentValue);
    _animateStretchTo(1);
    _followValueAfterFrame();
  }

  void _onDragCancel() {
    // Also called when a drag that never started loses the arena — to a
    // tap, or to a scroll view's vertical drag. Nothing to end then.
    if (!_dragging) {
      return;
    }
    _dragging = false;
    widget.onChangeEnd?.call(_currentValue);
    _animateStretchTo(1);
    _followValueAfterFrame();
  }

  /// A tap sets the value under it, bracketed by the same start and end
  /// callbacks a drag gets.
  ///
  /// Its own recognizer, not a drag that never moved: a drag recognizer
  /// only wins a stationary pointer when it is alone in the arena, and
  /// inside a scroll view it never is — the list's vertical drag is there
  /// too, and neither claims a pointer that does not move.
  void _onTapUp(TapUpDetails details) {
    widget.onChangeStart?.call(_currentValue);
    _updateFromLocalX(details.localPosition.dx);
    widget.onChangeEnd?.call(_currentValue);
    _followValueAfterFrame();
  }

  void _updateFromLocalX(double dx) {
    // `min == max`: fixed at `min`, fraction pinned to 0 — see the class
    // doc. Dividing by `_range` below would be a division by zero; worse,
    // moving the thumb from raw pointer geometry alone, ignoring `_range`
    // entirely, would still move a thumb whose value can never change.
    if (_range <= 0) {
      widget.onChanged?.call(widget.min);
      return;
    }
    final travel = (_trackWidth - _thumbSize).clamp(0.0, double.infinity);
    // Distance from the [GlassSlider.min] end: the right edge under RTL.
    final fromStart = _textDirection == TextDirection.rtl
        ? _trackWidth - dx
        : dx;
    final rawFraction = travel == 0
        ? 0.0
        : (fromStart - _thumbSize / 2).clamp(0.0, travel) / travel;
    _position.value = _snap(rawFraction);
    widget.onChanged?.call(_currentValue);
  }

  /// Live speed, in logical pixels per second, off the raw drag deltas —
  /// what `GlassJiggle.stretchFor` wants — timed by `sourceTimeStamp` since
  /// this widget has no render-tree velocity tracker of its own to read the
  /// way `InteractiveGlass` does.
  void _updateStretch(DragUpdateDetails details) {
    if (GlassReduceMotion.instance.value) {
      return;
    }
    final now = details.sourceTimeStamp;
    final x = details.localPosition.dx;
    final lastTimestamp = _lastTimestamp;
    if (now != null && lastTimestamp != null) {
      final dtMicros = (now - lastTimestamp).inMicroseconds;
      if (dtMicros > 0) {
        final speed =
            (x - _lastX).abs() / dtMicros * Duration.microsecondsPerSecond;
        _stretch.value = _jiggle.stretchFor(speed);
      }
    }
    _lastTimestamp = now;
    _lastX = x;
  }

  void _animateStretchTo(double target) {
    if (GlassReduceMotion.instance.value) {
      _stretch.value = target;
      return;
    }
    final motion = GlassTheme.motionOf(context, GlassMotionRole.settle);
    // The motion's tolerance is in pixels and [_stretch] is a ratio of the
    // thumb's size: rescaled, or a 0.5 px tolerance outweighs the whole
    // 0.18 stretch and the spring stops before it starts, leaving the
    // thumb stretched.
    final tolerance = motion.tolerance;
    _stretch.animateWith(
      SpringSimulation(
        motion.spring,
        _stretch.value,
        target,
        0,
        tolerance: Tolerance(
          distance: tolerance.distance / _thumbSize,
          time: tolerance.time,
          velocity: tolerance.velocity / _thumbSize,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    final currentValue = _currentValue;
    _textDirection = Directionality.of(context);
    return GlassControlFrame(
      onActivate: null,
      semanticLabel: widget.semanticLabel,
      button: false,
      slider: true,
      value: _formatValue(currentValue),
      increasedValue: enabled
          ? _formatValue(
              (currentValue + _stepSize).clamp(widget.min, widget.max),
            )
          : null,
      decreasedValue: enabled
          ? _formatValue(
              (currentValue - _stepSize).clamp(widget.min, widget.max),
            )
          : null,
      onIncrease: enabled ? _increase : null,
      onDecrease: enabled ? _decrease : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _trackWidth = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            // `down`, not the default `start` — see `GlassSwitch` for why:
            // the same touch-slop dropping the first movement applies here,
            // and a tap-to-set slider especially needs first contact to
            // register, not only movement past a threshold.
            dragStartBehavior: DragStartBehavior.down,
            onTapUp: enabled ? _onTapUp : null,
            onHorizontalDragStart: enabled ? _onDragStart : null,
            onHorizontalDragUpdate: enabled ? _onDragUpdate : null,
            onHorizontalDragEnd: enabled ? _onDragEnd : null,
            onHorizontalDragCancel: enabled ? _onDragCancel : null,
            child: _body(context, constraints.maxWidth, enabled: enabled),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, double width, {required bool enabled}) {
    final style = GlassTheme.surfaceOf(
      context,
      GlassSurfaceRole.control,
      size: Size(width, _thumbSize),
      backdrop: widget.backdrop,
    );
    final onGlass = GlassHostScope.isOnGlass(context);
    final trackColor = style.material.tint.withValues(
      alpha: style.material.tintOpacity,
    );
    final fillColor = style.labelColor;
    final thumb = _thumb(style: style, onGlass: onGlass);

    final visual = SizedBox(
      width: width,
      height: GlassControlFrame.minimumExtent,
      child: AnimatedBuilder(
        animation: Listenable.merge([_position, _stretch]),
        builder: (context, child) {
          final travel = (width - _thumbSize).clamp(0.0, double.infinity);
          // Thumb and fill both measure from the [GlassSlider.min] end —
          // the start edge, so the right one under RTL.
          final start = _position.value * travel;
          final filled = (start + _thumbSize / 2).clamp(0.0, width);
          final left = _textDirection == TextDirection.rtl
              ? travel - start
              : start;
          const trackTop = (GlassControlFrame.minimumExtent - _trackHeight) / 2;
          const thumbTop = (GlassControlFrame.minimumExtent - _thumbSize) / 2;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: trackTop,
                child: ClipPath(
                  // On content the thumb is glass, which the layer draws
                  // under the track's and fill's paint: leave a hole where
                  // it is, following its drag stretch. See
                  // [TrackCutoutClipper].
                  clipper: TrackCutoutClipper(
                    shape: style.shape,
                    hole: onGlass
                        ? null
                        : Rect.fromLTWH(
                            left,
                            thumbTop - trackTop,
                            _thumbSize,
                            _thumbSize,
                          ),
                    holeScale: Offset(_stretch.value, 1 / _stretch.value),
                  ),
                  child: SizedBox(
                    width: width,
                    height: _trackHeight,
                    child: Stack(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(color: trackColor),
                          child: SizedBox(width: width, height: _trackHeight),
                        ),
                        PositionedDirectional(
                          start: 0,
                          top: 0,
                          bottom: 0,
                          width: filled,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: fillColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: left,
                top: thumbTop,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(
                    _stretch.value,
                    1 / _stretch.value,
                    1,
                  ),
                  child: child,
                ),
              ),
            ],
          );
        },
        child: thumb,
      ),
    );

    return enabled ? visual : Opacity(opacity: _disabledOpacity, child: visual);
  }

  Widget _thumb({required GlassSurfaceStyle style, required bool onGlass}) {
    const size = SizedBox(width: _thumbSize, height: _thumbSize);
    if (onGlass) {
      return ClipPath(
        clipper: _SliderTrackClipper(style.shape),
        child: const DecoratedBox(
          decoration: BoxDecoration(color: _thumbColor),
          child: size,
        ),
      );
    }
    return Glass(shape: style.shape, child: size);
  }
}

/// Clips to [shape] at the real, laid-out size.
///
/// A local copy of the same two lines `GlassButton` and `GlassSwitch` each
/// carry under their own name — see either file's doc comment for why this
/// is not shared: the package's real clip lives on `Glass` itself and is
/// `@visibleForTesting` for that widget's own tests, not for other widgets
/// in this package to paint with.
class _SliderTrackClipper extends CustomClipper<Path> {
  const _SliderTrackClipper(this.shape);

  final GlassShape shape;

  @override
  Path getClip(Size size) =>
      shape.toBorder(size).getOuterPath(Offset.zero & size);

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) =>
      oldClipper is! _SliderTrackClipper || oldClipper.shape != shape;
}
