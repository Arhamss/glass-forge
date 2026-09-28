import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/shape_limits.dart';

/// [count] small shapes in one material, in a row [spacing] logical pixels
/// apart.
Widget _row(int count, {required double spacing}) {
  return MaterialApp(
    home: GlassLayer(
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: <Widget>[
          for (var i = 0; i < count; i++)
            const Glass(
              shape: GlassOval(),
              child: SizedBox(width: 30, height: 30),
            ),
        ],
      ),
    ),
  );
}

/// [count] shapes in one material, each overlapping the one before it.
Widget _overlapping(int count) {
  return MaterialApp(
    home: GlassLayer(
      child: Stack(
        children: <Widget>[
          for (var i = 0; i < count; i++)
            Positioned(
              left: i * 10.0,
              top: 0,
              child: const Glass(
                shape: GlassOval(),
                child: SizedBox(width: 30, height: 30),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Clear space between neighbours in [_row] that keeps every shape in a
/// cluster of its own: a Control-Centre grid's gap. A cluster needs its
/// matte exact only across the coverage ramp, about 3.5 physical pixels
/// past each shape (see `clusterPadding`), so 12 logical pixels -- 36
/// physical at the test's 3x -- is far apart.
const double _apart = 12;

Future<List<String>> _printedWhilePumping(
  WidgetTester tester,
  Widget widget,
) async {
  final printed = <String>[];
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    if (message != null) printed.add(message);
  };
  try {
    await tester.pumpWidget(widget);
    await tester.pump();
  } finally {
    debugPrint = original;
  }
  return printed;
}

void main() {
  setUpAll(ShaderLibrary.instance.warmUp);

  // A cluster past the limit drops the extra shapes without a trace: the
  // uniform block has room for kMaxShapes and the rest are never written.
  // Nothing on screen says why a surface has no glass.
  testWidgets('one more overlapping shape than a cluster carries warns', (
    tester,
  ) async {
    final printed = await _printedWhilePumping(
      tester,
      _overlapping(kMaxShapes + 1),
    );
    expect(
      printed.where((m) => m.contains('at most $kMaxShapes')),
      hasLength(1),
    );
  });

  testWidgets('shapes close enough for their mattes to meet warn too', (
    tester,
  ) async {
    // Not overlapping, but one logical pixel apart -- three physical, less
    // than the two paddings between them: one cluster all the same.
    final printed = await _printedWhilePumping(
      tester,
      _row(kMaxShapes + 1, spacing: 1),
    );
    expect(
      printed.where((m) => m.contains('at most $kMaxShapes')),
      hasLength(1),
    );
  });

  testWidgets('exactly as many as a cluster carries does not', (
    tester,
  ) async {
    final printed = await _printedWhilePumping(
      tester,
      _overlapping(kMaxShapes),
    );
    expect(printed.where((m) => m.contains('at most')), isEmpty);
  });

  testWidgets('twelve separate shapes in one material do not warn', (
    tester,
  ) async {
    // Each is its own cluster and its own draw, so none is dropped. This
    // warned, wrongly, while a pass was a single draw of kMaxShapes.
    final printed = await _printedWhilePumping(
      tester,
      _row(12, spacing: _apart),
    );
    expect(printed.where((m) => m.contains('at most')), isEmpty);
  });
}
