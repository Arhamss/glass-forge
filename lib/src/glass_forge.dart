import 'package:glass_forge/src/platform/glass_forge_platform_interface.dart';

/// Entry point for glass_forge's native signals.
///
/// These are the signals Flutter does not surface on its own. Reduce
/// Transparency is the one that matters: Flutter's accessibility bitmask never
/// reads it on iOS, and Android has no public equivalent, so every other
/// Flutter glass package approximates it with `MediaQuery.highContrast` and
/// documents the resulting hole.
///
/// `GlassForge` is the façade app code calls; it defers to
/// [GlassForgePlatform.instance] for the platform-specific answer.
class GlassForge {
  /// Whether the user has asked the system to reduce transparency.
  ///
  /// Returns `null` when the platform cannot answer. Callers must treat that
  /// as "unknown" and fall back to the `MediaQuery.highContrast`
  /// approximation, rather than treating it as "off" and rendering full glass
  /// to someone who asked for less.
  Future<bool?> isReduceTransparencyEnabled() {
    return GlassForgePlatform.instance.isReduceTransparencyEnabled();
  }
}
