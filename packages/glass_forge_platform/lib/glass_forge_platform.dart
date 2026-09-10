/// Native accessibility and thermal signals for `glass_forge`.
///
/// Flutter does not surface Reduce Transparency: the iOS accessibility bitmask
/// never reads `isReduceTransparencyEnabled`, and Android has no public
/// equivalent. This plugin exists to provide that signal, along with thermal
/// status and low-power mode, so the tier engine can respond to both
/// accessibility preferences and sustained thermal pressure.
///
/// The API here is scaffolding. See
/// `docs/superpowers/specs/2026-09-10-glass-forge-architecture-design.md` §5.6
/// for the intended surface.
library;

import 'package:glass_forge_platform/glass_forge_platform_platform_interface.dart';

/// Entry point for the native signals this package provides.
class GlassForgePlatform {
  /// Returns the host platform version, or `null` when unavailable.
  Future<String?> getPlatformVersion() {
    return GlassForgePlatformPlatform.instance.getPlatformVersion();
  }
}
