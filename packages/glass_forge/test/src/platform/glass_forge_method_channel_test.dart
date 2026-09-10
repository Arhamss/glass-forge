import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/platform/glass_forge_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelGlassForge();
  const channel = MethodChannel('glass_forge');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns the value the host platform reports', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'isReduceTransparencyEnabled');
      return true;
    });

    expect(await platform.isReduceTransparencyEnabled(), isTrue);
  });

  test('returns null when the host platform returns nothing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    expect(await platform.isReduceTransparencyEnabled(), isNull);
  });
}
