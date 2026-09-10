import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_platform/glass_forge_platform.dart';
import 'package:glass_forge_platform/glass_forge_platform_method_channel.dart';
import 'package:glass_forge_platform/glass_forge_platform_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockGlassForgePlatformPlatform extends GlassForgePlatformPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getPlatformVersion() async => '42';
}

void main() {
  final initialPlatform = GlassForgePlatformPlatform.instance;

  test('default instance is the method channel implementation', () {
    expect(initialPlatform, isA<MethodChannelGlassForgePlatform>());
  });

  test('getPlatformVersion delegates to the platform instance', () async {
    final plugin = GlassForgePlatform();
    final fake = MockGlassForgePlatformPlatform();
    GlassForgePlatformPlatform.instance = fake;

    expect(await plugin.getPlatformVersion(), '42');
  });
}
