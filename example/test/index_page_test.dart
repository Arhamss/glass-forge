import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_example/main.dart' as app;
import 'package:glass_forge_example/src/catalogue/catalogue.dart';

void main() {
  test('the seven groups are present and ordered', () {
    expect(catalogueGroups, <String>[
      'Surfaces',
      'Shapes',
      'Motion',
      'Composition',
      'Chrome',
      'Design system',
      'Adaptation',
    ]);
  });

  test(
    'every group has the entry count the spec promises',
    () {
      // The spec's inventory is a contract: 33 entries, and these counts. A
      // group that quietly loses an entry is a catalogue that quietly stops
      // covering the API.
      expect(entriesIn('Surfaces'), hasLength(6));
      expect(entriesIn('Shapes'), hasLength(4));
      expect(entriesIn('Motion'), hasLength(7));
      expect(entriesIn('Composition'), hasLength(4));
      expect(entriesIn('Chrome'), hasLength(4));
      expect(entriesIn('Design system'), hasLength(5));
      expect(entriesIn('Adaptation'), hasLength(3));
      expect(
        catalogueGroups.fold<int>(0, (n, g) => n + entriesIn(g).length),
        33,
      );
    },
  );

  test('every entry names a group that exists', () {
    for (final group in catalogueGroups) {
      for (final entry in entriesIn(group)) {
        expect(entry.group, group);
        expect(entry.api, isNotEmpty);
        expect(entry.purpose, isNotEmpty);
      }
    }
  });

  testWidgets(
    'the real app boots to the index and its Licences button reaches the '
    'Geist OFL text the pubspec promises ships with the fonts',
    (tester) async {
      // The whole app, started the way the device starts it. Nothing else
      // in this suite pumps `GlassForgeExample` or `CatalogueIndexPage`,
      // and the licence path is the one obligation in this repo that a
      // reader cannot satisfy for themselves: `main()` registers the Geist
      // and Geist Mono OFL text with `LicenseRegistry`, the pubspec says
      // the bundled fonts travel with it, and exactly one tap on screen
      // reaches it. Until this test, that tap was untested.
      //
      // Every error raised while the app boots and the tap lands is
      // collected, rather than read back through a `takeException()` that
      // would discard whichever of them it happened to return — and would
      // pass just as happily on a real regression.
      //
      // Nothing is tolerated. `_EntryRow`'s rows used to raise a
      // first-frame `getTransformTo` exception apiece, because
      // `RenderGlassShape` read a shape's transform during layout, through
      // ancestors the index had not laid out yet; the walk happens at
      // paint now, so booting this app is expected to be silent.
      final caught = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = caught.add;
      try {
        app.main();
        await tester.pumpAndSettle();

        expect(
          find.text('Catalogue'),
          findsOneWidget,
          reason: 'the app boots to the index, not to an entry',
        );

        await tester.tap(find.text('Licences'));
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = originalOnError;
      }

      expect(
        caught.map((details) => details.exception).toList(),
        isEmpty,
        reason:
            'booting the app and tapping through to the licences is '
            'expected to raise nothing at all',
      );

      // Flutter's own page, reached — not a second licence screen this
      // example drew.
      expect(find.byType(LicensePage), findsOneWidget);

      // And the fonts this example bundles are in it. Both families, by
      // name: `main()` registers them as one entry over two packages, so
      // a registration that lost a family would still show the other.
      for (final family in const <String>['Geist', 'Geist Mono']) {
        expect(
          find.widgetWithText(ListTile, family),
          findsOneWidget,
          reason:
              '$family is bundled by this example, so the OFL text has to '
              'be reachable from inside the app',
        );
      }
    },
  );
}
