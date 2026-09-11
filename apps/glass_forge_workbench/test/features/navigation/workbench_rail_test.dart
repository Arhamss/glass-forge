import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/navigation/presentation/widgets/workbench_rail.dart';
import 'package:glass_forge_workbench/features/navigation/presentation/widgets/workbench_rail_tab.dart';
import 'package:glass_forge_workbench/utils/enums/workbench_section.dart';

void main() {
  group('WorkbenchRail', () {
    testWidgets('reports the section behind the tab that was tapped',
        (tester) async {
      final tapped = <WorkbenchSection>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: WorkbenchRail(
              currentIndex: 0,
              onSelected: tapped.add,
            ),
          ),
        ),
      );

      expect(
        find.byType(WorkbenchRailTab),
        findsNWidgets(WorkbenchSection.values.length),
      );

      for (final section in WorkbenchSection.values) {
        await tester.tap(find.widgetWithText(WorkbenchRailTab, section.label));
      }

      expect(tapped, WorkbenchSection.values);
    });

    testWidgets('marks exactly the section on screen as selected',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: WorkbenchRail(
              currentIndex: WorkbenchSection.tiers.index,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      final selected = tester
          .widgetList<WorkbenchRailTab>(find.byType(WorkbenchRailTab))
          .where((tab) => tab.isSelected)
          .toList();

      expect(selected, hasLength(1));
      expect(selected.single.section, WorkbenchSection.tiers);
    });

    testWidgets('every tab clears the 44pt touch target', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: WorkbenchRail(
              currentIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      for (final section in WorkbenchSection.values) {
        final size = tester.getSize(
          find.widgetWithText(WorkbenchRailTab, section.label),
        );
        expect(size.height, greaterThanOrEqualTo(44), reason: section.label);
        expect(size.width, greaterThanOrEqualTo(44), reason: section.label);
      }
    });
  });
}
