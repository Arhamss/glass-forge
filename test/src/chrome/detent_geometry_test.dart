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
        gap: 20,
        floatingRadius: 50,
        flushRadius: 60,
      );
      expect(metrics.progress, 0);
      expect(metrics.gap, 20);
      expect(metrics.radius, 50);
    });

    test('at the top detent it is flush: no gap, the display radius', () {
      final metrics = GlassDetentSheetMetrics.at(
        height: 800,
        lowest: 80,
        top: 800,
        gap: 20,
        floatingRadius: 50,
        flushRadius: 60,
      );
      expect(metrics.progress, 1);
      expect(metrics.gap, 0);
      expect(metrics.radius, 60);
    });

    // The point of the whole class. Half way up is half the morph, whether or
    // not a detent lives there — a finger dragging through this height sees
    // the gap tighten under it rather than jump when a detent is passed.
    test('half way up is half the gap and half the radius', () {
      final metrics = GlassDetentSheetMetrics.at(
        height: 440,
        lowest: 80,
        top: 800,
        gap: 20,
        floatingRadius: 50,
        flushRadius: 60,
      );
      expect(metrics.progress, closeTo(0.5, 1e-9));
      expect(metrics.gap, closeTo(10, 1e-9));
      expect(metrics.radius, closeTo(55, 1e-9));
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

  group('snapping on release', () {
    const detents = <double>[80, 400, 800];

    test('a slow release goes to the nearest detent', () {
      expect(nearestDetentIndex(detents, 150), 0);
      expect(nearestDetentIndex(detents, 300), 1);
      expect(nearestDetentIndex(detents, 700), 2);
    });

    test('exactly on a detent stays there', () {
      expect(nearestDetentIndex(detents, 400), 1);
    });

    // The reason velocity is projected through friction rather than compared
    // against a threshold: a flick is a statement about where the sheet was
    // going, and the decay already knows where that is. A threshold would
    // need a second constant nobody can tune from first principles.
    test('a flick up carries past the nearest detent to the next', () {
      // From just above the lowest detent, nearest is 0. A hard flick up
      // coasts most of the way to the middle detent, so it should land there.
      expect(nearestDetentIndex(detents, 120), 0);
      expect(nearestDetentIndex(detents, 120, velocity: 900), 1);
    });

    test('a flick down carries past the nearest detent to the one below', () {
      expect(nearestDetentIndex(detents, 760), 2);
      expect(nearestDetentIndex(detents, 760, velocity: -900), 1);
    });

    test('a fling never leaves the detent list', () {
      expect(nearestDetentIndex(detents, 700, velocity: 100000), 2);
      expect(nearestDetentIndex(detents, 200, velocity: -100000), 0);
    });

    test('a single detent is always the answer', () {
      expect(nearestDetentIndex(const <double>[400], 90, velocity: 4000), 0);
    });
  });
}
