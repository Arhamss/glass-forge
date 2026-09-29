import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';

/// Clips a control's painted track to [shape], less a hole where its glass
/// element is.
///
/// A `GlassLayer` composites its glass *under* everything its subtree
/// paints: the backdrop filter reads what is behind the layer, and the
/// subtree draws on top of the result. So a control that paints its track
/// across the whole capsule and then puts a `Glass` knob, thumb or pill on
/// it has painted over its own glass. An opaque track hides the glass
/// entirely -- an "on" `GlassSwitch` showed a solid green capsule and no
/// knob at all -- and a translucent one tints it.
///
/// Cutting the glass element's footprint out of the track fixes that where
/// the problem is, in the control, and costs one path operation on the
/// frames the element moves. It needs no second pass and no paint moved out
/// of the layer, so it holds wherever the control's layer lives -- an
/// implicit one, a screen's, a scaffold's -- and never puts glass on glass.
///
/// Only for a control on content. Under `GlassHostScope` the element is
/// painted, not glass, and it is painted over the track, so there is no
/// hole to leave; pass a null [hole] there.
///
/// [hole] is in the clipped box's own coordinates, before [holeScale].
/// [holeScale] scales the hole's outline about its own centre, the way a
/// `Transform` around the glass element scales that element's glass (the
/// slider thumb's drag stretch), so the hole keeps following it.
@immutable
class TrackCutoutClipper extends CustomClipper<Path> {
  /// Creates a clipper for a track of [shape] with an optional [hole] of
  /// [holeShape].
  const TrackCutoutClipper({
    required this.shape,
    this.hole,
    this.holeShape,
    this.holeScale = const Offset(1, 1),
  });

  /// The track's own outline.
  final GlassShape shape;

  /// Where the glass element sits, or null for no hole.
  final Rect? hole;

  /// The glass element's outline. Null uses [shape].
  final GlassShape? holeShape;

  /// How the glass element is scaled about its centre, x and y.
  final Offset holeScale;

  @override
  Path getClip(Size size) {
    final outer = shape.toBorder(size).getOuterPath(Offset.zero & size);
    final rect = hole;
    if (rect == null || rect.isEmpty) {
      return outer;
    }
    var inner = (holeShape ?? shape).toBorder(rect.size).getOuterPath(rect);
    if (holeScale != const Offset(1, 1)) {
      final centre = rect.center;
      final matrix = Matrix4.identity()
        ..translateByDouble(centre.dx, centre.dy, 0, 1)
        ..scaleByDouble(holeScale.dx, holeScale.dy, 1, 1)
        ..translateByDouble(-centre.dx, -centre.dy, 0, 1);
      inner = inner.transform(matrix.storage);
    }
    return Path.combine(PathOperation.difference, outer, inner);
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) =>
      oldClipper is! TrackCutoutClipper ||
      oldClipper.shape != shape ||
      oldClipper.hole != hole ||
      oldClipper.holeShape != holeShape ||
      oldClipper.holeScale != holeScale;
}
