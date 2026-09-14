import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/shapes/shape_type.dart';

/// A shape that can be rendered as glass.
///
/// Deliberately a closed set. Every member has an exact SDF whose silhouette
/// matches the Flutter clip used for its children — an open family would make
/// that guarantee impossible to keep. Every member is also a value type: it
/// carries `==`/`hashCode` by its fields, because callers routinely rebuild a
/// non-const shape every frame (a radius bound to theme, state, or an
/// animation) and both `RenderGlassShape` and `GlassShapeClipper` need to
/// tell that apart from a real change.
@immutable
sealed class GlassShape {
  const GlassShape();

  /// Which SDF branch this shape resolves to.
  ShapeType get type;

  /// The corner radius in logical pixels for a shape of [size].
  ///
  /// Clamped to half the shorter side, so an intentionally huge radius yields
  /// a capsule rather than an invalid distance field.
  double resolveRadius(Size size);

  /// The border this shape clips its children with.
  ///
  /// The SDF and this border must describe the same silhouette. They are
  /// tested against each other; if they drift, refraction and clip disagree
  /// at the corners.
  ShapeBorder toBorder(Size size);
}

/// A rounded rectangle.
class GlassRoundedRectangle extends GlassShape {
  /// Creates a rounded rectangle with the given corner [radius].
  const GlassRoundedRectangle({required this.radius});

  /// The corner radius, before clamping.
  final BorderRadius radius;

  @override
  ShapeType get type => ShapeType.roundedRectangle;

  @override
  double resolveRadius(Size size) => _clampRadius(radius, size);

  @override
  ShapeBorder toBorder(Size size) => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(resolveRadius(size)),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlassRoundedRectangle && other.radius == radius);

  @override
  int get hashCode => Object.hash(GlassRoundedRectangle, radius);
}

/// An ellipse inscribed in the shape's bounds.
class GlassOval extends GlassShape {
  /// Creates an oval.
  const GlassOval();

  @override
  ShapeType get type => ShapeType.ellipse;

  @override
  double resolveRadius(Size size) => 0;

  @override
  ShapeBorder toBorder(Size size) => const OvalBorder();

  @override
  bool operator ==(Object other) => other is GlassOval;

  @override
  int get hashCode => (GlassOval).hashCode;
}

/// A rounded superellipse, matching Flutter's `RoundedSuperellipse`.
class GlassSuperellipse extends GlassShape {
  /// Creates a rounded superellipse with the given corner [radius].
  const GlassSuperellipse({required this.radius});

  /// The corner radius, before clamping.
  final BorderRadius radius;

  @override
  ShapeType get type => ShapeType.superellipse;

  @override
  double resolveRadius(Size size) => _clampRadius(radius, size);

  @override
  ShapeBorder toBorder(Size size) => RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(resolveRadius(size)),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlassSuperellipse && other.radius == radius);

  @override
  int get hashCode => Object.hash(GlassSuperellipse, radius);
}

double _clampRadius(BorderRadius radius, Size size) {
  final requested = math.max(
    math.max(radius.topLeft.x, radius.topRight.x),
    math.max(radius.bottomLeft.x, radius.bottomRight.x),
  );
  final limit = math.min(size.width, size.height) / 2;
  return math.min(requested, limit);
}
