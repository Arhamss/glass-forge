import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/gpu_geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/geometry/runtime_geometry_producer.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/rendering/render_glass_shape.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';

/// A fake accelerated producer that reports itself available immediately,
/// but flips to unavailable only once [warmUp] has actually run -- mirroring
/// `GpuGeometryProducer`'s real two-stage honesty contract (context probe
/// now, bundle-load result later) without needing real GPU hardware.
class _OptimisticThenFailingProducer implements GeometryProducer {
  bool _available = true;

  /// Whether [warmUp] has been called yet.
  bool warmUpCalled = false;

  @override
  GeometryCapabilities get capabilities =>
      GeometryCapabilities(available: _available, name: 'optimistic');

  @override
  Future<void> warmUp() async {
    warmUpCalled = true;
    // Discovered only now -- the moment a real bundle load would resolve --
    // that this producer cannot actually work.
    _available = false;
  }

  @override
  MatteGeneration? produce(GlassScene scene, MatteRequest request) => null;

  @override
  void release(MatteGeneration generation) {}

  @override
  void dispose() {}
}

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
      // A real shape between the layer and the spy, not just the spy: a
      // layer with nothing registered in it now pushes no backdrop at all,
      // which would leave this taking the plain `super.paint` branch and
      // asserting nothing about the pushClipRect/pushLayer path it exists
      // to guard.
      final shape = RenderGlassShape(shape: const GlassOval(), group: null)
        ..child = spy;

      // Attached before the child is adopted, so `adoptChild`'s
      // `markNeedsCompositingBitsUpdate()` call registers with a real
      // owner instead of silently no-op-ing against a still-null one --
      // otherwise `needsCompositing` asserts that its dirty bit was never
      // cleared, which paint() reads to decide whether to composite.
      final owner = PipelineOwner();
      layer
        ..attach(owner)
        ..child = shape;
      owner.flushCompositingBits();
      layer.layout(const BoxConstraints.tightFor(width: 40, height: 40));
      expect(
        layer.scene.shapes,
        hasLength(1),
        reason:
            'without a registered shape there is no backdrop pass, and '
            'the offset below would be checked on the wrong code path',
      );

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

  group('accelerated producer wiring (Task 18 fix round)', () {
    tearDown(() {
      ProducerRegistry.debugReset();
      debugResetAcceleratedProducerRegistration();
    });

    test(
      'building a RenderGlassLayer registers an accelerated producer '
      'without the caller ever naming GpuGeometryProducer '
      '(regression: C1 -- register() was never called in production)',
      () {
        ProducerRegistry.debugReset();
        debugResetAcceleratedProducerRegistration();
        expect(ProducerRegistry.debugAcceleratedCount, 0);

        // tier: none on purpose -- registration must happen regardless of
        // which tier this particular layer asked for, since a later layer
        // in the same app might ask for accelerated.
        final layer = RenderGlassLayer(
          material: const GlassMaterial(),
          tier: GeometryTier.none,
          devicePixelRatio: 1,
        );

        expect(ProducerRegistry.debugAcceleratedCount, greaterThan(0));
        layer.dispose();
      },
    );

    test(
      'the constructor warms up the selected producer through the '
      'interface, not just the shared runtime-effect ShaderLibrary '
      '(regression: C2 -- the constructor hardcoded '
      'ShaderLibrary.instance.warmUp(), never producer.warmUp())',
      () async {
        ProducerRegistry.debugReset();
        final tracking = _OptimisticThenFailingProducer();
        ProducerRegistry.registerAccelerated(() => tracking);

        final layer = RenderGlassLayer(
          material: const GlassMaterial(),
          tier: GeometryTier.accelerated,
          devicePixelRatio: 1,
        );
        // Confirms the fake really was selected, so warmUpCalled becoming
        // true below can only be explained by the constructor calling
        // producer.warmUp() -- ShaderLibrary.instance.warmUp() alone has no
        // way to reach this unrelated object.
        expect(identical(layer.debugProducer, tracking), isTrue);

        await pumpEventQueue();

        expect(tracking.warmUpCalled, isTrue);
        layer.dispose();
      },
    );

    test(
      'a producer that turns out unavailable once warm-up actually runs is '
      'replaced with the runtime producer, not left returning null forever '
      '(regression: C3 -- claiming availability it does not have degraded '
      'every glass layer to permanently unrefracted rendering)',
      () async {
        ProducerRegistry.debugReset();
        ProducerRegistry.registerAccelerated(
          _OptimisticThenFailingProducer.new,
        );

        final layer = RenderGlassLayer(
          material: const GlassMaterial(),
          tier: GeometryTier.accelerated,
          devicePixelRatio: 1,
        );
        expect(layer.debugProducer, isA<_OptimisticThenFailingProducer>());

        await pumpEventQueue();

        expect(layer.debugProducer, isA<RuntimeGeometryProducer>());
        layer.dispose();
      },
    );

    test(
      'the real GpuGeometryProducer, with a real usable GPU context but a '
      'shader bundle that cannot load, falls all the way back to a working '
      'runtime producer through RenderGlassLayer -- not to blank, '
      'unrefracted rendering (fail-soft check, re-run with '
      '--enable-flutter-gpu as flagged in the Task 18 review)',
      () async {
        ProducerRegistry.debugReset();
        // A deliberately-unresolvable asset key, exercising the same
        // ShaderLibrary.fromAsset failure path a genuinely broken build
        // would -- see debugBundleAssetKeys' doc comment -- through the
        // real GpuGeometryProducer, not a fake standing in for it.
        ProducerRegistry.registerAccelerated(
          () => GpuGeometryProducer(
            debugBundleAssetKeys: const [
              'packages/glass_forge/does/not/exist.shaderbundle',
            ],
          ),
        );

        final layer = RenderGlassLayer(
          material: const GlassMaterial(),
          tier: GeometryTier.accelerated,
          devicePixelRatio: 1,
        );

        if (!layer.debugProducer.capabilities.available) {
          // Flutter GPU's own backend is unavailable here (no
          // --enable-flutter-gpu in this invocation), so ProducerRegistry
          // .select already fell through to the runtime producer before
          // construction finished, and the warm-up-time fallback this test
          // targets never has anything to do. A legitimate outcome, not a
          // false pass: confirm the trivial case explicitly instead of
          // silently asserting nothing.
          expect(layer.debugProducer, isA<RuntimeGeometryProducer>());
          layer.dispose();
          return;
        }
        expect(layer.debugProducer, isA<GpuGeometryProducer>());

        await pumpEventQueue();

        expect(layer.debugProducer, isA<RuntimeGeometryProducer>());
        layer.dispose();
      },
      tags: ['impeller'],
    );
  });
}
