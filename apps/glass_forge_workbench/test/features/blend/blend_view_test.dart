import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/blend/presentation/cubit/blend_cubit.dart';
import 'package:glass_forge_workbench/features/blend/presentation/views/blend_view.dart';
import 'package:glass_forge_workbench/features/blend/presentation/widgets/blend_stage.dart';
import 'package:glass_forge_workbench/utils/enums/blend_arrangement.dart';

BlendCubit _cubitOf(WidgetTester tester) =>
    tester.element(find.byType(BlendStage)).read<BlendCubit>();

double _blendInScene(WidgetTester tester) =>
    tester.widget<GlassBlendGroup>(find.byType(GlassBlendGroup)).blend;

/// A phone-shaped surface, so the stage lays out at the sizes the screen
/// was designed for rather than at the 800x600 test default.
void _useAPhone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(400, 1200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('BlendView', () {
    testWidgets('the blend slider reaches the group that does the folding',
        (tester) async {
      _useAPhone(tester);
      await tester.pumpWidget(const MaterialApp(home: BlendView()));
      expect(_blendInScene(tester), 20);

      _cubitOf(tester).setBlend(48);
      await tester.pumpAndSettle();

      expect(_blendInScene(tester), 48);
    });

    testWidgets('the arrangement decides how many shapes are in the group',
        (tester) async {
      _useAPhone(tester);
      await tester.pumpWidget(const MaterialApp(home: BlendView()));
      expect(find.byType(Glass), findsNWidgets(2));

      _cubitOf(tester).setArrangement(BlendArrangement.triad);
      await tester.pumpAndSettle();

      expect(find.byType(Glass), findsNWidgets(3));
    });

    testWidgets('the stage states what it expects before you look at it',
        (tester) async {
      _useAPhone(tester);
      await tester.pumpWidget(const MaterialApp(home: BlendView()));

      // Default scene: 148 apart, 96 across, so a 52 px gap against a
      // 20 px fold.
      expect(
        find.text('gap 52 px  ·  blend 20 px  →  two shapes'),
        findsOneWidget,
      );

      _cubitOf(tester).setSeparation(120);
      await tester.pumpAndSettle();

      expect(
        find.text('gap 24 px  ·  blend 20 px  →  two shapes'),
        findsOneWidget,
      );

      _cubitOf(tester).setBlend(40);
      await tester.pumpAndSettle();

      expect(
        find.text('gap 24 px  ·  blend 40 px  →  one shape'),
        findsOneWidget,
      );
    });

    testWidgets('dragging the stage spreads the shapes', (tester) async {
      _useAPhone(tester);
      await tester.pumpWidget(const MaterialApp(home: BlendView()));
      final before = _cubitOf(tester).state.separation;

      await tester.drag(find.byType(BlendStage), const Offset(30, 0));
      await tester.pumpAndSettle();

      expect(_cubitOf(tester).state.separation, before + 60);
    });
  });
}
