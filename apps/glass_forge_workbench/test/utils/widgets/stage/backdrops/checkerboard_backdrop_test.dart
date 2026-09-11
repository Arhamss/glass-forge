import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/backdrops/checkerboard_backdrop.dart';

void main() {
  testWidgets(
    'CheckerboardBackdrop keeps its squares larger than the refraction it '
    'has to survive',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 200,
            height: 200,
            child: CheckerboardBackdrop(),
          ),
        ),
      );

      final painter = tester
          .widget<CustomPaint>(find.byType(CustomPaint))
          .painter;

      expect(painter, isA<CheckerboardPainter>());
      final squareSize = (painter! as CheckerboardPainter).squareSize;

      // Refraction is only visible as the offset of a recognisable feature.
      // A square smaller than the displacement is pushed through whole
      // periods of the pattern and lands looking exactly like itself, so the
      // glass appears to do nothing — which is what a 1-physical-pixel grid
      // did here before. The instrument's edge-refraction slider tops out
      // well under this, so the bend always stays legible.
      expect(squareSize, greaterThanOrEqualTo(24));
    },
  );
}
