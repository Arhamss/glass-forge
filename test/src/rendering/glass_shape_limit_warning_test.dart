import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/shape_limits.dart';

/// [count] small, separate shapes in one material, in a row.
Widget _row(int count) {
  return MaterialApp(
    home: GlassLayer(
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
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

  // A pass past the limit drops the extra shapes without a trace: the
  // uniform block has room for kMaxShapes and the rest are never written.
  // Nothing on screen says why a surface has no glass.
  testWidgets('one more shape than a pass carries warns', (tester) async {
    final printed = await _printedWhilePumping(tester, _row(kMaxShapes + 1));
    expect(
      printed.where((m) => m.contains('at most $kMaxShapes')),
      hasLength(1),
    );
  });

  testWidgets('exactly as many as a pass carries does not', (tester) async {
    final printed = await _printedWhilePumping(tester, _row(kMaxShapes));
    expect(printed.where((m) => m.contains('at most')), isEmpty);
  });
}
