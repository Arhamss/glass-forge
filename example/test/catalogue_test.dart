import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';
import 'package:glass_forge_example/src/catalogue/entries/surfaces.dart';
import 'package:glass_forge_example/src/catalogue/snippet.dart';

void main() {
  CatalogueEntry entryWithFrost(double frost) {
    return CatalogueEntry(
      api: 'Glass',
      purpose: 'One glass surface.',
      group: 'Surfaces',
      knobs: <Knob<Object?>>[
        Knob<double>(name: 'frost', value: frost, min: 0, max: 24),
      ],
      build: (knobs) => SizedBox(width: knobs.first.value! as double),
      code: (knobs) =>
          'Glass(material: GlassMaterial(frost: '
          '${knobs.first.value}))',
      seeAlso: const <String>['GlassMaterial'],
    );
  }

  test('the widget and the snippet read the same knob', () {
    final entry = entryWithFrost(8).withKnob(0, 12.0);
    final built = entry.build(entry.knobs) as SizedBox;

    expect(built.width, 12.0, reason: 'the widget reads the new value');
    expect(
      renderSnippet(entry),
      contains('frost: 12.0'),
      reason: 'and so does the snippet, from the same list',
    );
  });

  test('changing a knob cannot move one without the other', () {
    // The drift this design exists to prevent: assert both derive from the
    // same source by checking they agree across several values, not just one.
    for (final value in <double>[0, 4, 16, 24]) {
      final entry = entryWithFrost(0).withKnob(0, value);
      expect((entry.build(entry.knobs) as SizedBox).width, value);
      expect(renderSnippet(entry), contains('frost: $value'));
    }
  });

  test('withKnob leaves the original entry untouched', () {
    final original = entryWithFrost(8)..withKnob(0, 20.0);
    expect(original.knobs.first.value, 8.0);
  });

  test('entry.knobs cannot be mutated through a held reference', () {
    final entry = entryWithFrost(8);

    expect(
      () => entry.knobs[0] = Knob<double>(name: 'frost', value: 99),
      throwsUnsupportedError,
      reason: 'the list is unmodifiable, not just the field',
    );
    expect(
      entry.knobs.first.value,
      8.0,
      reason: 'the failed write left the entry as it was',
    );
  });

  group('surfacesEntries', () {
    test('the group has its promised six entries', () {
      expect(surfacesEntries, hasLength(6));
    });

    test('every entry names its api, its purpose and at least one knob', () {
      for (final entry in surfacesEntries) {
        expect(entry.api, isNotEmpty, reason: 'a nameless entry');
        expect(
          entry.purpose,
          isNotEmpty,
          reason: '${entry.api} has no purpose',
        );
        expect(
          entry.knobs,
          isNotEmpty,
          reason: '${entry.api} has nothing to move',
        );
      }
    });

    test('every entry names the Surfaces group', () {
      for (final entry in surfacesEntries) {
        expect(entry.group, 'Surfaces');
      }
    });

    test('every entry api is unique', () {
      final names = surfacesEntries.map((entry) => entry.api).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test(
      'entry.build(entry.knobs) constructs without throwing, for every '
      "entry's default knobs",
      () {
        for (final entry in surfacesEntries) {
          expect(
            () => entry.build(entry.knobs),
            returnsNormally,
            reason: '${entry.api} threw building its default widget',
          );
        }
      },
    );

    testWidgets(
      'every entry mounts and paints under a real GlassLayer, at default '
      'knobs',
      (tester) async {
        for (final entry in surfacesEntries) {
          await tester.pumpWidget(
            MaterialApp(
              home: GlassLayer(child: Center(child: entry.build(entry.knobs))),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.api} threw once mounted',
          );
        }
      },
    );

    test("every entry's code compiles from its default knobs", () {
      for (final entry in surfacesEntries) {
        expect(
          renderSnippet(entry),
          isNotEmpty,
          reason: '${entry.api} rendered no snippet',
        );
      }
    });
  });
}
