import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/design/glass_legibility.dart';

const Color _white = Color(0xFFFFFFFF);
const Color _black = Color(0xFF000000);
const Color _grey = Color(0xFF808080);

void main() {
  test('the contrast scale hits its documented endpoints', () {
    expect(GlassLegibility.contrastRatio(_white, _black), closeTo(21, 0.01));
    expect(GlassLegibility.contrastRatio(_grey, _grey), closeTo(1, 1e-9));
  });

  test('compositing at the ends of the range is a no-op either way', () {
    // Guards the seam between this layer and the compositor: an opacity of
    // zero must leave the backdrop exactly alone (otherwise a "no tint"
    // surface would still shift colour), and an opacity of one must produce
    // the tint exactly (otherwise the opaque step could never reach its
    // stated contrast).
    expect(
      GlassLegibility.surfaceOver(
        tint: _white,
        opacity: 0,
        backdrop: _grey,
      ),
      _grey,
    );
    expect(
      GlassLegibility.surfaceOver(tint: _white, opacity: 1, backdrop: _grey),
      _white,
    );
  });

  test('contrast is monotone in opacity, which bisection depends on', () {
    // opacityForContrast bisects, and bisection is only correct because
    // contrast never turns around as opacity rises. If the compositing model
    // ever stops being a straight interpolation — a linear-light blend, a
    // wide-gamut colour space — this is the test that catches it before the
    // solver starts returning nonsense.
    for (final backdrop in <Color>[_white, _black, _grey]) {
      var previous = GlassLegibility.labelContrast(
        tint: const Color(0xFF3A3A3A),
        opacity: 0,
        backdrop: backdrop,
        label: _white,
      );
      var direction = 0;
      for (var i = 1; i <= 100; i++) {
        final next = GlassLegibility.labelContrast(
          tint: const Color(0xFF3A3A3A),
          opacity: i / 100,
          backdrop: backdrop,
          label: _white,
        );
        final step = (next - previous).abs() < 1e-12
            ? 0
            : (next > previous ? 1 : -1);
        if (step != 0) {
          if (direction == 0) {
            direction = step;
          }
          expect(
            step,
            direction,
            reason: 'contrast reversed direction over $backdrop at $i%',
          );
        }
        previous = next;
      }
    }
  });

  test('a floor that already clears the target is left alone', () {
    // "Adapt" may only ever add tint. A surface that is already more legible
    // than it promised is not a defect to be corrected downward, and a
    // solver that returned the exact target would make every such surface
    // *less* transparent than it needs to be.
    final opacity = GlassLegibility.opacityForContrast(
      tint: const Color(0xFF3A3A3A),
      backdrop: _black,
      label: _white,
      target: 4.5,
      floor: 0.2,
      ceiling: 0.9,
    );
    expect(opacity, 0.2);
  });

  test('a raised opacity is the smallest one that reaches the target', () {
    const tint = Color(0xFF3A3A3A);
    final opacity = GlassLegibility.opacityForContrast(
      tint: tint,
      backdrop: _white,
      label: _white,
      target: 4.5,
      floor: 0.1,
      ceiling: 1,
    );

    double contrastAt(double value) => GlassLegibility.labelContrast(
      tint: tint,
      opacity: value,
      backdrop: _white,
      label: _white,
    );

    expect(contrastAt(opacity), greaterThanOrEqualTo(4.5));
    // Minimal to within the solver's own resolution: one bisection step
    // below, the target is missed. A solver that just returned the ceiling
    // would clear the first assertion and fail this one.
    expect(contrastAt(opacity - 1 / 4096), lessThan(4.5));
  });

  test('an unreachable target falls back to the better end, not the top', () {
    // A light tint over a mid-grey backdrop with a light label: every extra
    // point of opacity makes the label *less* legible. The floor is the best
    // available answer, and returning the ceiling because the search ran out
    // would hand back the worst one.
    const tint = _white;
    double contrastAt(double value) => GlassLegibility.labelContrast(
      tint: tint,
      opacity: value,
      backdrop: _grey,
      label: _white,
    );

    expect(contrastAt(0.2), lessThan(5));
    expect(contrastAt(0.9), lessThan(contrastAt(0.2)));

    final opacity = GlassLegibility.opacityForContrast(
      tint: tint,
      backdrop: _grey,
      label: _white,
      target: 5,
      floor: 0.2,
      ceiling: 0.9,
    );
    expect(opacity, 0.2);
  });
}
