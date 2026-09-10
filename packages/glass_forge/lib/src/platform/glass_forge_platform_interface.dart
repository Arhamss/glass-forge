import 'package:glass_forge/src/platform/glass_forge_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The interface platform implementations of glass_forge's native signals
/// must implement.
///
/// These are signals Flutter itself does not surface. Reduce Transparency is
/// the important one: the iOS accessibility bitmask never reads
/// `isReduceTransparencyEnabled`, and Android has no public equivalent, so a
/// package that wants to honour it has to ask the platform directly.
///
/// Implementations should extend this class rather than implement it, so new
/// signals can be added without breaking existing implementations.
abstract class GlassForgePlatform extends PlatformInterface {
  /// Constructs a [GlassForgePlatform].
  GlassForgePlatform() : super(token: _token);

  static final Object _token = Object();

  static GlassForgePlatform _instance = MethodChannelGlassForge();

  /// The default instance to use.
  static GlassForgePlatform get instance => _instance;

  /// Sets the default instance.
  static set instance(GlassForgePlatform value) {
    PlatformInterface.verifyToken(value, _token);
    _instance = value;
  }

  /// Whether the user has asked the system to reduce transparency.
  ///
  /// Returns `null` when the platform cannot answer, which callers must treat
  /// as "unknown" rather than "off" — falling back to the
  /// `MediaQuery.highContrast` approximation and saying so, rather than
  /// silently rendering full glass to someone who asked for less.
  Future<bool?> isReduceTransparencyEnabled() {
    throw UnimplementedError(
      'isReduceTransparencyEnabled() has not been implemented.',
    );
  }
}
