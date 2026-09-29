// A control's glass on content, read back as pixels.
//
// Impeller only, for the same reason as `glass_material_pass_test.dart`:
// real glass means `ui.ImageFilter.shader`. Run with
// `flutter test --tags impeller --run-skipped --enable-impeller`.
//
// Each control is rendered once as itself, then its glass element (the
// switch knob, the slider thumb, the segmented pill) is rendered again on
// its own: the same shape and material, at the same rect, over the same
// backdrop, with none of the control's painted parts. The centre pixel of
// the first must be the centre pixel of the second. Before the painted
// parts left a hole where the glass is, they drew straight over it -- the
// layer composites its glass under its subtree's paint -- so a switch that
// was on showed its green track where the knob should have been.
//
// The geometry follows `glass_material_pass_test.dart`'s two rasterizer
// constraints: glass near the top-left, and a device pixel ratio of 1.
@Tags(<String>['impeller'])
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/controls/glass_segmented_control.dart';
import 'package:glass_forge/src/controls/glass_slider.dart';
import 'package:glass_forge/src/controls/glass_switch.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

/// A saturated backdrop no control paints in, so a track colour and the
/// refracted backdrop can never be confused.
const Color _backdrop = Color(0xFF1E3AE0);

const Color _switchGreen = Color(0xFF34C759);

const _key = ValueKey<String>('boundary');

Widget _scene(Widget child) => RepaintBoundary(
  key: _key,
  child: MediaQuery(
    data: const MediaQueryData(),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: _backdrop,
        child: GlassLayer(
          tier: GeometryTier.portable,
          child: child,
        ),
      ),
    ),
  ),
);

/// Places [control] at the top-left in a tight box of [size], so where it
/// lands does not depend on how it sizes itself in loose space.
Widget _placed(Size size, Widget control) => Align(
  alignment: Alignment.topLeft,
  child: Padding(
    padding: const EdgeInsets.all(8),
    child: SizedBox.fromSize(size: size, child: control),
  ),
);

/// Reads back the RGBA at [point]. See `glass_material_pass_test.dart` for
/// why this has to leave the fake clock.
Future<Color> _colorAt(WidgetTester tester, Offset point) async {
  late Color result;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_key),
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

int _distance(Color a, Color b) {
  int channel(double x) => (x * 255).round();
  return [
    (channel(a.r) - channel(b.r)).abs(),
    (channel(a.g) - channel(b.g)).abs(),
    (channel(a.b) - channel(b.b)).abs(),
  ].reduce((x, y) => x > y ? x : y);
}

/// Renders [control], then its lone [Glass] alone at the same rect, and
/// returns both centre pixels: `(control, glassAlone)`.
Future<(Color, Color)> _centres(
  WidgetTester tester,
  Size size,
  Widget control,
) async {
  await tester.pumpWidget(_scene(_placed(size, control)));
  await tester.pump();

  final glassFinder = find.byType(Glass);
  expect(glassFinder, findsOneWidget, reason: 'the control is on content');
  final glass = tester.widget<Glass>(glassFinder);
  final rect = tester.getRect(glassFinder);
  final inControl = await _colorAt(tester, rect.center);

  await tester.pumpWidget(
    _scene(
      Stack(
        children: [
          Positioned.fromRect(
            rect: rect,
            child: Glass(shape: glass.shape, material: glass.material),
          ),
        ],
      ),
    ),
  );
  await tester.pump();
  final alone = await _colorAt(tester, rect.center);
  return (inControl, alone);
}

/// How far the two may differ per channel: rounding in the rasterizer, and
/// nothing a painted track over the glass could hide inside.
const int _tolerance = 3;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  testWidgets('an on switch shows its knob, not its green track', (
    tester,
  ) async {
    final (inControl, alone) = await _centres(
      tester,
      const Size(63, 44),
      GlassSwitch(value: true, onChanged: (_) {}),
    );
    expect(_distance(inControl, _switchGreen), greaterThan(40));
    expect(_distance(inControl, alone), lessThanOrEqualTo(_tolerance));
  });

  testWidgets('an off switch shows its knob, not its track tint', (
    tester,
  ) async {
    final (inControl, alone) = await _centres(
      tester,
      const Size(63, 44),
      GlassSwitch(value: false, onChanged: (_) {}),
    );
    expect(_distance(inControl, alone), lessThanOrEqualTo(_tolerance));
  });

  testWidgets('a slider at mid-value shows its thumb, not its track', (
    tester,
  ) async {
    final (inControl, alone) = await _centres(
      tester,
      const Size(200, 44),
      GlassSlider(value: 0.5, onChanged: (_) {}),
    );
    expect(_distance(inControl, alone), lessThanOrEqualTo(_tolerance));
  });

  testWidgets('a segmented control shows its pill, not its track tint', (
    tester,
  ) async {
    final (inControl, alone) = await _centres(
      tester,
      const Size(200, 44),
      GlassSegmentedControl<int>(
        segments: const [
          GlassSegment(value: 0, label: SizedBox.shrink()),
          GlassSegment(value: 1, label: SizedBox.shrink()),
        ],
        selected: 1,
        onChanged: (_) {},
      ),
    );
    expect(_distance(inControl, alone), lessThanOrEqualTo(_tolerance));
  });
}
