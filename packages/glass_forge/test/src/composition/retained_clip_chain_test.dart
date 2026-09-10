import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  testWidgets('glass survives being scrolled to the viewport edge',
      (tester) async {
    // Upstream #124: glass and its contents disappear at the scroll bounds.
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 300,
          child: ListView(
            controller: controller,
            children: const <Widget>[
              SizedBox(height: 400),
              GlassLayer(
                child: Glass(
                  shape: GlassRoundedRectangle(
                    radius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: SizedBox(
                    height: 80,
                    child: Center(child: Text('glass')),
                  ),
                ),
              ),
              SizedBox(height: 400),
            ],
          ),
        ),
      ),
    );

    for (final offset in const <double>[0, 200, 380, 400, 420, 600]) {
      controller.jumpTo(offset);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'at offset $offset');
    }

    controller.dispose();
  }, tags: <String>['impeller']);

  testWidgets('glass inside a clipped container stays clipped',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: const SizedBox(
              width: 200,
              height: 200,
              child: GlassLayer(
                child: Glass(
                  shape: GlassOval(),
                  child: SizedBox(width: 400, height: 400),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  }, tags: <String>['impeller']);

  testWidgets(
    'a clip nested between a layer and its shape is retained for the '
    'backdrop pass',
    (tester) async {
      // A stronger check than the two tests above, which only prove
      // nothing throws. This exercises RetainedClipChain.collect through
      // the actual render tree it is meant to walk: a ClipRRect a caller
      // places between a GlassLayer and one of its Glass shapes must be
      // captured and re-pushed outside the layer's own offset, not merely
      // rely on already being an ancestor in the render tree — see
      // RetainedClipChain's own doc comment for why capturing it inside
      // the moving layer would not clip at all once the layer scrolls.
      await tester.pumpWidget(
        const MaterialApp(
          home: GlassLayer(
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              child: Glass(
                shape: GlassOval(),
                child: SizedBox(width: 80, height: 80),
              ),
            ),
          ),
        ),
      );

      final layer = tester.renderObject<RenderGlassLayer>(
        find.byType(GlassLayer),
      );

      expect(layer.debugClipChain, hasLength(1));
      expect(layer.debugClipChain.single.rrect, isNotNull);
      expect(layer.debugClipChain.single.behavior, Clip.antiAlias);
    },
    tags: <String>['impeller'],
  );
}
