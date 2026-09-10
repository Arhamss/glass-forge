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
  /// This is deliberately not "every [GlassShaderId] loaded": `finalRender`'s
  /// asset, `shaders/final_render.frag`, does not exist until Task 13 ships
  /// it, so [warmUp] tolerates that one shader failing to load. `isReady`
  /// becomes `true` once warm-up has finished attempting every shader,
  /// whether or not `finalRender` actually loaded; `geometry` and `probe`
  /// are always required to have loaded, since a failure there is a real
  /// bug and [warmUp] lets it propagate instead of reaching this point.
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
      } on Object catch (error) {
        if (id != GlassShaderId.finalRender) {
          // `geometry` and `probe` both ship today and are declared in
          // `pubspec.yaml`; a load failure for either is a real bug — a
          // typo in the asset key, a bundling failure, a genuine GLSL
          // compile error — and must propagate with the engine's own
          // message intact rather than be swallowed here.
          rethrow;
        }
        // TEMPORARY SCAFFOLDING — remove once Task 13 ships
        // `shaders/final_render.frag`.
        //
        // `GlassShaderId` enumerates all three shaders this package will
        // ever use, including `finalRender`, because that is the correct,
        // final API — but `final_render.frag` does not exist until Task 13,
        // and it is not declared in `pubspec.yaml` yet either. Without this
        // narrow carve-out, `warmUp()` would throw for every caller and
        // every test in the window between this task and that one, over an
        // asset that is known-missing rather than a real failure. The
        // tolerance is scoped to `finalRender` only — a missing asset and a
        // failed GLSL compile both surface as the same plain `Exception`
        // from the engine, with nothing to distinguish them, so tolerating
        // every shader's failure here would just as happily swallow a
        // genuine compile error in `geometry` or `probe`.
        //
        // Once `final_render.frag` exists, delete this branch entirely: a
        // missing or failing asset at that point means something is
        // actually broken and `warmUp()` should throw for it too, not
        // shrug.
        debugPrint(
          'ShaderLibrary: ${id.assetKey} did not load (expected until '
          'Task 13 ships final_render.frag): $error',
        );
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
      final String reason;
      if (!_warmUpComplete) {
        reason = 'warmUp() has not completed';
      } else if (id == GlassShaderId.finalRender) {
        // The one tolerated gap: see the scaffolding note on
        // ShaderLibrary._loadAll. Task 13 removes both the gap and this
        // branch.
        reason = '${id.assetKey} does not exist yet — Task 13 ships it';
      } else {
        // warmUp() only reaches _warmUpComplete = true after every shader
        // other than finalRender has loaded successfully (see _loadAll), so
        // this should be unreachable — but if it happens, it is a real bug,
        // not the finalRender scaffolding gap.
        reason =
            '${id.assetKey} failed to load; this is not the '
            'finalRender scaffolding gap';
      }
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
