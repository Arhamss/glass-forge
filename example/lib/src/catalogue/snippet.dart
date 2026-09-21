import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';

/// The Dart that produces [entry]'s current live widget.
///
/// A thin wrapper over the entry's own `code` function rather than a
/// formatter: the entry owns how its source reads, because only the entry
/// knows which of its parameters are worth showing. What this adds is the
/// single call site, so every consumer renders snippets the same way.
String renderSnippet(CatalogueEntry entry) => entry.code(entry.knobs);
