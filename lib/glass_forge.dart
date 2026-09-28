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

export 'src/chrome/glass_detent.dart';
export 'src/chrome/glass_detent_sheet.dart';
export 'src/chrome/glass_detent_sheet_controller.dart';
export 'src/chrome/glass_sheet_scroll_physics.dart';
export 'src/composition/glass_glow.dart' show GlassGlow;
export 'src/controls/glass_button.dart';
export 'src/controls/glass_slider.dart';
export 'src/controls/glass_switch.dart';
export 'src/design/glass_legibility.dart';
export 'src/design/glass_motion_defaults.dart';
export 'src/design/glass_surface.dart';
export 'src/design/glass_surfaces.dart';
export 'src/design/glass_theme.dart';
export 'src/design/glass_tint.dart';
export 'src/design/glass_tokens.dart';
export 'src/geometry/producer_registry.dart' show GeometryTier;
export 'src/glass_forge.dart';
export 'src/material/glass_material.dart';
export 'src/material/glass_profile.dart';
export 'src/material/glass_variant.dart';
export 'src/motion/glass_decay.dart';
export 'src/motion/glass_jiggle.dart' show GlassJiggle;
export 'src/motion/glass_motion.dart';
export 'src/motion/glass_motion_controller.dart';
export 'src/motion/glass_motion_state.dart';
export 'src/motion/glass_overdrag.dart';
export 'src/motion/glass_press_stretch.dart' show GlassPressStretch;
export 'src/motion/interactive_glass.dart';
export 'src/motion/reduce_motion.dart';
export 'src/platform/glass_forge_platform_interface.dart'
    show GlassForgePlatform;
export 'src/shapes/glass_shape.dart';
export 'src/tier/accessibility_signals.dart';
export 'src/tier/frame_watchdog.dart';
export 'src/tier/glass_tier_engine.dart';
export 'src/tier/glass_tier_scope.dart';
export 'src/tier/render_capabilities.dart'
    show GraphicsBackend, RenderCapabilities;
export 'src/tier/thermal_state.dart';
export 'src/tier/tier_profile.dart';
export 'src/tier/tier_resolver.dart';
export 'src/widgets/glass.dart';
export 'src/widgets/glass_blend_group.dart';
export 'src/widgets/glass_host_scope.dart';
export 'src/widgets/glass_layer.dart';
export 'src/widgets/glass_presence.dart';
