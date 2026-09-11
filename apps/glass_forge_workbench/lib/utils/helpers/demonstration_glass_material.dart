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
/// the specimen's rim is the thing a viewer notices — tint kept low, a
/// faint chromatic edge, and an edge refraction close to the fitted value
/// rather than far above it.
///
/// Pushing the refraction up does not make the bend more visible, it makes
/// it stop reading as a bend. The band is `edgeRefraction` wide, so at 64 it
/// swallowed nearly half the specimen's half-width and the undistorted
/// interior shrank to a small central square — with the band's own boundary
/// showing as hard diagonal seams where a rounded rectangle's SDF normal
/// changes quadrant. The result reads as a bevelled plastic button. A narrow
/// band against a coarse backdrop is what reads as glass.
///
/// The frost is deliberately far below the fitted value. Blur is what
/// destroys the evidence of refraction: it erases the backdrop structure
/// whose displacement is the only thing making the bend visible. At the
/// fitted sigma a finely-patterned backdrop flattens to grey inside the
/// shape and the glass reads as a solid.
GlassMaterial demonstrationGlassMaterial() {
  return const GlassMaterial().copyWith(
    edgeRefraction: 28,
    frost: 3,
    chromaticAberration: 0.35,
    tint: AppColors.stageForeground,
    tintOpacity: 0.1,
    highlight: 1.2,
    contour: 0.16,
  );
}
