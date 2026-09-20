import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/chrome/detent_geometry.dart';

void main() {
  group('the morph is continuous in height, not stepped by detent', () {
    test('at the lowest detent the sheet floats: full gap, floating radius',
        () {
      final metrics = GlassDetentSheetMetrics.at(
        height: 80,
        lowest: 80,
        top: 800,
      );
      expect(metrics.progress, 0);
      expect(metrics.gap, 12);
      expect(metrics.radius, 44);
    });

    test('at the top detent it is flush: no gap, the display radius', () {
      final metrics = GlassDetentSheetMetrics.at(
        height: 800,
        lowest: 80,
        top: 800,
      );
      expect(metrics.progress, 1);
      expect(metrics.gap, 0);
      expect(metrics.radius, 55);
    });

    // The point of the whole class. Half way up is half the morph, whether or
    // not a detent lives there — a finger dragging through this height sees
    // the gap tighten under it rather than jump when a detent is passed.
    test('half way up is half the gap and half the radius', () {
      final metrics = GlassDetentSheetMetrics.at(
        height: 440,
        lowest: 80,
        top: 800,
      );
      expect(metrics.progress, closeTo(0.5, 1e-9));
      expect(metrics.gap, closeTo(6, 1e-9));
      expect(metrics.radius, closeTo(49.5, 1e-9));
    });

    test('dragged below the lowest detent it stays fully floating', () {
      final metrics = GlassDetentSheetMetrics.at(
        height: 20,
        lowest: 80,
        top: 800,
      );
      expect(metrics.progress, 0);
    });

    test('dragged above the top detent it stays flush', () {
      final metrics = GlassDetentSheetMetrics.at(
        height: 900,
        lowest: 80,
        top: 800,
      );
      expect(metrics.progress, 1);
    });

    // A single detent, or a window so short that every detent collapsed into
    // one. Dividing by the span would be a divide by zero and put NaN into a
    // shader uniform, which paints nothing at all rather than painting wrong.
    test('a degenerate span resolves to flush rather than to NaN', () {
      final metrics = GlassDetentSheetMetrics.at(
        height: 400,
        lowest: 400,
        top: 400,
      );
      expect(metrics.progress, 1);
      expect(metrics.gap, 0);
    });
  });
}
