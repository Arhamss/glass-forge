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
