import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:glass_forge/src/platform/glass_forge_platform_interface.dart';
import 'package:glass_forge/src/tier/accessibility_signals.dart';
import 'package:glass_forge/src/tier/frame_watchdog.dart';
import 'package:glass_forge/src/tier/render_capabilities.dart';
import 'package:glass_forge/src/tier/thermal_state.dart';
import 'package:glass_forge/src/tier/tier_profile.dart';
import 'package:glass_forge/src/tier/tier_resolver.dart';

/// Owns the four tier signals and publishes the one tier they resolve to.
///
/// The signals are deliberately separate objects rather than fields: each has
/// its own lifecycle, its own failure mode and its own test. This class does
/// nothing but start them, listen to them, and hand the result to
/// [resolveTier] — so a bug in combination logic can be found without a
/// device, and a bug in a signal can be found without the combination logic.
///
/// Injectable end to end. A test supplies fakes for any subset; whatever it
/// does not supply is built here and disposed here, and whatever it does
/// supply is left alone, because an engine that disposed a watchdog it did
/// not create would tear down a fixture the test still needs.
class GlassTierEngine extends ChangeNotifier
    implements ValueListenable<ResolvedTier> {
  /// Creates an engine.
  ///
  /// [requested] pins the performance tier. See [resolveTier] for exactly
  /// what it does and does not override — in short, it beats capability,
  /// heat and frame health, and does not beat accessibility.
  GlassTierEngine({
    GlassTier? requested,
    GlassForgePlatform? platform,
    FrameWatchdog? watchdog,
    ThermalSignal? thermal,
    AccessibilitySignalSource? accessibility,
    RenderCapabilities? capabilities,
  }) : _ownsWatchdog = watchdog == null,
       _ownsThermal = thermal == null,
       _ownsAccessibility = accessibility == null,
       _watchdog = watchdog ?? FrameWatchdog(),
       _thermal = thermal ?? ThermalSignal(platform: platform),
       _accessibility =
           accessibility ?? AccessibilitySignalSource(platform: platform),
       _capabilities = capabilities ?? RenderCapabilityProbe.immediate,
       _probeCapabilities = capabilities == null {
    // Assigned here rather than in the initializer list because the field is
    // private and a named parameter cannot be, so no initializing formal
    // spells this.
    _requested = requested;
    _value = _resolve();
    _watchdog.addListener(_recompute);
    _thermal.addListener(_recompute);
    _accessibility.addListener(_recompute);
  }

  final FrameWatchdog _watchdog;
  final ThermalSignal _thermal;
  final AccessibilitySignalSource _accessibility;
  final bool _ownsWatchdog;
  final bool _ownsThermal;
  final bool _ownsAccessibility;
  final bool _probeCapabilities;

  RenderCapabilities _capabilities;
  GlassTier? _requested;
  late ResolvedTier _value;
  bool _started = false;
  bool _disposed = false;

  @override
  ResolvedTier get value => _value;

  /// The frame watchdog, so a host can inspect or reconfigure it.
  FrameWatchdog get watchdog => _watchdog;

  /// The thermal signal.
  ThermalSignal get thermal => _thermal;

  /// The accessibility signals.
  AccessibilitySignalSource get accessibility => _accessibility;

  /// The tier a caller has pinned, if any.
  GlassTier? get requested => _requested;
  set requested(GlassTier? value) {
    if (_requested == value) {
      return;
    }
    _requested = value;
    _recompute();
  }

  /// Starts every signal.
  ///
  /// The capability probe is deferred to after the next frame, not run here.
  /// Flutter GPU has no Impeller context to hand back on Android until a
  /// surface frame has been drawn, so probing during startup would record a
  /// permanent "no acceleration" for a device that has it — and unlike the
  /// other three signals, this one is measured once and never revisited.
  Future<void> start() async {
    if (_started || _disposed) {
      return;
    }
    _started = true;
    _watchdog.start();
    if (_probeCapabilities) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        unawaited(_probe());
      });
    }
    await Future.wait(<Future<void>>[
      _thermal.start(),
      _accessibility.start(),
    ]);
  }

  Future<void> _probe() async {
    final measured = await RenderCapabilityProbe.run();
    if (_disposed || measured == _capabilities) {
      return;
    }
    _capabilities = measured;
    _recompute();
  }

  ResolvedTier _resolve() {
    return resolveTier(
      capabilities: _capabilities,
      thermal: _thermal.value,
      frameHealth: _watchdog.value,
      accessibility: _accessibility.value,
      requested: _requested,
    );
  }

  void _recompute() {
    if (_disposed) {
      return;
    }
    final next = _resolve();
    if (next == _value) {
      return;
    }
    // Notified on any change, including one that moves only the evidence: a
    // thermal reading that rose from nominal to fair changes nothing about
    // what is rendered, but a host reading the engine for diagnostics needs
    // to see it. Keeping glass layers from rebuilding over it is
    // `GlassTierScope`'s job, not this one's — it filters on the tier and
    // the profile, which is exactly the part that decides pixels.
    _value = next;
    _describeOnce(next);
    notifyListeners();
  }

  GlassTier? _describedTier;

  /// Logs the tier the first time each rung is reached, in debug only.
  ///
  /// Once per rung rather than once per change: a device oscillating between
  /// two rungs is a bug worth seeing, but a line per transition would bury
  /// it, and the rung is the part a developer needs in order to reproduce
  /// what they are looking at.
  void _describeOnce(ResolvedTier resolved) {
    if (_describedTier == resolved.tier) {
      return;
    }
    _describedTier = resolved.tier;
    assert(() {
      debugPrint('glass_forge: ${resolved.describe()}');
      return true;
    }(), 'the diagnostic above is debug-only');
  }

  @override
  void dispose() {
    _disposed = true;
    _watchdog.removeListener(_recompute);
    _thermal.removeListener(_recompute);
    _accessibility.removeListener(_recompute);
    if (_ownsWatchdog) {
      _watchdog.dispose();
    } else {
      _watchdog.stop();
    }
    if (_ownsThermal) {
      _thermal.dispose();
    }
    if (_ownsAccessibility) {
      _accessibility.dispose();
    }
    super.dispose();
  }
}
