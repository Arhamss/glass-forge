import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/views/gallery_view.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/widgets/gallery_stage.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/widgets/instrument/gallery_resolution_group.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/widgets/instrument/gallery_roster_row.dart';

GalleryCubit _cubitOf(WidgetTester tester) =>
    tester.element(find.byType(GalleryStage)).read<GalleryCubit>();

Finder _surfacesFor(GlassSurfaceRole role) => find.byWidgetPredicate(
  (widget) => widget is GlassSurface && widget.role == role,
);

/// A phone-shaped surface, so the stage lays out at the sizes the screen
/// was designed for rather than at the 800x600 test default.
void _useAPhone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(400, 1200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('GalleryView', () {
    testWidgets('draws every semantic role, in both schemes', (tester) async {
      _useAPhone(tester);
      await tester.pumpWidget(const MaterialApp(home: GalleryView()));

      for (final role in GlassSurfaceRole.values) {
        _cubitOf(tester).setRole(role);
        await tester.pumpAndSettle();

        expect(
          _surfacesFor(role),
          findsNWidgets(2),
          reason: '${role.name} should be on the stage once per scheme',
        );
        expect(tester.takeException(), isNull, reason: role.name);
      }
    });

    testWidgets('the verdict follows the size across the flip gate',
        (tester) async {
      _useAPhone(tester);
      await tester.pumpWidget(const MaterialApp(home: GalleryView()));
      final resolution = find.byType(GalleryResolutionGroup);

      _cubitOf(tester).setShortSide(52);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: resolution, matching: find.text('flips')),
        findsOneWidget,
      );

      _cubitOf(tester).setShortSide(150);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: resolution, matching: find.text('adapts')),
        findsOneWidget,
        reason: 'past the gate a navigation bar is no longer chrome',
      );
    });

    testWidgets('the roster puts the role it names on the stage',
        (tester) async {
      _useAPhone(tester);
      await tester.pumpWidget(const MaterialApp(home: GalleryView()));

      final row = find.widgetWithText(GalleryRosterRow, 'Control');
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(_surfacesFor(GlassSurfaceRole.control), findsNWidgets(2));
      expect(
        _cubitOf(tester).state.shortSide,
        44,
        reason: 'a control is drawn at the size a control really ships at',
      );
    });
  });
}
