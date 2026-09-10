import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/platform/glass_forge_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeGlassForgePlatform extends GlassForgePlatform
    with MockPlatformInterfaceMixin {
  _FakeGlassForgePlatform({required this.value});

  final bool? value;

  @override
  Future<bool?> isReduceTransparencyEnabled() async => value;
}

void main() {
  final defaultInstance = GlassForgePlatform.instance;

  tearDown(() => GlassForgePlatform.instance = defaultInstance);

  test('defaults to the method channel implementation', () {
    expect(defaultInstance, isA<MethodChannelGlassForge>());
  });

  test('reports reduce transparency when the platform says it is on', () async {
    GlassForgePlatform.instance = _FakeGlassForgePlatform(value: true);

    expect(await GlassForge().isReduceTransparencyEnabled(), isTrue);
  });

  test('surfaces null when the platform cannot answer', () async {
    GlassForgePlatform.instance = _FakeGlassForgePlatform(value: null);

    // Null must stay null. Collapsing it to false here would render full glass
    // to a user who asked for reduced transparency.
    expect(await GlassForge().isReduceTransparencyEnabled(), isNull);
  });
}
