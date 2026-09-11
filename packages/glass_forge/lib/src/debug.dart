/// Development and measurement toggles for glass_forge.
///
/// Nothing here is part of the public API: `package:glass_forge/glass_forge
/// .dart` does not export this file. Import
/// `package:glass_forge/src/debug.dart` directly, the same way the package's
/// own tests reach other `src/` files.
library;

/// Forces the composition to bind the bilinear backdrop-reconstruction
/// shader (`final_render_bilinear_probe.frag`) instead of the shipped
/// nearest-neighbour default (`final_render.frag`).
///
/// `ImageFilter.shader`'s backdrop sampler is nearest-neighbour by default
/// (flutter#186945), so every displaced lookup snaps between texels. This
/// flag exists to measure that against a hand-reconstructed bilinear
/// alternative — see `docs/reference/backdrop_sampling.md` for the decision
/// and the numbers behind it, and `glass_forge_workbench`'s sampling probe
/// screen for the toggle that flips it.
///
/// Defaults to `false`. Nothing in production code ever sets it; it only
/// matters while the sampling probe is on screen.
bool debugBilinearBackdropSampling = false;
