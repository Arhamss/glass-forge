import 'package:glass_forge/glass_forge.dart';

/// Display strings for `glass_forge`'s [GlassVariant].
extension GlassVariantX on GlassVariant {
  /// The label shown on the variant segmented control.
  String get label => switch (this) {
    GlassVariant.regular => 'Regular',
    GlassVariant.clear => 'Clear',
  };
}
