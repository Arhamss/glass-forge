import 'package:glass_forge/src/platform/glass_forge_method_channel.dart';
import 'package:glass_forge/src/tier/thermal_state.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The interface platform implementations of glass_forge's native signals
/// must implement.
///
/// These are signals Flutter itself does not surface. Reduce Transparency is
/// the important one: the iOS accessibility bitmask never reads
/// `isReduceTransparencyEnabled`, and Android has no public equivalent, so a
/// package that wants to honour it has to ask the platform directly. Thermal
/// state is the other: the engine never reads it on any platform.
///
/// Every method here may answer "I do not know", and says so with null or an
/// empty stream rather than with a plausible default. That is the single
/// rule this interface exists to enforce.
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

  /// Emits whenever Reduce Transparency changes.
  ///
  /// A separate channel from Flutter's own accessibility notifications
  /// because the setting is not in the bitmask those carry — a user toggling
  /// Reduce Transparency produces no
  /// `PlatformDispatcher.onAccessibilityFeaturesChanged` at all, so without
  /// this the value read at startup would be the value used forever.
  ///
  /// Implementations with no such signal return an empty stream. Never an
  /// error stream and never a stream that opens with a fabricated `false`.
  Stream<bool> reduceTransparencyChanges() {
    throw UnimplementedError(
      'reduceTransparencyChanges() has not been implemented.',
    );
  }

  /// The device's current thermal pressure, or `null` when unavailable.
  ///
  /// `null` is the honest answer on every desktop platform, on web, and on
  /// Android below API 29. Callers must treat it as unknown; see
  /// [ThermalState] for why there is no `unknown` enum member to collapse it
  /// into.
  Future<ThermalState?> getThermalState() {
    throw UnimplementedError('getThermalState() has not been implemented.');
  }

  /// Emits whenever the device's thermal pressure changes.
  ///
  /// Push rather than poll on purpose: both platforms offer a notification
  /// (iOS `thermalStateDidChangeNotification`, Android
  /// `addThermalStatusListener`), and polling would either miss transitions
  /// or add a timer to every app that uses glass.
  ///
  /// Implementations with no such signal return an empty stream.
  Stream<ThermalState> thermalStateChanges() {
    throw UnimplementedError(
      'thermalStateChanges() has not been implemented.',
    );
  }
}
