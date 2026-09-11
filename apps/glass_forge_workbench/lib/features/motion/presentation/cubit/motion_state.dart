import 'package:equatable/equatable.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';
import 'package:glass_forge_workbench/utils/enums/motion_release.dart';
import 'package:glass_forge_workbench/utils/enums/motion_spring_channel.dart';

/// State for the motion playground.
///
/// Springs are held as `GlassMotion` values rather than as loose numbers,
/// so what the sliders edit is exactly what `InteractiveGlass` is handed —
/// duration and bounce, Apple's vocabulary, never stiffness and damping.
class MotionState extends Equatable {
  /// Creates a state, at the same defaults `InteractiveGlass` uses.
  const MotionState({
    this.channel = MotionSpringChannel.settle,
    this.follow = const GlassMotion.interactive(),
    this.settle = const GlassMotion.bouncy(),
    this.press = const GlassMotion.snappy(
      duration: Duration(milliseconds: 320),
    ),
    this.pressScale = 0.96,
    this.overdragLimit = 56,
    this.overdragResistance = 0.55,
    this.release = MotionRelease.springsHome,
    this.decayDrag = 0.135,
    this.maxStretch = 1.18,
    this.halfSpeed = 1600,
    this.backdrop = GlassBackdrop.photographic,
  });

  /// The shortest spring period the slider offers, in milliseconds.
  static const minDurationMs = 60.0;

  /// The longest, in milliseconds.
  static const maxDurationMs = 900.0;

  /// The tightest rubber band the slider offers, in logical pixels.
  static const minOverdragLimit = 24.0;

  /// The loosest, in logical pixels.
  static const maxOverdragLimit = 200.0;

  /// The slowest fling decay the slider offers, as velocity retained per
  /// second.
  static const minDecayDrag = 0.02;

  /// The fastest.
  static const maxDecayDrag = 0.6;

  /// The largest stretch ratio the slider offers.
  static const maxStretchCeiling = 1.4;

  /// The lowest speed at which half the stretch is reached, in logical
  /// pixels per second.
  static const minHalfSpeed = 300.0;

  /// The highest.
  static const maxHalfSpeed = 4000.0;

  /// Which spring the duration and bounce sliders are editing.
  final MotionSpringChannel channel;

  /// The spring that runs while a pointer is down.
  final GlassMotion follow;

  /// The spring that runs once the pointer has gone.
  final GlassMotion settle;

  /// The spring that runs the press response.
  final GlassMotion press;

  /// What a fully pressed surface scales to.
  final double pressScale;

  /// How far past rest the surface may be dragged, in logical pixels.
  final double overdragLimit;

  /// The fraction of pointer movement that reaches the surface at rest.
  final double overdragResistance;

  /// What letting go does.
  final MotionRelease release;

  /// Velocity retained per second during a free fling.
  final double decayDrag;

  /// The stretch ratio approached at infinite speed.
  final double maxStretch;

  /// The speed at which half the available stretch is reached, in logical
  /// pixels per second.
  final double halfSpeed;

  /// The backdrop the specimen moves over.
  final GlassBackdrop backdrop;

  /// The spring the duration and bounce sliders currently point at.
  GlassMotion get editedSpring => switch (channel) {
    MotionSpringChannel.follow => follow,
    MotionSpringChannel.settle => settle,
    MotionSpringChannel.press => press,
  };

  /// The rubber band, built from the two resistance knobs.
  GlassOverdrag get overdrag =>
      GlassOverdrag(limit: overdragLimit, resistance: overdragResistance);

  /// The friction a free fling runs under.
  GlassDecay get decay => GlassDecay(drag: decayDrag);

  /// The squash and stretch, built from the two deformation knobs.
  GlassJiggle get jiggle =>
      GlassJiggle(maxStretch: maxStretch, halfSpeed: halfSpeed);

  /// Everything `InteractiveGlass` needs to know about dragging.
  GlassDrag get drag => GlassDrag(
    overdrag: overdrag,
    returnsHome: release == MotionRelease.springsHome,
    decay: decay,
  );

  /// Returns a copy with the given fields replaced.
  MotionState copyWith({
    MotionSpringChannel? channel,
    GlassMotion? follow,
    GlassMotion? settle,
    GlassMotion? press,
    double? pressScale,
    double? overdragLimit,
    double? overdragResistance,
    MotionRelease? release,
    double? decayDrag,
    double? maxStretch,
    double? halfSpeed,
    GlassBackdrop? backdrop,
  }) {
    return MotionState(
      channel: channel ?? this.channel,
      follow: follow ?? this.follow,
      settle: settle ?? this.settle,
      press: press ?? this.press,
      pressScale: pressScale ?? this.pressScale,
      overdragLimit: overdragLimit ?? this.overdragLimit,
      overdragResistance: overdragResistance ?? this.overdragResistance,
      release: release ?? this.release,
      decayDrag: decayDrag ?? this.decayDrag,
      maxStretch: maxStretch ?? this.maxStretch,
      halfSpeed: halfSpeed ?? this.halfSpeed,
      backdrop: backdrop ?? this.backdrop,
    );
  }

  @override
  List<Object?> get props => [
    channel,
    follow,
    settle,
    press,
    pressScale,
    overdragLimit,
    overdragResistance,
    release,
    decayDrag,
    maxStretch,
    halfSpeed,
    backdrop,
  ];
}
