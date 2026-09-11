import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/platform/glass_forge_platform_interface.dart';
import 'package:glass_forge/src/tier/thermal_state.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A platform whose thermal answers the test controls.
class _FakePlatform extends GlassForgePlatform with MockPlatformInterfaceMixin {
  _FakePlatform({this.initial, this.pollDelay = Duration.zero});

  final ThermalState? initial;
  final Duration pollDelay;
  final StreamController<ThermalState> controller =
      StreamController<ThermalState>.broadcast();

  @override
  Future<ThermalState?> getThermalState() async {
    if (pollDelay > Duration.zero) {
      await Future<void>.delayed(pollDelay);
    }
    return initial;
  }

  @override
  Stream<ThermalState> thermalStateChanges() => controller.stream;
}

void main() {
  test('reads as unknown before the platform has said anything', () {
    final signal = ThermalSignal(platform: _FakePlatform());
    addTearDown(signal.dispose);

    expect(signal.value, isNull);
    expect(signal.isKnown, isFalse);
  });

  test('adopts the first reading the platform gives', () async {
    final platform = _FakePlatform(initial: ThermalState.serious);
    addTearDown(platform.controller.close);
    final signal = ThermalSignal(platform: platform);
    addTearDown(signal.dispose);

    await signal.start();

    expect(signal.value, ThermalState.serious);
    expect(signal.isKnown, isTrue);
  });

  test(
    'a platform with nothing to say stays unknown, never nominal',
    () async {
      final platform = _FakePlatform();
      addTearDown(platform.controller.close);
      final signal = ThermalSignal(platform: platform);
      addTearDown(signal.dispose);

      await signal.start();

      // Windows, Linux, web and Android below API 29 all land here. The
      // distinction that matters is not "which enum value" but "did anyone
      // actually measure this", which is why there is no `unknown` member to
      // collapse into and why `isKnown` is a separate question.
      expect(signal.value, isNull);
      expect(signal.isKnown, isFalse);
    },
  );

  test('a reading that stops arriving does not read as cooling down', () async {
    final platform = _FakePlatform();
    addTearDown(platform.controller.close);
    final signal = ThermalSignal(platform: platform);
    addTearDown(signal.dispose);
    await signal.start();

    signal.debugReport(ThermalState.serious);
    expect(signal.value, ThermalState.serious);

    // The channel went away — the plugin detached, the host stopped
    // answering. That is an absence of evidence, not evidence the phone
    // cooled off, so the reading that caused a downgrade has to survive it.
    signal.debugReport(null);

    expect(signal.value, ThermalState.serious);
    expect(signal.isKnown, isTrue);
  });

  test('an errored stream leaves the last reading in place', () async {
    final platform = _FakePlatform();
    addTearDown(platform.controller.close);
    final signal = ThermalSignal(platform: platform);
    addTearDown(signal.dispose);
    await signal.start();

    platform.controller.add(ThermalState.critical);
    await Future<void>.delayed(Duration.zero);
    expect(signal.value, ThermalState.critical);

    platform.controller.addError(Exception('channel closed'));
    await Future<void>.delayed(Duration.zero);

    expect(signal.value, ThermalState.critical);
  });

  test('follows the platform up and down once it is known', () async {
    final platform = _FakePlatform(initial: ThermalState.nominal);
    addTearDown(platform.controller.close);
    final signal = ThermalSignal(platform: platform);
    addTearDown(signal.dispose);
    await signal.start();

    platform.controller.add(ThermalState.critical);
    await Future<void>.delayed(Duration.zero);
    expect(signal.value, ThermalState.critical);

    // A real cooler reading *does* lift the state. Only the absence of a
    // reading is refused.
    platform.controller.add(ThermalState.nominal);
    await Future<void>.delayed(Duration.zero);
    expect(signal.value, ThermalState.nominal);
  });

  test('notifies only when the state actually changes', () async {
    final platform = _FakePlatform();
    addTearDown(platform.controller.close);
    final signal = ThermalSignal(platform: platform);
    addTearDown(signal.dispose);
    await signal.start();
    var notifications = 0;
    signal.addListener(() => notifications++);

    platform.controller
      ..add(ThermalState.fair)
      ..add(ThermalState.fair)
      ..add(ThermalState.fair);
    await Future<void>.delayed(Duration.zero);

    expect(notifications, 1);
  });

  test('a slow initial poll does not overwrite a fresher push', () async {
    // The one-shot query and the event channel race on every platform. The
    // query was sent first, so its answer is the stale one when it loses.
    final platform = _FakePlatform(
      initial: ThermalState.nominal,
      pollDelay: const Duration(milliseconds: 20),
    );
    addTearDown(platform.controller.close);
    final signal = ThermalSignal(platform: platform);
    addTearDown(signal.dispose);

    final started = signal.start();
    await Future<void>.delayed(Duration.zero);
    platform.controller.add(ThermalState.critical);
    await started;

    expect(signal.value, ThermalState.critical);
  });

  test('parses the wire vocabulary and refuses anything else', () {
    expect(thermalStateFromName('nominal'), ThermalState.nominal);
    expect(thermalStateFromName('fair'), ThermalState.fair);
    expect(thermalStateFromName('serious'), ThermalState.serious);
    expect(thermalStateFromName('critical'), ThermalState.critical);

    // A level a future OS invents, or a typo in a host implementation, must
    // read as unknown. Defaulting it to nominal would mean the one thing a
    // new thermal level certainly does not mean.
    expect(thermalStateFromName('emergency'), isNull);
    expect(thermalStateFromName(null), isNull);
  });
}
