import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/utils/helpers/tab_geometry.dart';

void main() {
  group('TabGeometry', () {
    test('alignFor spans -1 to 1 across the tabs', () {
      expect(TabGeometry.alignFor(0, 4), -1);
      expect(TabGeometry.alignFor(3, 4), 1);
      expect(TabGeometry.alignFor(0, 1), 0);
    });

    test('indexAt maps a finger to its slot, clamps, and mirrors in RTL', () {
      expect(TabGeometry.indexAt(10, 400, 4, rtl: false), 0);
      expect(TabGeometry.indexAt(390, 400, 4, rtl: false), 3);
      expect(TabGeometry.indexAt(10, 400, 4, rtl: true), 3);
      expect(TabGeometry.indexAt(-50, 400, 4, rtl: false), 0);
      expect(TabGeometry.indexAt(999, 400, 4, rtl: false), 3);
    });

    test('alignAt follows the finger between the outer slot centres', () {
      expect(TabGeometry.alignAt(0, 400, 4, rtl: false), -1);
      expect(TabGeometry.alignAt(400, 400, 4, rtl: false), 1);
      expect(TabGeometry.alignAt(200, 400, 4, rtl: false), closeTo(0, 1e-9));
      expect(TabGeometry.alignAt(0, 400, 4, rtl: true), 1);
    });

    test('squashScale is identity at rest, and stretches along the travel', () {
      expect(TabGeometry.squashScale(0, squash: 0.8), const Offset(1, 1));

      final moving = TabGeometry.squashScale(12, squash: 0.8);
      expect(moving.dx, greaterThan(1));
      expect(moving.dy, lessThan(1));

      expect(TabGeometry.squashScale(12, squash: 0), const Offset(1, 1));
      expect(
        TabGeometry.squashScale(-12, squash: 0.8),
        TabGeometry.squashScale(12, squash: 0.8),
      );
    });
  });
}
