import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';
import 'package:glass_forge_example/src/catalogue/entries/adaptation.dart';
import 'package:glass_forge_example/src/catalogue/entries/chrome.dart';
import 'package:glass_forge_example/src/catalogue/entries/composition.dart';
import 'package:glass_forge_example/src/catalogue/entries/design_system.dart';
import 'package:glass_forge_example/src/catalogue/entries/motion.dart';
import 'package:glass_forge_example/src/catalogue/entries/shapes.dart';
import 'package:glass_forge_example/src/catalogue/entries/surfaces.dart';

/// The seven groups, in the order the index shows them.
const List<String> catalogueGroups = <String>[
  'Surfaces',
  'Shapes',
  'Motion',
  'Composition',
  'Chrome',
  'Design system',
  'Adaptation',
];

/// The entries belonging to [group], in the order the index shows them.
///
/// An unrecognised group name gets an empty list rather than a thrown
/// error — the index only ever calls this with a name drawn from
/// [catalogueGroups], so a mismatch here would be this file's own bug, not
/// the caller's, and there is nothing sensible to throw over.
List<CatalogueEntry> entriesIn(String group) => switch (group) {
  'Surfaces' => surfacesEntries,
  'Shapes' => shapesEntries,
  'Motion' => motionEntries,
  'Composition' => compositionEntries,
  'Chrome' => chromeEntries,
  'Design system' => designSystemEntries,
  'Adaptation' => adaptationEntries,
  _ => const <CatalogueEntry>[],
};

/// The entry named [api], if the catalogue has one — for a see-also chip
/// deciding whether it has somewhere to send the reader.
///
/// A linear scan over 33 entries, on every tap, rather than an index built
/// once: the catalogue is small enough that building and invalidating a
/// lookup table would cost more to maintain than it ever saves.
CatalogueEntry? findEntryByApi(String api) {
  for (final group in catalogueGroups) {
    for (final entry in entriesIn(group)) {
      if (entry.api == api) {
        return entry;
      }
    }
  }
  return null;
}
