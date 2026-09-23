import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

void main() {
  setUpAll(ShaderLibrary.instance.warmUp);

  testWidgets('two overlapping shapes in different passes warn', (
    tester,
  ) async {
    final printed = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) printed.add(message);
    };
    // Restored with try/finally, not addTearDown: addTearDown callbacks run
    // after the whole test() body -- including flutter_test's own
    // end-of-test invariant check that debugPrint was not left changed --
    // so restoring there is too late and the check throws.
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlassLayer(
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 0,
                  top: 0,
                  child: Glass(
                    shape: GlassRoundedRectangle(
                      radius: BorderRadius.all(Radius.circular(28)),
                    ),
                    material: GlassMaterial(frost: 8),
                    child: SizedBox(width: 100, height: 100),
                  ),
                ),
                Positioned(
                  left: 40,
                  top: 40,
                  child: Glass(
                    shape: GlassRoundedRectangle(
                      radius: BorderRadius.all(Radius.circular(28)),
                    ),
                    material: GlassMaterial(frost: 20),
                    child: SizedBox(width: 100, height: 100),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    } finally {
      debugPrint = original;
    }

    expect(
      printed.where((m) => m.contains('187820')),
      isNotEmpty,
      reason:
          'overlapping shapes in different passes stack backdrop '
          'filters',
    );
  });

  testWidgets('two shapes sharing a material do not warn', (tester) async {
    final printed = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) printed.add(message);
    };
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlassLayer(
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 0,
                  top: 0,
                  child: Glass(
                    shape: GlassRoundedRectangle(
                      radius: BorderRadius.all(Radius.circular(28)),
                    ),
                    child: SizedBox(width: 100, height: 100),
                  ),
                ),
                Positioned(
                  left: 40,
                  top: 40,
                  child: Glass(
                    shape: GlassRoundedRectangle(
                      radius: BorderRadius.all(Radius.circular(28)),
                    ),
                    child: SizedBox(width: 100, height: 100),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    } finally {
      debugPrint = original;
    }

    expect(printed.where((m) => m.contains('187820')), isEmpty);
  });

  testWidgets('two shrunken shapes that do not meet on screen do not '
      'warn', (tester) async {
    // The catalogue index's arrangement, reduced: each thumbnail fits a
    // 200x200 specimen into a 44x44 slot, and two of them sit a row apart
    // with different materials, so they are in different passes. On screen
    // they are 22 pixels wide and 120 apart and cannot touch. The warning
    // read the shapes' own 200x200 extent against their layer-space
    // origins, which is four and a half times too wide in each direction,
    // and fired on every paint of the index.
    final printed = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) printed.add(message);
    };
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlassLayer(
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 20,
                  top: 20,
                  width: 44,
                  height: 44,
                  child: FittedBox(
                    child: Glass(
                      shape: GlassOval(),
                      material: GlassMaterial(frost: 8),
                      child: SizedBox(width: 200, height: 200),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 140,
                  width: 44,
                  height: 44,
                  child: FittedBox(
                    child: Glass(
                      shape: GlassOval(),
                      material: GlassMaterial(frost: 20),
                      child: SizedBox(width: 200, height: 200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    } finally {
      debugPrint = original;
    }

    // Both halves. The gap is what must not warn; the shrink is what makes
    // the gap worth testing, and without it this is the ordinary
    // non-overlapping case two passes already handled.
    expect(
      tester.getRect(find.byType(Glass).first),
      const Rect.fromLTWH(20, 20, 44, 44),
      reason: 'the FittedBox did not shrink the first specimen',
    );
    expect(
      tester.getRect(find.byType(Glass).last),
      const Rect.fromLTWH(20, 140, 44, 44),
    );
    expect(
      printed.where((m) => m.contains('187820')),
      isEmpty,
      reason:
          'two 44x44 thumbnails 120 pixels apart were reported as '
          'overlapping:\n${printed.join('\n')}',
    );
  });
}
