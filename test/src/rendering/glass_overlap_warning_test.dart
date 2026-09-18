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
}
