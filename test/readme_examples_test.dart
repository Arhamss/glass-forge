import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

/// Every `dart` code block in README.md, plus every `dart` code block in a
/// `lib/` doc comment, compiled.
///
/// A README — or a doc comment — is the one piece of a package that is read
/// far more often than it is run, so its examples rot silently: a
/// constructor gains a required argument, a name changes, and nothing fails
/// until someone copies the snippet and it does not build. These are the
/// same snippets, kept here so the analyzer and the test run see them.
///
/// Keep this file, the README and the `lib/` doc comments in lockstep. If a
/// snippet changes there, change it here. Where the original names a
/// hypothetical caller type (`YourContent`, `NavBarContents`...), the copy
/// here substitutes a real, equivalent widget so it actually compiles —
/// same shape as the README section above.
void main() {
  testWidgets('the quick-start example builds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          material: GlassMaterial.regular(brightness: Brightness.dark),
          child: const Stack(
            children: [
              SizedBox.expand(),
              Align(
                alignment: Alignment.bottomCenter,
                child: Glass(
                  shape: GlassRoundedRectangle(
                    radius: BorderRadius.all(Radius.circular(28)),
                  ),
                  child: SizedBox(height: 56),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the blend-group example builds', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassLayer(
          child: GlassBlendGroup(
            blend: 24,
            child: Row(
              children: [
                Glass(shape: GlassOval()),
                Glass(shape: GlassOval()),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the InteractiveGlass example builds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: InteractiveGlass(
            drag: const GlassDrag(),
            settleMotion: const GlassMotion.smooth(),
            onTap: () {},
            child: const Glass(shape: GlassOval()),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tier-scope and theme examples build', (tester) async {
    await tester.pumpWidget(
      const GlassTierScope(
        child: MaterialApp(
          home: GlassTheme(
            data: GlassThemeData.dark,
            child: GlassSurface.navigationBar(child: SizedBox(height: 56)),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('GlassSuperellipse is a real shape the README can name', () {
    expect(
      const GlassSuperellipse(
        radius: BorderRadius.all(Radius.circular(24)),
      ),
      isA<GlassShape>(),
    );
  });

  // -- lib/ doc-comment examples -------------------------------------------

  testWidgets('the GlassSurface.navigationBar doc example builds', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassLayer(
          child: GlassSurface.navigationBar(child: SizedBox(height: 56)),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('the GlassThemeData one-field-override doc example builds', () {
    expect(
      const GlassThemeData(
        tokens: GlassTokens(blur: GlassBlurScale(thick: 18)),
      ),
      isA<GlassThemeData>(),
    );
  });

  testWidgets(
    'the GlassTheme brightness-follows-Material doc example builds',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return GlassTheme(
                data: GlassThemeData(brightness: Theme.of(context).brightness),
                child: const SizedBox(),
              );
            },
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the InteractiveGlass one-line doc example builds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: InteractiveGlass(
            child: Glass(
              shape: GlassRoundedRectangle(radius: BorderRadius.circular(999)),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the InteractiveGlass draggable doc example builds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: InteractiveGlass(
            drag: const GlassDrag(overdrag: GlassOverdrag(limit: 80)),
            child: Glass(
              shape: GlassRoundedRectangle(radius: BorderRadius.circular(999)),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the GlassHostScope.isOnGlass doc example builds', (
    tester,
  ) async {
    Widget painted() => const SizedBox();
    const shape = GlassOval();
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Builder(
            builder: (context) {
              final onGlass = GlassHostScope.isOnGlass(context);
              return onGlass
                  ? painted()
                  : Glass(shape: shape, child: painted());
            },
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the GlassPresence doc example builds', (tester) async {
    final sheetController = AnimationController(
      vsync: const TestVSync(),
      value: 1,
    );
    addTearDown(sheetController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: GlassPresence(
            presence: sheetController,
            child: Glass(
              shape: GlassRoundedRectangle(radius: BorderRadius.circular(28)),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the GlassDetentSheet example builds', (tester) async {
    // `Map()` and `results` in the class doc are hypothetical — a caller's
    // own map widget and their own list of rows. Substituted here with a
    // real backdrop and a real list, same shape as the doc's `Stack`.
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Stack(
            children: [
              const SizedBox.expand(),
              GlassDetentSheet(
                detents: const [
                  GlassDetent.fraction(0.1),
                  GlassDetent.fraction(0.5),
                  GlassDetent.fraction(1),
                ],
                child: ListView(children: const [SizedBox(height: 40)]),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
