/// Development and measurement toggles for glass_forge.
///
/// Deliberately separate from `package:glass_forge/glass_forge.dart` —
/// nothing exported here is meant for ordinary consumers of the package.
/// Import this directly from tooling that needs it, such as
/// `glass_forge_workbench`'s sampling probe screen.
library;

export 'src/debug.dart';
