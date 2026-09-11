import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/platform/glass_forge_method_channel.dart';
import 'package:glass_forge/src/tier/thermal_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelGlassForge();
  const channel = MethodChannel('glass_forge');

  void answer(Object? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => handler(call));
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('reduce transparency', () {
    test('returns the value the host platform reports', () async {
      answer((call) {
        expect(call.method, 'isReduceTransparencyEnabled');
        return true;
      });

      expect(await platform.isReduceTransparencyEnabled(), isTrue);
    });

    test('returns null when the host platform returns nothing', () async {
      answer((_) => null);

      expect(await platform.isReduceTransparencyEnabled(), isNull);
    });

    test('returns null when no host implements the method', () async {
      // No mock handler at all, which is what an unimplemented method and an
      // unregistered plugin both look like from Dart: a
      // MissingPluginException. Letting that escape would turn "this
      // platform cannot answer" — the documented, expected case on Windows,
      // Linux and web — into an exception every caller has to catch.
      expect(await platform.isReduceTransparencyEnabled(), isNull);
    });

    test('returns null when the host fails inside the method', () async {
      answer((_) => throw PlatformException(code: 'unavailable'));

      expect(await platform.isReduceTransparencyEnabled(), isNull);
    });
  });

  group('thermal state', () {
    test('parses the name the host platform reports', () async {
      answer((call) {
        expect(call.method, 'getThermalState');
        return 'serious';
      });

      expect(await platform.getThermalState(), ThermalState.serious);
    });

    test('returns null for a level it does not recognise', () async {
      // Android's seven levels are collapsed on the Kotlin side, so anything
      // arriving here that is not one of the four is a host this build does
      // not understand. Unknown, not nominal.
      answer((_) => 'emergency');

      expect(await platform.getThermalState(), isNull);
    });

    test('returns null when no host implements the method', () async {
      expect(await platform.getThermalState(), isNull);
    });
  });
}
