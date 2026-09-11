import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/backdrops/checkerboard_backdrop.dart';

void main() {
  testWidgets(
    'CheckerboardBackdrop sizes its squares to device pixels, not logical '
    'ones',
    (tester) async {
      const devicePixelRatio = 3.0;

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(devicePixelRatio: devicePixelRatio),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 200,
              height: 200,
              child: CheckerboardBackdrop(),
            ),
          ),
        ),
      );

      final painter =
          tester.widget<CustomPaint>(find.byType(CustomPaint)).painter;

      expect(painter, isA<CheckerboardPainter>());
      final squareSize = (painter! as CheckerboardPainter).squareSize;

      // A true 1-physical-pixel square is 1/devicePixelRatio logical
      // pixels. If the painter were sized to 1 *logical* pixel instead,
      // squareSize would be 1.0 regardless of devicePixelRatio — exactly
      // the bug this test exists to catch.
      expect(squareSize, closeTo(1 / devicePixelRatio, 1e-9));
      expect(squareSize, isNot(closeTo(1.0, 1e-9)));
    },
  );
}
