import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/platform/glass_forge_platform_interface.dart';

/// The accessibility settings that change what glass is allowed to look
/// like.
///
/// These are correctness requirements, not preferences. Apple states what
/// each one does to Liquid Glass: Reduce Transparency "makes Liquid Glass
/// frostier and obscures more of the content behind it"; Increase Contrast
/// "makes elements predominantly black or white and highlights them with a
/// contrasting border"; Reduce Motion "decreases the intensity of some
/// effects and disables any elastic properties for the material". A package
/// that renders full glass to a user who asked for less is broken, not
/// merely opinionated.
@immutable
class AccessibilitySignals {
  /// Creates a signal set.
  const AccessibilitySignals({
    this.reduceTransparency = false,
    this.reduceMotion = false,
    this.increaseContrast = false,
    this.reduceTransparencyIsApproximated = false,
  });

  /// Reads what Flutter can answer, and takes Reduce Transparency as given.
  ///
  /// [nativeReduceTransparency] comes from the platform channel and is null
  /// when the platform could not answer. Null falls back to the
  /// `highContrast` approximation every competing package uses — and records
  /// that it did, in [reduceTransparencyIsApproximated], so the shortfall is
  /// visible in a diagnostic instead of being indistinguishable from a real
  /// reading.
  ///
  /// Two traps are avoided here deliberately:
  ///
  /// - **`reduceMotion` is read from `dart:ui`, never from `MediaQuery`, and
  ///   takes *either* engine bit.** `MediaQueryData` mirrors only seven of
  ///   the engine's accessibility flags and has no `reduceMotion` field at
  ///   all; its `disableAnimations` is documented *not* to be set by iOS
  ///   Reduce Motion (flutter#65874). Reading it there would silently answer
  ///   "off" for every iOS user who turned the setting on.
  ///
  ///   The two engine bits are not interchangeable either: `dart:ui`
  ///   documents `reduceMotion` as "only supported on iOS", while
  ///   `disableAnimations` is the generic flag Android sets from its animator
  ///   duration scale. This read was `flags.reduceMotion` alone, which is the
  ///   mirror-image of the `MediaQuery` trap — right on iOS and silently
  ///   "off" for every Android user. `GlassReduceMotion` already took the
  ///   union; the tier path did not, so the same setting could degrade motion
  ///   and not the tier on the same device.
  /// - **`highContrast` is Increase Contrast, not Reduce Transparency.**
  ///   The iOS bitmask builder maps `isDarkerSystemColorsEnabled` onto
  ///   `highContrast`; that is a different toggle with a different meaning,
  ///   which is exactly why using it as a stand-in is an approximation and
  ///   is labelled as one.
  factory AccessibilitySignals.fromPlatform({
    required bool? nativeReduceTransparency,
    ui.AccessibilityFeatures? features,
  }) {
    final flags =
        features ?? ui.PlatformDispatcher.instance.accessibilityFeatures;
    return AccessibilitySignals(
      reduceTransparency: nativeReduceTransparency ?? flags.highContrast,
      reduceMotion: flags.disableAnimations || flags.reduceMotion,
      increaseContrast: flags.highContrast,
      reduceTransparencyIsApproximated: nativeReduceTransparency == null,
    );
  }

  /// Whether the user asked the system to reduce transparency.
  final bool reduceTransparency;

  /// Whether the user asked the system to reduce motion.
  final bool reduceMotion;

  /// Whether the user asked the system to increase contrast.
  final bool increaseContrast;

  /// Whether [reduceTransparency] is the `highContrast` stand-in rather than
  /// the real setting.
  ///
  /// True on Android always (the platform has no such setting), on Windows,
  /// Linux and web, and on any platform where the channel is not attached.
  final bool reduceTransparencyIsApproximated;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AccessibilitySignals &&
        other.reduceTransparency == reduceTransparency &&
        other.reduceMotion == reduceMotion &&
        other.increaseContrast == increaseContrast &&
        other.reduceTransparencyIsApproximated ==
            reduceTransparencyIsApproximated;
  }

  @override
  int get hashCode => Object.hash(
    reduceTransparency,
    reduceMotion,
    increaseContrast,
    reduceTransparencyIsApproximated,
  );

  @override
  String toString() {
    final source = reduceTransparencyIsApproximated
        ? 'approximated from highContrast'
        : 'from the platform';
    return 'AccessibilitySignals(reduceTransparency: $reduceTransparency '
        '($source), reduceMotion: $reduceMotion, '
        'increaseContrast: $increaseContrast)';
  }
}

/// Keeps [AccessibilitySignals] current.
///
/// Two sources, because no single one carries all three settings. Reduce
/// Motion and Increase Contrast arrive on the engine's own accessibility
/// bitmask; Reduce Transparency is not in that bitmask on any platform and
/// has to come over glass_forge's channel, including its change
/// notification — toggling it produces no
/// `didChangeAccessibilityFeatures` at all, so without the channel's stream
/// the value read at startup would be the value used for the rest of the
/// session.
class AccessibilitySignalSource extends ChangeNotifier
    with WidgetsBindingObserver
    implements ValueListenable<AccessibilitySignals> {
  /// Creates a source reading from [platform].
  ///
  /// The bitmask is read through `WidgetsBinding.instance.platformDispatcher`
  /// rather than by naming `PlatformDispatcher.instance`. In a real app they
  /// are the same object, but under `flutter_test` the binding substitutes a
  /// `TestPlatformDispatcher`, so a widget test can drive Reduce Motion and
  /// Increase Contrast through
  /// `tester.platformDispatcher.accessibilityFeaturesTestValue` instead of
  /// asserting against a mock of our own plumbing.
  ///
  /// [features] overrides that read entirely, for a test with no binding to
  /// drive. Production always uses the default.
  AccessibilitySignalSource({
    GlassForgePlatform? platform,
    ui.AccessibilityFeatures Function()? features,
  }) : _platform = platform ?? GlassForgePlatform.instance,
       _features =
           features ??
           (() => WidgetsBinding.instance.platformDispatcher
               .accessibilityFeatures);

  final GlassForgePlatform _platform;
  final ui.AccessibilityFeatures Function() _features;
  StreamSubscription<bool>? _subscription;
  bool? _nativeReduceTransparency;
  AccessibilitySignals _value = const AccessibilitySignals(
    reduceTransparencyIsApproximated: true,
  );
  bool _started = false;
  bool _disposed = false;
  bool _warnedAboutApproximation = false;

  @override
  AccessibilitySignals get value => _value;

  /// Reads the current settings and follows changes to all three.
  Future<void> start() async {
    if (_started || _disposed) {
      return;
    }
    _started = true;
    // The framework's own observer list, not
    // `PlatformDispatcher.onAccessibilityFeaturesChanged`: that is a single
    // callback slot which `WidgetsBinding` already occupies, and assigning
    // to it would disconnect MediaQuery from accessibility changes for the
    // whole app.
    WidgetsBinding.instance.addObserver(this);

    _subscription = _platform.reduceTransparencyChanges().listen(
      (enabled) {
        _nativeReduceTransparency = enabled;
        _refresh();
      },
      // A platform with no such channel is not an error; it is a platform
      // with nothing to say, and the approximation below covers it.
      onError: (Object _) {},
      cancelOnError: true,
    );

    final initial = await _platform.isReduceTransparencyEnabled();
    if (_disposed) {
      return;
    }
    // Only if the stream has not already answered: the await can outlast the
    // stream's opening event, and a stale poll landing second would undo it.
    _nativeReduceTransparency ??= initial;
    _refresh();
  }

  @override
  void didChangeAccessibilityFeatures() => _refresh();

  void _refresh() {
    if (_disposed) {
      return;
    }
    final next = AccessibilitySignals.fromPlatform(
      nativeReduceTransparency: _nativeReduceTransparency,
      features: _features(),
    );
    if (next == _value) {
      return;
    }
    _value = next;
    _warnAboutApproximationOnce();
    notifyListeners();
  }

  /// Says so, rather than pretending.
  ///
  /// The package's whole claim about accessibility is that it reads the real
  /// Reduce Transparency setting where every competitor approximates it. On
  /// a platform where it cannot, that has to be visible to the developer —
  /// once, in debug, not once per frame and not in release.
  void _warnAboutApproximationOnce() {
    if (!_value.reduceTransparencyIsApproximated || _warnedAboutApproximation) {
      return;
    }
    _warnedAboutApproximation = true;
    assert(() {
      debugPrint(
        'glass_forge: this platform did not answer Reduce Transparency, so '
        'it is being approximated from MediaQuery-style highContrast. A user '
        'with Reduce Transparency on and Increase Contrast off will receive '
        'more glass than they asked for.',
      );
      return true;
    }(), 'the diagnostic above is debug-only');
  }

  /// Feeds a native reading as if the platform had reported it. Test-only.
  @visibleForTesting
  void debugReportReduceTransparency({required bool? enabled}) {
    _nativeReduceTransparency = enabled;
    _refresh();
  }

  /// Recomputes from the engine's current bitmask. Test-only.
  @visibleForTesting
  void debugRefresh() => _refresh();

  @override
  void dispose() {
    _disposed = true;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
    }
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
