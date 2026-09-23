import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';
import 'package:glass_forge_example/src/catalogue/entry_page.dart';

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
    // ramps cheaply -- but proves nothing about whether `catalogueEntryRoute`
    // (and, so far as a real index can be pumped without tripping a
    // separate bug -- see `_CoveredStandIn` below -- `CatalogueIndexPage`)
    // actually wire the right animation into each function. A mutation
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
      // The outgoing side is `_CoveredStandIn` below, not the real
      // `CatalogueIndexPage` -- see its doc comment for why, and for what
      // that trade-off costs this test.
      await tester.pumpWidget(
        const MaterialApp(home: _CoveredStandIn()),
      );
      await tester.pumpAndSettle();

      // `_CoveredStandIn` wraps its own content in `GlassPresence` (a
      // descendant), but `catalogueEntryRoute` wraps `CatalogueEntryPage`
      // *in* a `GlassPresence` from its `transitionsBuilder` -- an
      // ancestor, not a descendant -- so the two sides need opposite
      // `find` directions.
      //
      // `skipOffstage: false` on both: once the push fully settles, the
      // opaque incoming route wraps everything below it (`_CoveredStandIn`)
      // in an `Offstage`, and every `find.byType`/`find.descendant` skips
      // offstage widgets by default -- which would otherwise make the very
      // check for "settled at 0" unable to find the thing it is checking.
      final outgoingFinder = find.descendant(
        of: find.byType(_CoveredStandIn, skipOffstage: false),
        matching: find.byType(GlassPresence, skipOffstage: false),
        skipOffstage: false,
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

/// A minimal stand-in for the covered ("outgoing") side of the handoff.
///
/// Not `CatalogueIndexPage` itself, and deliberately: a real, populated
/// index (Tasks 5-10, landing concurrently with this fix) trips a
/// separate, pre-existing bug the moment it is pumped -- `_EntryRow`'s
/// `FittedBox`, present since Task 3, has not been laid out yet on the
/// frame a fresh `Glass` specimen beneath it first registers its
/// geometry, and `RenderGlassShape._syncGeometry`'s `getTransformTo` walk
/// throws reading its size. Reproduced directly (a throwaway `pumpWidget
/// (CatalogueIndexPage())` in a scratch test) and it is genuinely
/// unstable from one run to the next -- one exception that self-corrects,
/// or several across many frames, depending on how many rows a given run
/// happens to have. That is `_EntryRow`'s bug to fix, not this test's,
/// and not stable enough to build an assertion on top of.
///
/// This carries only the one line under test -- reading
/// `ModalRoute.secondaryAnimation` and feeding it to
/// `outgoingCataloguePresence` -- with no rows, no real entries, nothing
/// that can trip the `FittedBox` issue. The trade-off: this test cannot
/// catch a mutation made directly inside `CatalogueIndexPage.build`'s own
/// copy of that line, only inside `outgoingCataloguePresence` and
/// `catalogueEntryRoute` itself. Worth pointing this test at the real
/// page once `_EntryRow` is fixed.
class _CoveredStandIn extends StatelessWidget {
  const _CoveredStandIn();

  @override
  Widget build(BuildContext context) {
    final covering = ModalRoute.of(context);
    final covered = covering?.secondaryAnimation ?? kAlwaysDismissedAnimation;
    return GlassLayer(
      child: GlassPresence(
        presence: outgoingCataloguePresence(covered),
        child: const ColoredBox(color: Color(0xFF07080A)),
      ),
    );
  }
}
