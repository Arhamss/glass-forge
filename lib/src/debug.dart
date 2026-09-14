/// Development and measurement toggles for glass_forge.
///
/// Nothing here is part of the public API: `package:glass_forge/glass_forge
/// .dart` does not export this file. Import
/// `package:glass_forge/src/debug.dart` directly, the same way the package's
/// own tests reach other `src/` files.
library;

import 'package:glass_forge/src/shaders/shader_library.dart';

/// Forces the composition to bind the bilinear backdrop-reconstruction
/// shader (`final_render_bilinear_probe.frag`) instead of the shipped
/// nearest-neighbour default (`final_render.frag`).
///
/// `ImageFilter.shader`'s backdrop sampler is nearest-neighbour by default
/// (flutter#186945), so every displaced lookup snaps between texels. This
/// flag exists to measure that against a hand-reconstructed bilinear
/// alternative — see `docs/reference/backdrop_sampling.md` for the decision
/// and the numbers behind it. The probe screen that flipped it lived in the
/// workbench app, which has since been deleted.
///
/// Defaults to `false`. Nothing in production code ever sets it; it only
/// matters to tooling that does. Setting it `true` before
/// [debugWarmUpBilinearBackdropSampling] has completed throws — the shader
/// it selects is not loaded eagerly (see [GlassShaderId.core]), precisely so
/// no other consumer pays to load it.
bool debugBilinearBackdropSampling = false;

/// Loads the shader [debugBilinearBackdropSampling] selects.
///
/// `ShaderLibrary.warmUp()` never loads
/// [GlassShaderId.finalRenderBilinearProbe] — it is not a core shader, so no
/// consumer of this package compiles or loads it at startup just because it
/// exists. Await this once before setting [debugBilinearBackdropSampling]
/// to `true` for the first time; safe to call more than once.
Future<void> debugWarmUpBilinearBackdropSampling() =>
    ShaderLibrary.instance.ensureLoaded(GlassShaderId.finalRenderBilinearProbe);
