import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/rendering/render_glass_shape.dart';
import 'package:glass_forge/src/scene/blend_group_link.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/tier/glass_tier_scope.dart';
import 'package:glass_forge/src/widgets/glass_blend_group.dart';
import 'package:glass_forge/src/widgets/glass_host_scope.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';
import 'package:glass_forge/src/widgets/glass_presence.dart';

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
  /// Costs a second backdrop pass in that layer, not a second one per shape:
  /// the layer groups its shapes by material and pushes one pass per
  /// distinct material among them, so ten cards sharing one override still
  /// cost one pass between them. Leave it null wherever the layer's own
  /// material will do.
  ///
  /// Ignored for a shape inside a `GlassBlendGroup` whose group already
  /// renders with another material. Shapes that smooth-min into one another
  /// are one surface, and one surface has one material; the group takes the
  /// material its first shape asked for. Debug builds say so when it
  /// happens.
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

    assert(
      !GlassHostScope.isOnGlass(context),
      "glass_forge: this Glass was built somewhere inside another Glass's "
      'child — not necessarily as its direct child, but anywhere in that '
      'subtree. Two refractions over the same pixels is a stacked backdrop '
      'filter (flutter#187820), which samples a stale previous-frame '
      'backdrop including its own output and white-washes over time. Put '
      'both shapes in one GlassLayer instead, or join them with a '
      'GlassBlendGroup.',
    );

    final group = GlassBlendGroupScope.maybeOf(context)?.link;
    return _RawGlass(
      shape: shape,
      group: group,
      presence: GlassPresenceScope.maybeOf(context),
      material: _resolveMaterialFor(context, material),
      child: GlassHostScope(
        child: ClipPath(
          clipper: GlassShapeClipper(shape),
          clipBehavior: clipBehavior,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// The material to hand the render object, degraded to the resolved tier.
///
/// `GlassLayer` already degrades the material it puts in scope, so
/// inheriting needs nothing done and stays null all the way down — which
/// is also what lets the layer re-route inheriting shapes when its own
/// material changes. An override is degraded here instead, because the
/// parts of that degradation that come from accessibility settings are not
/// preferences to opt out of, and a per-shape material that skipped them
/// would be exactly such an opt-out.
GlassMaterial? _resolveMaterialFor(
  BuildContext context,
  GlassMaterial? override,
) {
  if (override == null) {
    return null;
  }
  final resolved = GlassTierScope.maybeOf(context);
  if (resolved == null) {
    return override;
  }
  return resolved.materialFor(
    override,
    brightness:
        MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light,
  );
}

/// Clips to [shape] at paint time, once its size is known.
///
/// [GlassShape.resolveRadius] clamps a requested corner radius to half the
/// shorter side of the size it is given. Clipping with `shape.toBorder`
/// against [Size.zero], as though the shape had no size, would resolve every
/// corner radius to zero — the clip would then disagree with the SDF at
/// every corner the shape actually paints at.
///
/// Not private: exercised directly by tests, since [GlassShape]'s value
/// equality (what makes [shouldReclip] skip a rebuilt-but-unchanged shape)
/// has no other externally observable effect.
@visibleForTesting
class GlassShapeClipper extends CustomClipper<Path> {
  /// Creates a clipper for [shape].
  const GlassShapeClipper(this.shape);

  /// The shape being clipped to.
  final GlassShape shape;

  @override
  Path getClip(Size size) =>
      shape.toBorder(size).getOuterPath(Offset.zero & size);

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return oldClipper is! GlassShapeClipper || oldClipper.shape != shape;
  }
}

class _RawGlass extends SingleChildRenderObjectWidget {
  const _RawGlass({
    required this.shape,
    required this.group,
    required this.presence,
    required this.material,
    required Widget super.child,
  });

  final GlassShape shape;
  final BlendGroupLink? group;
  final Animation<double>? presence;
  final GlassMaterial? material;

  @override
  RenderGlassShape createRenderObject(BuildContext context) {
    return RenderGlassShape(
      shape: shape,
      group: group,
      presence: presence,
      material: material,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassShape renderObject,
  ) {
    renderObject
      ..shape = shape
      ..group = group
      ..presence = presence
      ..material = material;
  }
}
