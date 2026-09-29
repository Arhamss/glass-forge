import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/controls/control_frame.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/design/glass_tint.dart';
import 'package:glass_forge/src/motion/settle_spring.dart';
import 'package:glass_forge/src/shapes/glass_shape_clipper.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_host_scope.dart';

/// One choice in a [GlassSegmentedControl]: what selecting it reports, and
/// what is drawn for it.
@immutable
class GlassSegment<T> {
  /// Creates a segment.
  const GlassSegment({
    required this.value,
    required this.label,
    this.semanticLabel,
  });

  /// What [GlassSegmentedControl.onChanged] is called with when this
  /// segment is chosen, and what [GlassSegmentedControl.selected] is
  /// compared against with `==` to find it again.
  final T value;

  /// This segment's own visual — usually a [Text], whose words also name
  /// the segment to a screen reader unless [semanticLabel] is given.
  final Widget label;

  /// The accessible name read for this segment.
  ///
  /// Null, the default, reads the text [label] already shows. Give one when
  /// [label] is an icon, or abbreviates what a screen reader should say in
  /// full.
  final String? semanticLabel;
}

/// A row of mutually exclusive choices under a travelling glass pill.
///
/// | | On content | On a glass surface |
/// |---|---|---|
/// | Track | painted, around the pill | painted |
/// | Pill | `Glass` | painted |
///
/// On content the painted parts leave a hole the shape of the glass
/// element and follow it as it moves, because a `GlassLayer` draws its
/// glass under whatever its subtree paints; see `GlassShapeClipper`.
///
/// The pill travels to the selected segment on the theme's `settle` spring,
/// and can be dragged directly from anywhere in the control — not only from
/// the pill itself, the same reach `GlassSlider` gives its thumb. A drag
/// moves the pill continuously under the finger; only on release does it
/// snap to the nearest segment and, if that changed the selection, call
/// [onChanged].
///
/// The pill always ends up under [selected]. It springs toward a new
/// choice at once, for feel, then reports it; if the owner has not rebuilt
/// with that value by the next frame — it declined the change, or is still
/// deciding — the pill springs back, and a later rebuild with the new value
/// moves it again. Only the segment at [selected] ever reports itself
/// selected.
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
/// equals [selected]. Each is named by its [GlassSegment.label] text, or by
/// [GlassSegment.semanticLabel] when given. The left and right arrow keys
/// (up and down too) move the selection by one segment while any segment
/// is focused. That is a keyboard affordance only: segments do not expose
/// increase and decrease semantics actions, which would announce each one
/// as adjustable, a slider's role.
///
/// Under [TextDirection.rtl] the whole control mirrors: the first segment
/// sits on the right, the pill and a drag travel right to left, and the
/// left arrow moves to the next segment, as the horizontal arrows follow
/// the reading direction.
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

  /// The choices, in reading order: left to right, or right to left under
  /// [TextDirection.rtl]. Never empty — see the class doc.
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
    with SingleTickerProviderStateMixin, ReduceMotionSnap {
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

  /// The most recent build's reading direction, read by the drag handlers
  /// for the same reason as [_trackWidth]. Under [TextDirection.rtl] the
  /// `Row` of segments puts index 0 on the right, so the pill and a drag
  /// both measure [_position] from the right edge instead.
  TextDirection _textDirection = TextDirection.ltr;

  /// +1 when [_position] grows left to right, -1 when it grows right to
  /// left — what a horizontal pixel delta is multiplied by to move it.
  double get _direction => _textDirection == TextDirection.rtl ? -1 : 1;

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
  }

  @override
  void didUpdateWidget(GlassSegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragging && widget.onChanged == null) {
      // Disabled under the finger. The drag recognizer is dropped without
      // an end or a cancel, so the drag is over here: the pill goes back
      // to [GlassSegmentedControl.selected], and nothing is reported.
      _dragging = false;
      final index = _indexOf(widget.selected);
      if (index != -1) {
        _animateTo(index);
      }
    }
    if (!_dragging && oldWidget.segments.length != widget.segments.length) {
      // [_position] is a fraction of [_lastIndex], so a new segment count
      // moves every index under it: 0.5 is index 1 of three but index 2 of
      // five. The pill's width changes in the same frame, so it jumps to
      // the selected segment's new fraction rather than springing there.
      final index = _indexOf(widget.selected);
      if (index != -1) {
        _targetIndex = index;
        _position.value = _fractionOf(index);
      }
    }
    _followSelected();
  }

  /// Springs the pill to [GlassSegmentedControl.selected] unless a drag
  /// owns it or it is already heading there.
  void _followSelected() {
    if (_dragging) {
      return;
    }
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

  /// Reports the segment at [index] to [onChanged], then checks after the
  /// next frame that the owner took it: an owner that declined, or has not
  /// rebuilt yet, has left [GlassSegmentedControl.selected] where it was,
  /// and the pill springs back to it.
  void _report(ValueChanged<T> onChanged, int index) {
    onChanged(widget.segments[index].value);
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) {
          _followSelected();
        }
      })
      ..ensureVisualUpdate();
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  void didChangeReduceMotion({required bool reduceMotion}) {
    if (reduceMotion && _position.isAnimating) {
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
    // [_position] is a fraction of [_travel], so one unit of it is
    // [_travel] pixels: unscaled, a 0.5 px tolerance reads as half the
    // track and the spring stops well short of the segment.
    _position.settleTo(
      context,
      _fractionOf(index),
      pixelsPerUnit: _travel,
      velocity: velocity,
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
    _report(onChanged, clamped);
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
    final delta = _direction * (details.primaryDelta ?? 0) / travel;
    _position.value = (_position.value + delta).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    _dragging = false;
    final nearest = _nearestIndex();
    final changed = nearest != _targetIndex;
    final travel = _travel;
    final velocity = travel > 0
        ? _direction * details.velocity.pixelsPerSecond.dx / travel
        : 0.0;
    _animateTo(nearest, velocity: velocity);
    final onChanged = widget.onChanged;
    if (changed && onChanged != null) {
      _report(onChanged, nearest);
    }
  }

  void _onDragCancel() {
    _dragging = false;
    _animateTo(_nearestIndex());
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    _textDirection = Directionality.of(context);
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
    final pill = _pill(style: style, onGlass: onGlass);

    final visual = SizedBox(
      width: width,
      height: _height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _position,
            builder: (context, child) {
              final pill = _pillRect(segmentWidth);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ClipPath(
                      // On content the pill is glass, which the layer
                      // draws under the track's paint: leave a hole where
                      // it is. See [GlassShapeClipper].
                      clipper: GlassShapeClipper(
                        style.shape,
                        hole: onGlass ? null : pill,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: trackColor),
                      ),
                    ),
                  ),
                  Positioned.fromRect(rect: pill, child: child!),
                ],
              );
            },
            child: pill,
          ),
          Positioned.fill(
            child: Row(
              children: [
                for (var i = 0; i < _segmentCount; i++)
                  Expanded(
                    child: _segment(
                      i,
                      enabled: enabled,
                      style: style,
                      onGlass: onGlass,
                    ),
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
    required bool onGlass,
  }) {
    final segment = widget.segments[index];
    final selected = segment.value == widget.selected;
    return GlassControlFrame(
      onActivate: enabled ? () => _select(index) : null,
      onIncrease: enabled ? _selectNext : null,
      onDecrease: enabled ? _selectPrevious : null,
      selected: selected,
      semanticLabel: segment.semanticLabel,
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: _labelColorFor(
            style: style,
            onGlass: onGlass,
            selected: selected,
          ),
        ),
        child: segment.label,
      ),
    );
  }

  /// The colour a segment's label is drawn in.
  ///
  /// Every segment but the selected one sits on the track, whose tint is
  /// exactly what `style.labelColor` was chosen to clear — the package-wide
  /// promise `glass_surfaces_test.dart` proves for every role. The selected
  /// segment sits on the pill instead, and the pill is not always that same
  /// surface: off a glass host it is a real [Glass] drawn in the ambient
  /// material, so `style.labelColor` is still the right label; on a glass
  /// host — where a second backdrop pass is refused (flutter#187820) — the
  /// pill in [_pill] paints flat instead, and always white, the same
  /// deliberate choice `GlassSwitch._knobColor` and `GlassSlider._thumbColor`
  /// make. That fixed white surface is decoupled from whichever material
  /// `style.labelColor` was tuned against, so a dark scheme's white label
  /// would land on it invisibly. The selected label on that one surface
  /// takes the light scheme's own label colour instead — pure black, the ink
  /// [GlassTintRamp.appleLight] already guarantees reads against a light
  /// surface, and the painted pill is exactly that.
  Color _labelColorFor({
    required GlassSurfaceStyle style,
    required bool onGlass,
    required bool selected,
  }) {
    if (selected && onGlass) {
      return GlassTintRamp.appleLight.label;
    }
    return style.labelColor;
  }

  /// Where the pill is at [_position], in this control's own box: its
  /// segment slot, inset by [_pillInset] on every side. Measured from the
  /// right edge under [TextDirection.rtl], where the first segment is.
  Rect _pillRect(double segmentWidth) => Rect.fromLTWH(
    _pillInset +
        _travel *
            (_textDirection == TextDirection.rtl
                ? 1 - _position.value
                : _position.value),
    _pillInset,
    (segmentWidth - 2 * _pillInset).clamp(0.0, double.infinity),
    _height - 2 * _pillInset,
  );

  Widget _pill({required GlassSurfaceStyle style, required bool onGlass}) {
    if (onGlass) {
      return ClipPath(
        clipper: GlassShapeClipper(style.shape),
        child: const DecoratedBox(
          decoration: BoxDecoration(color: _pillColor),
          child: SizedBox.expand(),
        ),
      );
    }
    return Glass(shape: style.shape, child: const SizedBox.expand());
  }
}
