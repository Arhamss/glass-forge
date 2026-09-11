import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

/// Every code block in README.md, compiled.
///
/// A README is the one piece of a package that is read far more often than
/// it is run, so its examples rot silently: a constructor gains a required
/// argument, a name changes, and nothing fails until someone copies the
/// snippet and it does not build. These are the same snippets, kept here so
/// the analyzer and the test run see them.
///
/// Keep this file and the README in lockstep. If a snippet changes there,
/// change it here.
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
}
