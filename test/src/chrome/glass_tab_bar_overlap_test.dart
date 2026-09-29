// The package's own tab bar never trips the package's own overlap warning.
//
// Impeller only: the warning is checked where the backdrop passes are
// pushed, which needs `ui.ImageFilter.shader`. Run with
// `flutter test --tags impeller --run-skipped --enable-impeller`.
//
// The lens is a second pass over the bar's, on purpose and only while the
// selection travels. It declares itself a handoff (see
// `DeclaredGlassHandoff`), and the overlap check leaves declared handoffs
// out, so nothing prints: not at rest before the tap, not mid-flight, and
// not once it has landed. Before that declaration, the first tap in any
// debug app printed the flutter#187820 warning.
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

  testWidgets('a tap on a tab prints no overlap warning', (tester) async {
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

    expect(sawLens, isTrue, reason: 'the lens must fly for this to count');
    expect(index, 2);
    expect(printed.where((line) => line.contains('187820')), isEmpty);
  });

  testWidgets(
    'the lens swelling over other glass next to the bar still warns: the '
    'handoff exemption is for the bar alone',
    (tester) async {
      final printed = <String>[];
      final previous = debugPrint;
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
                    // Beside the bar, past its right edge: the bar never
                    // meets it, but the lens, swollen by a held finger over
                    // the last tab, reaches past the bar's edge onto it.
                    const Positioned(
                      right: 0,
                      bottom: 10,
                      width: 12,
                      height: 60,
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
        expect(
          printed.where((line) => line.contains('187820')),
          isEmpty,
          reason: 'at rest the bar and the side glass do not meet',
        );

        // Drag from Home onto Profile and hold: the held finger keeps the
        // lens fully swollen while the selection travels.
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Home')),
        );
        await gesture.moveTo(tester.getCenter(find.text('Profile')));
        for (var i = 0; i < 60; i++) {
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
        await gesture.up();
        await tester.pumpAndSettle();
      } finally {
        debugPrint = previous;
      }

      expect(sawLens, isTrue, reason: 'the lens must fly for this to count');
      expect(printed.where((line) => line.contains('187820')), isNotEmpty);
    },
  );
}
