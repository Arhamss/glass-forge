import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:flutter/scheduler.dart';
import 'package:glass_forge/src/chrome/detent_geometry.dart';
import 'package:glass_forge/src/design/glass_motion_defaults.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/motion/glass_decay.dart';
import 'package:glass_forge/src/motion/glass_motion.dart';
import 'package:glass_forge/src/motion/reduce_motion.dart';
import 'package:glass_forge/src/motion/spring_axis.dart';

/// Drives one detent sheet's height.
///
/// An [Animation] of logical pixels, therefore a `ValueListenable`,
/// therefore something a `GlassPresence` can be driven from and a render
/// object can subscribe to. Nothing here calls `setState`: the widget
/// rebuilds its layout from this value through an `AnimatedBuilder` scoped
/// to the sheet alone, and the covered chrome's presence is derived from the
/// same object rather than pushed to it.
///
/// Height increases upward. A drag that raises the sheet is a positive
/// [dragBy]; a fling upward is a positive velocity.
class GlassDetentSheetController extends Animation<double>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin {
  /// Creates a controller with no detents yet. Call [setDetents] before use.
  GlassDetentSheetController({
    required TickerProvider vsync,
    this.settleMotion,
    this.decay = const GlassDecay(),
    this.respectReduceMotion = true,
  }) {
    _ticker = vsync.createTicker(_tick);
    if (respectReduceMotion) {
      GlassReduceMotion.instance.addListener(_onReduceMotionChanged);
    }
  }

  /// The spring the snap runs on, or null to let the sheet's theme decide.
  ///
  /// Null is the usual answer, and it is not "no spring": a
  /// `GlassDetentSheet` fills this in from the theme, with the spring the
  /// sheet *role* names, as soon as it has a `BuildContext` — and again
  /// whenever the theme changes. That is the whole point of the role layer,
  /// and it is why this is not a hand-written stiffness: a designer who
  /// retunes `GlassMotionDefaults.present` retunes this sheet with it.
  ///
  /// That spring is the `GlassMotionRole.present` role's, not `settle`'s,
  /// although a snap between detents is a settle: `GlassSurfaces` gives
  /// the sheet role `present`, the spring the sheet already rises on, so
  /// a sheet snaps to a detent the way it arrived rather than with the
  /// bounce a control settles with. Once a sheet has filled it in, reading
  /// this answers that spring, not null. Left null outside a sheet, the
  /// controller runs on the same role's untuned spring.
  ///
  /// Naming a spring here instead pins it, and the sheet leaves it alone
  /// afterwards — a caller who says which spring they want has said it for a
  /// reason. Assigning takes effect on the next frame of any snap already in
  /// flight, because the spring is read per tick rather than baked into a
  /// simulation.
  GlassMotion? settleMotion;

  /// The spring actually used, with [settleMotion] unset standing for the
  /// untuned value of the same theme lookup the sheet performs — so a
  /// controller driven outside a sheet moves exactly like one inside a sheet
  /// under the default theme, rather than like a second opinion written out
  /// by hand here.
  GlassMotion get _effectiveMotion => settleMotion ?? _defaultMotion;

  static final GlassMotion _defaultMotion = const GlassMotionDefaults().of(
    const GlassSurfaces().of(GlassSurfaceRole.sheet).motion,
  );

  /// How a fling's velocity is projected forward before the snap is chosen.
  final GlassDecay decay;

  /// Whether Reduce Motion collapses the snap to an instant settle.
  final bool respectReduceMotion;

  /// Called when the resting detent changes, never on every frame.
  ///
  /// One slot, and a mounted `GlassDetentSheet` owns it: the widget claims
  /// this field while it is attached to the controller and clears it on the
  /// way out, so a handler assigned here before or during that time is
  /// silently replaced. Callers inside a sheet want
  /// `GlassDetentSheet.onDetentChanged`, which is the same notification
  /// routed through the owner. This field is for a controller driven with no
  /// sheet attached to it.
  ///
  /// A single slot rather than a listener list because that is the whole of
  /// the need today — the sheet is the one consumer, and a list would be an
  /// API to keep rather than a convenience to use. Worth revisiting if a
  /// second consumer ever appears.
  ValueChanged<int>? onDetentChanged;

  /// The longest step the physics is advanced by in one frame.
  ///
  /// A resume guard, not a stability one: the spring is closed-form and
  /// exact at any step, but a sheet mid-snap when the app went to the
  /// background would otherwise fast-forward the whole elapsed wall clock in
  /// one frame.
  static const double _maxStep = 1 / 30;

  late final Ticker _ticker;

  final SpringAxis _axis = SpringAxis();
  List<double> _detents = const <double>[];
  int _detent = 0;
  bool _dragging = false;
  Duration _lastTick = Duration.zero;
  AnimationStatus _status = AnimationStatus.dismissed;

  @override
  double get value => _axis.position;

  @override
  AnimationStatus get status => _status;

  @override
  bool get isAnimating => _ticker.isActive;

  /// Whether a finger is currently carrying the sheet.
  bool get isDragging => _dragging;

  /// The resolved detent heights, ascending.
  List<double> get detents => _detents;

  /// Which detent the sheet is resting at, or heading to.
  int get detent => _detent;

  /// The lowest detent's height.
  double get lowest => _detents.isEmpty ? 0 : _detents.first;

  /// The top detent's height.
  double get top => _detents.isEmpty ? 0 : _detents.last;

  /// Replaces the detent heights, keeping the current detent *index*.
  ///
  /// Index, not height: a rotation re-resolves every fraction against a new
  /// window, and a sheet that was half open should still be half open
  /// afterwards. Keeping the pixel height instead would leave it at whatever
  /// fraction of the new window that number happens to be.
  void setDetents(List<double> heights, {int? initialDetent}) {
    assert(heights.isNotEmpty, 'a sheet needs at least one detent');
    final wasEmpty = _detents.isEmpty;
    _detents = List<double>.unmodifiable(heights);
    final index = initialDetent ?? _detent;
    _detent = index.clamp(0, _detents.length - 1);
    final target = _detents[_detent];
    _axis.target = target;
    if (wasEmpty || (!_dragging && !isAnimating)) {
      _axis
        ..position = target
        ..velocity = 0;
      _publish();
    }
  }

  /// Takes the sheet over from whatever was moving it.
  void beginDrag() {
    _dragging = true;
    _axis
      ..endFling()
      ..velocity = 0;
    _stopTicker();
  }

  /// Moves the sheet by [delta] logical pixels. Positive raises it.
  void dragBy(double delta) {
    if (_detents.isEmpty) {
      return;
    }
    // Clamped to the detent range rather than rubber-banded. A sheet dragged
    // past its top detent has nowhere to go — the screen ends — and one
    // dragged below its lowest is asking to be dismissed, which this widget
    // does not do. `GlassOverdrag` is the right tool the day either of
    // those becomes a gesture.
    _axis
      ..position = (_axis.position + delta).clamp(lowest, top)
      ..target = _axis.position
      ..velocity = 0;
    _publish();
  }

  /// Ends the drag and snaps, carrying [velocity] forward through friction.
  void endDrag({double velocity = 0}) {
    _dragging = false;
    if (_detents.isEmpty) {
      return;
    }
    final index = nearestDetentIndex(
      _detents,
      _axis.position,
      velocity: velocity,
      decay: decay,
    );
    _axis.velocity = velocity;
    _goTo(index);
  }

  /// Springs to [index].
  ///
  /// A call before the sheet has laid out is a no-op rather than an error.
  /// Detents are resolved inside `GlassDetentSheet`'s `LayoutBuilder`, so
  /// `initState`, a post-frame callback and a deep link restoring a saved
  /// detent all legitimately arrive before there is anywhere to go — which
  /// is why the assert below excuses the empty list and why [dragBy] and
  /// [endDrag] carry the same guard. An out-of-range index with detents
  /// present is the genuine programming error, and is still asserted; in
  /// release it is clamped, because a bare `RangeError` out of a sheet is a
  /// worse answer than the nearest detent.
  void animateToDetent(int index) {
    assert(
      _detents.isEmpty || (index >= 0 && index < _detents.length),
      'no detent at index $index; there are ${_detents.length}',
    );
    if (_detents.isEmpty) {
      return;
    }
    _goTo(index.clamp(0, _detents.length - 1));
  }

  void _goTo(int index) {
    final changed = index != _detent;
    _detent = index;
    _axis.target = _detents[index];

    if (respectReduceMotion && GlassReduceMotion.instance.value) {
      _axis.settleInstantly();
      _stopTicker();
      _publish();
    } else if (_axis.position != _axis.target || _axis.velocity != 0) {
      _startTicker();
    }

    if (changed) {
      onDetentChanged?.call(index);
    }
  }

  void _startTicker() {
    if (_ticker.isActive) {
      return;
    }
    _lastTick = Duration.zero;
    _status = AnimationStatus.forward;
    _ticker.start();
    notifyStatusListeners(_status);
  }

  void _stopTicker() {
    if (!_ticker.isActive) {
      return;
    }
    _ticker.stop();
    _status = AnimationStatus.completed;
    notifyStatusListeners(_status);
  }

  void _tick(Duration elapsed) {
    final seconds = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final dt = seconds > _maxStep ? _maxStep : seconds;
    if (dt <= 0) {
      return;
    }
    final motion = _effectiveMotion;
    final moving = _axis.advance(
      dt: dt,
      spring: motion.spring,
      tolerance: motion.tolerance,
    );
    _publish();
    if (!moving) {
      _stopTicker();
    }
  }

  /// Notifies listeners, but never in the middle of somebody else's build.
  ///
  /// `GlassDetentSheet` resolves its detents inside a `LayoutBuilder`,
  /// because the available height is the one number only layout can supply,
  /// and resolving them calls [setDetents] — so on the first layout this
  /// notifier would fire during the build/layout phase. A listener that has
  /// already been built by then is a *sibling* of the sheet rather than a
  /// descendant of it, and marking one of those dirty mid-build throws
  /// "setState called during build". The arrangement is not exotic: a bottom
  /// bar fading out under a rising sheet is exactly an `AnimatedBuilder` on
  /// this controller standing next to the sheet.
  ///
  /// Only the *notification* waits. Everything the caller changed — the
  /// detent heights, the index, the position — is already in place, so the
  /// sheet's own subtree, which is built from this value moments later
  /// inside that same layout pass, sees the new height on the very frame
  /// that resolved it. The frame the siblings lose is the frame before the
  /// sheet had a height at all.
  void _publish() {
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      notifyListeners();
      return;
    }
    if (_deferredPublish) {
      return;
    }
    _deferredPublish = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _deferredPublish = false;
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  /// Whether a [_publish] is already waiting for the end of this frame.
  bool _deferredPublish = false;

  /// Whether [dispose] has run, so a deferred [_publish] can stand down.
  bool _disposed = false;

  void _onReduceMotionChanged() {
    if (!GlassReduceMotion.instance.value || !isAnimating) {
      return;
    }
    _axis.settleInstantly();
    _stopTicker();
    _publish();
  }

  /// How present glass chrome between [start] and [end] should be.
  ///
  /// 1 while the sheet's top edge is below [start], 0 once it has reached
  /// [end], linear in between — both measured, like the height itself, from
  /// the bottom of the sheet's available area.
  ///
  /// This is the handoff, not a cross-fade. Where the sheet floats above a
  /// bottom bar, both want to be glass over the same pixels, and two backdrop
  /// filters over one region is flutter#187820: the upper pass samples the
  /// lower one's output and white-washes over time. So the bar's presence
  /// reaches 0 *before* the sheet's glass arrives, driven by the same height
  /// that drives the morph, which is what keeps the two in step through a
  /// drag that stops and reverses half way.
  Animation<double> presenceUnder({
    required double start,
    required double end,
  }) {
    assert(end >= start, 'the ramp ends above where it starts');
    return drive(_CoverTween(start: start, end: end));
  }

  @override
  void dispose() {
    _disposed = true;
    if (respectReduceMotion) {
      GlassReduceMotion.instance.removeListener(_onReduceMotionChanged);
    }
    _ticker.dispose();
    super.dispose();
  }

  @override
  String toString() =>
      'GlassDetentSheetController(${value.toStringAsFixed(1)}px, '
      'detent $_detent of ${_detents.length})';
}

/// Maps a sheet height to how present the chrome under it should be.
class _CoverTween extends Animatable<double> {
  const _CoverTween({required this.start, required this.end});

  final double start;
  final double end;

  @override
  double transform(double height) {
    if (height <= start) {
      return 1;
    }
    if (end <= start || height >= end) {
      // A zero-width ramp is a step. Dividing by the span would be a divide
      // by zero, and NaN in a presence uniform paints nothing at all.
      return 0;
    }
    return 1 - (height - start) / (end - start);
  }
}
