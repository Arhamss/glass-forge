// The package's own tab bar never trips the package's own overlap warning.
//
// Impeller only: the warning is checked where the backdrop passes are
// pushed, which needs `ui.ImageFilter.shader`. Run with
// `flutter test --tags impeller --run-skipped --enable-impeller`.
//
// The bar is painted and its lens is its only glass, so the lens never
// sits over another pass: nothing prints at rest, across a tap, or across
// a drag. Other glass put over the lens still warns, once.
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

  testWidgets('the bar and its lens print no overlap warning, at rest, '
      'across a tap or across a drag', (tester) async {
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

      final lens = find.descendant(
        of: find.byType(GlassTabBar),
        matching: find.byType(Glass),
      );
      await tester.tap(find.text('Profile'));
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        sawLens = sawLens || lens.evaluate().isNotEmpty;
      }
      await tester.pumpAndSettle();

      // A drag back to Home, a frame per step, lens following the finger.
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Profile')),
      );
      final home = tester.getCenter(find.text('Home'));
      for (var i = 1; i <= 20; i++) {
        await gesture.moveTo(
          Offset.lerp(tester.getCenter(find.text('Profile')), home, i / 20)!,
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    } finally {
      debugPrint = previous;
    }

    expect(sawLens, isTrue, reason: 'the lens must be up for this to count');
    expect(index, 0);
    expect(printed.where((line) => line.contains('187820')), isEmpty);
  });

  testWidgets(
    'other glass over the lens still warns against it, and only it: the '
    'bar under it is not glass',
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

      // Once, against the lens. A bar of glass would add a second.
      expect(
        printed.where((line) => line.contains('187820')),
        hasLength(1),
      );
    },
  );
}
