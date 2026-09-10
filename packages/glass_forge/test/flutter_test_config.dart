// This file works around a `flutter test` asset-bundling quirk described in
// the doc comment on `testExecutable` below: run from this package, `flutter
// test` bundles glass_forge's own shaders at a bare path instead of the
// `packages/glass_forge/...` prefix real consumers get, so `ShaderLibrary`'s
// production asset keys would 404 here without this bridge.
//
// The fix relies on current, undocumented `flutter test` behavior — that a
// root package's own declared assets land at the bare path, and that
// dart:ui's shader loader reads asset files lazily by path rather than from
// a preloaded manifest, so staging the mirror before `testMain()` runs is
// enough. Both were confirmed empirically against Flutter 3.47.2; neither is
// a documented contract.
//
// If a Flutter upgrade breaks this (the mirrored files stop resolving, or
// `build/unit_test_assets` changes shape), do not patch the bridge harder.
// This repo already has the correct fallback: `apps/glass_forge_workbench`
// and `apps/glass_forge_benchmark` both depend on glass_forge as an ordinary
// path package, so a test run from either bundles shaders under
// `packages/glass_forge/...` exactly as a real consumer does, with no bridge
// needed. Move the asset-loading assertions (the `ShaderLibrary` tests that
// actually call `warmUp()`) into one of those app test suites instead.
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
