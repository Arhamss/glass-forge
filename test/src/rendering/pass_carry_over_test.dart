// A pass carried over to a new key (see `_carryOverMovedPasses`) is more
// than a bake count: it has to draw with its new material, follow a new
// presence object, and step aside for the ordinary path when only part of
// it moves.
//
// Impeller only: real glass means `ui.ImageFilter.shader`. Run with
// `flutter test --tags impeller --run-skipped --enable-impeller`.
@Tags(<String>['impeller'])
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/composition/glass_composition.dart';
import 'package:glass_forge/src/diagnostics/render_counters.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';
import 'package:glass_forge/src/widgets/glass_lift.dart';
import 'package:glass_forge/src/widgets/glass_presence.dart';

const _boundary = ValueKey<String>('boundary');

const Color _backdrop = Color(0xFF808080);

const GlassMaterial _red = GlassMaterial(
  tint: Color(0xFFFF0000),
  tintOpacity: 0.8,
);
const GlassMaterial _blue = GlassMaterial(
  tint: Color(0xFF0000FF),
  tintOpacity: 0.8,
);

const Rect _rect = Rect.fromLTWH(8, 8, 120, 60);

Widget _scene(List<Widget> children, {Key? layerKey}) => RepaintBoundary(
  key: _boundary,
  // Its own `MediaQuery`, at a device pixel ratio of 1: see
  // `glass_material_pass_test.dart` for why this rasterizer needs it.
  child: MediaQuery(
    data: const MediaQueryData(),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: _backdrop,
        child: GlassLayer(
          key: layerKey,
          tier: GeometryTier.portable,
          child: Stack(children: children),
        ),
      ),
    ),
  ),
);

Widget _at(Rect rect, Widget glass) =>
    Positioned.fromRect(rect: rect, child: glass);

Future<Color> _colorAt(WidgetTester tester, Offset point) async {
  late Color result;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_boundary),
    );
    final image = await boundary.toImage();
    try {
      final bytes = (await image.toByteData())!;
      final index = ((point.dy.round() * image.width) + point.dx.round()) * 4;
      result = Color.fromARGB(
        bytes.getUint8(index + 3),
        bytes.getUint8(index),
        bytes.getUint8(index + 1),
        bytes.getUint8(index + 2),
      );
    } finally {
      image.dispose();
    }
  });
  return result;
}

/// Lets whatever a readback's real-async window settled -- the layer's
/// warm-up -- reach paint: a repaint, and a frame after. Since the warm-up
/// settling stopped re-baking mattes already in hand (see
/// `readback_rebake_test.dart`) this bakes nothing, and is kept so a count
/// after it starts from a layer with nothing left pending.
Future<void> _settle(WidgetTester tester) async {
  tester
      .renderObject<RenderGlassLayer>(find.byType(GlassLayer))
      .markNeedsPaint();
  await tester.pump();
  await tester.pump();
}

int _distance(Color a, Color b) {
  int channel(double x) => (x * 255).round();
  return [
    (channel(a.r) - channel(b.r)).abs(),
    (channel(a.g) - channel(b.g)).abs(),
    (channel(a.b) - channel(b.b)).abs(),
  ].reduce((x, y) => x > y ? x : y);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  testWidgets(
    'a lifted pass draws what the lit material draws, and lifting moves no '
    'pass',
    (tester) async {
      const base = GlassMaterial(
        tint: Color(0xFFFFFFFF),
        tintOpacity: 0.3,
        highlight: 0.4,
      );
      final lit = base.copyWith(
        tintOpacity: GlassComposition.liftedTintOpacity(base.tintOpacity, 1),
        highlight: GlassComposition.liftedHighlight(base.highlight, 1),
      );
      final lift = AnimationController(vsync: const TestVSync());
      addTearDown(lift.dispose);

      await tester.pumpWidget(
        _scene([
          _at(
            _rect,
            GlassLiftScope(
              lift: lift,
              child: const Glass(shape: GlassOval(), material: base),
            ),
          ),
        ]),
      );
      await tester.pump();
      final unlifted = await _colorAt(tester, _rect.center);
      await _settle(tester);

      GlassRenderCounters.instance.reset();
      lift.value = 1;
      await tester.pump();
      expect(GlassRenderCounters.instance.passAssignmentCount, 0);
      expect(GlassRenderCounters.instance.matteProduceCount, 0);
      final lifted = await _colorAt(tester, _rect.center);
      expect(
        _distance(lifted, unlifted),
        greaterThan(8),
        reason: 'the lift has to reach the pass',
      );

      // The same glass in the lit material, in a layer built fresh.
      await tester.pumpWidget(
        _scene(
          [_at(_rect, Glass(shape: const GlassOval(), material: lit))],
          layerKey: UniqueKey(),
        ),
      );
      await tester.pump();
      final reference = await _colorAt(tester, _rect.center);
      expect(_distance(lifted, reference), lessThanOrEqualTo(1));
    },
  );

  testWidgets(
    'a pass carried over to a shading-only change draws the new tint',
    (tester) async {
      await tester.pumpWidget(
        _scene([_at(_rect, const Glass(shape: GlassOval(), material: _red))]),
      );
      await tester.pump();
      final red = await _colorAt(tester, _rect.center);
      // Let the warm-up the readback's real-async window settled reach
      // paint before counting.
      await _settle(tester);

      GlassRenderCounters.instance.reset();
      await tester.pumpWidget(
        _scene([_at(_rect, const Glass(shape: GlassOval(), material: _blue))]),
      );
      await tester.pump();
      expect(
        GlassRenderCounters.instance.matteProduceCount,
        0,
        reason: 'the pass was carried over, not rebuilt',
      );
      final carried = await _colorAt(tester, _rect.center);

      // The same glass in blue, in a layer built fresh.
      await tester.pumpWidget(
        _scene(
          [_at(_rect, const Glass(shape: GlassOval(), material: _blue))],
          layerKey: UniqueKey(),
        ),
      );
      await tester.pump();
      final fresh = await _colorAt(tester, _rect.center);

      expect(
        _distance(red, fresh),
        greaterThan(40),
        reason: 'red and blue must read apart for this to mean anything',
      );
      expect(_distance(carried, fresh), lessThanOrEqualTo(3));
    },
  );

  testWidgets(
    'a pass whose presence object is replaced is carried over and follows '
    'the new one',
    (tester) async {
      final first = AnimationController(vsync: tester, value: 1);
      final second = AnimationController(vsync: tester, value: 1);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      Widget under(Animation<double> presence) => _scene([
        _at(
          _rect,
          GlassPresence(
            presence: presence,
            child: const Glass(shape: GlassOval(), material: _red),
          ),
        ),
      ]);

      await tester.pumpWidget(under(first));
      await tester.pump();
      final shown = await _colorAt(tester, _rect.center);
      await _settle(tester);

      GlassRenderCounters.instance.reset();
      await tester.pumpWidget(under(second));
      await tester.pump();
      expect(GlassRenderCounters.instance.matteProduceCount, 0);
      expect(
        _distance(await _colorAt(tester, _rect.center), shown),
        lessThanOrEqualTo(3),
      );

      // Following the new object: the old one no longer drives it.
      first.value = 0;
      await tester.pump();
      expect(
        _distance(await _colorAt(tester, _rect.center), shown),
        lessThanOrEqualTo(3),
      );
      second.value = 0;
      await tester.pump();
      expect(
        _distance(await _colorAt(tester, _rect.center), _backdrop),
        lessThanOrEqualTo(3),
      );
    },
  );

  testWidgets(
    'half a pass moving to a new material takes the ordinary path: two '
    'passes, and the moved shape drawn in its new material',
    (tester) async {
      const left = Rect.fromLTWH(8, 8, 120, 60);
      const right = Rect.fromLTWH(200, 8, 120, 60);
      Widget build(GlassMaterial rightMaterial) => _scene([
        _at(left, const Glass(shape: GlassOval(), material: _red)),
        _at(right, Glass(shape: const GlassOval(), material: rightMaterial)),
      ]);

      await tester.pumpWidget(build(_red));
      await tester.pump();
      final layer = tester.renderObject<RenderGlassLayer>(
        find.byType(GlassLayer),
      );
      expect(layer.debugPassClips, hasLength(1));

      GlassRenderCounters.instance.reset();
      await tester.pumpWidget(build(_blue));
      await tester.pump();
      expect(layer.debugPassClips, hasLength(2));
      expect(
        GlassRenderCounters.instance.matteProduceCount,
        greaterThan(0),
        reason: 'both passes changed shape, so both bake',
      );

      final leftColor = await _colorAt(tester, left.center);
      await _settle(tester);
      final rightColor = await _colorAt(tester, right.center);
      expect(_distance(leftColor, rightColor), greaterThan(40));
    },
  );
}
