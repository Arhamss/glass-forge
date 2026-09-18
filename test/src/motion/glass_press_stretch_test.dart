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

  test('a zero anchor is the identity', () {
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

  test('none() is the identity for any anchor', () {
    final m = transformFor(
      const GlassMotionState(
        translation: Offset.zero,
        velocity: Offset.zero,
        press: 1,
        pressAnchor: Offset(80, 20),
      ),
      const GlassPressStretch.none(),
    );
    expect(m, equals(Matrix4.identity()));
  });

  test('translation is exactly travel x anchor x press', () {
    final m = transformFor(
      const GlassMotionState(
        translation: Offset.zero,
        velocity: Offset.zero,
        press: 1,
        pressAnchor: Offset(80, 0),
      ),
      const GlassPressStretch(intensity: 0, squash: 0),
    );
    expect(m.getTranslation().x, closeTo(12, 1e-9)); // 0.15 * 80
    expect(m.getTranslation().y, closeTo(0, 1e-9));
  });

  test('squash 1 conserves area', () {
    final m = transformFor(
      const GlassMotionState(
        translation: Offset.zero,
        velocity: Offset.zero,
        press: 1,
        pressAnchor: Offset(60, 25),
      ),
      const GlassPressStretch(squash: 1, travel: 0),
    );
    final determinant =
        m.entry(0, 0) * m.entry(1, 1) - m.entry(0, 1) * m.entry(1, 0);
    expect(determinant, closeTo(1, 1e-6));
  });

  test('an unpressed surface is unstretched however far the anchor is', () {
    final m = transformFor(
      const GlassMotionState(
        translation: Offset.zero,
        velocity: Offset.zero,
        press: 0,
        pressAnchor: Offset(90, 30),
      ),
      stretch,
    );
    expect(m, equals(Matrix4.identity()));
  });
}
