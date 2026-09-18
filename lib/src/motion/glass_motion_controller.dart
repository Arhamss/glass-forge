import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:glass_forge/src/motion/glass_decay.dart';
import 'package:glass_forge/src/motion/glass_motion.dart';
import 'package:glass_forge/src/motion/glass_motion_state.dart';
import 'package:glass_forge/src/motion/glass_overdrag.dart';
import 'package:glass_forge/src/motion/reduce_motion.dart';
import 'package:glass_forge/src/motion/spring_axis.dart';

/// Which spring the translation channels are currently running.
enum GlassMotionPhase {
  /// Nothing is holding the surface and nothing is moving it.
  idle,

  /// A pointer is down and the surface is chasing it.
  following,

  /// The pointer is gone and the surface is springing back.
  settling,

  /// Friction is carrying the surface after a fling.
  flinging,
}

/// Drives one glass surface's live deformation.
///
/// An [Animation], therefore a [ValueListenable], therefore something a
/// render object can subscribe to with `addListener(markNeedsPaint)`. That is
/// the whole point: nothing here ever calls `setState`, and no widget
/// rebuilds while a surface is in motion. `RenderGlassShape` re-reads
/// `getTransformTo(layer)` at paint time and re-registers its geometry, so a
/// render object above it that applies this controller's transform in both
/// `paint` and `applyPaintTransform` reaches the shader with no element tree
/// involvement at all.
///
/// Three channels: x and y translation, and press depth. Squash and stretch
/// is **not** a fourth — it is read off the translation channels' velocity,
/// see `GlassJiggle`.
class GlassMotionController extends Animation<GlassMotionState>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin {
  /// Creates a controller at rest.
  GlassMotionController({
    required TickerProvider vsync,
    this.followMotion = const GlassMotion.interactive(),
    this.settleMotion = const GlassMotion.bouncy(),
    this.pressMotion = const GlassMotion.snappy(
      duration: Duration(milliseconds: 320),
    ),
    this.decay = const GlassDecay(),
    this.overdrag = const GlassOverdrag.none(),
    this.respectReduceMotion = true,
  }) {
    _ticker = vsync.createTicker(_tick);
    // Resolved once, springs and tolerances alike. `CupertinoMotion
    // .description` rebuilds a SpringDescription from a sqrt and a pow on
    // every single access, and `GlassMotion.tolerance` allocates; reading
    // either per frame — or worse, per axis per frame — is a real cost for
    // values that cannot change.
    _followSpring = followMotion.spring;
    _settleSpring = settleMotion.spring;
    _pressSpring = pressMotion.spring;
    _followTolerance = followMotion.tolerance;
    _settleTolerance = settleMotion.tolerance;
    _pressTolerance = pressMotion.scaledTo(_pressTravelPixels).tolerance;
    if (respectReduceMotion) {
      GlassReduceMotion.instance.addListener(_onReduceMotionChanged);
    }
  }

  /// The spring that runs while a pointer is down.
  final GlassMotion followMotion;

  /// The spring that runs once the pointer is gone.
  final GlassMotion settleMotion;

  /// The spring the press channel runs, in both directions.
  final GlassMotion pressMotion;

  /// How a fling decays.
  final GlassDecay decay;

  /// How far the surface may be dragged from rest, and how hard it resists.
  final GlassOverdrag overdrag;

  /// Whether the platform's Reduce Motion setting collapses every spring
  /// here to an instant settle.
  final bool respectReduceMotion;

  /// How many logical pixels of movement the press channel stands for.
  ///
  /// Only ever used to convert the press spring's settle thresholds — stated
  /// in pixels, like every other threshold in this package — into the press
  /// channel's own unitless 0-to-1 range. It changes nothing visible; it is
  /// the difference between the press settling when it is within half a
  /// pixel of done and settling when it is within half of its entire range.
  static const double _pressTravelPixels = 8;

  /// The longest step the physics is advanced by in one frame.
  ///
  /// Not a stability guard — the closed form in [SpringAxis] is exact at any
  /// step. It is a resume guard: a surface that was mid-spring when the app
  /// went to the background, or when `TickerMode` muted its subtree, would
  /// otherwise fast-forward the whole elapsed wall clock in a single frame
  /// and appear to teleport.
  static const double _maxStep = 1 / 30;

  late final Ticker _ticker;
  final SpringAxis _x = SpringAxis();
  final SpringAxis _y = SpringAxis();
  final SpringAxis _press = SpringAxis();

  late final SpringDescription _followSpring;
  late final SpringDescription _settleSpring;
  late final SpringDescription _pressSpring;
  late final Tolerance _followTolerance;
  late final Tolerance _settleTolerance;
  late final Tolerance _pressTolerance;

  Duration _lastTick = Duration.zero;
  GlassMotionPhase _phase = GlassMotionPhase.idle;
  GlassMotionState _value = GlassMotionState.rest;
  AnimationStatus _status = AnimationStatus.dismissed;
  Offset _pressAnchor = Offset.zero;

  @override
  GlassMotionState get value => _value;

  @override
  AnimationStatus get status => _status;

  @override
  bool get isAnimating => _ticker.isActive;

  /// What the translation channels are doing.
  GlassMotionPhase get phase => _phase;

  /// Whether the platform is currently asking for reduced motion.
  bool get isReduced => respectReduceMotion && GlassReduceMotion.instance.value;

  /// Moves the surface's target to [rawDisplacement], rubber-banded.
  ///
  /// This is the follow primitive. Call it once per pointer move: it assigns
  /// three doubles and, at most, starts a ticker that is usually already
  /// running.
  ///
  /// motor's only equivalent is `animateTo`, which allocates a fresh
  /// [Simulation] per dimension, discards the running ones and restarts the
  /// ticker on every call (see `docs/reference/motor_teardown.md`). At 120 Hz
  /// that is 240 simulation allocations and 120 ticker restarts a second,
  /// for one gesture.
  void follow(Offset rawDisplacement) {
    final banded = overdrag.apply(rawDisplacement);
    _x
      ..endFling()
      ..target = banded.dx;
    _y
      ..endFling()
      ..target = banded.dy;
    _phase = GlassMotionPhase.following;
    _begin();
  }

  /// The raw pointer displacement that would put the surface where it is.
  ///
  /// A gesture that starts while the surface is still travelling has to
  /// resume from the current displacement rather than from zero, or the
  /// surface snaps to the finger the moment it moves. With no rubber band
  /// this is just the current translation; with one it is the inverse of the
  /// band.
  Offset get rawDisplacement {
    final current = Offset(_x.position, _y.position);
    final distance = current.distance;
    if (distance == 0) {
      return Offset.zero;
    }
    return current * (overdrag.rawForScalar(distance) / distance);
  }

  /// Releases the surface: it springs to [to], carrying its velocity.
  ///
  /// [withVelocity] overrides the spring's own velocity with the pointer's.
  /// Those are not the same number and the difference is the point — the
  /// spring has been lagging behind the finger for the whole gesture, so
  /// handing off its own velocity throws away most of the flick.
  void release({Offset to = Offset.zero, Offset? withVelocity}) {
    _x
      ..endFling()
      ..target = to.dx;
    _y
      ..endFling()
      ..target = to.dy;
    if (withVelocity != null) {
      _x.velocity = withVelocity.dx;
      _y.velocity = withVelocity.dy;
    }
    _phase = GlassMotionPhase.settling;
    _begin();
  }

  /// Flings the surface at [velocity] logical pixels per second.
  ///
  /// Friction carries it; when friction gives out the settle spring takes
  /// over toward [settleAt], which defaults to wherever friction was heading
  /// — clamped into [overdrag]'s band, so a hard fling on a bounded surface
  /// overshoots and springs back rather than leaving its layer.
  void fling(Offset velocity, {Offset? settleAt}) {
    _x.fling(decay, velocity.dx);
    _y.fling(decay, velocity.dy);
    final resting = Offset(
      decay.restingPoint(start: _x.position, velocity: velocity.dx),
      decay.restingPoint(start: _y.position, velocity: velocity.dy),
    );
    final target = settleAt ?? overdrag.apply(resting);
    _x.target = target.dx;
    _y.target = target.dy;
    _phase = GlassMotionPhase.flinging;
    _begin();
  }

  /// Presses the surface toward the layer, or lets it back up.
  void setPressed({required bool pressed}) {
    _press.target = pressed ? 1 : 0;
    _begin();
  }

  /// Records where the finger is, relative to the surface's centre.
  ///
  /// Not sprung: it is multiplied by the press depth wherever it is read,
  /// and that is already sprung. See `GlassPressStretch`.
  void setPressAnchor(Offset anchor) {
    if (_pressAnchor == anchor) {
      return;
    }
    _pressAnchor = anchor;
    _publish();
  }

  /// Stops everything where it is, keeping the current displacement.
  void halt() {
    _x
      ..endFling()
      ..velocity = 0
      ..target = _x.position;
    _y
      ..endFling()
      ..velocity = 0
      ..target = _y.position;
    _press
      ..velocity = 0
      ..target = _press.position;
    _phase = GlassMotionPhase.idle;
    _stopTicker();
    _publish();
  }

  /// Either starts the ticker or, under Reduce Motion, finishes now.
  void _begin() {
    if (isReduced) {
      _settleEverythingNow();
      return;
    }
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
    _updateStatus();
  }

  void _settleEverythingNow() {
    _stopTicker();
    _x.settleInstantly();
    _y.settleInstantly();
    _press.settleInstantly();
    _pressAnchor = Offset.zero;
    _phase = GlassMotionPhase.idle;
    _publish();
  }

  void _onReduceMotionChanged() {
    if (isReduced) {
      // Turning the setting on mid-flight takes effect on the frame it is
      // turned on, not on whatever frame the spring would have finished.
      _settleEverythingNow();
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) {
      // A Ticker's first callback reports zero elapsed. No time has passed
      // since the start, so there is nothing to integrate yet.
      return;
    }
    final step = dt < _maxStep ? dt : _maxStep;

    final following = _phase == GlassMotionPhase.following;
    final spring = following ? _followSpring : _settleSpring;
    final tolerance = following ? _followTolerance : _settleTolerance;

    // Non-short-circuiting on purpose: every channel advances every frame.
    var moving = _x.advance(dt: step, spring: spring, tolerance: tolerance);
    moving |= _y.advance(dt: step, spring: spring, tolerance: tolerance);
    moving |= _press.advanceSpring(
      dt: step,
      spring: _pressSpring,
      tolerance: _pressTolerance,
    );

    if (_phase == GlassMotionPhase.flinging &&
        !_x.isDecaying &&
        !_y.isDecaying) {
      _phase = GlassMotionPhase.settling;
    }

    if (!moving) {
      // Settled controllers cost nothing: the ticker is stopped and
      // unscheduled, so a surface at rest schedules no frames at all.
      _phase = GlassMotionPhase.idle;
      _stopTicker();
    }
    _publish();
  }

  void _stopTicker() {
    if (_ticker.isActive) {
      _ticker.stop(canceled: true);
    }
  }

  void _publish() {
    final next = GlassMotionState(
      translation: Offset(_x.position, _y.position),
      velocity: Offset(_x.velocity, _y.velocity),
      press: _press.position,
      pressAnchor: _pressAnchor,
    );
    if (next != _value) {
      _value = next;
      notifyListeners();
    }
    // Outside the guard: the frame a spring settles on very often reports
    // the same value it reported last frame, and that is exactly the frame
    // the status has to stop saying `forward`.
    _updateStatus();
  }

  void _updateStatus() {
    final next = switch ((isAnimating, _value.isAtRest)) {
      (true, _) => AnimationStatus.forward,
      (false, true) => AnimationStatus.dismissed,
      (false, false) => AnimationStatus.completed,
    };
    if (next == _status) {
      return;
    }
    _status = next;
    notifyStatusListeners(next);
  }

  @override
  void dispose() {
    if (respectReduceMotion) {
      GlassReduceMotion.instance.removeListener(_onReduceMotionChanged);
    }
    _ticker.dispose();
    super.dispose();
  }
}
