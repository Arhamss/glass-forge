import 'dart:async';
import 'dart:io';

/// Bridges a `flutter test` bundling quirk so `ShaderLibrary` tests exercise
/// the same asset keys real consumers use.
///
/// `flutter test` bundles a package's own declared assets — the `shaders:`
/// entries in this package's `pubspec.yaml` — at their bare path, e.g.
/// `shaders/geometry.frag`, because for this test run `glass_forge` is the
/// root project. Every real consumer instead depends on `glass_forge` as a
/// package, so Flutter bundles those same files under
/// `packages/glass_forge/shaders/geometry.frag` for them. `GlassShaderId`
/// rightly uses that consumer-facing key, since that is the key that matters
/// in production, so this mirrors the already-bundled test assets under that
/// same prefix rather than giving the tests a bare-path shortcut the
/// production code does not take.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final bareShaders = Directory('build/unit_test_assets/shaders');
  if (bareShaders.existsSync()) {
    final mirror = Directory(
      'build/unit_test_assets/packages/glass_forge/shaders',
    )..createSync(recursive: true);
    for (final entity in bareShaders.listSync()) {
      if (entity is File) {
        final name = entity.uri.pathSegments.last;
        entity.copySync('${mirror.path}/$name');
      }
    }
  }
  await testMain();
}
