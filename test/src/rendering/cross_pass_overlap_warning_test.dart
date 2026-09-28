import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

/// Two shapes in different materials, one on top of the other.
Widget _stacked() {
  return const MaterialApp(
    home: GlassLayer(
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 20,
            top: 20,
            width: 200,
            height: 60,
            child: Glass(shape: GlassOval()),
          ),
          Positioned(
            left: 40,
            top: 30,
            width: 80,
            height: 40,
            child: Glass(
              material: GlassMaterial(frost: 6),
              shape: GlassOval(),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  setUpAll(ShaderLibrary.instance.warmUp);

  // The check runs on every paint. An overlap that persists used to print
  // on every frame, which buried the rest of the log.
  testWidgets('a persisting overlap is reported once, not every frame', (
    tester,
  ) async {
    final printed = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) printed.add(message);
    };
    try {
      await tester.pumpWidget(_stacked());
      for (var i = 0; i < 10; i++) {
        tester.binding.scheduleForcedFrame();
        await tester.pump();
        // A repaint of the layer itself, not just a frame.
        tester.renderObject(find.byType(GlassLayer)).markNeedsPaint();
      }
    } finally {
      debugPrint = original;
    }
    expect(printed.where((m) => m.contains('187820')), hasLength(1));
  });
}
