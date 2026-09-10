import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/rendering/render_glass_shape.dart';
import 'package:glass_forge/src/scene/blend_group_link.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass_blend_group.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

/// One glass surface.
class Glass extends StatelessWidget {
  /// Creates a glass surface.
  const Glass({
    required this.shape,
    this.child,
    this.material,
    this.containsChild = false,
    this.clipBehavior = Clip.antiAlias,
    super.key,
  });

  /// The silhouette.
  final GlassShape shape;

  /// Content drawn with the glass.
  final Widget? child;

  /// Overrides the enclosing layer's material for this shape alone.
  ///
  /// Composition is exactly one filter per layer, so nothing consumes a
  /// per-shape override yet; it is accepted now so a future task can wire it
  /// without a breaking constructor change.
  final GlassMaterial? material;

  /// Whether [child] sits behind the glass and is refracted by it.
  ///
  /// Reserved for a future task; not yet wired to any rendering behaviour.
  final bool containsChild;

  /// How [child] is clipped to [shape].
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final scope = GlassLayerScope.maybeOf(context);
    if (scope == null) {
      // No enclosing layer. Wrap in an implicit one rather than asserting in
      // debug and null-crashing in release, which is what upstream does.
      assert(() {
        debugPrint(
          'glass_forge: a Glass with no enclosing GlassLayer created an '
          'implicit one. That costs a backdrop capture per shape. Wrap the '
          'screen in a single GlassLayer instead.',
        );
        return true;
      }(), 'debug-only warning; always true');
      return GlassLayer(child: this);
    }

    final group = GlassBlendGroupScope.maybeOf(context)?.link;
    return _RawGlass(
      shape: shape,
      group: group,
      child: ClipPath(
        clipper: _GlassShapeClipper(shape),
        clipBehavior: clipBehavior,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Clips to [shape] at paint time, once its size is known.
///
/// [GlassShape.resolveRadius] clamps a requested corner radius to half the
/// shorter side of the size it is given. Clipping with `shape.toBorder`
/// against [Size.zero], as though the shape had no size, would resolve every
/// corner radius to zero — the clip would then disagree with the SDF at
/// every corner the shape actually paints at.
class _GlassShapeClipper extends CustomClipper<Path> {
  /// Creates a clipper for [shape].
  const _GlassShapeClipper(this.shape);

  /// The shape being clipped to.
  final GlassShape shape;

  @override
  Path getClip(Size size) =>
      shape.toBorder(size).getOuterPath(Offset.zero & size);

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return oldClipper is! _GlassShapeClipper || oldClipper.shape != shape;
  }
}

class _RawGlass extends SingleChildRenderObjectWidget {
  const _RawGlass({
    required this.shape,
    required this.group,
    required Widget super.child,
  });

  final GlassShape shape;
  final BlendGroupLink? group;

  @override
  RenderGlassShape createRenderObject(BuildContext context) {
    return RenderGlassShape(shape: shape, group: group);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassShape renderObject,
  ) {
    renderObject
      ..shape = shape
      ..group = group;
  }
}
