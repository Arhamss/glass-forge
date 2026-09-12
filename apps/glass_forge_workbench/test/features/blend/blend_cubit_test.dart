import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/features/blend/presentation/cubit/blend_cubit.dart';
import 'package:glass_forge_workbench/features/blend/presentation/cubit/blend_state.dart';
import 'package:glass_forge_workbench/utils/enums/blend_arrangement.dart';

void main() {
  group('BlendCubit', () {
    test('a drag moves both shapes, so the centres part by twice the '
        'travel', () {
      final cubit = BlendCubit()
        ..setSeparation(120)
        ..dragSeparation(20);

      expect(cubit.state.separation, 160);
      addTearDown(cubit.close);
    });

    test('dragging cannot push the shapes through each other or off the '
        'stage', () {
      final cubit = BlendCubit()..dragSeparation(-10000);
      expect(cubit.state.separation, BlendState.minSeparation);

      cubit.dragSeparation(10000);
      expect(cubit.state.separation, BlendState.maxSeparation);
      addTearDown(cubit.close);
    });

    test('the slider is clamped to the same range as the drag', () {
      final cubit = BlendCubit()..setSeparation(1000);

      expect(cubit.state.separation, BlendState.maxSeparation);
      addTearDown(cubit.close);
    });
  });

  group('BlendState', () {
    test('the merge is expected exactly while the gap is under the blend', () {
      const gapOf40 = BlendState(
        separation: BlendState.nodeDiameter + 40,
        blend: 40,
      );
      const gapJustUnder = BlendState(
        separation: BlendState.nodeDiameter + 39,
        blend: 40,
      );

      // The boundary is not decoration: at a gap equal to the blend width
      // the fold has exactly run out of reach, so the honest claim is
      // "still two shapes".
      expect(gapOf40.expectsMerge, isFalse);
      expect(gapJustUnder.expectsMerge, isTrue);
    });

    test('overlap is reported separately from a merge', () {
      const touching = BlendState(separation: BlendState.nodeDiameter);
      const apart = BlendState(
        separation: BlendState.nodeDiameter + 1,
        blend: 0,
      );

      expect(touching.isOverlapping, isTrue);
      expect(touching.edgeGap, 0);
      expect(apart.isOverlapping, isFalse);
    });

    test('the default scene is two visibly separate shapes', () {
      const state = BlendState();

      expect(state.expectsMerge, isFalse);
      expect(state.isOverlapping, isFalse);
      expect(state.edgeGap, greaterThan(state.blend));
    });

    test('a triad is equilateral, so one gap describes every pair', () {
      const state = BlendState(
        arrangement: BlendArrangement.triad,
        separation: 150,
      );
      final centres = state.nodeCentres;

      expect(centres, hasLength(3));
      for (var i = 0; i < centres.length; i++) {
        for (var j = i + 1; j < centres.length; j++) {
          expect(
            (centres[i] - centres[j]).distance,
            closeTo(150, 0.001),
            reason: 'shapes $i and $j',
          );
        }
      }
    });

    test('a triad stays centred on the stage', () {
      // Centred on the bounding box, not the centroid: the apex sits further
      // from the centre than the base row does, so a centroid-centred triad
      // hangs low and meets the caption on a short stage.
      const state = BlendState(
        arrangement: BlendArrangement.triad,
        separation: 150,
      );
      final centres = state.nodeCentres;
      final xs = centres.map((c) => c.dx).toList();
      final ys = centres.map((c) => c.dy).toList();

      expect(xs.reduce(math.min) + xs.reduce(math.max), closeTo(0, 0.001));
      expect(ys.reduce(math.min) + ys.reduce(math.max), closeTo(0, 0.001));
    });

    test('a pair is exactly the separation apart', () {
      const state = BlendState(separation: 170);
      final centres = state.nodeCentres;

      expect(centres, hasLength(2));
      expect((centres.first - centres.last).distance, closeTo(170, 0.001));
    });
  });

  group('arrangement geometry', () {
    test('a pair is centred on the origin', () {
      const state = BlendState();
      final centres = state.nodeCentres;
      expect(centres.first.dx, -centres.last.dx);
      expect(centres.every((c) => c.dy == 0), isTrue);
    });

    test('two nodes at full separation fit the narrowest stage', () {
      const state = BlendState(separation: BlendState.maxSeparation);
      final span = state.separation + BlendState.nodeDiameter;
      expect(span, lessThanOrEqualTo(320 - 32));
    });
  });
}
