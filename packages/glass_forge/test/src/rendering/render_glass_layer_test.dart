import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

/// Records the offset it is actually asked to paint at, then paints
/// normally.
///
/// `tester.getTopLeft` cannot catch a paint-offset bug: it reads the render
/// tree's *layout* geometry (sizes and `parentData.offset`, fixed before
/// `paint()` ever runs), which a bug in [RenderGlassLayer.paint]'s own
/// offset handling cannot touch. Only something that observes the offset
/// `paint()` itself receives -- this spy -- can.
class _SpyOffsetBox extends RenderConstrainedBox {
  _SpyOffsetBox({required super.additionalConstraints});

  /// The offset most recently passed to [paint].
  Offset? lastPaintOffset;

  @override
  void paint(PaintingContext context, Offset offset) {
    lastPaintOffset = offset;
    super.paint(context, offset);
  }
}

void main() {
  tearDown(ShaderLibrary.instance.disposeAll);

  test(
    'a layer whose shaders are not ready yet still paints its child '
    '(regression: gating readiness on the widget, not on paint, recurses '
    'infinitely -- see Glass orphan-wrapping)',
    () {
      // `tester.pumpWidget` cannot exercise this branch: flutter_tester's
      // asset loading resolves quickly enough that a single pumped frame
      // fully settles the constructor's warm-up future, so `isReady` is
      // already true by the time any widget test could inspect it. Driving
      // the render object directly, with no `await` between disposeAll()
      // and paint(), is the only way to guarantee `isReady` is still false
      // at the moment paint() runs -- warm-up's completion is a microtask,
      // and nothing here yields to the event loop before the assertions do.
      ShaderLibrary.instance.disposeAll();
      expect(ShaderLibrary.instance.isReady, isFalse);

      final child = RenderConstrainedBox(
        additionalConstraints: BoxConstraints.tight(const Size(40, 40)),
      );
      final layer =
          RenderGlassLayer(
            material: const GlassMaterial(),
            tier: GeometryTier.none,
            devicePixelRatio: 1,
          )
          ..child = child
          ..layout(const BoxConstraints.tightFor(width: 40, height: 40));
      expect(ShaderLibrary.instance.isReady, isFalse);

      final rootLayer = ContainerLayer();
      final context = PaintingContext(rootLayer, Rect.largest);

      // Taking the ready branch here would call GlassComposition.build(),
      // which calls ShaderLibrary.acquire() -- and acquire() throws
      // deliberately before warm-up completes (see shader_library.dart). So
      // a clean run is itself the proof that paint() took the not-ready
      // branch, not just a guess about which one it took.
      expect(() => layer.paint(context, Offset.zero), returnsNormally);

      rootLayer.dispose();
    },
  );

  test(
    'a glass child paints at the offset it is given, not at (0, 0) '
    '(regression: backdrop offset bug)',
    () async {
      // Requires a real backdrop filter, hence Impeller (see the file-level
      // note in glass_widgets_test.dart): the bug this guards only exists on
      // the pushClipRect/pushLayer path, which only runs once a material
      // renders something and shaders have loaded.
      await ShaderLibrary.instance.warmUp();

      final spy = _SpyOffsetBox(
        additionalConstraints: BoxConstraints.tight(const Size(40, 40)),
      );
      final layer = RenderGlassLayer(
        material: const GlassMaterial(),
        tier: GeometryTier.none,
        devicePixelRatio: 1,
      );

      // Attached before the child is adopted, so `adoptChild`'s
      // `markNeedsCompositingBitsUpdate()` call registers with a real
      // owner instead of silently no-op-ing against a still-null one --
      // otherwise `needsCompositing` asserts that its dirty bit was never
      // cleared, which paint() reads to decide whether to composite.
      final owner = PipelineOwner();
      layer
        ..attach(owner)
        ..child = spy;
      owner.flushCompositingBits();
      layer.layout(const BoxConstraints.tightFor(width: 40, height: 40));

      final rootLayer = ContainerLayer();
      final context = PaintingContext(rootLayer, Rect.largest);
      const realOffset = Offset(40, 60);

      // Upstream's equivalent zeroes the offset it hands pushLayer, so the
      // child paints at (0, 0) in the ambient coordinate frame instead of at
      // the layer's actual position -- wrong for every layer that is not
      // already at its parent's origin.
      layer.paint(context, realOffset);

      expect(spy.lastPaintOffset, realOffset);

      rootLayer.dispose();
    },
    tags: <String>['impeller'],
  );
}
