import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';

/// Clips to [shape] at paint time, once its size is known, less an optional
/// [hole].
///
/// The one clip-to-a-`GlassShape` in this package: `Glass` clips its child
/// with it, every control clips its painted stand-in with it, and a control
/// on content clips its painted track with it, cutting out its glass
/// element. Internal: not exported.
///
/// **Why at paint time.** [GlassShape.resolveRadius] clamps a requested
/// corner radius to half the shorter side of the size it is given.
/// Clipping with `shape.toBorder` against [Size.zero], as though the shape
/// had no size, would resolve every corner radius to zero — the clip would
/// then disagree with the SDF at every corner the shape actually paints at.
///
/// **Why a hole.** A `GlassLayer` composites its glass *under* everything
/// its subtree paints: the backdrop filter reads what is behind the layer,
/// and the subtree draws on top of the result. So a control that paints its
/// track across the whole capsule and then puts a `Glass` knob, thumb or
/// pill on it has painted over its own glass. An opaque track hides the
/// glass entirely -- an "on" `GlassSwitch` showed a solid green capsule and
/// no knob at all -- and a translucent one tints it. Cutting the glass
/// element's footprint out of the track fixes that where the problem is, in
/// the control, and costs one path operation on the frames the element
/// moves. It needs no second pass and no paint moved out of the layer, so
/// it holds wherever the control's layer lives -- an implicit one, a
/// screen's, a scaffold's -- and never puts glass on glass.
///
/// A hole is only for a control on content. Under `GlassHostScope` the
/// element is painted, not glass, and it is painted over the track, so
/// there is no hole to leave; pass a null [hole] there.
///
/// [hole] is in the clipped box's own coordinates, before [holeScale].
/// [holeScale] scales the hole's outline about its own centre, the way a
/// `Transform` around the glass element scales that element's glass (the
/// slider thumb's drag stretch), so the hole keeps following it.
@immutable
class GlassShapeClipper extends CustomClipper<Path> {
  /// Creates a clipper for [shape], with an optional [hole] of [holeShape].
  const GlassShapeClipper(
    this.shape, {
    this.hole,
    this.holeShape,
    this.holeScale = const Offset(1, 1),
  });

  /// The outline being clipped to.
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
      oldClipper is! GlassShapeClipper ||
      oldClipper.shape != shape ||
      oldClipper.hole != hole ||
      oldClipper.holeShape != holeShape ||
      oldClipper.holeScale != holeScale;
}
