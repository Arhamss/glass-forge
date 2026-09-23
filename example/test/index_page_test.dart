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
      // `_EntryRow`'s known first-frame geometry bug (docs/TODO.md) fires
      // here, once per row that registers geometry before its `FittedBox`
      // has been laid out. Every error is collected and matched against
      // that one signature rather than swallowed by a `takeException()`,
      // which would discard whichever of them it happened to return — and
      // would pass just as happily on a real regression.
      //
      // Matched on the stack rather than on the message, unlike
      // `catalogue_test.dart`'s copy. The same `getTransformTo` walk
      // raises two different exceptions depending on what it walks
      // through: a `hasSize` assertion against a box that has not been
      // laid out, and a null check inside
      // `RenderSliverMultiBoxAdaptor.childMainAxisPosition` when the
      // unlaid ancestor is one of the index's own slivers. The walk is
      // the bug; the message is which host it happened to reach.
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

      for (final details in caught) {
        final stack = details.stack.toString();
        final isKnownFirstFrameBug =
            stack.contains('RenderGlassShape._syncGeometry') &&
            stack.contains('RenderObject.getTransformTo');
        expect(
          isKnownFirstFrameBug,
          isTrue,
          reason:
              'booting the app and tapping through to the licences threw '
              'something other than the known, tolerated first-frame '
              'geometry exception: ${details.exception}',
        );
      }

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
