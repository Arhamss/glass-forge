import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/rendering/render_glass_shape.dart';

void main() {
  testWidgets('presence reaches the shape below it', (tester) async {
    const presence = AlwaysStoppedAnimation<double>(0.4);
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: GlassPresence(
            presence: presence,
            child: Glass(
              shape: GlassRoundedRectangle(radius: BorderRadius.circular(28)),
              child: const SizedBox(width: 100, height: 40),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final shape = tester.renderObject(find.byType(Glass).first);
    expect((shape as RenderGlassShape).presence!.value, 0.4);
  });

  testWidgets('a glass with no presence above it is fully present',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Glass(
            shape: GlassRoundedRectangle(radius: BorderRadius.circular(28)),
            child: const SizedBox(width: 100, height: 40),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
