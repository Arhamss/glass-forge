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

  group('the handoff', () {
    // Not a widget test: the safety property is about the *shape* of the
    // two ramps, so it is cheaper and more direct to drive plain
    // `AnimationController`s through the same construction the route uses
    // and sample the resulting `Animation<double>`s than to pump a real
    // `Navigator` transition and infer the same thing from what painted.
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

    test('the incoming page reaches full presence once the push completes', () {
      final incoming = incomingCataloguePresence(route);
      route.value = 1;
      expect(incoming.value, 1.0);
    });
  });
}
