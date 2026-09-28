import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/main.dart';
import 'package:glass_forge_example/src/controls.dart';
import 'package:glass_forge_example/src/playground.dart';
import 'package:glass_forge_example/src/presets.dart';
import 'package:glass_forge_example/src/tab_bar.dart';

void main() {
  group('GlassMaterialTween', () {
    test('lands exactly on both ends', () {
      final a = presets[1].material;
      final b = presets.last.material;
      final tween = GlassMaterialTween(begin: a, end: b);
      expect(tween.lerp(1), b);
      // Clear has no tint, so its begin borrows the far end's colour —
      // everything else must match the start exactly.
      expect(tween.lerp(0).copyWith(tint: a.tint), a);
    });

    test('borrows the tint of the end that has one', () {
      final clear = GlassMaterial.clear();
      const pink = GlassMaterial(tint: Color(0xFFFF4F9A), tintOpacity: 0.3);
      final mid = GlassMaterialTween(begin: clear, end: pink).lerp(0.5);
      expect(mid.tint, pink.tint);
      expect(mid.tintOpacity, closeTo(0.15, 1e-9));
    });
  });

  group('dartFor', () {
    test('names only what differs from the defaults', () {
      expect(dartFor(const GlassMaterial()), 'const GlassMaterial()');
      expect(
        dartFor(const GlassMaterial(frost: 12.5, profile: GlassProfile.dome)),
        'const GlassMaterial(\n'
        '  profile: GlassProfile.dome,\n'
        '  frost: 12.5,\n'
        ')',
      );
    });

    test('round-trips every preset', () {
      // Each preset's code, read back field by field, is the preset.
      for (final preset in presets) {
        final code = dartFor(preset.material);
        final m = preset.material;
        if (m.tintOpacity > 0.005) {
          expect(code, contains('tintOpacity: '), reason: preset.name);
          expect(
            code,
            contains(m.tint.toARGB32().toRadixString(16).toUpperCase()),
            reason: preset.name,
          );
        }
        if (m.profile == GlassProfile.dome) {
          expect(code, contains('GlassProfile.dome'), reason: preset.name);
        }
      }
    });
  });

  group('app', () {
    Future<Playground> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final playground = Playground();
      await tester.pumpWidget(GlassForgeExample(playground: playground));
      await tester.pump(const Duration(seconds: 1));
      return playground;
    }

    testWidgets('opens on the lens scene with the Liquid preset', (
      tester,
    ) async {
      final playground = await pumpApp(tester);
      expect(find.text('Glass Forge'), findsOneWidget);
      expect(
        find.text('Pick it up and move it. Tap to change shape.'),
        findsOne,
      );
      expect(playground.preset, 'Liquid');
    });

    testWidgets('the tab bar switches scenes', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Kit'));
      // Two frames: the old scene shrinks away, then the new one grows in.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('The same glass, doing a day job.'), findsOne);
      expect(find.text('Refraction'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(GlassTabBar),
          matching: find.text('Liquid'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(GlassBlendGroup), findsOneWidget);
    });

    testWidgets('a preset chip morphs the layer to that material', (
      tester,
    ) async {
      final playground = await pumpApp(tester);
      // Raise the sheet, so the chips are on screen to be tapped.
      await tester.drag(find.text('Material'), const Offset(0, -400));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.widgetWithText(PresetChip, 'Clear'));
      await tester.pump(const Duration(milliseconds: 100));

      final clear = presets.firstWhere((p) => p.name == 'Clear').material;
      expect(playground.material, clear);
      // Mid-morph the layer is somewhere in between…
      expect(
        tester.widget<GlassLayer>(find.byType(GlassLayer)).material,
        isNot(clear),
      );
      // …and it arrives.
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<GlassLayer>(find.byType(GlassLayer)).material,
        clear,
      );
    });

    testWidgets('a slider tweak lands on the layer the same frame', (
      tester,
    ) async {
      final playground = await pumpApp(tester);
      final tweaked = playground.material.copyWith(frost: 21);
      playground.tweak(tweaked);
      await tester.pump();
      expect(playground.preset, isNull);
      expect(
        tester.widget<GlassLayer>(find.byType(GlassLayer)).material,
        tweaked,
      );
    });

    testWidgets('pinning a tier reaches the scope', (tester) async {
      final playground = await pumpApp(tester);
      playground.tier = GlassTier.flat;
      await tester.pump();
      final context = tester.element(find.byType(GlassLayer));
      expect(GlassTierScope.of(context).requested, GlassTier.flat);
    });
  });
}
