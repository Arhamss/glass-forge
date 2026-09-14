import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The live Reduce Motion signal, read from `dart:ui`.
///
/// Deliberately **not** `MediaQuery.disableAnimations`.
/// `MediaQueryData.disableAnimations` is documented not to be set by iOS
/// Reduce Motion, so anything branching on it is right on Android and
/// silently wrong on the platform this package models.
///
/// Reads **both** engine bits, and treats either as a yes. They are not
/// interchangeable and neither one covers both platforms:
/// `AccessibilityFeatures.reduceMotion` is documented in `dart:ui` as "only
/// supported on iOS", while `disableAnimations` is the generic flag Android
/// sets from its animator duration scale. Gating on `disableAnimations`
/// alone leaves iOS Reduce Motion doing nothing (flutter#65874); gating on
/// `reduceMotion` alone leaves Android's setting doing nothing. The union
/// is the only reading that cannot be silently wrong on one of them, and
/// over-honouring a request for less motion is the safe direction to err.
///
/// None of this comes from motor: it stores an `AnimationBehavior` on every
/// controller and never reads it back (see
/// `docs/reference/motor_teardown.md`), so its reduce-motion handling is
/// exactly nothing.
///
/// The read goes through `WidgetsBinding.instance.platformDispatcher` rather
/// than naming `PlatformDispatcher.instance` directly. In a real app those
/// are the same object — `BindingBase.platformDispatcher` returns
/// `PlatformDispatcher.instance` — but under `flutter_test` the binding
/// substitutes a `TestPlatformDispatcher`, which is the only way a test can
/// drive this signal end to end (`tester.platformDispatcher
/// .accessibilityFeaturesTestValue`). Reading the singleton directly would
/// have made every reduce-motion test assert against a mock of our own
/// plumbing instead of against the platform channel we actually ship.
class GlassReduceMotion extends ChangeNotifier
    with WidgetsBindingObserver
    implements ValueListenable<bool> {
  GlassReduceMotion._() {
    _last = _readFromPlatform();
    WidgetsBinding.instance.addObserver(this);
  }

  /// The process-wide signal.
  ///
  /// A lazy static: Dart does not run this initializer until something reads
  /// it, which is always from widget code, so the binding its observer
  /// attaches to is guaranteed to exist by then.
  static final GlassReduceMotion instance = GlassReduceMotion._();

  late bool _last;

  /// Whether the user has asked for reduced motion.
  @override
  bool get value => _readFromPlatform();

  static bool _readFromPlatform() {
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return features.disableAnimations || features.reduceMotion;
  }

  /// Re-reads the signal and notifies only on a real change.
  ///
  /// The binding fans this out to every observer whenever the engine's
  /// accessibility bitmask changes, and the bitmask carries a dozen
  /// unrelated flags — bold text, high contrast, screen reader — so an
  /// unconditional `notifyListeners` here would restart settled springs
  /// every time an unrelated feature toggled.
  @override
  void didChangeAccessibilityFeatures() {
    final next = _readFromPlatform();
    if (next == _last) {
      return;
    }
    _last = next;
    notifyListeners();
  }
}
