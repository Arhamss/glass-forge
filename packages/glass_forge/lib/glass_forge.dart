/// Performance-tiered liquid glass rendering for Flutter — real refraction
/// where the GPU allows, graceful degradation everywhere else.
///
/// One package, one `pub add`. Rendering, tiering, motion, design tokens and
/// the native accessibility signals all live here, because a consumer should
/// never have to assemble the library themselves to get correct behaviour.
///
/// Nothing is implemented yet. See
/// `docs/superpowers/specs/2026-09-10-glass-forge-architecture-design.md`.
library;

export 'src/glass_forge.dart';
export 'src/platform/glass_forge_platform_interface.dart'
    show GlassForgePlatform;
