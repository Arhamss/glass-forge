import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/tier/glass_tier_scope.dart';
import 'package:glass_forge/src/widgets/glass_host_scope.dart';

/// Measures what is behind every glass surface beneath it, so surfaces can
/// adapt without being told a `backdrop` colour.
///
/// Glass reads its backdrop through a backdrop filter, and a backdrop
/// filter's input cannot be read back on the CPU. So this does not look
/// through the glass. It looks at the content the glass sits on: whatever
/// is wrapped in a [GlassBackdropSource] beneath this widget is snapshotted
/// at low resolution, and every surface beneath this widget gets the mean
/// colour of the part of that snapshot it covers.
///
/// ```dart
/// GlassBackdropSampler(
///   child: Stack(
///     children: [
///       GlassBackdropSource(child: Image.asset('photo.jpg')),
///       GlassLayer(child: GlassSurface.card(child: Text('Hello'))),
///     ],
///   ),
/// )
/// ```
///
/// Opt-in, and an explicit `backdrop` on a surface always wins over the
/// sample.
///
/// ## Cost
///
/// One `toImage` of the source, at [resolution] of its logical size and
/// never more than [maxExtent] pixels on its longest side, followed by one
/// `toByteData` — both asynchronous, so no frame waits on them. That
/// happens at most once per [interval], only after the source has repainted
/// (or something beneath this widget scrolled), and only while at least one
/// surface is listening. A still background is snapshotted once. At the
/// defaults a phone-sized source is under 50 × 100 pixels, 20 KB of RGBA.
/// Surfaces that move over an unchanged source reuse the last snapshot:
/// re-averaging is a loop over the few pixels under each surface, run at
/// the end of a frame in which a surface repainted.
///
/// Nothing is sampled for a surface whose tier renders no glass or whose
/// user asked to reduce transparency — its tint is near-opaque there and
/// the backdrop does not reach the label — nor for one already on glass,
/// whose backdrop is that glass and not the source.
///
/// ## Limits
///
/// A repaint inside the source that stops at a repaint boundary of its own
/// — a video, a platform view, an animated shader behind a
/// `RepaintBoundary` — does not reach the source's own paint, so it is not
/// seen. Call [markNeedsSample] when such a source changes. A surface that
/// moves without repainting, and not because anything scrolled, keeps its
/// last reading until the next sample.
///
/// Where the platform cannot snapshot a layer, sampling switches itself off
/// and surfaces behave as if no sampler were there.
class GlassBackdropSampler extends StatefulWidget {
  /// Creates a sampler for the surfaces in [child].
  const GlassBackdropSampler({
    required this.child,
    this.interval = const Duration(milliseconds: 200),
    this.resolution = 1 / 8,
    this.maxExtent = 96,
    this.hysteresis = 0.06,
    super.key,
  }) : assert(resolution > 0, 'resolution must be positive'),
       assert(maxExtent >= 1, 'maxExtent must be at least one pixel'),
       assert(hysteresis >= 0, 'hysteresis cannot be negative');

  /// The subtree holding both the [GlassBackdropSource] and the surfaces.
  final Widget child;

  /// The shortest time between two snapshots.
  ///
  /// A background that repaints every frame is still read at most this
  /// often. The last repaint in a window is never lost: a snapshot follows
  /// when the window closes.
  final Duration interval;

  /// The snapshot's scale relative to the source's logical size.
  ///
  /// Small on purpose. A surface's legibility depends on the average of
  /// what is behind it, and a blur has already thrown the detail away.
  final double resolution;

  /// The most pixels the snapshot may have along its longer side, whatever
  /// [resolution] asks for.
  final double maxExtent;

  /// How far, in relative luminance from 0 to 1, a reading must move from
  /// the one a surface is using before the surface is told.
  ///
  /// This is what stops a surface flickering between schemes as content
  /// scrolls past: a backdrop that hovers around the point where the light
  /// and dark schemes swap keeps whichever scheme it had until it moves
  /// clearly to one side. Zero reports every change.
  final double hysteresis;

  /// Asks the sampler above [context] to take a fresh snapshot, for a
  /// source whose change it could not see (see Limits above).
  ///
  /// Does nothing when there is no sampler above [context].
  static void markNeedsSample(BuildContext context) {
    context
        .getInheritedWidgetOfExactType<_SamplerScope>()
        ?.state
        ._markSourceChanged();
  }

  /// Whether a sampler is above [context].
  ///
  /// Does not register a dependency: whether a sampler is there is fixed
  /// for the life of a subtree.
  static bool isActive(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_SamplerScope>() != null;

  /// How many snapshots have been started, across every sampler.
  @visibleForTesting
  static int debugSnapshotCount = 0;

  @override
  State<GlassBackdropSampler> createState() => _GlassBackdropSamplerState();
}

class _GlassBackdropSamplerState extends State<GlassBackdropSampler> {
  final Set<_GlassBackdropBuilderState> _probes = {};
  _RenderBackdropSource? _source;

  // Whether the source has painted since the last snapshot started. True
  // at first so the first surface to register gets a reading.
  bool _sourceChanged = true;
  // Whether a surface may have moved since the last averaging.
  bool _probesMoved = false;
  bool _frameCallbackPending = false;
  bool _inFlight = false;
  // Closed from the start of one snapshot until [interval] later.
  Timer? _window;
  // Set when the platform refused a snapshot; sampling stays off.
  bool _unsupported = false;

  ByteData? _pixels;
  int _pixelWidth = 0;
  int _pixelHeight = 0;
  // Snapshot pixels per logical pixel of the source, per axis.
  double _scaleX = 0;
  double _scaleY = 0;

  bool get _disposed => !mounted;

  void _attachSource(_RenderBackdropSource source) {
    assert(
      _source == null || identical(_source, source),
      'A GlassBackdropSampler samples one GlassBackdropSource.',
    );
    _source = source;
    _markSourceChanged();
  }

  void _detachSource(_RenderBackdropSource source) {
    if (identical(_source, source)) {
      // Detach runs while the tree is locked, so the surfaces hear about it
      // at the end of the frame rather than now.
      _source = null;
      _pixels = null;
      _markProbesMoved();
    }
  }

  void _register(_GlassBackdropBuilderState probe) {
    _probes.add(probe);
    _markProbesMoved();
  }

  void _unregister(_GlassBackdropBuilderState probe) {
    _probes.remove(probe);
  }

  void _markSourceChanged() {
    _sourceChanged = true;
    _scheduleCheck();
  }

  void _markProbesMoved() {
    _probesMoved = true;
    _scheduleCheck();
  }

  void _scheduleCheck() {
    if (_frameCallbackPending || _disposed || _unsupported) {
      return;
    }
    _frameCallbackPending = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _check())
      ..ensureVisualUpdate();
  }

  // Runs at the end of a frame, when every layer is current.
  void _check() {
    _frameCallbackPending = false;
    if (_disposed || _unsupported || _probes.isEmpty) {
      return;
    }
    final source = _source;
    if (source == null || !source.attached || !source.hasSize) {
      _probesMoved = false;
      _publishAll();
      return;
    }
    if (_sourceChanged && !_inFlight && _window == null) {
      unawaited(_snapshot(source));
    } else if (_probesMoved && _pixels != null) {
      _probesMoved = false;
      _publishAll();
    }
  }

  Future<void> _snapshot(_RenderBackdropSource source) async {
    final size = source.size;
    if (size.isEmpty) {
      return;
    }
    _sourceChanged = false;
    _inFlight = true;
    GlassBackdropSampler.debugSnapshotCount++;
    _window = Timer(widget.interval, _onWindowClosed);

    final ratio = math.min(
      widget.resolution,
      widget.maxExtent / math.max(size.width, size.height),
    );
    ui.Image? image;
    try {
      image = await source.toImage(pixelRatio: ratio);
      if (_disposed) {
        return;
      }
      final data = await image.toByteData();
      if (_disposed || data == null) {
        return;
      }
      _pixels = data;
      _pixelWidth = image.width;
      _pixelHeight = image.height;
      _scaleX = image.width / size.width;
      _scaleY = image.height / size.height;
      _probesMoved = false;
      _publishAll();
    } on Object {
      // A backend that cannot snapshot a layer. Degrade to the behaviour of
      // no sampler at all rather than keep failing every interval.
      _unsupported = true;
      _pixels = null;
      if (!_disposed) {
        _publishAll();
      }
    } finally {
      image?.dispose();
      _inFlight = false;
    }
    if (!_disposed && (_sourceChanged || _probesMoved)) {
      _scheduleCheck();
    }
  }

  void _onWindowClosed() {
    _window = null;
    if (_sourceChanged) {
      _scheduleCheck();
    }
  }

  void _publishAll() {
    for (final probe in _probes.toList()) {
      probe._receive(_sample(probe));
    }
  }

  // The mean colour of the snapshot under [probe], or null where it is not
  // over the source or there is no snapshot.
  Color? _sample(_GlassBackdropBuilderState probe) {
    final pixels = _pixels;
    final source = _source;
    final box = probe._box;
    if (pixels == null ||
        source == null ||
        !source.attached ||
        box == null ||
        !box.attached ||
        !box.hasSize) {
      return null;
    }
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(source),
      Offset.zero & box.size,
    );
    final left = (rect.left * _scaleX).floor().clamp(0, _pixelWidth);
    final top = (rect.top * _scaleY).floor().clamp(0, _pixelHeight);
    final right = (rect.right * _scaleX).ceil().clamp(0, _pixelWidth);
    final bottom = (rect.bottom * _scaleY).ceil().clamp(0, _pixelHeight);
    if (right <= left || bottom <= top) {
      return null;
    }
    return meanOf(
      pixels,
      width: _pixelWidth,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
  }

  @override
  void dispose() {
    _window?.cancel();
    _window = null;
    _probes.clear();
    _pixels = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (_) {
        // Something scrolled: either the source moved under the surfaces,
        // or surfaces moved over it, and a scrolled child need not repaint.
        _sourceChanged = true;
        _markProbesMoved();
        return false;
      },
      child: _SamplerScope(state: this, child: widget.child),
    );
  }
}

/// The unpremultiplied mean of the premultiplied RGBA [pixels] in the
/// half-open box `[left, right) × [top, bottom)`, or null when less than
/// half of that box is covered.
///
/// Weighting by alpha means a transparent pixel — somewhere the source drew
/// nothing — neither darkens the mean nor counts toward it.
@visibleForTesting
Color? meanOf(
  ByteData pixels, {
  required int width,
  required int left,
  required int top,
  required int right,
  required int bottom,
}) {
  var red = 0;
  var green = 0;
  var blue = 0;
  var alpha = 0;
  for (var y = top; y < bottom; y++) {
    var offset = (y * width + left) * 4;
    for (var x = left; x < right; x++) {
      red += pixels.getUint8(offset);
      green += pixels.getUint8(offset + 1);
      blue += pixels.getUint8(offset + 2);
      alpha += pixels.getUint8(offset + 3);
      offset += 4;
    }
  }
  final count = (right - left) * (bottom - top);
  if (alpha * 2 < count * 255) {
    return null;
  }
  return Color.from(
    alpha: 1,
    red: red / alpha,
    green: green / alpha,
    blue: blue / alpha,
  );
}

class _SamplerScope extends InheritedWidget {
  const _SamplerScope({required this.state, required super.child});

  final _GlassBackdropSamplerState state;

  @override
  bool updateShouldNotify(_SamplerScope oldWidget) =>
      !identical(oldWidget.state, state);
}

/// Marks the content glass sits on, for the [GlassBackdropSampler] above.
///
/// Wraps [child] in a repaint boundary — the layer that is snapshotted —
/// so it also isolates the background's repaints from the glass above it,
/// which is usually what a background wants anyway.
///
/// Glass inside the source is not sampled: its backdrop is not the source
/// as a whole but the part painted before it.
class GlassBackdropSource extends StatelessWidget {
  /// Marks [child] as what the glass above it sits on.
  const GlassBackdropSource({required this.child, super.key});

  /// The background.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sampler = context
        .dependOnInheritedWidgetOfExactType<_SamplerScope>()
        ?.state;
    return _InsideSource(
      child: _BackdropSource(sampler: sampler, child: child),
    );
  }
}

class _InsideSource extends InheritedWidget {
  const _InsideSource({required super.child});

  @override
  bool updateShouldNotify(_InsideSource oldWidget) => false;
}

class _BackdropSource extends SingleChildRenderObjectWidget {
  const _BackdropSource({required this.sampler, required super.child});

  final _GlassBackdropSamplerState? sampler;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBackdropSource(sampler);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderBackdropSource).sampler = sampler;
  }
}

class _RenderBackdropSource extends RenderRepaintBoundary {
  _RenderBackdropSource(this._sampler);

  _GlassBackdropSamplerState? _sampler;

  _GlassBackdropSamplerState? get sampler => _sampler;

  set sampler(_GlassBackdropSamplerState? value) {
    if (identical(value, _sampler)) {
      return;
    }
    if (attached) {
      _sampler?._detachSource(this);
      value?._attachSource(this);
    }
    _sampler = value;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _sampler?._attachSource(this);
  }

  @override
  void detach() {
    _sampler?._detachSource(this);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    _sampler?._markSourceChanged();
  }
}

/// Builds with the backdrop behind it: [backdrop] when given, otherwise
/// what the [GlassBackdropSampler] above measured, otherwise null.
///
/// Every surface and control in this package that takes a `backdrop`
/// already builds through one of these; use it directly for a surface of
/// your own that calls `GlassTheme.surfaceOf`.
///
/// ```dart
/// GlassBackdropBuilder(
///   builder: (context, backdrop) {
///     final style = GlassTheme.surfaceOf(
///       context,
///       GlassSurfaceRole.card,
///       size: const Size(200, 120),
///       backdrop: backdrop,
///     );
///     return ColoredBox(color: style.material.tint);
///   },
/// )
/// ```
class GlassBackdropBuilder extends StatefulWidget {
  /// Creates a builder.
  const GlassBackdropBuilder({
    required this.builder,
    this.backdrop,
    super.key,
  });

  /// The backdrop the app knows. Wins over any sample, and switches
  /// sampling off for this surface.
  final Color? backdrop;

  /// Builds with the backdrop in effect, or null when none is known.
  final Widget Function(BuildContext context, Color? backdrop) builder;

  @override
  State<GlassBackdropBuilder> createState() => _GlassBackdropBuilderState();
}

class _GlassBackdropBuilderState extends State<GlassBackdropBuilder> {
  _GlassBackdropSamplerState? _sampler;
  Color? _sampled;

  // The probe this state builds is its first render object.
  RenderBox? get _box {
    if (!mounted) {
      return null;
    }
    final object = context.findRenderObject();
    return object is RenderBox ? object : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resubscribe();
  }

  @override
  void didUpdateWidget(GlassBackdropBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.backdrop == null) != (widget.backdrop == null)) {
      _resubscribe();
    }
  }

  void _resubscribe() {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_SamplerScope>()
        ?.state;
    final tier = GlassTierScope.maybeOf(context);
    final wanted =
        widget.backdrop == null &&
        scope != null &&
        context.getInheritedWidgetOfExactType<_InsideSource>() == null &&
        !GlassHostScope.isOnGlass(context) &&
        !(tier?.profile.rendersNothing ?? false) &&
        !(tier?.accessibility.reduceTransparency ?? false);
    final next = wanted ? scope : null;
    if (identical(next, _sampler)) {
      return;
    }
    _sampler?._unregister(this);
    _sampler = next;
    _sampled = null;
    next?._register(this);
  }

  // Applies hysteresis: a reading is only taken up when it is the first,
  // when it is the absence of one, or when its luminance has moved clearly
  // away from the reading in use.
  void _receive(Color? reading) {
    if (!mounted) {
      return;
    }
    final current = _sampled;
    if (reading == current) {
      return;
    }
    if (reading != null && current != null) {
      final moved = (reading.computeLuminance() - current.computeLuminance())
          .abs();
      if (moved < (_sampler?.widget.hysteresis ?? 0)) {
        return;
      }
    }
    setState(() => _sampled = reading);
  }

  void _onPaint() => _sampler?._markProbesMoved();

  @override
  void dispose() {
    _sampler?._unregister(this);
    _sampler = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PaintProbe(
      onPaint: _onPaint,
      child: widget.builder(context, widget.backdrop ?? _sampled),
    );
  }
}

class _PaintProbe extends SingleChildRenderObjectWidget {
  const _PaintProbe({required this.onPaint, super.child});

  final VoidCallback onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaintProbe(onPaint);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderPaintProbe).onPaint = onPaint;
  }
}

class _RenderPaintProbe extends RenderProxyBox {
  _RenderPaintProbe(this.onPaint);

  VoidCallback onPaint;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    onPaint();
  }
}
