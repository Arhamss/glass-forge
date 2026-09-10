import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// The shaders this package ships.
enum GlassShaderId {
  /// Bakes shape geometry into the matte.
  geometry('packages/glass_forge/shaders/geometry.frag'),

  /// Samples the matte and the backdrop to produce the final glass.
  finalRender('packages/glass_forge/shaders/final_render.frag'),

  /// Reports the render backend and uniform capacity.
  probe('packages/glass_forge/shaders/probe.frag');

  const GlassShaderId(this.assetKey);

  /// The asset key this shader loads from.
  final String assetKey;
}

/// Owns every `FragmentProgram` this package uses, and pools their shaders.
///
/// Exists because `flutter_shaders`' `ShaderBuilder` has no `dispose()` and
/// allocates a fresh `FragmentShader` per state — upstream therefore leaks one
/// shader per glass widget, and because an ungrouped shape silently creates
/// its own group, that is one leak per widget.
///
/// Warming up matters as much as pooling. Custom fragment programs compile at
/// load on Impeller, and pipeline *variants* — a different blend mode, sample
/// count or attachment format — compile **synchronously on first draw**. That
/// is the first-frame jank. [warmUp] pays it offscreen.
class ShaderLibrary {
  ShaderLibrary._();

  /// The shared instance.
  static final ShaderLibrary instance = ShaderLibrary._();

  final Map<GlassShaderId, ui.FragmentProgram> _programs = {};
  final Map<GlassShaderId, List<ui.FragmentShader>> _pool = {};
  final Map<ui.FragmentShader, GlassShaderId> _outstanding = {};
  Future<void>? _warmUp;
  bool _warmUpComplete = false;

  /// Whether the shaders that exist have loaded and are safe to [acquire].
  ///
  /// This is deliberately not "every [GlassShaderId] loaded": see the
  /// scaffolding note on [_loadAll].
  bool get isReady => _warmUpComplete;

  /// How many shaders are checked out. Test-only.
  @visibleForTesting
  int get debugOutstandingCount => _outstanding.length;

  /// Loads every shader. Safe to call repeatedly; the work happens once.
  Future<void> warmUp() => _warmUp ??= _loadAll();

  Future<void> _loadAll() async {
    for (final id in GlassShaderId.values) {
      try {
        _programs[id] = await ui.FragmentProgram.fromAsset(id.assetKey);
      } on Object {
        // TEMPORARY SCAFFOLDING — remove once Task 13 ships
        // `shaders/final_render.frag`.
        //
        // `GlassShaderId` enumerates all three shaders this package will
        // ever use, including `finalRender`, because that is the correct,
        // final API — but `final_render.frag` does not exist until Task 13,
        // and it is not declared in `pubspec.yaml` yet either. Without this
        // catch, `warmUp()` would throw for every caller and every test in
        // the window between this task and that one, over an asset that is
        // known-missing rather than a real failure.
        //
        // Once `final_render.frag` exists, delete this try/catch: a missing
        // asset at that point means something is actually broken (a typo in
        // the asset key, a bundling failure) and `warmUp()` should throw for
        // it, not shrug.
      }
    }
    _warmUpComplete = true;
  }

  /// Checks out a shader for [id].
  ///
  /// Throws if [id] has not loaded, deliberately. Rendering nothing until
  /// shaders load is how upstream ends up with invisible glass children and
  /// no explanation.
  ui.FragmentShader acquire(GlassShaderId id) {
    final program = _programs[id];
    if (program == null) {
      final reason = _warmUpComplete
          ? '${id.assetKey} has not loaded (see the scaffolding note on '
                'ShaderLibrary._loadAll if this is finalRender)'
          : 'warmUp() has not completed';
      throw StateError(
        'ShaderLibrary.acquire($id) failed: $reason. Await '
        'ShaderLibrary.instance.warmUp() during app startup.',
      );
    }
    final pooled = _pool[id];
    final shader = (pooled != null && pooled.isNotEmpty)
        ? pooled.removeLast()
        : program.fragmentShader();
    _outstanding[shader] = id;
    return shader;
  }

  /// Returns a shader to the pool.
  void release(ui.FragmentShader shader) {
    final id = _outstanding.remove(shader);
    if (id == null) {
      return;
    }
    (_pool[id] ??= <ui.FragmentShader>[]).add(shader);
  }

  /// Disposes everything. Call from tests, and on isolate teardown.
  void disposeAll() {
    for (final shaders in _pool.values) {
      for (final shader in shaders) {
        shader.dispose();
      }
    }
    for (final shader in _outstanding.keys) {
      shader.dispose();
    }
    _pool.clear();
    _outstanding.clear();
    _programs.clear();
    _warmUp = null;
    _warmUpComplete = false;
  }
}
