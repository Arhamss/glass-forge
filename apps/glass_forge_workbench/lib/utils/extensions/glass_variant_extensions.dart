import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/l10n/localization_service.dart';

/// Display strings for `glass_forge`'s [GlassVariant].
extension GlassVariantX on GlassVariant {
  /// The label shown on the variant segmented control.
  String get label => switch (this) {
    GlassVariant.regular => Localization.variantRegular,
    GlassVariant.clear => Localization.variantClear,
  };
}
