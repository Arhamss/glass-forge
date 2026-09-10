// `GlassLayer`'s shaders are already warm by the time these tests pump their
// first frame (see `setUpAll`), so its render object takes the real path
// through `GlassComposition`, which constructs `ui.ImageFilter.shader`. That
// throws `UnsupportedError` outside Impeller, so — like
// `glass_composition_test.dart` — this file is excluded from a bare
// `flutter test` run (see dart_test.yaml) and only runs via the separate
// `flutter test --tags impeller --run-skipped --enable-impeller` CI step.
@Tags(<String>['impeller'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  testWidgets('a glass child paints in place, not deferred', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassLayer(
          child: Center(
            child: Glass(
              shape: GlassRoundedRectangle(
                radius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Text('visible'),
            ),
          ),
        ),
      ),
    );

    // Upstream's children are invisible until both shaders load, because its
    // paint() is a no-op and the layer paints them later.
    expect(find.text('visible'), findsOneWidget);
    final box = tester.renderObject<RenderBox>(find.text('visible'));
    expect(box.hasSize, isTrue);
  });

  testWidgets('Glass outside a layer still renders', (tester) async {
    // Upstream asserts in debug and null-crashes in release. Create an
    // implicit layer instead and warn.
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: Glass(shape: GlassOval(), child: Text('orphan'))),
      ),
    );
    expect(find.text('orphan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('more shapes than the cap degrade, never blank the UI', (
    tester,
  ) async {
    // Upstream throws UnsupportedError from inside paint(): a red box in
    // debug, and in release the whole layer plus every child stops painting.
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Stack(
            children: <Widget>[
              for (var i = 0; i < 40; i++)
                Positioned(
                  left: i * 4.0,
                  child: const Glass(
                    shape: GlassOval(),
                    child: SizedBox(width: 10, height: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(GlassLayer), findsOneWidget);
  });

  testWidgets('disposing a layer leaks no shaders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassLayer(
          child: Glass(
            shape: GlassOval(),
            child: SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(ShaderLibrary.instance.debugOutstandingCount, 0);
  });
}
