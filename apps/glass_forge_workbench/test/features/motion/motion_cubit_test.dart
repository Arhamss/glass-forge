import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/features/motion/presentation/cubit/motion_cubit.dart';
import 'package:glass_forge_workbench/features/motion/presentation/cubit/motion_state.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';
import 'package:glass_forge_workbench/utils/enums/motion_release.dart';
import 'package:glass_forge_workbench/utils/enums/motion_spring_channel.dart';

void main() {
  group('MotionCubit', () {
    test('the duration slider writes to the selected spring and no '
        'other', () {
      final cubit = MotionCubit();
      final untouchedFollow = cubit.state.follow;
      final untouchedPress = cubit.state.press;

      cubit
        ..setChannel(MotionSpringChannel.settle)
        ..setDuration(720);

      expect(cubit.state.settle.duration.inMilliseconds, 720);
      expect(cubit.state.follow, untouchedFollow);
      expect(cubit.state.press, untouchedPress);
      addTearDown(cubit.close);
    });

    test('switching channel moves the sliders, not the values', () {
      final cubit = MotionCubit()
        ..setChannel(MotionSpringChannel.settle)
        ..setBounce(0.8)
        ..setChannel(MotionSpringChannel.follow)
        ..setBounce(-0.4);

      expect(cubit.state.settle.bounce, 0.8);
      expect(cubit.state.follow.bounce, -0.4);
      expect(cubit.state.editedSpring, cubit.state.follow);
      addTearDown(cubit.close);
    });

    test('retuning a spring keeps the settle thresholds it was carrying',
        () {
      // Dropping these would quietly put the spring back on a tolerance
      // measured in thousandths of a pixel, which is hundreds of frames of
      // invisible creep on something driving a shader. Started off the
      // defaults on purpose: with the defaults in place, losing them and
      // keeping them look identical.
      final cubit = MotionCubit(
        initialState: const MotionState(
          settle: GlassMotion.bouncy(settleDistance: 2, settleVelocity: 40),
        ),
      )
        ..setChannel(MotionSpringChannel.settle)
        ..setDuration(300)
        ..setBounce(0.1);

      expect(cubit.state.settle.settleDistance, 2);
      expect(cubit.state.settle.settleVelocity, 40);
      expect(cubit.state.settle.duration.inMilliseconds, 300);
      expect(cubit.state.settle.bounce, 0.1);
      addTearDown(cubit.close);
    });

    test('letting go decides whether the surface comes home', () {
      final cubit = MotionCubit();
      expect(cubit.state.drag.returnsHome, isTrue);

      cubit.setRelease(MotionRelease.fliesFree);

      expect(cubit.state.drag.returnsHome, isFalse);
      addTearDown(cubit.close);
    });

    test('the resistance knobs build the band the surface is handed', () {
      final cubit = MotionCubit()
        ..setOverdragLimit(120)
        ..setOverdragResistance(0.25);

      expect(cubit.state.drag.overdrag.limit, 120);
      expect(cubit.state.drag.overdrag.resistance, 0.25);
      addTearDown(cubit.close);
    });

    test('the deformation knobs build the jiggle the surface is handed',
        () {
      final cubit = MotionCubit()
        ..setMaxStretch(1.3)
        ..setHalfSpeed(900);

      expect(cubit.state.jiggle.maxStretch, 1.3);
      expect(cubit.state.jiggle.halfSpeed, 900);
      expect(cubit.state.jiggle.stretchFor(900), closeTo(1.15, 0.001));
      addTearDown(cubit.close);
    });

    test('putting everything back keeps where you were looking', () {
      final cubit = MotionCubit()
        ..setBackdrop(GlassBackdrop.diagonals)
        ..setChannel(MotionSpringChannel.press)
        ..setDuration(880)
        ..setMaxStretch(1.4)
        ..resetToDefaults();

      expect(cubit.state.backdrop, GlassBackdrop.diagonals);
      expect(cubit.state.channel, MotionSpringChannel.press);
      expect(cubit.state.press.duration.inMilliseconds, 320);
      expect(cubit.state.maxStretch, 1.18);
      addTearDown(cubit.close);
    });
  });
}
