import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/catalogue/catalogue.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';
import 'package:glass_forge_example/src/catalogue/entry_page.dart';
import 'package:glass_forge_example/src/chrome.dart';

/// Every distinct name any entry in the real catalogue cross-references.
///
/// Read off the live catalogue rather than listed here, so the assertions
/// below cannot go stale: adding an entry, removing one, or renaming a
/// `seeAlso` target all change this set on the next run.
Set<String> _allSeeAlsoTargets() {
  return <String>{
    for (final group in catalogueGroups)
      for (final entry in entriesIn(group)) ...entry.seeAlso,
  };
}

void main() {
  /// One page carrying every cross-reference the catalogue uses.
  ///
  /// Cheaper and steadier than pumping all 33 real entry pages: the
  /// specimens are live glass with their own springs, and none of them
  /// have anything to do with how a see-also name is drawn. The `seeAlso`
  /// list is the real one, which is the part under test.
  CatalogueEntry everyTargetOnOnePage() {
    return CatalogueEntry(
      api: 'Glass',
      purpose: 'A stand-in carrying the whole cross-reference set.',
      group: 'Surfaces',
      knobs: const <Knob<Object?>>[],
      build: (knobs) => const SizedBox(width: 40, height: 40),
      code: (knobs) => 'Glass()',
      seeAlso: _allSeeAlsoTargets().toList()..sort(),
    );
  }

  Future<void> pumpTallEnoughFor(
    WidgetTester tester,
    CatalogueEntry entry,
  ) async {
    // The see-also row is the last sliver on the page. At the default 800
    // by 600 it is far outside the viewport and its chips are never built,
    // so a test reading them would pass by finding nothing. A viewport
    // taller than the whole page is what makes them real.
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(child: CatalogueEntryPage(entry: entry)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('every see-also chip that looks tappable has somewhere to go', (
    tester,
  ) async {
    final entry = everyTargetOnOnePage();
    await pumpTallEnoughFor(tester, entry);

    final pilled = tester
        .widgetList<PillButton>(find.byType(PillButton))
        .map((pill) => pill.label)
        .toList();

    expect(
      pilled,
      isNotEmpty,
      reason:
          'no pills at all means this test is asserting over an empty list '
          'rather than over the see-also row',
    );
    for (final label in pilled) {
      expect(
        findEntryByApi(label),
        isNotNull,
        reason:
            '"$label" is drawn as a pill, which is this app\'s one promise '
            'of a destination, but the catalogue has no entry to open',
      );
    }
  });

  testWidgets('a name with no entry is still printed, just not as a pill', (
    tester,
  ) async {
    final entry = everyTargetOnOnePage();
    await pumpTallEnoughFor(tester, entry);

    final unresolved = entry.seeAlso
        .where((api) => findEntryByApi(api) == null)
        .toList();

    expect(
      unresolved,
      isNotEmpty,
      reason:
          'the catalogue deliberately cross-references symbols it spends no '
          'entry on; if that stopped being true this test would be vacuous',
    );

    final pilled = tester
        .widgetList<PillButton>(find.byType(PillButton))
        .map((pill) => pill.label)
        .toSet();

    for (final api in unresolved) {
      expect(
        pilled,
        isNot(contains(api)),
        reason: '"$api" has no entry, so it must not wear a pill',
      );
      expect(
        find.text(api),
        findsOneWidget,
        reason:
            '"$api" is a real exported symbol worth naming — dropping it is '
            'not the fix for its having no entry',
      );
    }
  });

  testWidgets('a name with an entry opens it', (tester) async {
    final entry = everyTargetOnOnePage();
    await pumpTallEnoughFor(tester, entry);

    // `GlassLayer` is the one target certain to resolve for as long as the
    // catalogue has a Surfaces group at all, and four entries name it.
    final target = findEntryByApi('GlassLayer');
    expect(target, isNotNull);

    await tester.tap(
      find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is PillButton && widget.label == 'GlassLayer',
        ),
        matching: find.text('GlassLayer'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(target!.purpose),
      findsOneWidget,
      reason: 'the pill pushed the entry it names',
    );
  });
}
