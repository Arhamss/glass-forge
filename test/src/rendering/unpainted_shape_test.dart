import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/diagnostics/render_counters.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';
import 'package:glass_forge/src/shapes/shape_limits.dart';

/// A shape that is attached and laid out but not drawn -- under an `Opacity`
/// at zero, an `Offstage`, a hidden `IndexedStack` child -- must not be in
/// the matte. It used to be: a shape that had never painted sat at the
/// layer's origin with no extent, so eleven of them read as one cluster and
/// warned; and one that had painted and then been hidden stayed in the
/// matte where it last was.
///
/// Every expectation about where a shape is comes from the widget tree
/// (`tester.getRect`), never from the layer under test.

/// Keeps every scene a layer asked to bake, as a snapshot, and bakes
/// nothing.
class _CapturingProducer implements GeometryProducer {
  final List<List<ShapeGeometry>> scenes = <List<ShapeGeometry>>[];

  List<ShapeGeometry> get last => scenes.last;

  @override
  GeometryCapabilities get capabilities =>
      const GeometryCapabilities(available: true, name: 'capturing');

  @override
  Future<void> warmUp() async {}

  @override
  MatteGeneration? produce(GlassScene scene, MatteRequest request) {
    scenes.add(List<ShapeGeometry>.of(scene.shapes));
    return null;
  }

  @override
  void release(MatteGeneration generation) {}

  @override
  void dispose() {}
}

_CapturingProducer _installCapturingProducer() {
  final producer = _CapturingProducer();
  ProducerRegistry.debugReset();
  ProducerRegistry.registerAccelerated(() => producer);
  addTearDown(() {
    ProducerRegistry.debugReset();
    debugResetAcceleratedProducerRegistration();
  });
  return producer;
}

const double _tile = 60;
const double _gap = 12;
const int _columns = 4;

Rect _tileRect(int i) => Rect.fromLTWH(
  (i % _columns) * (_tile + _gap),
  (i ~/ _columns) * (_tile + _gap),
  _tile,
  _tile,
);

Widget _tileAt(int i, Widget glass) => Positioned.fromRect(
  rect: _tileRect(i),
  child: glass,
);

Widget _glass(int i) => Glass(
  shape: const GlassRoundedRectangle(
    radius: BorderRadius.all(Radius.circular(16)),
  ),
  child: SizedBox(key: ValueKey<int>(i), width: _tile, height: _tile),
);

Widget _layer(List<Widget> children) => MaterialApp(
  home: GlassLayer(
    tier: GeometryTier.accelerated,
    child: Stack(children: children),
  ),
);

/// The layer-local logical rect a baked shape covers.
Rect _logical(ShapeGeometry shape, double dpr) {
  final box = shape.layerBounds;
  return Rect.fromLTRB(
    box.left / dpr,
    box.top / dpr,
    box.right / dpr,
    box.bottom / dpr,
  );
}

/// Whether [scene] holds a shape covering [rect], to within half a pixel.
bool _holds(List<ShapeGeometry> scene, Rect rect, double dpr) {
  for (final shape in scene) {
    final box = _logical(shape, dpr);
    if ((box.left - rect.left).abs() < 0.5 &&
        (box.top - rect.top).abs() < 0.5 &&
        (box.right - rect.right).abs() < 0.5 &&
        (box.bottom - rect.bottom).abs() < 0.5) {
      return true;
    }
  }
  return false;
}

Future<List<String>> _capturePrints(Future<void> Function() body) async {
  final printed = <String>[];
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    if (message != null) printed.add(message);
  };
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return printed;
}

void main() {
  setUpAll(ShaderLibrary.instance.warmUp);

  testWidgets('eleven tiles mounted under a zero Opacity and faded in never '
      'warn, and every one bakes', (tester) async {
    final producer = _installCapturingProducer();
    final opacity = ValueNotifier<double>(0);
    addTearDown(opacity.dispose);
    const count = 11;
    expect(count, greaterThan(kMaxShapes));

    final printed = await _capturePrints(() async {
      await tester.pumpWidget(
        _layer(<Widget>[
          for (var i = 0; i < count; i++)
            _tileAt(
              i,
              ValueListenableBuilder<double>(
                valueListenable: opacity,
                builder: (context, value, child) =>
                    Opacity(opacity: value, child: child),
                child: _glass(i),
              ),
            ),
        ]),
      );
      await tester.pump();
      for (final value in <double>[0.01, 0.4, 1]) {
        opacity.value = value;
        await tester.pump();
      }
    });

    expect(printed.where((m) => m.contains('at most')), isEmpty);
    for (final scene in producer.scenes) {
      expect(
        scene.where((shape) => shape.layerBounds.isEmpty),
        isEmpty,
        reason: 'a shape that had not painted was baked',
      );
    }
    final dpr = tester.view.devicePixelRatio;
    expect(producer.last, hasLength(count));
    for (var i = 0; i < count; i++) {
      final rect = tester.getRect(find.byKey(ValueKey<int>(i)));
      expect(
        _holds(producer.last, rect, dpr),
        isTrue,
        reason: 'tile $i at $rect is not in the last bake',
      );
    }
  });

  // How a shape is hidden decides how the layer finds out, so each is its
  // own case. An `Offstage` puts no repaint boundary under the layer, so a
  // shape that misses the layer's paint was not drawn. An `Opacity` above
  // zero is a repaint boundary itself, so the shape's last paint sits in a
  // retained layer and the layer has to ask whether that was composited. A
  // `RepaintBoundary` around the `Opacity` repaints without the layer
  // painting at all. And one inside it is reused, composited or not.
  final hiders =
      <String, Widget Function({required bool shown, required Widget glass})>{
        'an Offstage': ({required shown, required glass}) =>
            Offstage(offstage: !shown, child: glass),
        'an Opacity at zero': ({required shown, required glass}) =>
            Opacity(opacity: shown ? 1 : 0, child: glass),
        'an Opacity at zero inside a repaint boundary':
            ({required shown, required glass}) => RepaintBoundary(
              child: Opacity(opacity: shown ? 1 : 0, child: glass),
            ),
        'an Opacity at zero around a repaint boundary':
            ({required shown, required glass}) => Opacity(
              opacity: shown ? 1 : 0,
              child: RepaintBoundary(child: glass),
            ),
      };

  for (final MapEntry(key: how, value: hide) in hiders.entries) {
    testWidgets('a painted shape hidden by $how leaves no ghost in the '
        'matte, and bakes where it is once shown again', (tester) async {
      final producer = _installCapturingProducer();
      final shown = ValueNotifier<bool>(true);
      addTearDown(shown.dispose);

      await tester.pumpWidget(
        _layer(<Widget>[
          _tileAt(0, _glass(0)),
          _tileAt(
            2,
            ValueListenableBuilder<bool>(
              valueListenable: shown,
              builder: (context, value, child) =>
                  hide(shown: value, glass: child!),
              child: _glass(2),
            ),
          ),
        ]),
      );
      await tester.pump();

      final dpr = tester.view.devicePixelRatio;
      final hidden = tester.getRect(find.byKey(const ValueKey<int>(2)));
      final kept = tester.getRect(find.byKey(const ValueKey<int>(0)));
      expect(_holds(producer.last, hidden, dpr), isTrue);
      expect(_holds(producer.last, kept, dpr), isTrue);

      shown.value = false;
      // Two frames: where only the boundary repaints, the layer hears of it
      // after the first and repaints in the second.
      await tester.pump();
      await tester.pump();
      expect(
        _holds(producer.last, hidden, dpr),
        isFalse,
        reason: 'the hidden shape is still in the matte',
      );
      expect(producer.last, hasLength(1));
      expect(_holds(producer.last, kept, dpr), isTrue);

      shown.value = true;
      await tester.pump();
      await tester.pump();
      expect(producer.last, hasLength(2));
      expect(
        _holds(
          producer.last,
          tester.getRect(find.byKey(const ValueKey<int>(2))),
          dpr,
        ),
        isTrue,
        reason: 'the shown-again shape is not baked where it is',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a shape under a repaint boundary that stays on screen bakes '
      'no new matte while the layer repaints around it', (tester) async {
    // The marker path's steady state. The layer repaints every frame (the
    // colour is painted under it with no boundary between), the shape does
    // not (its own boundary is clean), so every frame it misses the
    // layer's paint and is asked whether it is still on screen. Yes, every
    // time -- and nothing about it changed, so nothing is baked.
    final producer = _installCapturingProducer();
    final colour = ValueNotifier<Color>(const Color(0xFF000000));
    addTearDown(colour.dispose);

    await tester.pumpWidget(
      _layer(<Widget>[
        Positioned.fill(
          child: ValueListenableBuilder<Color>(
            valueListenable: colour,
            builder: (context, value, _) => ColoredBox(color: value),
          ),
        ),
        _tileAt(0, RepaintBoundary(child: _glass(0))),
      ]),
    );
    await tester.pump();
    final layer = tester.renderObject<RenderGlassLayer>(
      find.byType(GlassLayer),
    );
    final bakes = producer.scenes.length;
    final subtreePaints = layer.subtreePaint;
    GlassRenderCounters.instance.reset();

    for (var i = 1; i <= 10; i++) {
      colour.value = Color(0xFF000000 + i);
      await tester.pump();
    }

    expect(
      layer.subtreePaint,
      subtreePaints + 10,
      reason: 'the layer did not repaint, so this checked nothing',
    );
    expect(GlassRenderCounters.instance.matteProduceCount, 0);
    expect(producer.scenes, hasLength(bakes));
    expect(producer.last, hasLength(1));
  });

  testWidgets('the shape-limit warning comes back after the cluster that '
      'set it off is gone', (tester) async {
    _installCapturingProducer();
    Widget tiles(double pitch) => _layer(<Widget>[
      for (var i = 0; i <= kMaxShapes; i++)
        Positioned(
          left: i * pitch,
          top: 0,
          child: const Glass(
            shape: GlassOval(),
            child: SizedBox(width: 30, height: 30),
          ),
        ),
    ]);

    Future<int> warningsAfter(double pitch) async {
      final printed = await _capturePrints(() async {
        await tester.pumpWidget(tiles(pitch));
        await tester.pump();
      });
      return printed.where((m) => m.contains('at most')).length;
    }

    expect(await warningsAfter(10), 1, reason: 'overlapping: one cluster');
    expect(await warningsAfter(50), 0, reason: 'apart: nine clusters');
    expect(
      await warningsAfter(10),
      1,
      reason: 'a second over-cap cluster must be reported, too',
    );
  });
}
