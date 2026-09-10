import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/scene/scene_revision.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

/// The set of shapes belonging to one glass layer, in layer-local space.
///
/// Registration is idempotent: re-registering a shape whose resolved geometry
/// is unchanged does not bump the revision. That matters because layout runs
/// again on every scroll frame and re-registers everything with identical
/// numbers.
class GlassScene {
  final Map<Object, ShapeGeometry> _shapes = <Object, ShapeGeometry>{};
  final SceneRevision _revision = SceneRevision();
  List<ShapeGeometry>? _cachedOrder;

  /// The registered shapes, in registration order.
  List<ShapeGeometry> get shapes =>
      _cachedOrder ??= List<ShapeGeometry>.unmodifiable(_shapes.values);

  /// The current revision. Changes only when the scene really changed.
  int get revision => _revision.value;

  /// Registers or updates the shape identified by [key].
  void register(Object key, ShapeGeometry geometry) {
    final existing = _shapes[key];
    if (existing != null && _sameGeometry(existing, geometry)) {
      return;
    }
    _shapes[key] = geometry;
    _cachedOrder = null;
    _revision.bump();
  }

  /// Removes the shape identified by [key].
  void unregister(Object key) {
    if (_shapes.remove(key) == null) {
      return;
    }
    _cachedOrder = null;
    _revision.bump();
  }

  /// The union of every shape's bounds, grown by [padding] physical pixels.
  ///
  /// The padding reserves room for the antialiasing band, which is centred on
  /// the edge and therefore extends outside the shape.
  Rect bounds({required double padding}) {
    if (_shapes.isEmpty) {
      return Rect.zero;
    }
    var result = _boundsOf(shapes.first);
    for (final shape in shapes.skip(1)) {
      result = result.expandToInclude(_boundsOf(shape));
    }
    return result.inflate(padding);
  }

  /// The common delta if every shape moved by the same amount and nothing
  /// else changed; `null` otherwise.
  ///
  /// When this returns a value the matte can be reused with shifted bounds
  /// rather than re-rendered — the common case for a glass layer scrolling
  /// past content.
  Offset? uniformTranslationSince(GlassScene other) {
    if (_shapes.length != other._shapes.length) {
      return null;
    }
    Offset? delta;
    for (final entry in _shapes.entries) {
      final previous = other._shapes[entry.key];
      if (previous == null ||
          !_sameShapeIgnoringOrigin(previous, entry.value)) {
        return null;
      }
      final candidate = entry.value.origin - previous.origin;
      if (delta == null) {
        delta = candidate;
      } else if ((candidate - delta).distanceSquared > 1e-6) {
        return null;
      }
    }
    return delta;
  }

  static Rect _boundsOf(ShapeGeometry shape) {
    // The shape's own extent, mapped through its basis. Taking the extremes of
    // the four transformed corners covers rotation and skew.
    final corners = <Offset>[
      shape.toLayerSpace(
        Offset(-shape.halfExtent.width, -shape.halfExtent.height),
      ),
      shape.toLayerSpace(
        Offset(shape.halfExtent.width, -shape.halfExtent.height),
      ),
      shape.toLayerSpace(
        Offset(-shape.halfExtent.width, shape.halfExtent.height),
      ),
      shape.toLayerSpace(
        Offset(shape.halfExtent.width, shape.halfExtent.height),
      ),
    ];
    var left = corners.first.dx;
    var top = corners.first.dy;
    var right = left;
    var bottom = top;
    for (final c in corners.skip(1)) {
      left = math.min(left, c.dx);
      top = math.min(top, c.dy);
      right = math.max(right, c.dx);
      bottom = math.max(bottom, c.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  static bool _sameGeometry(ShapeGeometry a, ShapeGeometry b) {
    return (a.origin - b.origin).distanceSquared < 1e-9 &&
        _sameShapeIgnoringOrigin(a, b);
  }

  static bool _sameShapeIgnoringOrigin(ShapeGeometry a, ShapeGeometry b) {
    if (a.type != b.type ||
        (a.radius - b.radius).abs() > 1e-9 ||
        (a.distanceScale - b.distanceScale).abs() > 1e-9 ||
        (a.blendMarker - b.blendMarker).abs() > 1e-9 ||
        a.halfExtent != b.halfExtent) {
      return false;
    }
    for (var i = 0; i < 4; i++) {
      if ((a.inverseBasis[i] - b.inverseBasis[i]).abs() > 1e-9) {
        return false;
      }
    }
    return true;
  }
}
