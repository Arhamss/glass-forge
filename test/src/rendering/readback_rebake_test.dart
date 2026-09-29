// A `toImage` readback of a boundary holding a glass layer costs no bake.
//
// Impeller only: real glass means `ui.ImageFilter.shader`. Run with
// `flutter test --tags impeller --run-skipped --enable-impeller`.
//
// What looked like the readback's doing was the layer's warm-up settling.
// A test's fake-async zone holds that back until the first real-async
// window, which a readback's `runAsync` is, and its settling used to force
// every pass to bake again even when the matte it held had come from a
// producer that was ready all along. On a device the same bake landed a
// few frames after every layer mounted, readback or not.
@Tags(<String>['impeller'])
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/diagnostics/render_counters.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

const _boundary = ValueKey<String>('boundary');

Widget _scene(GeometryTier tier) => RepaintBoundary(
  key: _boundary,
  // Its own `MediaQuery`, at a device pixel ratio of 1: see
  // `glass_material_pass_test.dart` for why this rasterizer needs it.
  child: MediaQuery(
    data: const MediaQueryData(),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF808080),
        child: GlassLayer(
          tier: tier,
          child: const Stack(
            children: [
              Positioned(
                left: 8,
                top: 8,
                width: 120,
                height: 60,
                child: Glass(shape: GlassOval()),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

/// Repaints the layer, and pumps a frame after, so any bake lands.
Future<void> _repaint(WidgetTester tester) async {
  tester
      .renderObject<RenderGlassLayer>(find.byType(GlassLayer))
      .markNeedsPaint();
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  /// Pumps [tier]'s scene, reads it back, and answers how many mattes were
  /// baked from the readback through two repaints after it.
  Future<int> bakesAcrossReadback(
    WidgetTester tester,
    GeometryTier tier,
  ) async {
    await tester.pumpWidget(_scene(tier));
    await _repaint(tester);
    expect(
      tester
          .renderObject<RenderGlassLayer>(find.byType(GlassLayer))
          .debugPassClips
          .where((clip) => !clip.isEmpty),
      isNotEmpty,
      reason: 'the pass must be pushed for a bake count to mean much',
    );

    GlassRenderCounters.instance.reset();
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_boundary),
      );
      final image = await boundary.toImage();
      image.dispose();
    });
    await _repaint(tester);
    await _repaint(tester);
    return GlassRenderCounters.instance.matteProduceCount;
  }

  testWidgets('a readback costs no bake', (tester) async {
    // The runtime producer is ready as soon as the shader library is, so
    // the pass already holds its matte when the warm-up settles.
    expect(await bakesAcrossReadback(tester, GeometryTier.portable), 0);
  });

  testWidgets('a pass the producer had nothing for bakes once its warm-up '
      'settles, and only once', (tester) async {
    // The accelerated producer's shader bundle loads asynchronously, and
    // in a test not before the readback's real-async window: every paint
    // before that got no matte, so the settling has to be retried on.
    expect(await bakesAcrossReadback(tester, GeometryTier.accelerated), 1);
  });
}
