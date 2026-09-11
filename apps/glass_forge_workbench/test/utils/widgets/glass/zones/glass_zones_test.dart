import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_zones.dart';

void main() {
  group('GlassZones', () {
    const bar = Rect.fromLTWH(16, 760, 358, 64);
    const caption = Rect.fromLTWH(24, 740, 342, 88);

    test('content yields to overlapping chrome, never the reverse', () {
      final zones = GlassZones()
        ..report('bar', bar, GlassPriority.chrome)
        ..report('caption', caption, GlassPriority.content);

      expect(
        zones.mustYield('caption', caption, GlassPriority.content),
        isTrue,
      );
      expect(zones.mustYield('bar', bar, GlassPriority.chrome), isFalse);
    });

    test('edges that only touch do not overlap', () {
      final zones = GlassZones()
        ..report(
          'bar',
          const Rect.fromLTWH(0, 100, 100, 50),
          GlassPriority.chrome,
        );

      expect(
        zones.mustYield(
          'card',
          const Rect.fromLTWH(0, 0, 100, 100),
          GlassPriority.content,
        ),
        isFalse,
      );
    });

    test('equal priorities never yield to each other', () {
      final zones = GlassZones()
        ..report(
          'a',
          const Rect.fromLTWH(0, 0, 100, 100),
          GlassPriority.chrome,
        );

      expect(
        zones.mustYield(
          'b',
          const Rect.fromLTWH(50, 50, 100, 100),
          GlassPriority.chrome,
        ),
        isFalse,
      );
    });

    test('a withdrawn zone stops forcing anything', () {
      final zones = GlassZones()
        ..report(
          'sheet',
          const Rect.fromLTWH(0, 0, 400, 400),
          GlassPriority.overlay,
        )
        ..withdraw('sheet');

      expect(
        zones.mustYield(
          'bar',
          const Rect.fromLTWH(0, 300, 400, 64),
          GlassPriority.chrome,
        ),
        isFalse,
      );
    });

    test('an unchanged report does not notify', () {
      var notified = 0;
      GlassZones()
        ..addListener(() => notified++)
        ..report('a', const Rect.fromLTWH(0, 0, 10, 10), GlassPriority.content)
        ..report('a', const Rect.fromLTWH(0, 0, 10, 10), GlassPriority.content);

      expect(notified, 1);
    });

    test('forcing everything static notifies once per change', () {
      var notified = 0;
      final zones = GlassZones()
        ..addListener(() => notified++)
        ..forceStatic = true
        ..forceStatic = true;

      expect(zones.forceStatic, isTrue);
      expect(notified, 1);
    });
  });
}
