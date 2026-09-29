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
// This repo already has the correct fallback: `example/` depends on
// glass_forge as an ordinary path package, so a test run from there bundles
// shaders under `packages/glass_forge/...` exactly as a real consumer does,
// with no bridge needed. Move the asset-loading assertions (the
// `ShaderLibrary` tests that actually call `warmUp()`) into a test suite
// under `example/` instead.
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
        _mirror(entity, File('${mirror.path}/${entity.uri.pathSegments.last}'));
      }
    }
  }
  await testMain();
}

/// Puts a copy of [source] at [target] without ever leaving [target] empty
/// or half-written.
///
/// `flutter test` runs test files in parallel, one process each, and every
/// one of them runs [testExecutable]. A plain `copySync` truncates the
/// target before writing it, so a process loading a shader while another
/// was re-copying it read an empty file: "manifest could not be decoded:
/// Payload is null or empty", the intermittent `setUpAll` failure in the
/// Impeller lane. Copying under a name no other process uses and renaming
/// it into place is atomic, so a reader sees the old file or the new one;
/// a target that already matches is left alone.
void _mirror(File source, File target) {
  final bytes = source.readAsBytesSync();
  if (target.existsSync() && _same(target.readAsBytesSync(), bytes)) {
    return;
  }
  File('${target.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp')
    ..writeAsBytesSync(bytes, flush: true)
    ..renameSync(target.path);
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
