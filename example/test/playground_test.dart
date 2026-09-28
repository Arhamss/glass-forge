import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/benchmark.dart' show warmUpGlassForgeShaders;
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/main.dart';
import 'package:glass_forge_example/src/controls.dart';
import 'package:glass_forge_example/src/playground.dart';
import 'package:glass_forge_example/src/presets.dart';
import 'package:glass_forge_example/src/scenes/kit.dart';
import 'package:glass_forge_example/src/tuner.dart';

void main() {
  // Baked mattes need the shaders; without them no pass bakes, and the
  // shape-limit warning — raised at bake time — could never print. First,
  // before any widget test: loaded after one has run, it never completes.
  setUpAll(warmUpGlassForgeShaders);

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

    testWidgets('the tab bar is the package GlassTabBar', (tester) async {
      await pumpApp(tester);
      final bar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
      expect(bar.tabs.map((t) => t.label), ['Lens', 'Liquid', 'Kit']);
      expect(bar.currentIndex, 0);
    });

    testWidgets('dragging along the tab bar switches where it lands', (
      tester,
    ) async {
      await pumpApp(tester);
      Finder tab(String label) => find.descendant(
        of: find.byType(GlassTabBar),
        matching: find.text(label),
      );
      final from = tester.getCenter(tab('Lens'));
      final to = tester.getCenter(tab('Kit'));
      final gesture = await tester.startGesture(from);
      // In steps, as a finger does, so the drag is recognised and followed.
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Nothing is committed while the finger is still down.
      expect(
        tester.widget<GlassTabBar>(find.byType(GlassTabBar)).currentIndex,
        0,
      );
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<GlassTabBar>(find.byType(GlassTabBar)).currentIndex,
        2,
      );
      expect(find.byType(KitScene), findsOneWidget);
    });

    testWidgets('the tuner on the sheet paints its controls, adding no '
        'glass', (tester) async {
      await pumpApp(tester);
      await tester.drag(find.text('Material'), const Offset(0, -400));
      await tester.pump(const Duration(seconds: 1));
      final tuner = find.byType(Tuner);
      expect(
        find.descendant(of: tuner, matching: find.byType(GlassSlider)),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: tuner,
          matching: find.byType(GlassSegmentedControl<GlassProfile>),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tuner, matching: find.byType(Glass)),
        findsNothing,
      );
    });
  });

  group('Kit', () {
    // On its own layer, with no tier scope: the app's scope resolves to
    // `off` under flutter_tester's software backend, which bakes nothing
    // and so could never warn. A bare layer keeps the accelerated default.
    testWidgets('draws more than eight glass controls, and every one', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final printed = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) printed.add(message);
      };
      try {
        await tester.pumpWidget(
          PlaygroundScope(
            playground: Playground(),
            child: const MaterialApp(
              home: GlassLayer(
                material: glassMaterial,
                child: Center(child: KitScene()),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
      } finally {
        debugPrint = original;
      }
      expect(find.byType(Glass).evaluate().length, greaterThan(8));
      expect(
        printed.where((m) => m.contains('cluster carries at most')),
        isEmpty,
      );
      // Two passes side by side, 12 apart: close, never touching.
      expect(printed.where((m) => m.contains('overlap')), isEmpty);
    });
  });
}
