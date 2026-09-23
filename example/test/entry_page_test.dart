import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';
import 'package:glass_forge_example/src/catalogue/entry_page.dart';
import 'package:glass_forge_example/src/catalogue/index_page.dart';

void main() {
  final entry = CatalogueEntry(
    api: 'Glass',
    purpose: 'One glass surface.',
    group: 'Surfaces',
    knobs: <Knob<Object?>>[
      // Not `const`: `Knob`'s constructor copies `options` through
      // `List.unmodifiable`, which is not a const expression, so it is
      // never const-constructible — the brief's own test snippet has this
      // wrong.
      Knob<double>(name: 'frost', value: 8, min: 0, max: 24),
    ],
    build: (knobs) => Text('frost ${knobs.first.value}'),
    code: (knobs) => 'GlassMaterial(frost: ${knobs.first.value})',
    seeAlso: const <String>['GlassMaterial'],
  );

  testWidgets('the page shows the api name, the live thing and the code', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(child: CatalogueEntryPage(entry: entry)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Glass'), findsOneWidget);
    expect(find.text('frost 8.0'), findsOneWidget);
    expect(find.textContaining('GlassMaterial(frost: 8.0)'), findsOneWidget);
  });

  testWidgets('moving a knob moves the widget and the snippet together', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(child: CatalogueEntryPage(entry: entry)),
      ),
    );
    await tester.pumpAndSettle();

    // A cascade rather than the brief's `final state = ...; state.setKnob`
    // pair — `very_good_analysis`'s `cascade_invocations` flags the
    // duplicated receiver as a real (if only `info`-level) issue, and this
    // task's own gate is `flutter analyze` with none left.
    tester
        .state<CatalogueEntryPageState>(find.byType(CatalogueEntryPage))
        .setKnob(0, 20.0);
    await tester.pumpAndSettle();

    expect(find.text('frost 20.0'), findsOneWidget);
    expect(find.textContaining('GlassMaterial(frost: 20.0)'), findsOneWidget);
  });

  group('the handoff, as pure curves', () {
    // These drive `incomingCataloguePresence`/`outgoingCataloguePresence`
    // with a bare `AnimationController`, which pins the *shape* of the two
    // ramps cheaply -- but proves nothing about whether
    // `catalogueEntryRoute` and `CatalogueIndexPage` actually wire the
    // right animation into each function. A mutation
    // that swaps `animation` for `secondaryAnimation` at either wiring
    // point leaves every test in this group green while breaking the
    // on-screen handoff outright, which is what the widget test below
    // (driven by a real `Navigator` push and pop, reading
    // `GlassPresence.presence.value` out of the actually-mounted pages) is
    // for.
    late AnimationController route;

    setUp(() {
      route = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 420),
      );
    });

    tearDown(() => route.dispose());

    test('the two presences are never both above 0 at once, pushing', () {
      final incoming = incomingCataloguePresence(route);
      final outgoing = outgoingCataloguePresence(route);

      for (var i = 0; i <= 100; i++) {
        route.value = i / 100;
        expect(
          incoming.value > 0 && outgoing.value > 0,
          isFalse,
          reason:
              'at t=${route.value}: incoming=${incoming.value}, '
              'outgoing=${outgoing.value}',
        );
      }
    });

    test('nor popping back', () {
      final incoming = incomingCataloguePresence(route);
      final outgoing = outgoingCataloguePresence(route);

      route.value = 1;
      for (var i = 100; i >= 0; i--) {
        route.value = i / 100;
        expect(
          incoming.value > 0 && outgoing.value > 0,
          isFalse,
          reason:
              'at t=${route.value}: incoming=${incoming.value}, '
              'outgoing=${outgoing.value}',
        );
      }
    });

    test('the outgoing page is back at full presence once the push starts '
        'reversing from the very top', () {
      // Guards against a curve that never actually reaches 1 -- a ramp
      // that asymptotes short of full presence would still "pass" the
      // no-overlap checks above while leaving the covered page dim
      // forever once fully popped.
      final outgoing = outgoingCataloguePresence(route);
      route.value = 0;
      expect(outgoing.value, 1.0);
    });

    test('the incoming page is at full presence once the push completes', () {
      final incoming = incomingCataloguePresence(route);
      route.value = 1;
      expect(incoming.value, 1.0);
    });
  });

  testWidgets(
    'a real push and pop: the two mounted GlassPresences are never both '
    'above 0 at once',
    (tester) async {
      // The thing the curve-only tests above cannot see: whether
      // `catalogueEntryRoute`'s `transitionsBuilder` actually wires
      // `animation` (not `secondaryAnimation`) into
      // `incomingCataloguePresence`. This drives a real push and pop
      // through a real `Navigator`, using the real, unmodified
      // `catalogueEntryRoute` and `CatalogueEntryPage`, and samples
      // `GlassPresence.presence.value` off the `GlassPresence` widgets
      // actually mounted in the tree, rather than recomputing anything
      // itself.
      //
      // The outgoing side is the real `CatalogueIndexPage`, so a mutation
      // inside its own copy of the `ModalRoute.secondaryAnimation` line is
      // caught here too. It used to be a stand-in, because the real page
      // tripped `RenderGlassShape`'s layout-time transform walk; that walk
      // reads at paint now.
      await tester.pumpWidget(
        const MaterialApp(home: CatalogueIndexPage()),
      );
      await tester.pumpAndSettle();

      // The page really rendered, rather than merely failing to throw.
      // Both catalogue pages once drew as a bare photograph with a single
      // 44x44 square of glass on it while every test in this repo stayed
      // green, because no test asserted anything was on the index.
      // The title, the first group's header as it is actually drawn
      // (`_GroupHeader` upper-cases it), and two API names off the rows
      // under it. Both are real `glass_forge` symbols, spelled out here
      // rather than read back out of `entriesIn('Surfaces')`, which would
      // agree with the page however wrong the page was.
      expect(find.text('Catalogue'), findsOneWidget);
      expect(find.text('SURFACES'), findsOneWidget);
      expect(find.text('Glass'), findsOneWidget);
      expect(find.text('GlassLayer'), findsOneWidget);

      // `CatalogueIndexPage` wraps its scroll view in `GlassPresence` (an
      // ancestor of that scroll view and nothing else), while
      // `catalogueEntryRoute` wraps `CatalogueEntryPage` in one from its
      // `transitionsBuilder`. Naming the index's scroll view rather than
      // the page keeps this off the `GlassPresence`es that some row
      // thumbnails are themselves specimens of.
      //
      // `skipOffstage: false` throughout: once the push fully settles, the
      // opaque incoming route wraps everything below it in an `Offstage`,
      // and every `find.byType`/`find.descendant` skips offstage widgets by
      // default -- which would otherwise make the very check for "settled
      // at 0" unable to find the thing it is checking.
      final outgoingFinder = find.ancestor(
        of: find.descendant(
          of: find.byType(CatalogueIndexPage, skipOffstage: false),
          matching: find.byType(CustomScrollView, skipOffstage: false),
          skipOffstage: false,
        ),
        matching: find.byType(GlassPresence, skipOffstage: false),
      );
      final incomingFinder = find.ancestor(
        of: find.byType(CatalogueEntryPage, skipOffstage: false),
        matching: find.byType(GlassPresence, skipOffstage: false),
      );
      double valueOf(Finder finder) =>
          tester.widget<GlassPresence>(finder).presence.value;

      void expectNeverBothPresent() {
        final outgoing = valueOf(outgoingFinder);
        final incoming = valueOf(incomingFinder);
        expect(
          outgoing > 0 && incoming > 0,
          isFalse,
          reason: 'outgoing=$outgoing, incoming=$incoming',
        );
      }

      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(catalogueEntryRoute(entry));

      // 420ms transition, sampled well inside a frame each step so the
      // shared 0.5 midpoint (see `_handoff`) is not the only sample.
      for (var elapsed = 0; elapsed < 420; elapsed += 12) {
        await tester.pump(const Duration(milliseconds: 12));
        if (incomingFinder.evaluate().isEmpty) {
          // The incoming route has not been inserted into the Overlay
          // yet -- true only of the very first pump right after `push`,
          // well before either ramp could be non-zero anyway.
          continue;
        }
        expectNeverBothPresent();
      }
      await tester.pumpAndSettle();

      // The push actually completed the handoff, not just "never both
      // present" -- a route that silently never proxies its covered
      // page's `secondaryAnimation` (the real bug this test caught before
      // `catalogueEntryRoute` was fixed to use
      // `MaterialRouteTransitionMixin`) would pass every sample above
      // while leaving `outgoing` pinned at 1.0 the entire time.
      expect(valueOf(outgoingFinder), 0.0);
      expect(valueOf(incomingFinder), 1.0);

      // Popped with a real tap -- the entry page's own back chevron --
      // rather than `Navigator.pop`, so this half exercises the actual
      // gesture path too, not just the animation math.
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pump();
      for (var elapsed = 0; elapsed < 420; elapsed += 12) {
        await tester.pump(const Duration(milliseconds: 12));
        expectNeverBothPresent();
      }
      await tester.pumpAndSettle();
    },
  );
}
