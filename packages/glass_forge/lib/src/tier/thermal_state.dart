import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:glass_forge/src/platform/glass_forge_platform_interface.dart';

/// How much thermal pressure the device reports.
///
/// Four values, because that is what iOS reports and what Android's seven
/// levels collapse onto without inventing precision — see
/// [thermalStateFromName] for the mapping and why it is lossy on purpose.
///
/// There is deliberately no `unknown` member. A platform that cannot answer
/// is represented by a *null* [ThermalState], so the type system forces
/// every caller to say what it does about not knowing, instead of letting
/// "unknown" quietly sort next to "nominal" in an enum comparison.
enum ThermalState {
  /// No thermal pressure. Full tier available.
  nominal,

  /// Slightly elevated. Apple's guidance is to reduce optional work; we do
  /// not degrade here, because a fair reading is common and transient and
  /// downgrading on it would make the tier flicker on ordinary use.
  fair,

  /// The system is actively shedding performance. Degrade.
  serious,

  /// The device is close to shutting down work. Degrade hard.
  critical,
}

/// Parses the wire name a platform sends, or null if it is not one we know.
///
/// The wire vocabulary is iOS's, because it is the coarser of the two and
/// the one that maps onto action. Android's seven `THERMAL_STATUS_*` levels
/// are collapsed on the Kotlin side: `NONE` to nominal, `LIGHT` to fair,
/// `MODERATE` to serious, and everything from `SEVERE` up to critical.
/// Collapsing there rather than here keeps the platform-specific constants
/// on the platform side, where they can be version-guarded.
ThermalState? thermalStateFromName(String? name) {
  for (final state in ThermalState.values) {
    if (state.name == name) {
      return state;
    }
  }
  return null;
}

/// The live thermal reading, or null while the platform cannot answer.
///
/// Null is a first-class answer, not a failure. Windows, Linux and web have
/// no thermal API at all; Android's is API 29+; and an app can be running
/// before the channel is attached. Treating any of those as
/// [ThermalState.nominal] would mean "we asked nothing and concluded the
/// device is cool", which is exactly the reasoning
/// `isReduceTransparencyEnabled` already refuses to do for accessibility.
class ThermalSignal extends ChangeNotifier
    implements ValueListenable<ThermalState?> {
  /// Creates a signal reading from [platform].
  ///
  /// [platform] defaults to the registered implementation; tests pass a fake
  /// so they can drive state changes without a device.
  ThermalSignal({GlassForgePlatform? platform})
    : _platform = platform ?? GlassForgePlatform.instance;

  final GlassForgePlatform _platform;
  StreamSubscription<ThermalState?>? _subscription;
  ThermalState? _value;
  bool _started = false;
  bool _disposed = false;

  @override
  ThermalState? get value => _value;

  /// Whether the platform has ever given a real reading.
  ///
  /// Distinguishes "cool" from "we do not know", which [value] alone cannot
  /// once a caller has written `state == ThermalState.nominal` and moved on.
  bool get isKnown => _value != null;

  /// Takes one reading, then follows the platform's change notifications.
  ///
  /// Both halves are individually optional: a platform may answer the
  /// one-shot query and have no event channel, or vice versa. Neither
  /// failing is an error, and neither failing moves [value] off null.
  Future<void> start() async {
    if (_started || _disposed) {
      return;
    }
    _started = true;

    _subscription = _platform.thermalStateChanges().listen(
      _record,
      // A stream that errors — no plugin on this platform, a channel that
      // went away — leaves the last known reading in place rather than
      // resetting it. See the class doc: losing the channel is not evidence
      // that the device cooled down.
      onError: (Object _) {},
      cancelOnError: true,
    );

    final initial = await _platform.getThermalState();
    if (_disposed) {
      return;
    }
    // Only if the stream has not already delivered something fresher: the
    // await above can outlast the first event, and an initial poll landing
    // second would roll the reading backwards.
    if (_value == null) {
      _record(initial);
    }
  }

  void _record(ThermalState? state) {
    if (_disposed || state == null || state == _value) {
      return;
    }
    _value = state;
    notifyListeners();
  }

  /// Feeds a reading as if the platform had reported it. Test-only.
  @visibleForTesting
  void debugReport(ThermalState? state) => _record(state);

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
