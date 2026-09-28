import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/controls/control_frame.dart';
import 'package:glass_forge/src/design/glass_motion_defaults.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/motion/reduce_motion.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_host_scope.dart';

/// One choice in a [GlassSegmentedControl]: what selecting it reports, and
/// what is drawn for it.
@immutable
class GlassSegment<T> {
  /// Creates a segment.
  const GlassSegment({required this.value, required this.label});

  /// What [GlassSegmentedControl.onChanged] is called with when this
  /// segment is chosen, and what [GlassSegmentedControl.selected] is
  /// compared against with `==` to find it again.
  final T value;

  /// This segment's own visual — usually a [Text]. Its semantics are
  /// excluded the same as every control's content in this package; see
  /// [GlassControlFrame].
  final Widget label;
}

/// A row of mutually exclusive choices under a travelling glass pill.
///
/// | | On content | On a glass surface |
/// |---|---|---|
/// | Track | painted | painted |
/// | Pill | `Glass` | painted |
///
/// The pill travels to the selected segment on the theme's `settle` spring,
/// and can be dragged directly from anywhere in the control — not only from
/// the pill itself, the same reach `GlassSlider` gives its thumb. A drag
/// moves the pill continuously under the finger; only on release does it
/// snap to the nearest segment and, if that changed the selection, call
/// [onChanged].
///
/// ```dart
/// GlassSegmentedControl<int>(
///   segments: const [
///     GlassSegment(value: 0, label: Text('Day')),
///     GlassSegment(value: 1, label: Text('Week')),
///     GlassSegment(value: 2, label: Text('Month')),
///   ],
///   selected: range,
///   onChanged: (next) => setState(() => range = next),
/// )
/// ```
///
/// `onChanged: null` disables it: no tap, no drag, no arrow-key step, and
/// the callback never runs. Each segment is its own selectable button —
/// [GlassControlFrame] gives it semantics, focus, a 44 × 44 minimum hit
/// target and Enter/Space activation — and reports
/// `SemanticsFlag.isSelected` for exactly the one whose [GlassSegment.value]
/// equals [selected]. The left and right arrow keys (up and down too) move
/// the selection by one segment while any segment is focused, through the
/// same [GlassControlFrame.onIncrease] and [GlassControlFrame.onDecrease]
/// `GlassSlider` steps with.
class GlassSegmentedControl<T> extends StatefulWidget {
  /// Creates a segmented control.
  const GlassSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.backdrop,
    super.key,
  });
  // Both `segments` non-empty and `selected` being one of their values are
  // asserted in `_GlassSegmentedControlState.initState`, not here: a
  // `List.length` read is not a constant expression, and this constructor
  // stays `const`-constructible for callers whose segments and callback
  // are const.

  /// The choices, left to right. Never empty — see the class doc.
  final List<GlassSegment<T>> segments;

  /// The value of the currently chosen segment.
  ///
  /// Must equal [GlassSegment.value] for one of [segments]; a caller
  /// passing something else is a caller bug this widget asserts against in
  /// debug rather than papering over.
  final T selected;

  /// Called with the newly selected segment's value on a tap, a settled
  /// drag that changed the selection, or an arrow-key step. Null renders
  /// this control disabled.
  final ValueChanged<T>? onChanged;

  /// What is behind this control, for the same adaptation `GlassSurface`
  /// offers.
  final Color? backdrop;

  @override
  State<GlassSegmentedControl<T>> createState() =>
      _GlassSegmentedControlState<T>();
}

class _GlassSegmentedControlState<T> extends State<GlassSegmentedControl<T>>
    with SingleTickerProviderStateMixin {
  /// The whole control's height, and the tappable height of every segment —
  /// `GlassControlFrame.minimumExtent` itself, the same reach `GlassSlider`
  /// gives its own track: the draggable hit area is the full visual, not a
  /// narrower painted strip inside it.
  static const double _height = GlassControlFrame.minimumExtent;

  /// The gap between the pill and the edges of the segment slot it fills.
  static const double _pillInset = 3;

  /// The pill's own colour, painted under [GlassHostScope]. Always white —
  /// the same reasoning, and the same lack of a capture to confirm against,
  /// as `GlassSwitch._knobColor` and `GlassSlider._thumbColor`.
  static const Color _pillColor = Color(0xFFFFFFFF);

  static const double _disabledOpacity = 0.4;

  /// The pill's position as a fraction of its total travel, 0 to 1, across
  /// [_lastIndex] index steps — the same domain `GlassSlider._position`
  /// uses for its own continuous value, reused here for a discrete index so
  /// a single segment (`_lastIndex` zero) has nothing to divide by rather
  /// than a division by zero.
  late final AnimationController _position;

  /// The index [_position] is currently springing toward, or was last
  /// dragged to. Compared against the index [GlassSegmentedControl.selected]
  /// resolves to in [didUpdateWidget], the same reason `GlassSwitch._target`
  /// exists: a live drag or a spring already in flight from this widget's
  /// own call to `onChanged` should not be re-targeted by the echo of that
  /// same call coming back down through the constructor.
  late int _targetIndex;

  /// Whether a drag is currently driving [_position] directly — see
  /// `GlassSwitch._dragging`, the same reason.
  bool _dragging = false;

  /// The most recent build's track width, read by the drag handlers, which
  /// run outside `build` and have no constraints of their own to ask.
  double _trackWidth = 0;

  int get _segmentCount => widget.segments.length;

  /// The highest valid segment index. Zero for one segment.
  int get _lastIndex => _segmentCount - 1;

  double get _segmentWidth =>
      _segmentCount == 0 ? 0 : _trackWidth / _segmentCount;

  /// How far the pill's left edge can travel, in logical pixels.
  double get _travel =>
      (_trackWidth - _segmentWidth).clamp(0.0, double.infinity);

  @override
  void initState() {
    super.initState();
    assert(
      widget.segments.isNotEmpty,
      'GlassSegmentedControl.segments must not be empty',
    );
    _targetIndex = _indexOf(widget.selected);
    assert(
      _targetIndex != -1,
      'GlassSegmentedControl.selected must be the value of one of '
      'segments',
    );
    _position = AnimationController(
      vsync: this,
      value: _fractionOf(_targetIndex),
    );
    GlassReduceMotion.instance.addListener(_onReduceMotionChanged);
  }

  @override
  void didUpdateWidget(GlassSegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging) {
      final desired = _indexOf(widget.selected);
      assert(
        desired != -1,
        'GlassSegmentedControl.selected must be the value of one of '
        'segments',
      );
      if (desired != _targetIndex) {
        _animateTo(desired);
      }
    }
  }

  @override
  void dispose() {
    GlassReduceMotion.instance.removeListener(_onReduceMotionChanged);
    _position.dispose();
    super.dispose();
  }

  void _onReduceMotionChanged() {
    if (GlassReduceMotion.instance.value && _position.isAnimating) {
      _position.value = _fractionOf(_targetIndex);
    }
  }

  int _indexOf(T value) =>
      widget.segments.indexWhere((segment) => segment.value == value);

  /// [index] as a fraction of the pill's travel, 0 to 1. [_lastIndex] at or
  /// below zero — a single segment — resolves to a fixed 0 rather than
  /// dividing by it, the same guard `GlassSlider._fractionOf` applies to a
  /// zero-width value range.
  double _fractionOf(int index) {
    if (_lastIndex <= 0) {
      return 0;
    }
    return (index / _lastIndex).clamp(0.0, 1.0);
  }

  /// The nearest segment index to [_position]'s current fraction.
  int _nearestIndex() {
    if (_lastIndex <= 0) {
      return 0;
    }
    return (_position.value * _lastIndex).round().clamp(0, _lastIndex);
  }

  void _animateTo(int index, {double velocity = 0}) {
    _targetIndex = index;
    final target = _fractionOf(index);
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

  void _select(int index) {
    final onChanged = widget.onChanged;
    if (onChanged == null) {
      return;
    }
    final clamped = index.clamp(0, _lastIndex);
    if (clamped == _targetIndex) {
      return;
    }
    _animateTo(clamped);
    onChanged(widget.segments[clamped].value);
  }

  void _selectNext() => _select(_targetIndex + 1);

  void _selectPrevious() => _select(_targetIndex - 1);

  void _onDragStart(DragStartDetails details) {
    _dragging = true;
    _position.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final travel = _travel;
    if (travel <= 0) {
      return;
    }
    final delta = (details.primaryDelta ?? 0) / travel;
    _position.value = (_position.value + delta).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    _dragging = false;
    final nearest = _nearestIndex();
    final changed = nearest != _targetIndex;
    final travel = _travel;
    final velocity = travel > 0
        ? details.velocity.pixelsPerSecond.dx / travel
        : 0.0;
    _animateTo(nearest, velocity: velocity);
    if (changed) {
      widget.onChanged?.call(widget.segments[nearest].value);
    }
  }

  void _onDragCancel() {
    _dragging = false;
    _animateTo(_nearestIndex());
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        _trackWidth = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // `down`, not the default `start` — see `GlassSwitch` and
          // `GlassSlider` for why: the touch-slop distance that clears
          // before `start` reports anything would otherwise be dropped
          // rather than delayed, and this pill has just as little travel
          // to spare.
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: enabled ? _onDragStart : null,
          onHorizontalDragUpdate: enabled ? _onDragUpdate : null,
          onHorizontalDragEnd: enabled ? _onDragEnd : null,
          onHorizontalDragCancel: enabled ? _onDragCancel : null,
          child: _body(context, constraints.maxWidth, enabled: enabled),
        );
      },
    );
  }

  Widget _body(BuildContext context, double width, {required bool enabled}) {
    final style = GlassTheme.surfaceOf(
      context,
      GlassSurfaceRole.control,
      size: Size(width, _height),
      backdrop: widget.backdrop,
    );
    final onGlass = GlassHostScope.isOnGlass(context);
    final trackColor = style.material.tint.withValues(
      alpha: style.material.tintOpacity,
    );
    final segmentWidth = _segmentWidth;
    final pill = _pill(style: style, onGlass: onGlass, width: segmentWidth);

    final visual = SizedBox(
      width: width,
      height: _height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: _SegmentedTrackClipper(style.shape),
              child: DecoratedBox(
                decoration: BoxDecoration(color: trackColor),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _position,
            builder: (context, child) {
              final left = _travel * _position.value;
              return Positioned(
                left: left,
                top: _pillInset,
                bottom: _pillInset,
                width: (segmentWidth - 2 * _pillInset).clamp(
                  0.0,
                  double.infinity,
                ),
                child: child!,
              );
            },
            child: pill,
          ),
          Positioned.fill(
            child: Row(
              children: [
                for (var i = 0; i < _segmentCount; i++)
                  Expanded(
                    child: _segment(i, enabled: enabled, style: style),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return enabled ? visual : Opacity(opacity: _disabledOpacity, child: visual);
  }

  Widget _segment(
    int index, {
    required bool enabled,
    required GlassSurfaceStyle style,
  }) {
    final segment = widget.segments[index];
    return GlassControlFrame(
      onActivate: enabled ? () => _select(index) : null,
      onIncrease: enabled ? _selectNext : null,
      onDecrease: enabled ? _selectPrevious : null,
      selected: segment.value == widget.selected,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: style.labelColor),
        child: segment.label,
      ),
    );
  }

  Widget _pill({
    required GlassSurfaceStyle style,
    required bool onGlass,
    required double width,
  }) {
    final size = SizedBox(
      width: (width - 2 * _pillInset).clamp(0.0, double.infinity),
      height: _height - 2 * _pillInset,
    );
    if (onGlass) {
      return ClipPath(
        clipper: _SegmentedTrackClipper(style.shape),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: _pillColor),
          child: size,
        ),
      );
    }
    return Glass(shape: style.shape, child: size);
  }
}

/// Clips to [shape] at the real, laid-out size.
///
/// A local copy of the same two lines `GlassButton`, `GlassSwitch` and
/// `GlassSlider` each carry under their own name — see any of their doc
/// comments for why this is not shared: the package's real clip lives on
/// `Glass` itself and is `@visibleForTesting` for that widget's own tests,
/// not for other widgets in this package to paint with.
class _SegmentedTrackClipper extends CustomClipper<Path> {
  const _SegmentedTrackClipper(this.shape);

  final GlassShape shape;

  @override
  Path getClip(Size size) =>
      shape.toBorder(size).getOuterPath(Offset.zero & size);

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) =>
      oldClipper is! _SegmentedTrackClipper || oldClipper.shape != shape;
}
