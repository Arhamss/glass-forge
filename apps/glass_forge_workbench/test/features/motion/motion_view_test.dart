import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/motion/presentation/cubit/motion_cubit.dart';
import 'package:glass_forge_workbench/features/motion/presentation/views/motion_view.dart';
import 'package:glass_forge_workbench/features/motion/presentation/widgets/motion_stage.dart';
import 'package:glass_forge_workbench/utils/enums/motion_spring_channel.dart';

import '../../helpers/test_app.dart';

MotionCubit _cubitOf(WidgetTester tester) =>
    tester.element(find.byType(MotionStage)).read<MotionCubit>();

InteractiveGlass _specimen(WidgetTester tester) =>
    tester.widget<InteractiveGlass>(find.byType(InteractiveGlass));

/// A phone-shaped surface, so the stage lays out at the sizes the screen
/// was designed for rather than at the 800x600 test default.
void _useAPhone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(400, 1200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('MotionView', () {
    testWidgets('the surface you throw around is a dome', (tester) async {
      // The screen where the glass should feel like a lens in hand: the
      // Apple edge band's flat interior reads as a frosted pane here.
      _useAPhone(tester);
      await tester.pumpWidget(testApp(const MotionView()));
      final layer = tester.widget<GlassLayer>(find.byType(GlassLayer));
      expect(layer.material, GlassMaterial.dome());
      expect(layer.material.profile, GlassProfile.dome);
    });

    testWidgets('the spring sliders reach the surface that springs', (
      tester,
    ) async {
      _useAPhone(tester);
      await tester.pumpWidget(testApp(const MotionView()));
      expect(_specimen(tester).settleMotion.duration.inMilliseconds, 500);

      _cubitOf(tester)
        ..setChannel(MotionSpringChannel.settle)
        ..setDuration(700)
        ..setBounce(0.6);
      await tester.pumpAndSettle();

      expect(_specimen(tester).settleMotion.duration.inMilliseconds, 700);
      expect(_specimen(tester).settleMotion.bounce, 0.6);
      expect(
        _specimen(tester).followMotion.duration.inMilliseconds,
        150,
        reason: 'editing one channel must not move the other two',
      );
    });

    testWidgets('the resistance and deformation knobs reach the surface', (
      tester,
    ) async {
      _useAPhone(tester);
      await tester.pumpWidget(testApp(const MotionView()));

      _cubitOf(tester)
        ..setOverdragLimit(140)
        ..setOverdragResistance(0.9)
        ..setMaxStretch(1.05);
      await tester.pumpAndSettle();

      expect(_specimen(tester).drag.overdrag.limit, 140);
      expect(_specimen(tester).drag.overdrag.resistance, 0.9);
      expect(_specimen(tester).jiggle.maxStretch, 1.05);
    });

    testWidgets('the specimen follows a finger and springs home after it', (
      tester,
    ) async {
      _useAPhone(tester);
      await tester.pumpWidget(testApp(const MotionView()));
      final glass = find.byType(Glass);
      final home = tester.getCenter(glass);

      final gesture = await tester.startGesture(home);
      await gesture.moveBy(const Offset(90, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));

      final held = tester.getCenter(glass);
      expect(
        held.dx - home.dx,
        greaterThan(8),
        reason: 'the surface has to move under the finger to be grabbable',
      );
      expect(
        held.dx - home.dx,
        lessThan(90),
        reason: 'and the rubber band has to resist while it does',
      );

      await gesture.up();
      await tester.pumpAndSettle();

      expect((tester.getCenter(glass) - home).distance, lessThan(1));
    });
  });
}
