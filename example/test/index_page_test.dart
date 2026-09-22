import 'package:flutter_test/flutter_test.dart';
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
}
