/// Performance-tiered liquid glass rendering for Flutter — real refraction
/// where the GPU allows, graceful degradation everywhere else.
///
/// One package, one `pub add`. Rendering, tiering, motion, design tokens and
/// the native accessibility signals all live here, because a consumer should
/// never have to assemble the library themselves to get correct behaviour.
///
/// See `docs/superpowers/specs/2026-09-10-glass-forge-architecture-design.md`
/// for how the pieces fit together.
library;

export 'src/glass_forge.dart';
export 'src/material/glass_material.dart';
export 'src/material/glass_variant.dart';
export 'src/motion/glass_decay.dart';
export 'src/motion/glass_jiggle.dart' show GlassJiggle;
export 'src/motion/glass_motion.dart';
export 'src/motion/glass_motion_controller.dart';
export 'src/motion/glass_motion_state.dart';
export 'src/motion/glass_overdrag.dart';
export 'src/motion/interactive_glass.dart';
export 'src/motion/reduce_motion.dart';
export 'src/platform/glass_forge_platform_interface.dart'
    show GlassForgePlatform;
export 'src/shapes/glass_shape.dart';
export 'src/widgets/glass.dart';
export 'src/widgets/glass_blend_group.dart';
export 'src/widgets/glass_layer.dart';
