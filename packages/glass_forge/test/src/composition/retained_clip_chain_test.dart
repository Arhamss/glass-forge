import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

/// Plain, non-swatch reds and whites for the pixel tests below.
///
/// `Colors.red`/`Colors.white` are [MaterialColor]s, whose `==` requires
/// the other side to also be a [MaterialColor] -- a plain [Color] read
/// back from a captured pixel never is, so comparing against them directly
/// always fails even when every channel matches.
const _red = Color(0xFFFF0000);
const _white = Color(0xFFFFFFFF);

/// Rasterizes the [RenderRepaintBoundary] found at [key] and reads back its
/// pixels as RGBA.
///
/// `toImage()` and `Image.toByteData()` both complete via a real engine
/// callback, which the fake clock `testWidgets` runs under never fires --
/// awaiting either directly inside a `testWidgets` body hangs forever.
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

  testWidgets(
    'a clip offset from the layer does not displace the content it clips',
    (tester) async {
      // Regression: RetainedClip.transform maps a clip's own local space
      // into the layer's, but the closures in _pushGlassLayers nested the
      // real content (pushBackdrop, reached through `super.paint`) inside
      // that same pushTransform -- content that was already correctly
      // positioned in the layer's own frame, so it needed no transform at
      // all. Any retained clip sitting at a non-identity offset from the
      // layer (here, a Padding between GlassLayer and the nested ClipRRect)
      // shifted the rendered content by that same offset.
      final boundaryKey = UniqueKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: Container(
                width: 200,
                height: 200,
                color: _white,
                child: GlassLayer(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 40, top: 40),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Glass(
                        shape: const GlassRoundedRectangle(
                          radius: BorderRadius.all(Radius.circular(8)),
                        ),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            width: 60,
                            height: 60,
                            color: _red,
                          ),
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

      final captured = await _captureRgba(tester, boundaryKey);

      // Correct position: the Padding places the red square's top-left at
      // (40, 40), so a point well inside it -- away from any antialiased
      // edge -- must be red.
      expect(captured.colorAt(const Offset(70, 70)), _red);

      // The bug's signature shift: it displaced content by the retained
      // clip's own offset from the layer, which is also (40, 40) here, so
      // a buggy build would have painted red starting around (80, 80)
      // instead. A point inside that wrong square but outside the correct
      // one must not be red.
      expect(captured.colorAt(const Offset(110, 110)), isNot(_red));
    },
    tags: <String>['impeller'],
  );

  testWidgets(
    'two nested clips at different offsets from each other still land '
    'content in the right place',
    (tester) async {
      // A second transform-composition case, with two retained clips
      // instead of one. Translations commute, so this alone cannot tell
      // the push-order fix (below) apart from getting it backwards -- see
      // "two nested clips composed through a non-commuting transform" for
      // that.
      final boundaryKey = UniqueKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: Container(
                width: 200,
                height: 200,
                color: _white,
                child: GlassLayer(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, top: 10),
                    child: ClipRect(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, top: 20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Glass(
                            shape: const GlassRoundedRectangle(
                              radius: BorderRadius.all(Radius.circular(8)),
                            ),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Container(
                                width: 40,
                                height: 40,
                                color: _red,
                              ),
                            ),
                          ),
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

      final layer = tester.renderObject<RenderGlassLayer>(
        find.byType(GlassLayer),
      );
      expect(layer.debugClipChain, hasLength(2));

      final captured = await _captureRgba(tester, boundaryKey);

      // The two Paddings place the red square's top-left at
      // (10 + 20, 10 + 20) = (30, 30).
      expect(captured.colorAt(const Offset(50, 50)), _red);
      // Well outside it in every direction a transform-composition or
      // push-order bug could plausibly displace it to.
      expect(captured.colorAt(const Offset(10, 10)), isNot(_red));
      expect(captured.colorAt(const Offset(150, 150)), isNot(_red));
    },
    tags: <String>['impeller'],
  );

  testWidgets(
    'two nested clips composed through a non-commuting transform still '
    'land content in the right place',
    (tester) async {
      // Regression: _pushGlassLayers built its closure chain in the same
      // order RetainedClipChain.clips lists its entries (outermost first),
      // which makes the *last*-processed entry the *outermost* invocation
      // once nesting unwinds -- the reverse of what "outermost first"
      // means for the closures themselves. That silently produced the
      // same pixels as getting it right whenever every retained clip sat
      // at a pure translation from its neighbours (as in the test above),
      // since translations commute regardless of nesting order. A scale
      // between the two clips does not commute with the translations
      // around it, so getting the push order backwards here really does
      // move content. The outer Padding's offset `a` and the scale `k`
      // are chosen so the wrong order displaces content by exactly
      // `a * (k - 1)` = 60 logical pixels -- far enough that the correct
      // and incorrect squares do not overlap at all, so both probes below
      // discriminate on their own.
      final boundaryKey = UniqueKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: Container(
                width: 200,
                height: 200,
                color: _white,
                child: GlassLayer(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 30, top: 30),
                    child: ClipRect(
                      child: Transform(
                        // No `alignment`/`origin`: those need the
                        // RenderTransform's own size, which is not yet
                        // known the first time RenderGlassShape resolves
                        // its geometry during layout (a pre-existing,
                        // separate limitation, not one this task's scope
                        // covers) -- an origin-less matrix has no such
                        // dependency.
                        transform: Matrix4.diagonal3Values(3, 3, 1),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10, top: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Glass(
                              shape: const GlassRoundedRectangle(
                                radius: BorderRadius.all(Radius.circular(8)),
                              ),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  color: _red,
                                ),
                              ),
                            ),
                          ),
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

      final layer = tester.renderObject<RenderGlassLayer>(
        find.byType(GlassLayer),
      );
      expect(layer.debugClipChain, hasLength(2));

      final captured = await _captureRgba(tester, boundaryKey);

      // The outer Padding places the ClipRect at (30, 30). Inside it, the
      // 3x scale triples both the inner Padding's offset and the red
      // square's own declared size: the square's top-left lands at
      // (30 + 3*10, 30 + 3*10) = (60, 60), and it is 3*20 = 60 logical
      // pixels wide, so its centre is (90, 90).
      expect(captured.colorAt(const Offset(90, 90)), _red);

      // Pushing the chain in list order instead of reversed composes the
      // two clips' transforms as `inner * outer` while the undo step
      // inverts `outer * inner`, leaving content shifted by exactly
      // `30 * (3 - 1)` = 60 -- putting the square at (120, 120)..(180,
      // 180), whose centre is here. It must not be red.
      expect(captured.colorAt(const Offset(150, 150)), isNot(_red));
    },
    tags: <String>['impeller'],
  );

  testWidgets(
    'an ancestor clip outside the layer already bounds the backdrop '
    'without the retained chain',
    (tester) async {
      // Critical 3's empirical check: RetainedClipChain.collect walks from
      // a shape up to its layer and stops there, so it never sees a clip
      // that is an ancestor of the *layer* itself, such as this ClipRect.
      // Before extending the walk past the layer on faith, confirm
      // Flutter's own ancestor clipping already bounds the backdrop pass
      // in that case: the ClipRect's clip layer is already in the
      // compositor's layer tree, pushed by ClipRect's own paint(), before
      // RenderGlassLayer.paint ever runs.
      final boundaryKey = UniqueKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: Container(
                width: 200,
                height: 200,
                color: _white,
                child: Center(
                  child: ClipRect(
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: OverflowBox(
                        maxWidth: 160,
                        maxHeight: 160,
                        child: GlassLayer(
                          child: Glass(
                            shape: const GlassRoundedRectangle(
                              radius: BorderRadius.all(Radius.circular(8)),
                            ),
                            child: Container(
                              width: 160,
                              height: 160,
                              color: _red,
                            ),
                          ),
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

      final layer = tester.renderObject<RenderGlassLayer>(
        find.byType(GlassLayer),
      );
      // Confirms this really is testing Flutter's own ancestor clipping,
      // not the retained chain quietly picking the ClipRect up anyway:
      // collect() never walks past the layer, so it must be empty here.
      expect(layer.debugClipChain, isEmpty);

      final captured = await _captureRgba(tester, boundaryKey);

      // The 160x160 red content is centered on a 60x60 window (ClipRect's
      // own reported size), so the window spans (70, 70)..(130, 130) and
      // the content spans (20, 20)..(180, 180). This probe sits 30 logical
      // pixels left of the window and halfway down it -- deep inside the
      // overflowing content, nowhere near its own corners or the glass
      // shape's rounding, so it is red unless the ClipRect really is
      // bounding the backdrop pass.
      expect(captured.colorAt(const Offset(40, 100)), isNot(_red));
      // And a point inside the window must be red -- proving the glass
      // content is actually there, not absent for some unrelated reason.
      expect(captured.colorAt(const Offset(100, 100)), _red);
    },
    tags: <String>['impeller'],
  );

  testWidgets(
    "a scrolling viewport's own clip already bounds the backdrop of a "
    'glass layer inside it',
    (tester) async {
      // Critical 3, in the shape the brief actually framed it: a
      // GlassLayer inside a ListView. collect() walks from a shape up to
      // its layer and stops, so the ListView's RenderViewport -- an
      // ancestor of the layer, not a descendant -- is never captured. The
      // viewport pushes its own clip in its own paint(), before
      // RenderGlassLayer.paint runs, and that clip layer is an ancestor of
      // everything this layer pushes, including the backdrop pass. So it
      // stays anchored to the viewport while the content scrolls through
      // it, with nothing to re-push.
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final boundaryKey = UniqueKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: Container(
                width: 200,
                height: 300,
                color: _white,
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      height: 200,
                      child: ListView(
                        controller: controller,
                        children: <Widget>[
                          const SizedBox(height: 150),
                          GlassLayer(
                            child: Glass(
                              shape: const GlassRoundedRectangle(
                                radius: BorderRadius.all(Radius.circular(8)),
                              ),
                              child: Container(height: 100, color: _red),
                            ),
                          ),
                          const SizedBox(height: 400),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final layer = tester.renderObject<RenderGlassLayer>(
        find.byType(GlassLayer),
      );
      // Nothing between the layer and its shape clips, so the chain is
      // empty -- whatever bounds the glass below is Flutter's own, not
      // anything this task re-pushes.
      expect(layer.debugClipChain, isEmpty);

      final captured = await _captureRgba(tester, boundaryKey);

      // The red glass sits at list offset 150..250 while the viewport
      // shows 0..200, so it is cut halfway down. Above the cut it is red.
      expect(captured.colorAt(const Offset(100, 175)), _red);
      // Below the viewport's own bottom edge the boundary is still 100
      // logical pixels of white Column space, which is where the glass
      // would spill to if the viewport's clip were moving with the
      // content instead of staying put.
      expect(captured.colorAt(const Offset(100, 220)), isNot(_red));
    },
    tags: <String>['impeller'],
  );
}
