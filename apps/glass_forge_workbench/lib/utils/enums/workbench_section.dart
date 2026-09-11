import 'package:glass_forge_workbench/exports.dart';

/// The five top-level sections of the workbench.
///
/// Declaration order is the order of the branches in
/// `StatefulShellRoute.indexedStack` and the order of the tabs in
/// `WorkbenchRail`, so [Enum.index] is what maps a tab to its branch.
/// Adding a section means adding a branch in the same position.
enum WorkbenchSection {
  /// The five semantic surfaces, light against dark.
  gallery,

  /// One specimen and every material knob.
  specimen,

  /// Shapes merging into one another.
  blend,

  /// The tier engine, and why it landed where it did.
  tiers,

  /// Springs, drag, and squash under the thumb.
  motion,
}

/// Labels and routes for [WorkbenchSection].
extension WorkbenchSectionX on WorkbenchSection {
  /// The tab label. One word, because five of them share a phone's width.
  String get label => switch (this) {
    WorkbenchSection.gallery => 'Gallery',
    WorkbenchSection.specimen => 'Specimen',
    WorkbenchSection.blend => 'Blend',
    WorkbenchSection.tiers => 'Tiers',
    WorkbenchSection.motion => 'Motion',
  };

  /// What this section is for, read out by a screen reader after [label].
  String get hint => switch (this) {
    WorkbenchSection.gallery => 'The five semantic surfaces, light and dark',
    WorkbenchSection.specimen => 'One specimen and every material knob',
    WorkbenchSection.blend => 'Shapes merging into one another',
    WorkbenchSection.tiers => 'The tier engine and the signals behind it',
    WorkbenchSection.motion => 'Springs, drag and squash under the thumb',
  };

  /// The path this section's branch is rooted at.
  String get path => switch (this) {
    WorkbenchSection.gallery => AppRoutes.gallery,
    WorkbenchSection.specimen => AppRoutes.specimen,
    WorkbenchSection.blend => AppRoutes.blend,
    WorkbenchSection.tiers => AppRoutes.tiers,
    WorkbenchSection.motion => AppRoutes.motion,
  };
}
