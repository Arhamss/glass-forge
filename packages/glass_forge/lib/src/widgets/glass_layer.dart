import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/tier/glass_tier_scope.dart';

/// One backdrop capture per material, shared by every `Glass` beneath it.
///
/// Apple's own guidance is that "glass cannot sample other glass", and that a
/// container lets nearby elements share one sampling region. The same
/// applies here for the same reason: one layer around a screen's worth of
/// controls costs one capture, while a layer per control costs one each.
///
/// Per material, not per shape: shapes that override [material] are grouped
/// by the material they asked for and each group captures once, so a screen
/// of controls that all inherit still costs exactly one. Overlapping shapes
/// belong in the same material, or in one `GlassBlendGroup` — where two
/// captures overlap, the later one samples the earlier one's glass.
///
/// Its shaders load asynchronously, but [child] never waits on them:
/// [RenderGlassLayer] always exists and always paints its subtree in place,
/// with or without a backdrop pass, so descendants are visible from the
/// first frame and the glass itself fades in once loading finishes.
///
/// Under a `GlassTierScope`, the layer adopts the resolved tier: both the
/// geometry producer and [material] are degraded to what the device, its
/// temperature, its recent frame times and the user's accessibility settings
/// allow. With no scope above it, nothing is adopted and the layer renders
/// exactly what it was given.
class GlassLayer extends StatelessWidget {
  /// Creates a glass layer.
  const GlassLayer({
    required this.child,
    this.material = const GlassMaterial(),
    this.tier,
    super.key,
  });

  /// The subtree this layer captures behind.
  final Widget child;

  /// How the glass in this layer looks by default.
  ///
  /// A ceiling, not a guarantee. A resolved tier can only reduce it — take
  /// refraction away, add frost, force a border — never add to it.
  final GlassMaterial material;

  /// How much geometry work this layer may do.
  ///
  /// Null adopts the enclosing `GlassTierScope`'s answer, or
  /// [GeometryTier.accelerated] when there is no scope. Setting it pins the
  /// producer for this layer regardless of what any scope resolved, which is
  /// the escape hatch for a surface whose cost is known — a single small
  /// control that should stay cheap, or a hero surface that should stay rich.
  ///
  /// It pins the *producer* only. The material is still degraded by the
  /// resolved tier, because the parts of that degradation that come from
  /// accessibility settings are not preferences to opt out of.
  final GeometryTier? tier;

  @override
  Widget build(BuildContext context) {
    final resolved = GlassTierScope.maybeOf(context);
    final effective =
        resolved?.materialFor(
          material,
          brightness:
              MediaQuery.maybePlatformBrightnessOf(context) ??
              Brightness.light,
        ) ??
        material;
    final geometry = tier ?? resolved?.geometry ?? GeometryTier.accelerated;

    return GlassLayerScope(
      material: effective,
      child: _RawGlassLayer(
        material: effective,
        tier: geometry,
        child: child,
      ),
    );
  }
}

/// Exposes the nearest layer's default material to descendants.
///
/// Presence of this widget, not readiness of the layer's shaders, is what
/// tells a `Glass` beneath it that it is not orphaned.
class GlassLayerScope extends InheritedWidget {
  /// Creates a scope.
  const GlassLayerScope({
    required this.material,
    required super.child,
    super.key,
  });

  /// The layer's default material.
  ///
  /// Already degraded to the resolved tier, so a `Glass` that inherits it
  /// gets the same treatment as the layer itself rather than the material
  /// the developer wrote.
  final GlassMaterial material;

  /// The nearest enclosing scope, if any.
  static GlassLayerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GlassLayerScope>();
  }

  @override
  bool updateShouldNotify(GlassLayerScope oldWidget) =>
      oldWidget.material != material;
}

class _RawGlassLayer extends SingleChildRenderObjectWidget {
  const _RawGlassLayer({
    required this.material,
    required this.tier,
    required Widget super.child,
  });

  final GlassMaterial material;
  final GeometryTier tier;

  @override
  RenderGlassLayer createRenderObject(BuildContext context) {
    return RenderGlassLayer(
      material: material,
      tier: tier,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassLayer renderObject,
  ) {
    renderObject
      ..material = material
      // Assigned on every update, not just at creation: a tier that can only
      // be chosen once would make every downgrade the engine resolves
      // invisible to the thing that renders.
      ..tier = tier
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}
