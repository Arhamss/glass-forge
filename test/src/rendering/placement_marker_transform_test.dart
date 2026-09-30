import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/motion/glass_jiggle.dart';
import 'package:glass_forge/src/motion/glass_press_stretch.dart';
import 'package:glass_forge/src/motion/interactive_glass.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

// A shape under a repaint boundary inside its glass layer adds an empty
// placement marker where it paints. Adding a layer ends the picture being
// recorded, and a canvas transform an ancestor applied to that picture does
// not carry into the next one -- so the content painted after the marker,
// the glass's own label or glyph, used to paint untransformed while the
// glass it sits on stretched. The example's buttons sit under exactly such
// a boundary: the `Opacity` of their entrance animation.

const GlassMaterial _inert = GlassMaterial(
  frost: 0,
  edgeRefraction: 0,
  highlight: 0,
);

const Key _capture = Key('capture');
const Color _red = Color(0xFFFF0000);

Future<Color> _pixelAt(WidgetTester tester, Offset point) async {
  late Uint8List pixels;
  late int width;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_capture),
    );
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData();
      pixels = data!.buffer.asUint8List();
      width = image.width;
    } finally {
      image.dispose();
    }
  });
  final i = (point.dy.round() * width + point.dx.round()) * 4;
  return Color.fromARGB(
    pixels[i + 3],
    pixels[i],
    pixels[i + 1],
    pixels[i + 2],
  );
}

void main() {
  testWidgets(
    'content on stretched glass under a repaint boundary stretches too',
    (tester) async {
      await tester.pumpWidget(
        const RepaintBoundary(
          key: _capture,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: GlassLayer(
              tier: GeometryTier.none,
              material: _inert,
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  // A repaint boundary between the glass and its layer.
                  child: Opacity(
                    opacity: 0.99,
                    child: SizedBox.square(
                      dimension: 40,
                      child: InteractiveGlass(
                        pressGrowth: 0,
                        jiggle: GlassJiggle.none(),
                        glow: false,
                        pressStretch: GlassPressStretch(travel: 0),
                        child: Glass(
                          shape: GlassOval(),
                          child: ColoredBox(color: _red),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(40, 40));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Past the first frame the shape has asked its ancestors to composite,
      // so the stretch is a layer the marker cannot split, not a canvas
      // transform -- which is what keeps anything painted after the marker
      // in step too, not only the shape's own content.
      expect(
        tester
            .renderObject<RenderBox>(find.byType(InteractiveGlass))
            .needsCompositing,
        isTrue,
      );

      // At rest the box spans y 20 to 60. Stretched down its middle it
      // reaches past 60 at the bottom and above 20 at the top.
      final below = await _pixelAt(tester, const Offset(40, 63));
      final above = await _pixelAt(tester, const Offset(40, 17));
      expect(below.r, greaterThan(0.9), reason: 'the content did not stretch');
      expect(above.r, greaterThan(0.9), reason: 'the content did not stretch');

      await gesture.up();
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    },
  );
}
