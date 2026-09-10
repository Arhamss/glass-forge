import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_platform/glass_forge_platform_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelGlassForgePlatform();
  const channel = MethodChannel('glass_forge_platform');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async => '42');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion returns the value from the channel', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
