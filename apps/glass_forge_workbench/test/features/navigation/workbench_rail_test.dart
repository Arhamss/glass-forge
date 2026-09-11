import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/features/navigation/presentation/widgets/workbench_rail.dart';
import 'package:glass_forge_workbench/utils/enums/workbench_section.dart';

void main() {
  testWidgets('the rail stays a strip, whatever height it is offered', (
    tester,
  ) async {
    // A Container with an `alignment` and bounded parent constraints expands
    // to fill its parent. This rail's parent is a `bottomNavigationBar`,
    // whose maximum height is the whole screen, so an aligned tab grew to
    // full height and took the rail with it — the app launched showing
    // nothing but a full-height selection pill and no body at all. The same
    // mistake had already shipped once in the backdrop rail, which is why
    // this asserts the property rather than the widget tree.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: WorkbenchRail(
            currentIndex: 1,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final railHeight = tester.getSize(find.byType(WorkbenchRail)).height;
    final screenHeight = tester.getSize(find.byType(Scaffold)).height;

    expect(railHeight, lessThan(screenHeight / 4));
    expect(
      railHeight,
      greaterThanOrEqualTo(44),
      reason: 'the touch target must survive the fix',
    );
  });

  testWidgets('every section is reachable and reports its own index', (
    tester,
  ) async {
    final tapped = <WorkbenchSection>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: WorkbenchRail(
            currentIndex: 0,
            onSelected: tapped.add,
          ),
        ),
      ),
    );

    for (final section in WorkbenchSection.values) {
      await tester.tap(find.text(section.label));
    }
    expect(tapped, WorkbenchSection.values);
  });
}
