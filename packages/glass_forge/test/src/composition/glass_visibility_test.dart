import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/diagnostics/render_counters.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

/// Rasterizes the boundary at [key] and reads its pixels back as RGBA.
///
/// `toImage()` and `toByteData()` both complete via a real engine callback,
/// which the fake clock `testWidgets` runs under never fires, so this drops
/// out of that zone with `runAsync`.
Future<_Captured> _capture(WidgetTester tester, Key key) async {
  late Uint8List pixels;
  late int width;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final image = await boundary.toImage();
    try {
      pixels = (await image.toByteData())!.buffer.asUint8List();
      width = image.width;
    } finally {
      image.dispose();
    }
  });
  return _Captured(pixels, width);
}

class _Captured {
  const _Captured(this._pixels, this._width);

  final Uint8List _pixels;
  final int _width;

  /// Reads at a point given in the harness's *logical* pixels.
  ///
  /// `toImage()` rasterizes at the device pixel ratio, so a 300pt harness
  /// comes back 900px wide under the test binding's default ratio of 3.
  /// Indexing it with logical coordinates samples the top-left corner and
  /// quietly misses the shape entirely.
  Color at(Offset point) {
    final scale = _width / _harnessSize;
    final index =
        ((point.dy * scale).round() * _width + (point.dx * scale).round()) * 4;
    return Color.fromARGB(
      _pixels[index + 3],
      _pixels[index],
      _pixels[index + 1],
      _pixels[index + 2],
    );
  }
}

/// The harness's logical size, in points.
const double _harnessSize = 300;

const _boundary = Key('boundary');

/// A backdrop with structure in it, so refraction has something to bend.
Widget _harness({required GlassMaterial material}) {
  return MaterialApp(
    home: RepaintBoundary(
      key: _boundary,
      child: SizedBox(
        width: _harnessSize,
        height: _harnessSize,
        child: Stack(
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[Color(0xFFFFFFFF), Color(0xFF000000)],
                ),
              ),
              child: SizedBox.expand(),
            ),
            Center(
              child: GlassLayer(
                material: material,
                child: const SizedBox(
                  width: 120,
                  height: 120,
                  child: Glass(
                    shape: GlassRoundedRectangle(
                      radius: BorderRadius.all(Radius.circular(24)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  testWidgets(
    'the interior of a glass shape is not the raw backdrop',
    (tester) async {
      // The regression that made every surface read as a frosted cut-out:
      // coverage came from the displacement magnitude, which the edge-band
      // profile zeroes across the whole interior, so the middle of every
      // shape fell through to the untouched backdrop.
      await tester.pumpWidget(
        _harness(
          material: const GlassMaterial().copyWith(
            edgeRefraction: 40,
            tint: const Color(0xFF00FF00),
            tintOpacity: 0.5,
            frost: 0,
          ),
        ),
      );
      // The layer's shader/bundle warm-up is a real engine asset read, which
      // the fake clock a bare testWidgets body runs under cannot drive to
      // completion. runAsync drops out of that zone; the extra pump lets the
      // repaint its completion schedules actually run.
      await tester.runAsync(pumpEventQueue);
      await tester.pump();

      final captured = await _capture(tester, _boundary);
      // ignore-free diagnostic while bringing this test up
      expect(
        GlassRenderCounters.instance.matteProduceCount,
        greaterThan(0),
        reason: 'no matte was produced',
      );
      expect(
        GlassRenderCounters.instance.backdropPushCount,
        greaterThan(0),
        reason: 'no backdrop filter was pushed',
      );
      final centre = captured.at(const Offset(150, 150));
      final outside = captured.at(const Offset(20, 150));

      // A heavy green tint over a greyscale gradient: if the interior is
      // rendering at all, its green channel dominates. If coverage never
      // reaches the middle, the centre is just more grey.
      expect(
        centre.g,
        greaterThan(centre.r),
        reason: 'interior did not take the tint: $centre',
      );
      expect(
        outside.g,
        closeTo(outside.r, 0.01),
        reason: 'backdrop was tinted',
      );
    },
    tags: <String>['impeller'],
  );

  testWidgets(
    'the backdrop beside a glass shape is left untouched',
    (tester) async {
      // The other half: non-covered fragments used to be written back
      // opaque, carrying the already-blurred backdrop, so the frost covered
      // the whole layer rather than the shapes.
      await tester.pumpWidget(
        _harness(
          material: const GlassMaterial().copyWith(frost: 12, tintOpacity: 0),
        ),
      );
      // The layer's shader/bundle warm-up is a real engine asset read, which
      // the fake clock a bare testWidgets body runs under cannot drive to
      // completion. runAsync drops out of that zone; the extra pump lets the
      // repaint its completion schedules actually run.
      await tester.runAsync(pumpEventQueue);
      await tester.pump();

      final captured = await _capture(tester, _boundary);

      // Two neighbouring columns well outside the shape. A blur across the
      // whole layer would flatten the gradient between them.
      final a = captured.at(const Offset(10, 150));
      final b = captured.at(const Offset(70, 150));
      expect(
        (a.r - b.r).abs(),
        greaterThan(0.05),
        reason: 'backdrop was blurred',
      );
    },
    tags: <String>['impeller'],
  );
}
