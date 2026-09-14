import 'package:glass_forge/src/shaders/shader_library.dart';

/// Waits for every core glass_forge shader to finish loading and compiling.
///
/// A scene measured before this completes would count first-shader-load
/// jank as part of its steady-state frame cost. That is a real cost, but a
/// one-time one -- see `docs/superpowers/specs/2026-09-10-glass-forge-
/// architecture-design.md` §5.8 -- and folding it into a per-frame p90 would
/// blame the wrong thing for a slow scene. Call this once before measuring
/// the first scene; safe to call again, the work happens once.
Future<void> warmUpGlassForgeShaders() => ShaderLibrary.instance.warmUp();
