import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/constants/app_colors.dart';

/// The workbench's demonstration material — this screen's default, and a
/// preset in its own right alongside the Apple-fitted ones.
///
/// `glass_forge`'s presets (`GlassMaterial.regular` / `.clear`, fitted
/// against real iOS 27 captures — see
/// `packages/glass_forge/lib/src/material/apple_presets.dart`) are correct
/// for what Apple uses them for: a small navigation pill sitting over
/// bright, content-rich backdrops. `regular(brightness: dark)` carries a
/// 56% dark tint tuned for exactly that. Over this screen's dark stage, at
/// demo scale, that tint simply paints over the backdrop — there is
/// nothing left to refract through.
///
/// This material is not fitted data; it is tuned so the optical bend at
/// the specimen's rim is the thing a viewer notices — tint kept low, edge
/// refraction pushed well past the fitted `27.42` so the backdrop visibly
/// displaces, a light frost that reads as glass without smearing the
/// refraction, and a faint chromatic edge.
GlassMaterial demonstrationGlassMaterial() {
  return const GlassMaterial().copyWith(
    edgeRefraction: 64,
    frost: 6,
    chromaticAberration: 1.5,
    tint: AppColors.stageForeground,
    tintOpacity: 0.1,
    highlight: 1.2,
    contour: 0.16,
  );
}
