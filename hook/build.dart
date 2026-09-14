import 'dart:io';

import 'package:flutter_gpu_shaders/build.dart';
import 'package:hooks/hooks.dart';

/// Where `buildShaderBundleJson` writes the compiled bundle, and where
/// `pubspec.yaml`'s `flutter: assets:` entry expects to find it. Must match
/// both: the manifest name below (`geometry.shaderbundle.json` becomes
/// `geometry.shaderbundle`) and `_bundleLegacyPath` in
/// `lib/src/geometry/gpu_geometry_producer.dart`.
const String _bundleLegacyPath = 'build/shaderbundles/geometry.shaderbundle';

/// Builds the Flutter GPU shader bundle.
///
/// This runs in every consumer's build. It must never fail one.
///
/// The GPU geometry producer is an optimisation: if its bundle cannot be
/// built — an unsupported toolchain, an experimental API that moved — the
/// package still renders through the runtime-effect producer. Breaking a
/// consumer's build over a fast path they never asked for is not a trade we
/// are willing to make, so failures are reported and swallowed.
///
/// Catching the failure here is not enough on its own: `pubspec.yaml`
/// statically declares [_bundleLegacyPath] under `flutter: assets:`, so
/// Flutter's asset bundler fails the *whole build* — independently of this
/// hook, and unconditionally — if that file does not exist when it runs,
/// regardless of how gracefully this `catch` block behaved. So on failure
/// this also stamps a placeholder at that exact path. `ShaderLibrary
/// .fromAsset` will fail to parse it, which `GpuGeometryProducer.warmUp`
/// already treats as an ordinary "unavailable" outcome — the placeholder
/// only has to exist, not be valid.
void main(List<String> args) async {
  await build(args, (input, output) async {
    try {
      await buildShaderBundleJson(
        buildInput: input,
        buildOutput: output,
        manifestFileName: 'shaders/gpu/geometry.shaderbundle.json',
        includeDirectories: [input.packageRoot.resolve('shaders/')],
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
      await _ensurePlaceholderBundleExists(input.packageRoot);
    }
  });
}

/// Writes an empty file at [_bundleLegacyPath] if nothing is there yet.
///
/// Guarded on its own: a placeholder failing to write must not turn a
/// soft shader-bundle failure into a hard build failure either.
Future<void> _ensurePlaceholderBundleExists(Uri packageRoot) async {
  try {
    final file = File.fromUri(packageRoot.resolve(_bundleLegacyPath));
    if (file.existsSync()) {
      return;
    }
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(const <int>[]);
  } on Object catch (error) {
    stderr.writeln(
      'glass_forge: could not stamp a placeholder Flutter GPU shader '
      'bundle either ($error). If `flutter: assets:` in pubspec.yaml still '
      'lists $_bundleLegacyPath, the build will fail on that missing '
      'asset — this is the one failure mode this hook cannot swallow on '
      'its own.',
    );
  }
}
