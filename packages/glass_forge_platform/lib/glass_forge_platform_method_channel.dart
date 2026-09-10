import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:glass_forge_platform/glass_forge_platform_platform_interface.dart';

/// A [GlassForgePlatformPlatform] backed by a [MethodChannel].
class MethodChannelGlassForgePlatform extends GlassForgePlatformPlatform {
  /// The channel used to talk to the host platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('glass_forge_platform');

  @override
  Future<String?> getPlatformVersion() async {
    return methodChannel.invokeMethod<String>('getPlatformVersion');
  }
}
