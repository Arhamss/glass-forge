import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(ShaderLibrary.instance.disposeAll);

  test('is not ready before warm-up', () {
    expect(ShaderLibrary.instance.isReady, isFalse);
  });

  test('acquiring before warm-up throws a directive, not a null error', () {
    // Upstream returns the bare child until its shaders load, so glass
    // children are simply invisible for the first frames and nobody can tell
    // why. Fail loudly instead.
    expect(
      () => ShaderLibrary.instance.acquire(GlassShaderId.geometry),
      throwsA(isA<StateError>()),
    );
  });

  test('warm-up is idempotent', () async {
    await ShaderLibrary.instance.warmUp();
    await ShaderLibrary.instance.warmUp();
    expect(ShaderLibrary.instance.isReady, isTrue);
  });

  test('released shaders are reused rather than reallocated', () async {
    await ShaderLibrary.instance.warmUp();
    final first = ShaderLibrary.instance.acquire(GlassShaderId.geometry);
    ShaderLibrary.instance.release(first);
    final second = ShaderLibrary.instance.acquire(GlassShaderId.geometry);
    expect(identical(first, second), isTrue);
  });

  test('disposeAll leaves nothing outstanding', () async {
    await ShaderLibrary.instance.warmUp();
    ShaderLibrary.instance.acquire(GlassShaderId.geometry);
    ShaderLibrary.instance.disposeAll();
    expect(ShaderLibrary.instance.isReady, isFalse);
    expect(ShaderLibrary.instance.debugOutstandingCount, 0);
  });
}
