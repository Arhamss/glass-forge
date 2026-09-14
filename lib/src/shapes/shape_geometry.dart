import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_type.dart';

/// A shape resolved into the form the geometry shader consumes.
///
/// Everything here is in **physical pixels, layer-local space**. The shader
/// evaluates each shape's SDF in its own local frame via [inverseBasis], then
/// scales the result back into layer pixels by [distanceScale].
///
/// Carrying a full basis rather than a centre and a size is what lets rotated
/// and non-uniformly scaled glass refract in the right direction.
@immutable
class ShapeGeometry {
  /// Creates a resolved shape.
  const ShapeGeometry({
    required this.type,
    required this.origin,
    required this.inverseBasis,
    required this.distanceScale,
    required this.radius,
    required this.halfExtent,
    required this.blendMarker,
  });

  /// Resolves [shape] at [size] under the transform [toLayer].
  factory ShapeGeometry.resolve({
    required GlassShape shape,
    required Size size,
    required Matrix4 toLayer,
    required double devicePixelRatio,
    double blendMarker = 0,
  }) {
    final scaled = Size(
      size.width * devicePixelRatio,
      size.height * devicePixelRatio,
    );

    // Read the basis by transforming the shape's centre and both unit axes,
    // which captures rotation, scale and skew without assuming the matrix
    // is affine in any particular arrangement. The centre, not
    // `Offset.zero` (this `RenderBox`'s own top-left corner): the SDF
    // evaluates every shape as `abs(local) - halfExtent`
    // (`common/sdf.glsl`), which only describes the right silhouette when
    // `local == 0` at the shape's middle -- anchoring at the top-left
    // instead shifts every shape by half its own size toward its origin
    // corner, which is invisible in any test that only checks a shape moved
    // by the *delta* it should have, rather than checking its *absolute*
    // position after a single layout.
    final center = Offset(size.width / 2, size.height / 2);
    final o = MatrixUtils.transformPoint(toLayer, center);
    final x =
        MatrixUtils.transformPoint(toLayer, center + const Offset(1, 0)) - o;
    final y =
        MatrixUtils.transformPoint(toLayer, center + const Offset(0, 1)) - o;

    final determinant = x.dx * y.dy - x.dy * y.dx;
    final invertible = determinant.abs() > 1e-9;
    final inv = Float32List(4);
    if (invertible) {
      inv[0] = y.dy / determinant;
      inv[1] = -y.dx / determinant;
      inv[2] = -x.dy / determinant;
      inv[3] = x.dx / determinant;
    } else {
      // A degenerate transform has no interior to refract. Leave the basis at
      // zero; the shader's coverage term collapses and the shape drops out.
      inv[0] = inv[1] = inv[2] = inv[3] = 0;
    }

    return ShapeGeometry(
      type: shape.type,
      origin: o * devicePixelRatio,
      inverseBasis: inv,
      distanceScale: minimumSingularValue(x, y),
      radius: shape.resolveRadius(size) * devicePixelRatio,
      halfExtent: Size(scaled.width / 2, scaled.height / 2),
      blendMarker: blendMarker,
    );
  }

  /// Which SDF branch this shape resolves to.
  final ShapeType type;

  /// The shape's origin in layer-local physical pixels.
  final Offset origin;

  /// The inverted 2x2 basis, row-major: `[a, b, c, d]`.
  final Float32List inverseBasis;

  /// Converts a local SDF distance into layer-space physical pixels.
  ///
  /// This is the basis's **minimum** singular value, not its average or its
  /// determinant. Anything larger would let the scaled distance overestimate
  /// how far away the surface is, which breaks the lower-bound property that
  /// culling and smooth-min both depend on.
  final double distanceScale;

  /// Corner radius in physical pixels.
  final double radius;

  /// Half the shape's extent in physical pixels.
  final Size halfExtent;

  /// Blend-group marker.
  ///
  /// Negative starts a new group and carries `-(blend + 1)`; positive
  /// continues the current group with that blend width. This is what lets
  /// several blend groups, and ungrouped shapes, share one geometry pass.
  final double blendMarker;

  /// The smallest factor by which this basis stretches any direction.
  ///
  /// For a 2x2 matrix the singular values are the square roots of the
  /// eigenvalues of `MᵀM`. For a 2x2 that reduces to a closed form in the
  /// trace and the determinant, with no iteration.
  static double minimumSingularValue(Offset axisX, Offset axisY) {
    final trace =
        axisX.dx * axisX.dx +
        axisX.dy * axisX.dy +
        axisY.dx * axisY.dx +
        axisY.dy * axisY.dy;
    final determinant = axisX.dx * axisY.dy - axisX.dy * axisY.dx;
    final discriminant = math.max(
      0,
      trace * trace - 4 * determinant * determinant,
    );
    return math.sqrt(math.max(0, (trace - math.sqrt(discriminant)) * 0.5));
  }

  /// Maps a layer-space point into this shape's local frame.
  Offset toLocal(Offset layerPoint) {
    final d = layerPoint - origin;
    return Offset(
      inverseBasis[0] * d.dx + inverseBasis[1] * d.dy,
      inverseBasis[2] * d.dx + inverseBasis[3] * d.dy,
    );
  }

  /// Maps a local point back into layer space. Inverse of [toLocal].
  Offset toLayerSpace(Offset localPoint) {
    final det =
        inverseBasis[0] * inverseBasis[3] - inverseBasis[1] * inverseBasis[2];
    if (det.abs() < 1e-12) {
      return origin;
    }
    final a = inverseBasis[3] / det;
    final b = -inverseBasis[1] / det;
    final c = -inverseBasis[2] / det;
    final d = inverseBasis[0] / det;
    return origin +
        Offset(
          a * localPoint.dx + b * localPoint.dy,
          c * localPoint.dx + d * localPoint.dy,
        );
  }
}
