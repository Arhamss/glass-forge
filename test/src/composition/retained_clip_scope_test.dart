// What the retained chain is allowed to contain when a layer holds more
// than one shape.
//
// `retained_clip_chain_test.dart` covers the single-shape arrangements:
// one `Glass` under one or two nested clips, where whatever clips that
// shape is also, trivially, a clip of every shape in the layer. This file
// covers the arrangement that one cannot reach -- several shapes, each
// with clips of its own -- and pins the rule that separates them: a
// retained clip is re-pushed *around the whole layer's backdrop pass and
// its subtree*, so a clip that bounds only one shape must never be
// retained. Retaining one crops every other shape, and every painted
// thing in the layer, to that one shape's private box.

import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';

/// A plain, non-swatch red.
///
/// `Colors.red` is a `MaterialColor`, whose `==` requires the other side to
/// also be one -- a plain [Color] read back off a captured pixel never is.
const _red = Color(0xFFFF0000);
const _white = Color(0xFFFFFFFF);

/// Rasterizes the [RenderRepaintBoundary] at [key] and reads its pixels.
///
/// `toImage()` and `Image.toByteData()` both complete via a real engine
/// callback, which the fake clock `testWidgets` runs under never fires;
/// `tester.runAsync` drops out of that fake zone just for this call.
Future<_CapturedImage> _captureRgba(WidgetTester tester, Key key) async {
  late Uint8List pixels;
  late int width;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final image = await boundary.toImage();
    try {
      final byteData = await image.toByteData();
      pixels = byteData!.buffer.asUint8List();
      width = image.width;
    } finally {
      image.dispose();
    }
  });
  return _CapturedImage(pixels, width);
}

/// RGBA pixels captured from a rasterized frame.
class _CapturedImage {
  const _CapturedImage(this._pixels, this._width);

  final Uint8List _pixels;
  final int _width;

  /// The color at [point], read back as premultiplied RGBA.
  Color colorAt(Offset point) {
    final x = point.dx.round();
    final y = point.dy.round();
    final index = (y * _width + x) * 4;
    return Color.fromARGB(
      _pixels[index + 3],
      _pixels[index],
      _pixels[index + 1],
      _pixels[index + 2],
    );
  }
}

/// Two shapes in one layer -- the first of them behind a private clip --
/// plus a painted marker that sits outside that clip.
///
/// Deliberately shaped like the example catalogue's index, which is where
/// this was found: a scrolled list of rows, each row's thumbnail in its own
/// small `ClipRRect`, a glass bar outside that list, and text everywhere.
Widget _twoShapesOneClipped(Key boundaryKey) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: boundaryKey,
        child: SizedBox(
          width: 200,
          height: 200,
          child: ColoredBox(
            color: _white,
            child: GlassLayer(
              child: Stack(
                children: [
                  // Registers first, so it is what `firstShapeOwner`
                  // answers -- the one shape whose private clip used to
                  // become the whole layer's.
                  const Positioned(
                    left: 0,
                    top: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(
                        Radius.circular(10),
                      ),
                      child: Glass(
                        shape: GlassRoundedRectangle(
                          radius: BorderRadius.all(Radius.circular(10)),
                        ),
                        child: SizedBox(width: 44, height: 44),
                      ),
                    ),
                  ),
                  // A second shape, outside that clip entirely.
                  const Positioned(
                    left: 0,
                    top: 60,
                    child: Glass(
                      shape: GlassRoundedRectangle(
                        radius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: SizedBox(width: 44, height: 44),
                    ),
                  ),
                  // Plain painted content, far from the clipped shape. The
                  // layer paints its subtree inside its last backdrop pass,
                  // so anything wrapped around that pass crops this too.
                  Positioned(
                    left: 20,
                    top: 140,
                    child: Container(width: 160, height: 40, color: _red),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'a clip private to one shape does not crop the rest of the layer',
    (tester) async {
      // Regression: `RenderGlassLayer.paint` collected the retained chain
      // from `scene.firstShapeOwner` -- one arbitrary shape -- and
      // re-pushed it around the whole backdrop pass, inside which the
      // subtree paints. On the example catalogue's index that arbitrary
      // shape was a 44x44 row thumbnail in its own `ClipRRect`, so the
      // entire page rendered as bare backdrop and a single 44x44 square.
      final errors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = errors.add;
      final boundaryKey = UniqueKey();
      try {
        await tester.pumpWidget(_twoShapesOneClipped(boundaryKey));
        // The geometry producer's warm-up resolves off the fake clock, and
        // the repaint it schedules once it settles has to actually run
        // before the boundary is clean enough for `toImage` -- which
        // asserts `!debugNeedsPaint` rather than painting on demand.
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
      } finally {
        FlutterError.onError = previousOnError;
      }
      expect(errors, isEmpty, reason: errors.map((e) => e.exception).join());

      final captured = await _captureRgba(tester, boundaryKey);

      // The marker is at (20, 140) to (180, 180). Probe well inside it.
      expect(captured.colorAt(const Offset(100, 160)), _red);
      expect(captured.colorAt(const Offset(30, 145)), _red);

      // And the layer kept nothing: neither shape's ancestry has a clip
      // the other shares.
      final layer = tester.renderObject<RenderGlassLayer>(
        find.byType(GlassLayer),
      );
      expect(layer.debugClipChain, isEmpty);
    },
  );

  testWidgets(
    'a clip every shape sits under is still retained',
    (tester) async {
      // The other half of the rule, so the fix above cannot be "retain
      // nothing". Both shapes are under the same `ClipRRect`, which is
      // therefore a clip of the layer's whole scene and has to survive --
      // it is what stops the backdrop filter sampling and filling outside
      // the box the caller asked for.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 200,
              child: GlassLayer(
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Glass(
                          shape: GlassRoundedRectangle(
                            radius: BorderRadius.all(Radius.circular(10)),
                          ),
                          child: SizedBox(width: 44, height: 44),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 60,
                        child: Glass(
                          shape: GlassRoundedRectangle(
                            radius: BorderRadius.all(Radius.circular(10)),
                          ),
                          child: SizedBox(width: 44, height: 44),
                        ),
                      ),
                    ],
                  ),
                ),
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
    },
  );
}
