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
}
