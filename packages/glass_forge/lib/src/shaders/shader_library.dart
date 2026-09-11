import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// The shaders this package ships.
enum GlassShaderId {
  /// Bakes shape geometry into the matte.
  geometry('packages/glass_forge/shaders/geometry.frag', core: true),

  /// Samples the matte and the backdrop to produce the final glass.
  finalRender('packages/glass_forge/shaders/final_render.frag', core: true),

  /// Reports the render backend and uniform capacity.
  probe('packages/glass_forge/shaders/probe.frag', core: true),

  /// [finalRender], but reconstructing the backdrop bilinearly instead of at
  /// the engine's nearest-neighbour default.
  ///
  /// Exists only to measure flutter#186945 against [finalRender] — see
  /// `docs/reference/backdrop_sampling.md`. Bound only when
  /// `debugBilinearBackdropSampling` (`package:glass_forge/src/debug.dart`)
  /// is set, which the sampling probe screen is the only thing that does.
  /// [core] is false: [ShaderLibrary.warmUp] never loads it, so no ordinary
  /// consumer compiles or loads a fourth shader at startup just because it
  /// exists. The probe loads it on demand via [ShaderLibrary.ensureLoaded]
  /// before it can ever be selected.
  finalRenderBilinearProbe(
    'packages/glass_forge/shaders/final_render_bilinear_probe.frag',
    core: false,
  );

  const GlassShaderId(this.assetKey, {required this.core});

  /// The asset key this shader loads from.
  final String assetKey;

  /// Whether [ShaderLibrary.warmUp] loads this shader eagerly.
  final bool core;
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

  /// Whether every core shader has loaded and is safe to [acquire].
  ///
  /// `true` once warm-up has finished loading every [GlassShaderId] with
  /// [GlassShaderId.core] set. A load failure for any of them propagates out
  /// of [warmUp] instead of being swallowed, so reaching `true` means all of
  /// them are genuinely ready. Says nothing about a non-core shader — see
  /// [ensureLoaded].
  bool get isReady => _warmUpComplete;

  /// How many shaders are checked out. Test-only.
  @visibleForTesting
  int get debugOutstandingCount => _outstanding.length;

  /// Loads every core shader. Safe to call repeatedly; the work happens
  /// once.
  Future<void> warmUp() => _warmUp ??= _loadAll();

  Future<void> _loadAll() async {
    for (final id in GlassShaderId.values.where((id) => id.core)) {
      // Every core shader is declared in `pubspec.yaml` and required to
      // load. A failure here — a typo in the asset key, a bundling failure,
      // a genuine GLSL compile error — is a real bug and must propagate
      // with the engine's own message intact rather than be swallowed.
      _programs[id] = await ui.FragmentProgram.fromAsset(id.assetKey);
    }
    _warmUpComplete = true;
  }

  /// Loads a non-core shader on demand.
  ///
  /// [warmUp] never loads a shader with [GlassShaderId.core] false — an
  /// experimental or probe-only shader that every consumer paid to load and
  /// compile at startup, whether or not anything ever binds it, is exactly
  /// the shared-cost/shared-failure-mode mistake this method exists to
  /// avoid. Idempotent, and safe to call every time a caller is about to
  /// need [id]; the actual load happens once. Await it before [acquire]ing
  /// a non-core [id] for the first time.
  Future<void> ensureLoaded(GlassShaderId id) async {
    if (_programs.containsKey(id)) {
      return;
    }
    _programs[id] = await ui.FragmentProgram.fromAsset(id.assetKey);
  }

  /// Checks out a shader for [id].
  ///
  /// Throws if [id] has not loaded, deliberately. Rendering nothing until
  /// shaders load is how upstream ends up with invisible glass children and
  /// no explanation.
  ui.FragmentShader acquire(GlassShaderId id) {
    final program = _programs[id];
    if (program == null) {
      // warmUp() only reaches _warmUpComplete = true after every shader has
      // loaded successfully — a failure for any of them propagates out of
      // _loadAll instead (see warmUp) — so the only way to land here is
      // calling acquire() before warmUp() has completed.
      final reason = _warmUpComplete
          ? '${id.assetKey} failed to load; this should be unreachable'
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
