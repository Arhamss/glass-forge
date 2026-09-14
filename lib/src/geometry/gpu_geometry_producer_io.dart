import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:glass_forge/src/composition/pixel_buckets.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_codec.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shapes/shape_limits.dart';

/// `buildShaderBundleJson`'s legacy output path for the compiled bundle,
/// relative to the package root: `build/shaderbundles/geometry.shaderbundle`,
/// derived from the manifest file name
/// `shaders/gpu/geometry.shaderbundle.json`.
const String _bundleLegacyPath = 'build/shaderbundles/geometry.shaderbundle';

/// Asset keys to try [gpu.ShaderLibrary.fromAsset] with, in order.
///
/// A consuming app bundles a dependency's declared assets under
/// `packages/<package>/<path>` — the form every other shader in this package
/// uses (see `GlassShaderId`) — so that is tried first. Empirically,
/// `flutter_tester` bundles glass_forge's own `flutter: assets:` entry under
/// its bare pubspec-relative path when testing glass_forge itself, unlike the
/// `flutter: shaders:` entries, which land under both; the bare form is
/// tried second so the package's own test suite still finds the bundle.
const List<String> _defaultBundleAssetKeys = <String>[
  'packages/glass_forge/$_bundleLegacyPath',
  _bundleLegacyPath,
];

/// Bakes the matte with a Flutter GPU render pass.
///
/// Faster than the runtime-effect producer: it renders straight into a
/// `devicePrivate` texture rather than round-tripping through `toImageSync`,
/// whose display list is retained until disposal (flutter#138627).
///
/// Every entry point is guarded. Flutter GPU is experimental, its shader
/// bundle may not have built, and it does not exist on Skia — so
/// [capabilities] answers honestly and [produce] returns null rather than
/// throwing.
///
/// [capabilities] is honest in two stages, not one, because loading the
/// shader bundle is unavoidably asynchronous while [capabilities] is not:
/// before [warmUp] completes, `available` reflects only whether the GPU
/// backend itself works ([_probe]); a bundle that fails to build is
/// discovered only once [warmUp] actually tries to load it, at which point
/// `available` is corrected to `false`. A caller that commits to this
/// producer from the earlier, optimistic answer — [ProducerRegistry.select]
/// does, since selection has to be synchronous — is expected to check
/// [capabilities] again after awaiting [warmUp] and fall back if it
/// changed; `RenderGlassLayer` does exactly that.
class GpuGeometryProducer implements GeometryProducer {
  /// Creates a producer.
  ///
  /// [debugBundleAssetKeys] overrides the asset keys [warmUp] tries to load
  /// the shader bundle from. Test-only: it exists so a test can exercise the
  /// real bundle-load failure path (not a stand-in for it) deterministically
  /// — pointing at a key that can never resolve — without needing an
  /// actually-broken build. Production code must never pass it; the default
  /// is what `register()`'s zero-argument factory uses.
  GpuGeometryProducer({List<String>? debugBundleAssetKeys})
    : _bundleAssetKeys = debugBundleAssetKeys ?? _defaultBundleAssetKeys;

  /// The context probe's answer, cached for the whole process.
  ///
  /// Static, not per-instance: whether Flutter GPU has a usable context is a
  /// property of the engine, and it cannot change while the app runs. Every
  /// `GlassLayer` builds its own producer, so a per-instance cache re-probed
  /// and re-logged once per layer -- which is why the "Flutter GPU is
  /// unavailable here" line appeared five times in a row on a screen with
  /// five layers, reading like a repeating fault rather than one fact.
  static bool? _contextProbe;

  bool? _available;
  gpu.ShaderLibrary? _library;
  final List<ui.Image> _live = <ui.Image>[];
  final List<String> _bundleAssetKeys;

  /// Registers this producer as an accelerated option.
  ///
  /// Called once during package initialisation.
  static void register() {
    ProducerRegistry.registerAccelerated(GpuGeometryProducer.new);
  }

  @override
  GeometryCapabilities get capabilities => GeometryCapabilities(
        available: _available ??= _probe(),
        name: 'flutter-gpu',
      );

  bool _probe() {
    final cached = _contextProbe;
    if (cached != null) {
      return cached;
    }
    try {
      // Touch the GPU context. On Skia, on an older Flutter, or when Impeller
      // has no context to hand back yet, this throws — which is an answer,
      // not an error.
      return _contextProbe = _gpuContextIsUsable();
    } on Object catch (error) {
      debugPrint(
        'glass_forge: Flutter GPU is unavailable here ($error). Falling back '
        'to the runtime-effect geometry producer.',
      );
      return _contextProbe = false;
    }
  }

  /// Clears the process-wide context probe so a test can observe it running
  /// fresh. Test-only.
  @visibleForTesting
  static void debugResetContextProbe() {
    _contextProbe = null;
  }

  bool _gpuContextIsUsable() {
    // gpu.gpuContext is a lazily-initialised top-level field: accessing it
    // for the first time runs GpuContext._createDefault(), which throws when
    // there is no usable Impeller context — the Skia backend, or (per the
    // Flutter GPU README) Android before its first surface frame, where the
    // Impeller context does not exist yet. Callers must not probe this
    // during startup on Android; a post-frame callback is soon enough.
    //
    // This only confirms the *backend* can hand back a context. Whether the
    // shader bundle actually loaded is a separate, asynchronous question —
    // see warmUp() — because ShaderLibrary.fromAsset cannot be answered
    // synchronously here. produce() re-checks that independently, so a
    // bundle that fails to load after this probe already returned true still
    // cannot make produce() throw.
    //
    // defaultColorFormat is queried, rather than merely touching the getter,
    // so a context that initialised but cannot report a real color format
    // (unknown) is also treated as unusable.
    return gpu.gpuContext.defaultColorFormat != gpu.PixelFormat.unknown;
  }

  @override
  Future<void> warmUp() async {
    if (!capabilities.available) {
      return;
    }
    Object? lastError;
    for (final key in _bundleAssetKeys) {
      try {
        _library = await gpu.ShaderLibrary.fromAsset(key);
        return;
      } on Object catch (error) {
        lastError = error;
      }
    }
    debugPrint(
      'glass_forge: the Flutter GPU shader bundle failed to load '
      '($lastError). Frames will render through the runtime-effect producer '
      'instead.',
    );
    _library = null;
    // The context probe alone said this producer was available; loading the
    // bundle is what actually settles it, and it just failed. Correcting
    // `available` here — not just leaving produce() to return null forever
    // — is what lets a caller that already committed to this producer (see
    // the class doc) notice and fall back to a producer that works, instead
    // of rendering unrefracted indefinitely while still claiming to be the
    // accelerated one.
    _available = false;
  }

  @override
  MatteGeneration? produce(GlassScene scene, MatteRequest request) {
    if (!capabilities.available) {
      return null;
    }
    final library = _library;
    if (library == null) {
      // Either warmUp() has not completed yet, or the bundle failed to load.
      // Neither is an error here: the caller falls back to an unrefracted
      // frame, and the runtime producer remains the reliable path.
      return null;
    }
    final vertex = library['GeometryVertex'];
    final fragment = library['GeometryFragment'];
    if (vertex == null || fragment == null) {
      return null;
    }

    if (scene.shapes.isEmpty) {
      return null;
    }
    final padded = scene.bounds(padding: request.antialiasWidth);
    if (padded.isEmpty || !padded.isFinite) {
      return null;
    }
    final allocation = expandToPixelBuckets(padded);
    final width = allocation.width.round();
    final height = allocation.height.round();
    if (width <= 0 || height <= 0) {
      return null;
    }

    try {
      final texture = _renderMatte(
        vertex: vertex,
        fragment: fragment,
        scene: scene,
        request: request,
        allocation: allocation,
        width: width,
        height: height,
      );
      _live.add(texture);
      return MatteGeneration(
        texture: texture,
        bounds: allocation,
        sceneRevision: scene.revision,
        codec: MatteCodec(maxDisplacement: request.maxDisplacement),
      );
    } on Object catch (error) {
      debugPrint(
        'glass_forge: the Flutter GPU render pass failed ($error). This '
        'frame renders without refraction rather than crashing.',
      );
      return null;
    }
  }

  ui.Image _renderMatte({
    required gpu.Shader vertex,
    required gpu.Shader fragment,
    required GlassScene scene,
    required MatteRequest request,
    required Rect allocation,
    required int width,
    required int height,
  }) {
    final texture = gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      width,
      height,
    );

    final renderTarget = gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(texture: texture),
    );

    final pipeline = gpu.gpuContext.createRenderPipeline(vertex, fragment);
    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final renderPass = commandBuffer.createRenderPass(renderTarget)
      ..bindPipeline(pipeline)
      ..setColorBlendEnable(false)
      ..setCullMode(gpu.CullMode.none);

    final vertexBuffer = gpu.gpuContext.createDeviceBufferWithCopy(
      ByteData.sublistView(_fullScreenQuadVertices),
    );
    renderPass.bindVertexBuffer(
      gpu.BufferView(
        vertexBuffer,
        offsetInBytes: 0,
        lengthInBytes: vertexBuffer.sizeInBytes,
      ),
    );

    _bindUniforms(renderPass, fragment, scene, request, allocation);

    renderPass.draw(_fullScreenQuadVertices.length ~/ 2);
    commandBuffer.submit();

    return texture.asImage();
  }

  void _bindUniforms(
    gpu.RenderPass renderPass,
    gpu.Shader fragment,
    GlassScene scene,
    MatteRequest request,
    Rect allocation,
  ) {
    final slot = fragment.getUniformSlot('FragInfo');
    final size = slot.sizeInBytes;
    if (size == null) {
      throw StateError(
        'GeometryFragment has no reflected FragInfo uniform block.',
      );
    }

    int offsetOf(String member) {
      final offset = slot.getMemberOffsetInBytes(member);
      if (offset == null) {
        throw StateError('FragInfo has no member named $member.');
      }
      return offset;
    }

    // Zero-filled: unused shape slots must still be written (see the padding
    // loop below), and ByteData starts zeroed, matching that requirement for
    // free.
    final bytes = ByteData(size);

    // FlutterFragCoord(), which the runtime-effect producer's shader reads,
    // reports coordinates local to the (translated) canvas it was drawn
    // through rather than raw device pixels; gl_FragCoord here is the
    // opposite. uOrigin reconciles the two -- see
    // shaders/gpu/geometry_fragment.glsl's file header for the full story,
    // confirmed empirically by the cross-producer golden test.
    final originOffset = offsetOf('uOrigin');
    bytes
      ..setFloat32(originOffset, allocation.left, Endian.host)
      ..setFloat32(originOffset + 4, allocation.top, Endian.host);

    final opticalOffset = offsetOf('uOptical');
    bytes
      ..setFloat32(opticalOffset, request.maxDisplacement, Endian.host)
      ..setFloat32(opticalOffset + 4, request.edgeRefraction, Endian.host)
      ..setFloat32(opticalOffset + 8, request.refractionSpread, Endian.host)
      ..setFloat32(opticalOffset + 12, request.antialiasWidth, Endian.host);

    // std140 (and std430) give every vec4 array element a 16-byte stride
    // regardless of the block's own layout qualifier, so the per-shape
    // offset below holds independent of how impellerc laid out FragInfo.
    // Reflection sees the real GLSL member name, not the #define alias
    // geometry_fragment.glsl gives it for the shared common/ files.
    final shapeDataOffset = offsetOf('uShapeDataBlock');
    final shapes = scene.shapes;
    for (var s = 0; s < kMaxShapes; s++) {
      if (s >= shapes.length) {
        continue;
      }
      final g = shapes[s];
      final base = shapeDataOffset + s * 3 * 16;
      final values = <double>[
        // Layer-local, matching the runtime-effect producer: the shader adds
        // uOrigin to gl_FragCoord to reach layer-local space, so subtracting
        // the allocation origin here too applied it twice. The two
        // producers agreed with each other byte for byte — which is why the
        // cross-producer golden passed — and were both wrong for any shape
        // not at its layer's top-left.
        g.origin.dx,
        g.origin.dy,
        g.halfExtent.width,
        g.halfExtent.height,
        g.inverseBasis[0],
        g.inverseBasis[1],
        g.inverseBasis[2],
        g.inverseBasis[3],
        g.type.sdfCode.toDouble(),
        g.radius,
        g.distanceScale,
        g.blendMarker,
      ];
      for (var v = 0; v < values.length; v++) {
        bytes.setFloat32(base + v * 4, values[v], Endian.host);
      }
    }

    bytes.setFloat32(
      offsetOf('uNumShapes'),
      shapes.length.clamp(0, kMaxShapes).toDouble(),
      Endian.host,
    );

    final profileOffset = offsetOf('uProfile');
    bytes
      ..setFloat32(profileOffset, request.profileCode, Endian.host)
      ..setFloat32(profileOffset + 4, request.thickness, Endian.host);

    final hostBuffer = gpu.gpuContext.createHostBuffer();
    renderPass.bindUniform(slot, hostBuffer.emplace(bytes));
  }

  @override
  void release(MatteGeneration generation) {
    if (!generation.isOwner) {
      // A translated() view aliases its origin's texture rather than owning
      // it, exactly as in RuntimeGeometryProducer. Releasing a view is a
      // no-op; only the owner can retire the texture.
      return;
    }
    if (_live.remove(generation.texture)) {
      generation.texture.dispose();
    }
  }

  @override
  void dispose() {
    for (final texture in _live) {
      texture.dispose();
    }
    _live.clear();
  }
}

/// Two triangles spanning clip space entirely, as `(x, y)` pairs.
///
/// The fragment shader reads `gl_FragCoord` directly rather than an
/// interpolated varying (see geometry_fragment.glsl), so this attribute
/// carries nothing but coverage.
final Float32List _fullScreenQuadVertices = Float32List.fromList(<double>[
  -1, -1,
  1, -1,
  -1, 1,
  1, -1,
  1, 1,
  -1, 1,
]);
