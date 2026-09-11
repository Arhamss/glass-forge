// Every scene here composes a real `ui.ImageFilter.shader` via
// `GlassComposition.build`, which throws `UnsupportedError` outside
// Impeller. Same reason and same pattern as
// `test/src/diagnostics/invalidation_test.dart` -- see dart_test.yaml.
@Tags(<String>['impeller'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/benchmark/scenes/benchmark_scene.dart';
import 'package:glass_forge/src/benchmark/scenes/glass_benchmark_scenes.dart';
import 'package:glass_forge/src/diagnostics/render_counters.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);
  setUp(GlassRenderCounters.instance.reset);

  test('every scene id is unique', () {
    // budgets.json is keyed by id; a duplicate would make one scene's
    // budget silently apply to two different measurements.
    final ids = glassBenchmarkScenes.map((scene) => scene.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('the catalog covers every axis the harness names', () {
    final axes = glassBenchmarkScenes.map((scene) => scene.axis).toSet();
    expect(axes, BenchmarkAxis.values.toSet());
  });

  for (final scene in glassBenchmarkScenes) {
    testWidgets('${scene.id} exercises the renderer, not just widgets', (
      tester,
    ) async {
      // The premise this test exists to check: a scene that only built an
      // inert tree -- an orphaned Glass, a material with nothing to render,
      // shaders that never finished loading -- would still produce frame
      // timings, and those timings would look like a real, if suspiciously
      // fast, measurement. Nothing about a frame-time percentile can tell
      // the difference on its own; this can, because GlassRenderCounters
      // only moves when RenderGlassLayer actually pushes a real backdrop
      // filter.
      expect(GlassRenderCounters.instance.backdropPushCount, 0);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(builder: scene.build),
        ),
      );

      expect(GlassRenderCounters.instance.backdropPushCount, greaterThan(0));

      // AnimatedBenchmarkBackdrop repeats its AnimationController forever,
      // by design -- it is what keeps a real on-device run producing frames
      // for the whole measurement window. Unmount it before the test ends
      // so its ticker is disposed; flutter_test asserts nothing is still
      // pending when a test finishes.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
