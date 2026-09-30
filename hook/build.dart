import 'dart:io';

import 'package:flutter_gpu_shaders/build.dart';
import 'package:hooks/hooks.dart';

/// Where the compiled bundle is copied to, relative to the package root.
///
/// `buildShaderBundleJson` writes into `build/shaderbundles/`, which is not
/// part of the published package, so declaring that file under `flutter:
/// assets:` names a file pub.dev's analysis never sees. Instead
/// `pubspec.yaml` declares the directory `glass_forge_generated/`, which
/// ships holding only its `.gitignore`, and the bundle is copied into it
/// here. Must match `_bundlePath` in
/// `lib/src/geometry/gpu_geometry_producer_io.dart`.
const String _bundlePath = 'glass_forge_generated/geometry.shaderbundle';

/// Builds the Flutter GPU shader bundle.
///
/// This runs in every consumer's build. It must never fail one.
///
/// The GPU geometry producer is an optimisation: if its bundle cannot be
/// built — an unsupported toolchain, an experimental API that moved — the
/// package still renders through the runtime-effect producer. Breaking a
/// consumer's build over a fast path they never asked for is not a trade we
/// are willing to make, so failures are reported and swallowed. A declared
/// asset *directory* does not fail the build when it has no bundle in it,
/// so nothing has to stand in for a bundle that did not build: the loader
/// finds no asset, which `GpuGeometryProducer.warmUp` already treats as
/// "unavailable".
void main(List<String> args) async {
  await build(args, (input, output) async {
    try {
      final result = await buildShaderBundleJson(
        buildInput: input,
        buildOutput: output,
        manifestFileName: 'shaders/gpu/geometry.shaderbundle.json',
        includeDirectories: [input.packageRoot.resolve('shaders/')],
      );
      _copyIfChanged(
        File.fromUri(result.outputFile),
        File.fromUri(input.packageRoot.resolve(_bundlePath)),
      );
    } on Object catch (error, stackTrace) {
      // A build hook runs as a standalone Dart script, outside Flutter's own
      // log capture, so stderr — not print(), which very_good_analysis
      // bans — is what reliably reaches the console for every `flutter`
      // command that triggers this hook.
      stderr.writeln(
        'glass_forge: the Flutter GPU shader bundle did not build, so the '
        'accelerated geometry producer will report itself unavailable and '
        'rendering will use the runtime-effect path instead. This is not '
        'fatal.\n$error\n$stackTrace',
      );
    }
  });
}

/// Copies [from] over [to] unless [to] already holds the same bytes.
///
/// Skipping an identical copy keeps the file's timestamp still, so nothing
/// watching the asset sees a change on a build that changed nothing.
void _copyIfChanged(File from, File to) {
  final bytes = from.readAsBytesSync();
  if (to.existsSync() && _sameBytes(to.readAsBytesSync(), bytes)) {
    return;
  }
  to.parent.createSync(recursive: true);
  to.writeAsBytesSync(bytes, flush: true);
}

bool _sameBytes(List<int> a, List<int> b) {
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
