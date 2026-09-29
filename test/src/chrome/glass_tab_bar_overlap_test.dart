// The package's own tab bar never trips the package's own overlap warning.
//
// Impeller only: the warning is checked where the backdrop passes are
// pushed, which needs `ui.ImageFilter.shader`. Run with
// `flutter test --tags impeller --run-skipped --enable-impeller`.
//
// The lens is a second pass over the bar's, on purpose and always. It
// declares itself a handoff (see `DeclaredGlassHandoff`), and the overlap
// check leaves declared handoffs out against the bar, so nothing prints:
// not at rest, not mid-flight, and not once it has landed.
@Tags(<String>['impeller'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

const List<GlassTab> _tabs = [
  GlassTab(icon: SizedBox(width: 24, height: 24), label: 'Home'),
  GlassTab(icon: SizedBox(width: 24, height: 24), label: 'Search'),
  GlassTab(icon: SizedBox(width: 24, height: 24), label: 'Profile'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  testWidgets('the bar and its lens print no overlap warning, at rest or '
      'across a tap', (tester) async {
    var index = 0;
    final printed = <String>[];
    final previous = debugPrint;
    // Restored in a `finally`: flutter_test checks `debugPrint` was put
    // back before any tear-down runs.
    debugPrint = (message, {wrapWidth}) {
      if (message != null) {
        printed.add(message);
      }
    };
    var sawLens = false;
    try {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: GlassLayer(
              tier: GeometryTier.portable,
              child: StatefulBuilder(
                builder: (context, setState) => Align(
                  alignment: Alignment.bottomCenter,
                  child: GlassTabBar(
                    tabs: _tabs,
                    currentIndex: index,
                    onTap: (next) => setState(() => index = next),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final lens = tester
            .widgetList<GlassPresence>(
              find.descendant(
                of: find.byType(GlassTabBar),
                matching: find.byType(GlassPresence),
              ),
            )
            .single;
        sawLens = sawLens || lens.presence.value > 0;
      }
      await tester.pumpAndSettle();
    } finally {
      debugPrint = previous;
    }

    expect(sawLens, isTrue, reason: 'the lens must be up for this to count');
    expect(index, 2);
    expect(printed.where((line) => line.contains('187820')), isEmpty);
  });

  testWidgets(
    'other glass over the lens still warns against it: the handoff '
    'exemption is for the bar alone',
    (tester) async {
      final printed = <String>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) {
          printed.add(message);
        }
      };
      try {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: GlassLayer(
                tier: GeometryTier.portable,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: GlassTabBar(
                        tabs: _tabs,
                        currentIndex: 0,
                        onTap: (_) {},
                      ),
                    ),
                    // Inside the bar, over the lens resting under Home: the
                    // bar's 16-point margin, its 6-point inset, and a little
                    // more.
                    const Positioned(
                      left: 30,
                      bottom: 30,
                      width: 12,
                      height: 12,
                      child: Glass(
                        shape: GlassOval(),
                        material: GlassMaterial(frost: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      } finally {
        debugPrint = previous;
      }

      // Once against the bar and once against the lens. A lens exempt
      // against everything would leave only the bar's.
      expect(
        printed.where((line) => line.contains('187820')),
        hasLength(2),
      );
    },
  );
}
