import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

/// Which graphics backend the engine actually bound.
///
/// "Actually" is the operative word. A manifest flag says what was
/// *requested*; Android's Vulkan-to-GLES fallback happens afterwards, per
/// device, and is written only to the log. So every value here except
/// [unknown] is either read out of the engine or measured, never inferred
/// from configuration.
enum GraphicsBackend {
  /// Impeller on Metal. iOS and macOS, where Skia was removed in 3.29 and
  /// there is no other possibility.
  metal,

  /// Impeller on Vulkan. Android's preferred backend, and the desktop
  /// default since 3.47.
  vulkan,

  /// Impeller on OpenGL ES. Android's runtime fallback, measured by the
  /// pixel probe rather than assumed.
  openGLES,

  /// Skia. `ui.ImageFilter.shader` throws here, so no glass shader can run
  /// as a backdrop filter at all.
  skia,

  /// The probe has not run, or could not answer.
  unknown,
}

/// What this device's renderer can do, as facts rather than as a policy.
///
/// Static for the life of the process — the engine picks its backend at
/// startup and never renegotiates — which is why [RenderCapabilityProbe]
/// caches this and nothing invalidates it. Everything that *can* change at
/// runtime (heat, frame health, accessibility settings) lives in its own
/// signal and is combined with this by the tier resolver.
@immutable
class RenderCapabilities {
  /// Creates a capability report.
  const RenderCapabilities({
    required this.shaderFilters,
    required this.backend,
    required this.acceleratedGeometry,
    required this.complete,
  });

  /// What is knowable without a GPU round-trip or a rendered frame.
  ///
  /// `ui.ImageFilter.isShaderFilterSupported` is a plain static set by the
  /// engine at isolate start, valid in release builds, and it is the only
  /// public API in `dart:ui` that reports Impeller-versus-Skia. The other
  /// two facts are not answerable here: the backend needs a pixel read back
  /// off the GPU, and Flutter GPU has no usable context on Android until
  /// after the first surface frame.
  factory RenderCapabilities.immediate() {
    return RenderCapabilities(
      shaderFilters: ui.ImageFilter.isShaderFilterSupported,
      backend: GraphicsBackend.unknown,
      acceleratedGeometry: false,
      complete: false,
    );
  }

  /// Whether `ui.ImageFilter.shader` works here.
  ///
  /// False means Skia, and means the whole glass composite pass is
  /// unavailable — not slow, unavailable. It is the one capability that can
  /// take a tier all the way to the bottom on its own.
  final bool shaderFilters;

  /// The backend the engine bound.
  final GraphicsBackend backend;

  /// Whether an accelerated geometry producer can run here.
  ///
  /// Sourced from [ProducerRegistry.probeAccelerated], not from a second
  /// Flutter GPU context probe of its own: the producers already answer this
  /// question honestly for their own selection, and two probes could
  /// disagree.
  final bool acceleratedGeometry;

  /// Whether the asynchronous half of the probe has finished.
  ///
  /// False means [backend] is [GraphicsBackend.unknown] and
  /// [acceleratedGeometry] is a pessimistic `false`, not a measured one.
  /// The tier resolver uses this to avoid printing a confident diagnostic
  /// about a device it has not finished measuring.
  final bool complete;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is RenderCapabilities &&
        other.shaderFilters == shaderFilters &&
        other.backend == backend &&
        other.acceleratedGeometry == acceleratedGeometry &&
        other.complete == complete;
  }

  @override
  int get hashCode =>
      Object.hash(shaderFilters, backend, acceleratedGeometry, complete);

  @override
  String toString() {
    return 'RenderCapabilities(shaderFilters: $shaderFilters, '
        'backend: ${backend.name}, '
        'acceleratedGeometry: $acceleratedGeometry, complete: $complete)';
  }
}

/// Measures [RenderCapabilities] once per process.
///
/// Caching is not an optimisation here, it is a correctness property: the
/// GLES probe costs an offscreen draw and a GPU fence, and re-running it per
/// glass layer would put that on the raster thread repeatedly for an answer
/// that cannot have changed.
abstract final class RenderCapabilityProbe {
  static RenderCapabilities? _measured;
  static Future<RenderCapabilities>? _inFlight;
  static RenderCapabilities? _override;

  /// The best answer available without waiting.
  ///
  /// The measured result once [run] has completed, otherwise the
  /// synchronously-knowable subset. A caller that renders from this before
  /// the probe lands gets a conservative answer, never a wrong one: the two
  /// fields the probe fills in both start at their pessimistic value.
  static RenderCapabilities get immediate =>
      _override ?? _measured ?? RenderCapabilities.immediate();

  /// Whether [run] has already produced a measured result.
  static bool get isMeasured => _override != null || _measured != null;

  /// Measures everything, once. Safe to call repeatedly.
  ///
  /// Call this after the first frame, not during startup: Flutter GPU has no
  /// Impeller context to hand back on Android until a surface frame has been
  /// drawn, and probing earlier would record a permanent `false` for a
  /// device that is in fact accelerated.
  static Future<RenderCapabilities> run() {
    final overridden = _override;
    if (overridden != null) {
      return Future<RenderCapabilities>.value(overridden);
    }
    final measured = _measured;
    if (measured != null) {
      return Future<RenderCapabilities>.value(measured);
    }
    return _inFlight ??= _measure();
  }

  static Future<RenderCapabilities> _measure() async {
    final shaderFilters = ui.ImageFilter.isShaderFilterSupported;
    final result = RenderCapabilities(
      shaderFilters: shaderFilters,
      backend: await _probeBackend(shaderFilters: shaderFilters),
      // Deliberately after the backend probe: both are cheap, but this one
      // touches the Flutter GPU context, and doing it last keeps the
      // "already drew a frame" precondition as late as it can be.
      acceleratedGeometry: ProducerRegistry.probeAccelerated() != null,
      complete: true,
    );
    _measured = result;
    _inFlight = null;
    return result;
  }

  static Future<GraphicsBackend> _probeBackend({
    required bool shaderFilters,
  }) async {
    if (!shaderFilters) {
      // `isShaderFilterSupported` is false only under Skia, so there is
      // nothing left to distinguish and no reason to pay for a GPU read.
      return GraphicsBackend.skia;
    }
    final isGles = await _probeOpenGLES();
    if (isGles == null) {
      return GraphicsBackend.unknown;
    }
    if (isGles) {
      return GraphicsBackend.openGLES;
    }
    // Metal-versus-Vulkan is not probeable: impellerc injects
    // IMPELLER_TARGET_METAL and IMPELLER_TARGET_VULKAN only into
    // .shaderbundle stages, never into runtime-stage shaders. Platform is
    // exact here anyway — iOS and macOS have had no backend other than
    // Metal since 3.29 removed Skia from iOS and the FLTEnableImpeller
    // opt-out stopped working.
    final apple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return apple ? GraphicsBackend.metal : GraphicsBackend.vulkan;
  }

  /// Renders the one-bit backend probe and reads the pixel back.
  ///
  /// Returns null when the answer could not be obtained, which is a normal
  /// outcome on web (where the asset exists but the whole notion of an
  /// Impeller target does not) and must not be mistaken for "not GLES" —
  /// hence the nullable return rather than a defaulted bool.
  ///
  /// `toImageSync` renders GPU-resident without a copy back, and
  /// `toByteData` completes on the command buffer's completion status, so
  /// this is a real fence rather than a guess. Nothing touches the screen.
  static Future<bool?> _probeOpenGLES() async {
    ui.Image? image;
    try {
      await ShaderLibrary.instance.ensureLoaded(GlassShaderId.backendProbe);
      final shader = ShaderLibrary.instance.acquire(
        GlassShaderId.backendProbe,
      );
      try {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawRect(
          const ui.Rect.fromLTWH(0, 0, 1, 1),
          ui.Paint()..shader = shader,
        );
        final picture = recorder.endRecording();
        try {
          image = picture.toImageSync(1, 1);
        } finally {
          picture.dispose();
        }
      } finally {
        ShaderLibrary.instance.release(shader);
      }
      final bytes = await image.toByteData();
      if (bytes == null || bytes.lengthInBytes < 4) {
        return null;
      }
      // Red channel. The shader writes a saturated 1.0 or 0.0, so the
      // midpoint is a wide margin, not a tuned threshold.
      return bytes.getUint8(0) > 127;
    } on Object catch (error) {
      debugPrint(
        'glass_forge: the render backend probe could not run ($error). '
        'Treating the backend as unknown rather than guessing.',
      );
      return null;
    } finally {
      image?.dispose();
    }
  }

  /// Pins the probe's answer. Test-only.
  ///
  /// Passing null restores real measurement. A test that wants a specific
  /// device shape asserts against the resolver with this set, rather than
  /// against whatever backend `flutter_tester` happens to bind.
  @visibleForTesting
  static RenderCapabilities? get debugOverride => _override;

  @visibleForTesting
  static set debugOverride(RenderCapabilities? value) => _override = value;

  /// Discards the cached measurement so it runs again. Test-only.
  @visibleForTesting
  static void debugReset() {
    _measured = null;
    _inFlight = null;
    _override = null;
  }
}
