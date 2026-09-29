// Body glass in a `GlassScaffold` never renders under a bar.
//
// Impeller only: a backdrop pass is only pushed, and so only clipped, once
// `ui.ImageFilter.shader` exists. Run with
// `flutter test --tags impeller --run-skipped --enable-impeller`.
//
// The body's layer clips its passes to the band between the bars. What is
// asserted is that clip, read back from the layer as it was pushed: a switch
// scrolled under the top bar has its glass clipped out of the bar's rect
// entirely, so the bar's backdrop filter never sits over a second one
// (flutter#187820). Before the body had a layer of its own, the switch built
// an implicit one whose single, unclipped pass drew wherever the switch was
// -- under the bar included.
@Tags(<String>['impeller'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/chrome/glass_scaffold.dart';
import 'package:glass_forge/src/controls/glass_button.dart';
import 'package:glass_forge/src/controls/glass_switch.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';

const double _barHeight = 60;

/// The layer that renders the switch's knob.
RenderGlassLayer _knobLayer(WidgetTester tester) {
  // `.last`: a `Glass` with no layer above it wraps itself in an implicit
  // one, and the inner of the two is the one that renders.
  final knob = find
      .descendant(of: find.byType(GlassSwitch), matching: find.byType(Glass))
      .last;
  RenderObject? node = tester.renderObject(knob);
  while (node != null && node is! RenderGlassLayer) {
    node = node.parent;
  }
  return node! as RenderGlassLayer;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  testWidgets(
    'a body switch scrolled under the top bar has no glass in the bar',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      final printed = <String>[];
      final previous = debugPrint;
      // Restored in a `finally`: flutter_test checks `debugPrint` was put
      // back before any tear-down runs.
      debugPrint = (message, {wrapWidth}) {
        if (message != null) {
          printed.add(message);
        }
      };
      final clipsInBand = <Rect>[];
      final clipsUnderBar = <Rect>[];
      try {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: GlassScaffold(
                topBar: const SizedBox(
                  height: _barHeight,
                  child: Glass(shape: GlassOval()),
                ),
                body: ListView(
                  controller: controller,
                  children: [
                    const SizedBox(height: 100),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GlassSwitch(value: true, onChanged: (_) {}),
                    ),
                    const SizedBox(height: 2000),
                  ],
                ),
              ),
            ),
          ),
        );
        // The bar's height is measured a frame late; see `_MeasureSize`.
        await tester.pump();
        await tester.pump();

        // At rest in the band: the knob's pass is there, and below the bar.
        clipsInBand.addAll(_knobLayer(tester).debugPassClips);

        // Scrolled so the switch sits squarely under the bar.
        final switchTop = tester.getTopLeft(find.byType(GlassSwitch)).dy;
        controller.jumpTo(switchTop - 10);
        await tester.pump();
        await tester.pump();
        final switchRect = tester.getRect(find.byType(GlassSwitch));
        expect(
          switchRect.bottom,
          lessThan(_barHeight),
          reason: 'the switch must be under the bar for this to mean anything',
        );
        clipsUnderBar.addAll(_knobLayer(tester).debugPassClips);
      } finally {
        debugPrint = previous;
      }

      expect(clipsInBand, isNotEmpty);
      expect(
        clipsInBand.any((clip) => !clip.isEmpty),
        isTrue,
        reason: 'the knob renders while it is between the bars',
      );
      for (final clip in [...clipsInBand, ...clipsUnderBar]) {
        expect(
          clip.isEmpty || clip.top >= _barHeight,
          isTrue,
          reason: 'body glass clipped to $clip reaches into the bar',
        );
      }
      // Under the bar the knob's pass is still pushed -- its clip keeps the
      // filter's reach below the bar's edge, where the pass draws nothing
      // -- but none of it is inside the bar, which the loop above checked.
      expect(clipsUnderBar, isNotEmpty);
      expect(
        printed.where(
          (line) => line.contains('implicit') || line.contains('overlap'),
        ),
        isEmpty,
      );
    },
  );

  /// Pumps a scaffold whose body holds a switch (and, with [button], a
  /// button in another material) 1000 px down a long list, scrolls the
  /// switch's top to [switchTop], and returns every pass clip of the
  /// body's layer there, and what was printed.
  Future<(List<Rect>, List<String>)> clipsWithSwitchAt(
    WidgetTester tester, {
    required double switchTop,
    Widget? topBar,
    Widget? bottomBar,
    double keyboard = 0,
    bool button = false,
  }) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final printed = <String>[];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) {
        printed.add(message);
      }
    };
    final clips = <Rect>[];
    try {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: const Size(800, 600),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: GlassScaffold(
              topBar: topBar,
              bottomBar: bottomBar,
              // Not a lazy list: the switch starts off screen, and must be
              // built to be found and scrolled to.
              body: SingleChildScrollView(
                controller: controller,
                child: Column(
                  children: [
                    const SizedBox(height: 1000),
                    Row(
                      children: [
                        GlassSwitch(value: true, onChanged: (_) {}),
                        if (button)
                          GlassButton(
                            onPressed: () {},
                            child: const Text('Go'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2000),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final top = tester.getTopLeft(find.byType(GlassSwitch)).dy;
      controller.jumpTo(controller.offset + top - switchTop);
      await tester.pump();
      await tester.pump();
      expect(
        tester.getTopLeft(find.byType(GlassSwitch)).dy,
        closeTo(switchTop, 0.5),
      );
      clips.addAll(_knobLayer(tester).debugPassClips);
    } finally {
      debugPrint = previous;
    }
    return (clips, printed);
  }

  const bar = SizedBox(
    height: _barHeight,
    child: Glass(shape: GlassOval()),
  );

  testWidgets('a body switch under the bottom bar has no glass in the bar', (
    tester,
  ) async {
    final (clips, printed) = await clipsWithSwitchAt(
      tester,
      bottomBar: bar,
      switchTop: 600 - _barHeight + 6,
    );
    expect(clips, isNotEmpty);
    for (final clip in clips) {
      expect(
        clip.isEmpty || clip.bottom <= 600 - _barHeight,
        isTrue,
        reason: 'body glass clipped to $clip reaches into the bottom bar',
      );
    }
    expect(printed.where((line) => line.contains('overlap')), isEmpty);
  });

  testWidgets('with the bottom bar lifted by the keyboard, body glass '
      'under it is clipped at its new edge', (tester) async {
    const keyboard = 200.0;
    const barTop = 600 - keyboard - _barHeight;
    final (clips, printed) = await clipsWithSwitchAt(
      tester,
      bottomBar: bar,
      keyboard: keyboard,
      switchTop: barTop + 6,
    );
    expect(clips, isNotEmpty);
    for (final clip in clips) {
      expect(
        clip.isEmpty || clip.bottom <= barTop,
        isTrue,
        reason: 'body glass clipped to $clip reaches into the lifted bar',
      );
    }
    expect(printed.where((line) => line.contains('overlap')), isEmpty);
  });

  testWidgets("the bars' passes are clipped to the bars, and never meet "
      "the body's", (tester) async {
    const topKey = ValueKey<String>('top');
    const bottomKey = ValueKey<String>('bottom');
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: GlassScaffold(
            topBar: const SizedBox(
              height: _barHeight,
              child: Glass(key: topKey, shape: GlassOval()),
            ),
            bottomBar: const SizedBox(
              height: _barHeight,
              child: Glass(key: bottomKey, shape: GlassOval()),
            ),
            // One switch scrolled half under the top bar, one mid-screen:
            // body glass both under a bar and well clear of the bars.
            body: SingleChildScrollView(
              controller: controller,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  GlassSwitch(value: true, onChanged: (_) {}),
                  const SizedBox(height: 200),
                  GlassSwitch(value: false, onChanged: (_) {}),
                  const SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    const topRect = Rect.fromLTRB(0, 0, 800, _barHeight);
    const bottomRect = Rect.fromLTRB(0, 600 - _barHeight, 800, 600);
    final top = _globalPassClips(tester, topKey);
    final bottom = _globalPassClips(tester, bottomKey);
    expect(top, isNotEmpty);
    expect(bottom, isNotEmpty);
    for (final (clips, bar) in [(top, topRect), (bottom, bottomRect)]) {
      for (final clip in clips) {
        expect(
          clip.isEmpty || bar.expandToInclude(clip) == bar,
          isTrue,
          reason: 'a bar pass clipped to $clip reaches outside $bar',
        );
      }
    }

    final body = _knobLayer(tester);
    final origin = body.localToGlobal(Offset.zero);
    final bodyClips = [
      for (final clip in body.debugPassClips) clip.shift(origin),
    ];
    expect(bodyClips.where((clip) => !clip.isEmpty), isNotEmpty);
    for (final clip in bodyClips.where((clip) => !clip.isEmpty)) {
      for (final barClip in [...top, ...bottom]) {
        final overlap = clip.intersect(barClip);
        expect(
          overlap.width <= 0 || overlap.height <= 0,
          isTrue,
          reason: 'body pass $clip stacks under bar pass $barClip',
        );
      }
    }
  });

  testWidgets('a body with two materials clips every one of its passes out '
      'of the bar', (tester) async {
    final (clips, printed) = await clipsWithSwitchAt(
      tester,
      topBar: bar,
      button: true,
      switchTop: 10,
    );
    // The switch knob's dome and the button's control material: two passes,
    // each pushed with its own clip.
    expect(clips.length, greaterThanOrEqualTo(2));
    for (final clip in clips) {
      expect(
        clip.isEmpty || clip.top >= _barHeight,
        isTrue,
        reason: 'body glass clipped to $clip reaches into the bar',
      );
    }
    expect(
      printed.where(
        (line) => line.contains('implicit') || line.contains('overlap'),
      ),
      isEmpty,
    );
  });
}

/// The layer that renders the `Glass` keyed [key], and its pass clips in
/// global coordinates.
List<Rect> _globalPassClips(WidgetTester tester, Key key) {
  RenderObject? node = tester.renderObject(find.byKey(key));
  while (node != null && node is! RenderGlassLayer) {
    node = node.parent;
  }
  final layer = node! as RenderGlassLayer;
  final origin = layer.localToGlobal(Offset.zero);
  return [for (final clip in layer.debugPassClips) clip.shift(origin)];
}
