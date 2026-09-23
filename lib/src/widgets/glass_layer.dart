import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/composition/glass_glow.dart';
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
class GlassLayer extends StatefulWidget {
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
  State<GlassLayer> createState() => _GlassLayerState();
}

class _GlassLayerState extends State<GlassLayer> {
  /// This layer's shared touch-glow channel.
  ///
  /// A plain field, not created per build: every `InteractiveGlass` beneath
  /// this layer writes into the same instance for as long as this state
  /// lives, and [GlassGlowScope.updateShouldNotify] relies on that identity
  /// staying put.
  final ValueNotifier<GlassGlow> _glow = ValueNotifier(const GlassGlow.none());

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = GlassTierScope.maybeOf(context);
    final effective =
        resolved?.materialFor(
          widget.material,
          brightness:
              MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light,
        ) ??
        widget.material;
    final geometry =
        widget.tier ?? resolved?.geometry ?? GeometryTier.accelerated;

    return GlassGlowScope(
      glow: _glow,
      child: GlassLayerScope(
        material: effective,
        child: _RawGlassLayer(
          material: effective,
          tier: geometry,
          glow: _glow,
          child: _RepaintOnScroll(child: widget.child),
        ),
      ),
    );
  }
}

/// Publishes the nearest `GlassLayer`'s shared touch-glow channel.
///
/// One `ValueNotifier<GlassGlow>` per layer, not per surface: every
/// `InteractiveGlass` beneath a given `GlassLayer` writes into the same
/// instance, because the glow itself is a property of the layer's single
/// backdrop pass, not of any one shape. See `RenderGlassLayer.glow`.
///
/// **Contention rule, decided explicitly because the design leaves it
/// open:** last writer wins. Whichever surface most recently wrote a glow
/// into the channel is the one that shows — there is no queueing and no
/// blending between two surfaces pressed at once, which matches Apple's own
/// description of the glow following the live touch. The one place that
/// needs a rule beyond "just write" is release: a surface letting go must
/// not zero a glow that a different surface has since claimed. Each
/// `InteractiveGlass` enforces that itself, by only ever clearing the
/// channel back to `GlassGlow.none()` when it still holds exactly what that
/// surface last wrote there — see `InteractiveGlass`'s own glow-release
/// doc comment for the mechanics.
class GlassGlowScope extends InheritedWidget {
  /// Creates a scope publishing [glow].
  const GlassGlowScope({required this.glow, required super.child, super.key});

  /// The nearest layer's shared glow channel.
  final ValueNotifier<GlassGlow> glow;

  /// The nearest enclosing scope, if any.
  static GlassGlowScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GlassGlowScope>();
  }

  @override
  bool updateShouldNotify(GlassGlowScope oldWidget) =>
      !identical(oldWidget.glow, glow);
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

/// Marks the enclosing [RenderGlassLayer] for paint whenever anything
/// beneath it scrolls.
///
/// A `Glass` reads where it is from its own `paint` and nowhere else, and
/// the layer reads what did not paint straight afterwards (see
/// `RenderGlassLayer._resyncShapesThatDidNotPaint`). Both depend on the
/// layer being asked to paint at all, and a scroll does not ask it:
/// `RenderViewportBase.isRepaintBoundary` is true, so a scroll marks the
/// viewport and stops there. The layer outside it is not dirty in layout or
/// in paint and never learns that everything it refracts just moved.
/// Measured: a `ListView` scrolled by 30 logical pixels moved every row and
/// did not paint the layer once.
///
/// A scroll notification is the signal that says so. It bubbles up the
/// element tree from whichever `Scrollable` moved, so one listener at the
/// layer covers every scroll view nested anywhere beneath it, however many,
/// and fires nothing at all on a frame where nothing scrolled. The cost per
/// notification is one hop up the element tree — this sits immediately
/// inside the render object it is looking for — and one `markNeedsPaint` on
/// a layer that is about to have to repaint anyway.
class _RepaintOnScroll extends StatelessWidget {
  const _RepaintOnScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final layer = context
            .findAncestorRenderObjectOfType<RenderGlassLayer>();
        if (layer != null && layer.attached) {
          layer.markNeedsPaint();
        }
        // Never absorbed: a caller's own listener above this layer has to
        // go on seeing every scroll its subtree reports.
        return false;
      },
      child: child,
    );
  }
}

class _RawGlassLayer extends SingleChildRenderObjectWidget {
  const _RawGlassLayer({
    required this.material,
    required this.tier,
    required this.glow,
    required Widget super.child,
  });

  final GlassMaterial material;
  final GeometryTier tier;
  final ValueNotifier<GlassGlow> glow;

  @override
  RenderGlassLayer createRenderObject(BuildContext context) {
    return RenderGlassLayer(
      material: material,
      tier: tier,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    )..glowListenable = glow;
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
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context)
      // `glow` is the same `ValueNotifier` instance across every rebuild
      // (see `_GlassLayerState._glow`), so this is a no-op past the first
      // assignment — the render object was already listening to it
      // directly, which is how the glow reaches paint without going
      // through build at all.
      ..glowListenable = glow;
  }
}
