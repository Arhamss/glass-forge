import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:glass_forge/src/platform/glass_forge_platform_interface.dart';

/// A [GlassForgePlatform] backed by a [MethodChannel].
class MethodChannelGlassForge extends GlassForgePlatform {
  /// The channel used to talk to the host platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('glass_forge');

  @override
  Future<bool?> isReduceTransparencyEnabled() {
    return methodChannel.invokeMethod<bool>('isReduceTransparencyEnabled');
  }
}
