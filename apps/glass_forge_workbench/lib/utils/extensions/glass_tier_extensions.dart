import 'package:glass_forge/glass_forge.dart';

/// Display copy for `glass_forge`'s [GlassTier] ladder.
extension GlassTierX on GlassTier {
  /// The rung's name.
  String get label => switch (this) {
    GlassTier.full => 'Full',
    GlassTier.balanced => 'Balanced',
    GlassTier.reduced => 'Reduced',
    GlassTier.flat => 'Flat',
    GlassTier.off => 'Off',
  };

  /// What this rung does to a material, in the terms the material is
  /// written in.
  String get effect => switch (this) {
    GlassTier.full =>
      'Everything on: the accelerated geometry pass, full refraction, '
          'full blur, dispersion, both specular lobes.',
    GlassTier.balanced =>
      'Portable geometry, still at full optical quality, minus '
          'dispersion. Three taps per fragment for the least visible '
          'thing in the material.',
    GlassTier.reduced =>
      'Half the lensing, blur at 0.6, half the rim highlight.',
    GlassTier.flat =>
      'No lensing at all. A tinted, lightly blurred, bordered surface '
          'that still bakes its own silhouette, because without one the '
          'blur has no shape to fill.',
    GlassTier.off =>
      'Glass renders nothing. This is not the bottom of the ladder, it '
          'is the honest answer on a backend where the filter throws '
          'instead of running.',
  };
}
