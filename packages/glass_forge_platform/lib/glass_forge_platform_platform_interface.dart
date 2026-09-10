import 'package:glass_forge_platform/glass_forge_platform_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The interface that platform implementations of `glass_forge_platform`
/// must implement.
///
/// Platform implementations should extend this class rather than implement it,
/// so that new methods can be added without breaking existing implementations.
abstract class GlassForgePlatformPlatform extends PlatformInterface {
  /// Constructs a [GlassForgePlatformPlatform].
  GlassForgePlatformPlatform() : super(token: _token);

  static final Object _token = Object();

  static GlassForgePlatformPlatform _instance =
      MethodChannelGlassForgePlatform();

  /// The default instance to use.
  ///
  /// Defaults to [MethodChannelGlassForgePlatform].
  static GlassForgePlatformPlatform get instance => _instance;

  /// Sets the default instance.
  ///
  /// Platform-specific implementations assign themselves here when they
  /// register.
  static set instance(GlassForgePlatformPlatform value) {
    PlatformInterface.verifyToken(value, _token);
    _instance = value;
  }

  /// Returns the host platform version, or `null` when unavailable.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }
}
