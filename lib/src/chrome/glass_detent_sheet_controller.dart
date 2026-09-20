import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:glass_forge/src/chrome/detent_geometry.dart';
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
    this.settleMotion = const GlassMotion.smooth(
      duration: Duration(milliseconds: 400),
    ),
    this.decay = const GlassDecay(),
    this.respectReduceMotion = true,
  }) {
    _ticker = vsync.createTicker(_tick);
    _spring = settleMotion.spring;
    _tolerance = settleMotion.tolerance;
    if (respectReduceMotion) {
      GlassReduceMotion.instance.addListener(_onReduceMotionChanged);
    }
  }

  /// The spring the snap runs on.
  ///
  /// Defaults to the same values `GlassMotionDefaults.present` carries, and
  /// for the same reason stated there: a sheet that springs past its detent
  /// and comes back reads as a mistake rather than as liveliness.
  final GlassMotion settleMotion;

  /// How a fling's velocity is projected forward before the snap is chosen.
  final GlassDecay decay;

  /// Whether Reduce Motion collapses the snap to an instant settle.
  final bool respectReduceMotion;

  /// Called when the resting detent changes, never on every frame.
  ValueChanged<int>? onDetentChanged;

  /// The longest step the physics is advanced by in one frame.
  ///
  /// A resume guard, not a stability one: the spring is closed-form and
  /// exact at any step, but a sheet mid-snap when the app went to the
  /// background would otherwise fast-forward the whole elapsed wall clock in
  /// one frame.
  static const double _maxStep = 1 / 30;

  late final Ticker _ticker;
  late final SpringDescription _spring;
  late final Tolerance _tolerance;

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
  void animateToDetent(int index) {
    assert(
      index >= 0 && index < _detents.length,
      'no detent at index $index; there are ${_detents.length}',
    );
    _goTo(index);
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
    final moving = _axis.advance(
      dt: dt,
      spring: _spring,
      tolerance: _tolerance,
    );
    _publish();
    if (!moving) {
      _stopTicker();
    }
  }

  void _publish() => notifyListeners();

  void _onReduceMotionChanged() {
    if (!GlassReduceMotion.instance.value || !isAnimating) {
      return;
    }
    _axis.settleInstantly();
    _stopTicker();
    _publish();
  }

  @override
  void dispose() {
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
