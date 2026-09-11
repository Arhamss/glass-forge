import 'dart:math' as math;
import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:glass_forge_workbench/utils/enums/blend_arrangement.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';

/// State for the blend playground.
///
/// The shapes are placed from one number — the centre-to-centre distance —
/// so the gap between their edges is exact rather than measured off the
/// screen. That is what lets this screen state, in pixels, what it expects
/// to see before you look at it.
class BlendState extends Equatable {
  /// Creates a state.
  ///
  /// The defaults are deliberately not a merged blob. A playground that
  /// opened on one smooth shape would look identical whether the fold
  /// worked or the shapes were simply drawn on top of each other.
  const BlendState({
    this.blend = 20,
    this.separation = 148,
    this.arrangement = BlendArrangement.pair,
    this.backdrop = GlassBackdrop.checkerboard,
  });

  /// The diameter of one shape, in logical pixels.
  static const nodeDiameter = 96.0;

  /// The closest the centres are allowed, in logical pixels.
  static const minSeparation = 60.0;

  /// The furthest, in logical pixels.
  static const maxSeparation = 240.0;

  /// The widest merge the slider offers, in logical pixels.
  static const maxBlend = 64.0;

  /// How wide the merge is, in logical pixels.
  final double blend;

  /// Centre-to-centre distance between any two shapes, in logical pixels.
  final double separation;

  /// How many shapes are on the stage.
  final BlendArrangement arrangement;

  /// The backdrop behind them.
  final GlassBackdrop backdrop;

  /// The distance between the nearest edges of two shapes, in logical
  /// pixels. Negative once they physically overlap.
  double get edgeGap => separation - nodeDiameter;

  /// Whether the shapes already intersect, fold or no fold.
  bool get isOverlapping => edgeGap <= 0;

  /// Whether the merge should be visible at this gap and this blend width.
  ///
  /// The claim the screen makes out loud: a fold that reaches [blend]
  /// pixels bridges a gap narrower than that and leaves a wider one alone.
  bool get expectsMerge => edgeGap < blend;

  /// Where each shape's centre sits, relative to the middle of the stage.
  ///
  /// The triad is equilateral, so every pair is exactly [separation] apart
  /// and one gap number describes the whole scene.
  List<Offset> get nodeCentres {
    final half = separation / 2;
    return switch (arrangement) {
      BlendArrangement.pair => <Offset>[Offset(-half, 0), Offset(half, 0)],
      BlendArrangement.triad => <Offset>[
        Offset(-half, -separation / (2 * math.sqrt(3))),
        Offset(half, -separation / (2 * math.sqrt(3))),
        Offset(0, separation / math.sqrt(3)),
      ],
    };
  }

  /// Returns a copy with the given fields replaced.
  BlendState copyWith({
    double? blend,
    double? separation,
    BlendArrangement? arrangement,
    GlassBackdrop? backdrop,
  }) {
    return BlendState(
      blend: blend ?? this.blend,
      separation: separation ?? this.separation,
      arrangement: arrangement ?? this.arrangement,
      backdrop: backdrop ?? this.backdrop,
    );
  }

  @override
  List<Object?> get props => [blend, separation, arrangement, backdrop];
}
