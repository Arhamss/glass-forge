import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';

/// One backdrop capture, shared by every `Glass` beneath it.
///
/// Apple's own guidance is that "glass cannot sample other glass", and that a
/// container lets nearby elements share one sampling region. The same
/// applies here for the same reason: one layer around a screen's worth of
/// controls costs one capture, while a layer per control costs one each.
///
/// Its shaders load asynchronously, but [child] never waits on them:
/// [RenderGlassLayer] always exists and always paints its subtree in place,
/// with or without a backdrop pass, so descendants are visible from the
/// first frame and the glass itself fades in once loading finishes.
class GlassLayer extends StatelessWidget {
  /// Creates a glass layer.
  const GlassLayer({
    required this.child,
    this.material = const GlassMaterial(),
    this.tier = GeometryTier.accelerated,
    super.key,
  });

  /// The subtree this layer captures behind.
  final Widget child;

  /// How the glass in this layer looks by default.
  final GlassMaterial material;

  /// How much geometry work this layer may do.
  final GeometryTier tier;

  @override
  Widget build(BuildContext context) {
    return GlassLayerScope(
      material: material,
      child: _RawGlassLayer(material: material, tier: tier, child: child),
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
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}
