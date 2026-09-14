import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:glass_forge/src/platform/glass_forge_platform_interface.dart';
import 'package:glass_forge/src/tier/thermal_state.dart';

/// A [GlassForgePlatform] backed by a [MethodChannel].
class MethodChannelGlassForge extends GlassForgePlatform {
  /// The channel used to talk to the host platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('glass_forge');

  /// Pushes Reduce Transparency changes. See
  /// [GlassForgePlatform.reduceTransparencyChanges].
  @visibleForTesting
  final reduceTransparencyChannel = const EventChannel(
    'glass_forge/reduce_transparency',
  );

  /// Pushes thermal state changes. See
  /// [GlassForgePlatform.thermalStateChanges].
  @visibleForTesting
  final thermalChannel = const EventChannel('glass_forge/thermal');

  @override
  Future<bool?> isReduceTransparencyEnabled() {
    return _ask<bool>('isReduceTransparencyEnabled');
  }

  @override
  Future<ThermalState?> getThermalState() async {
    return thermalStateFromName(await _ask<String>('getThermalState'));
  }

  @override
  Stream<bool> reduceTransparencyChanges() {
    return _events(
      reduceTransparencyChannel,
    ).map((event) => event is bool && event).distinct();
  }

  @override
  Stream<ThermalState> thermalStateChanges() {
    return _events(thermalChannel)
        .map((event) => thermalStateFromName(event as String?))
        .where((state) => state != null)
        .cast<ThermalState>()
        .distinct();
  }

  /// Invokes [method], turning "this platform has no answer" into null.
  ///
  /// A host that returns `FlutterMethodNotImplemented` — every platform this
  /// package supports where the signal genuinely does not exist, plus
  /// Windows and Linux, which register no plugin at all — surfaces in Dart
  /// as a [MissingPluginException], and an unhandled one would be thrown
  /// straight out of a signal that documents itself as returning null when
  /// it cannot answer. The whole contract of this interface is that not
  /// knowing is an answer, so not knowing must not be an exception.
  ///
  /// [PlatformException] is caught for the same reason but is a genuine
  /// fault, so it is logged: a host that implemented the method and then
  /// failed inside it is a bug worth seeing, unlike one that never claimed
  /// to implement it.
  Future<T?> _ask<T>(String method) async {
    try {
      return await methodChannel.invokeMethod<T>(method);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint(
        'glass_forge: the host failed to answer $method ($error). Treating '
        'the signal as unknown.',
      );
      return null;
    }
  }

  /// One stream per channel, for the life of the process.
  ///
  /// A channel may have exactly one active stream, and every
  /// `receiveBroadcastStream()` call builds a new one. Two of them on a
  /// single channel means two listen/cancel pairs against one native sink,
  /// and the second cancel finds nothing to cancel: the host throws
  /// `PlatformException(error, No active stream to cancel)`. That surfaces
  /// from the cancel handler rather than from the stream, so a consumer
  /// cannot catch it — it simply fails their test. Reported from an
  /// integration run that pumped its app twice, which is enough to build a
  /// second `AccessibilitySignalSource` in one process.
  ///
  /// Caching the stream makes every consumer share the one broadcast stream,
  /// so the host sees a single listen and a single cancel no matter how many
  /// sources come and go.
  static final Map<String, Stream<Object?>> _streams =
      <String, Stream<Object?>>{};

  /// Opens [channel], swallowing the "no such channel" failure and sharing
  /// one stream per channel — see [_streams].
  ///
  /// Same reasoning as [_ask]: a platform with no implementation must look
  /// like a platform with nothing to say, not like an error a consumer has
  /// to catch. `handleError` rather than a `try` because the failure arrives
  /// as the first event, after the stream is already open.
  Stream<Object?> _events(EventChannel channel) {
    return _streams.putIfAbsent(
      channel.name,
      () => channel.receiveBroadcastStream().handleError(
        (Object _) {},
        test: (error) => error is MissingPluginException,
      ),
    );
  }

  /// Drops the cached streams so a test can observe a channel being opened
  /// again. Test-only.
  @visibleForTesting
  static void debugResetStreams() => _streams.clear();
}
