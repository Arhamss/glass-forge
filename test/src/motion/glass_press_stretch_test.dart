import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/motion/glass_jiggle.dart';
import 'package:glass_forge/src/motion/glass_motion_state.dart';
import 'package:glass_forge/src/motion/glass_press_stretch.dart';

void main() {
  const size = Size(200, 80);
  const jiggle = GlassJiggle.none();
  const stretch = GlassPressStretch();

  Matrix4 transformFor(GlassMotionState state, GlassPressStretch s) {
    return glassSurfaceTransform(
      size: size,
      state: state,
      jiggle: jiggle,
      pressStretch: s,
      pressScale: 1,
    );
  }

  test('a wide surface stretches along the drag, not along a diagonal', () {
    // A drag toward the corner of a 200x80 surface is 22 degrees off its
    // long axis. Normalising the drag by each half-extent first turns it
    // into a 45-degree vector, and stretching a wide surface along a
    // diagonal it does not have is a shear: the card leans over like a
    // parallelogram.
    final m = transformFor(
      const GlassMotionState(
        translation: Offset.zero,
        velocity: Offset.zero,
        press: 1,
        pressDrag: Offset(100, 40),
      ),
      stretch,
    );
    // The stretch's long axis is the eigenvector of the symmetric 2x2 with
    // the larger eigenvalue.
    final a = m.entry(0, 0);
    final b = m.entry(0, 1);
    final d = m.entry(1, 1);
    final angle = 0.5 * math.atan2(2 * b, a - d);
    expect(angle, closeTo(math.atan2(40, 100), 0.02));
  });

  test('however far the finger drags, the stretch stops at 1 + intensity', () {
    final m = transformFor(
      const GlassMotionState(
        translation: Offset.zero,
        velocity: Offset.zero,
        press: 1,
        pressDrag: Offset(0, 5000),
      ),
      stretch,
    );
    // Largest stretch of the 2x2: at most 1 + intensity.
    final a = m.entry(0, 0);
    final b = m.entry(0, 1);
    final d = m.entry(1, 1);
    final mean = (a + d) / 2;
    final radius = math.sqrt(((a - d) / 2) * ((a - d) / 2) + b * b);
    expect(mean + radius, lessThanOrEqualTo(1 + stretch.intensity + 1e-9));
  });

  test('a finger that has not moved is the identity', () {
    final m = transformFor(
      const GlassMotionState(
        translation: Offset.zero,
        velocity: Offset.zero,
        press: 1,
      ),
      stretch,
    );
    expect(m, equals(Matrix4.identity()));
  });

  test(
    'a surface with no area is identity, not NaN',
    () {
      // A pointer cannot land on a zero-size box, but a drag can outlive
      // the size that accepted it: press a normal surface, then let layout
      // collapse it (an AnimatedSize, a shrinking list item, a constraint
      // change). Both the drag and the press depth survive that frame.
      //
      // Dividing by the resulting zero half-extent yields Infinity, and then
      // Infinity/Infinity is NaN. This asserts the guard rather than the
      // symptom, because the symptom is invisible: a NaN matrix does not
      // compare equal even to itself, so nothing downstream reports it.
      for (final size in const <Size>[
        Size.zero,
        Size(0, 80),
        Size(200, 0),
      ]) {
        final m = glassSurfaceTransform(
          size: size,
          state: const GlassMotionState(
            translation: Offset.zero,
            velocity: Offset.zero,
            press: 1,
            pressDrag: Offset(50, 50),
          ),
          jiggle: const GlassJiggle.none(),
          pressStretch: const GlassPressStretch(),
          pressScale: 1,
        );
        expect(
          m,
          equals(Matrix4.identity()),
          reason: 'a $size surface has nothing to reach across',
        );
        for (final entry in <double>[
          m.entry(0, 0),
          m.entry(0, 1),
          m.entry(1, 0),
          m.entry(1, 1),
          m.getTranslation().x,
          m.getTranslation().y,
        ]) {
          expect(entry.isNaN, isFalse, reason: 'NaN leaked from $size');
        }
      }
    },
  );

  test('none() is the identity for any drag', () {
    final m = transformFor(
      const GlassMotionState(
        translation: Offset.zero,
        velocity: Offset.zero,
        press: 1,
        pressDrag: Offset(80, 20),
      ),
      const GlassPressStretch.none(),
    );
    expect(m, equals(Matrix4.identity()));
  });

  test('translation is travel x the drag past the slop, capped', () {
    Offset travelled(Offset drag) {
      final m = transformFor(
        GlassMotionState(
          translation: Offset.zero,
          velocity: Offset.zero,
          press: 1,
          pressDrag: drag,
        ),
        const GlassPressStretch(intensity: 0, squash: 0),
      );
      return Offset(m.getTranslation().x, m.getTranslation().y);
    }

    // 0.05 of the 57 pt past the 3 pt slop.
    expect(travelled(const Offset(60, 0)).dx, closeTo(2.85, 1e-9));
    expect(travelled(const Offset(60, 0)).dy, closeTo(0, 1e-9));
    // Never more than a few points, however far the finger goes.
    expect(
      travelled(const Offset(0, -400)).dy,
      closeTo(-GlassPressStretch.maxTravel, 1e-9),
    );
  });

  test('the first 3 pt of movement are ignored', () {
    for (final drag in const <Offset>[Offset(2, 0), Offset(0, -3)]) {
      final m = transformFor(
        GlassMotionState(
          translation: Offset.zero,
          velocity: Offset.zero,
          press: 1,
          pressDrag: drag,
        ),
        stretch,
      );
      expect(m, equals(Matrix4.identity()), reason: '$drag moved it');
    }
  });

  test('a longer drag gives more, with diminishing returns', () {
    double along(double distance) => transformFor(
      GlassMotionState(
        translation: Offset.zero,
        velocity: Offset.zero,
        press: 1,
        pressDrag: Offset(distance, 0),
      ),
      const GlassPressStretch(travel: 0),
    ).entry(0, 0);
    final short = along(23) - 1;
    final twice = along(43) - 1;
    expect(short, greaterThan(0));
    expect(twice, greaterThan(short));
    expect(twice, lessThan(2 * short));
  });

  test('the default squash of 1 conserves area', () {
    final m = transformFor(
      const GlassMotionState(
        translation: Offset.zero,
        velocity: Offset.zero,
        press: 1,
        pressDrag: Offset(60, 25),
      ),
      // squash defaults to 1; a large intensity makes the check bite.
      const GlassPressStretch(intensity: 0.5, travel: 0),
    );
    final determinant =
        m.entry(0, 0) * m.entry(1, 1) - m.entry(0, 1) * m.entry(1, 0);
    expect(determinant, closeTo(1, 1e-6));
  });

  test('an unpressed surface is unstretched however far the drag is', () {
    final m = transformFor(
      const GlassMotionState(
        translation: Offset.zero,
        velocity: Offset.zero,
        press: 0,
        pressDrag: Offset(90, 30),
      ),
      stretch,
    );
    expect(m, equals(Matrix4.identity()));
  });

  test(
    'velocity-stretch and press-drag at 45 degrees pin the '
    'multiplication order to V·A, not A·V',
    () {
      // Velocity along x and a drag at exactly 45 degrees on a square
      // surface: the one non-axis-aligned, non-parallel configuration that
      // still keeps the arithmetic checkable by hand (see the doc comment
      // on glassSurfaceTransform). Axis-aligned choices would make both
      // matrices diagonal, so they would commute and neither order would
      // disagree with the other.
      const activeJiggle = GlassJiggle();
      const activeStretch = GlassPressStretch(intensity: 0.6, squash: 0.4);
      const velocity = Offset(1500, 0);
      const state = GlassMotionState(
        translation: Offset.zero,
        velocity: velocity,
        press: 1,
        pressDrag: Offset(100, 100),
      );

      final m = glassSurfaceTransform(
        size: const Size(40, 40),
        state: state,
        jiggle: activeJiggle,
        pressStretch: activeStretch,
        pressScale: 1,
      );

      // Velocity is along x, so V (the velocity matrix) is diagonal:
      // v00 = along, v11 = across, v01 = 0.
      final velocityStretch = activeJiggle.stretchFor(velocity.distance);
      final along = velocityStretch;
      final across = 1 / velocityStretch;

      // The drag is at 45 degrees on a square surface, and long enough that
      // its rubber-banded give (about 29 pt) passes the 20 pt half-extent:
      // a reach capped to 1. A (the drag matrix) has a00 == a11 and a
      // nonzero a01.
      const reachDistance = 1.0;
      final pressAlong = 1 + activeStretch.intensity * reachDistance;
      final pressAcross =
          1 /
          (1 + activeStretch.intensity * reachDistance * activeStretch.squash);
      final a01 = (pressAlong - pressAcross) * 0.5;

      // V·A, what glassSurfaceTransform computes, gives:
      //   m01 = v00*a01 + v01*a11 = along * a01
      //   m10 = v01*a00 + v11*a01 = across * a01
      // Both V and A are symmetric on their own (each is a similarity
      // transform of a diagonal), so (V·A)^T = A^T·V^T =
      // A·V: computing A·V instead would swap m01 and m10, and
      // re-mirroring m10 = m01 would collapse them together. Either bug
      // is caught below because along != across here (velocityStretch !=
      // 1) and a01 != 0.
      expect(m.entry(0, 1), closeTo(along * a01, 1e-9));
      expect(m.entry(1, 0), closeTo(across * a01, 1e-9));
      expect(m.entry(0, 1), isNot(closeTo(m.entry(1, 0), 1e-6)));
    },
  );
}
