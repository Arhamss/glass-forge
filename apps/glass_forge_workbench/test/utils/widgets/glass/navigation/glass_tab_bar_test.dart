import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/constants/asset_paths.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_tab_bar.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_tab_bar_item.dart';

import '../../../../helpers/test_app.dart';

const _items = [
  GlassTabBarItem(
    label: 'Showcase',
    icon: AssetPaths.squaresFour,
    activeIcon: AssetPaths.squaresFourFill,
  ),
  GlassTabBarItem(
    label: 'Components',
    icon: AssetPaths.stack,
    activeIcon: AssetPaths.stackFill,
  ),
  GlassTabBarItem(
    label: 'Material',
    icon: AssetPaths.cube,
    activeIcon: AssetPaths.cubeFill,
  ),
  GlassTabBarItem(
    label: 'Lab',
    icon: AssetPaths.flask,
    activeIcon: AssetPaths.flaskFill,
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required int index,
  required ValueChanged<int> onChanged,
  double textScale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    testApp(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GlassTabBar(
                items: _items,
                currentIndex: index,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tapping a tab reports its index', (tester) async {
    int? picked;
    await _pump(tester, index: 0, onChanged: (i) => picked = i);

    await tester.tap(find.text('Material'));
    await tester.pumpAndSettle();

    expect(picked, 2);
  });

  testWidgets('tapping the current tab reports nothing', (tester) async {
    int? picked;
    await _pump(tester, index: 1, onChanged: (i) => picked = i);

    await tester.tap(find.text('Components'));
    await tester.pumpAndSettle();

    expect(picked, isNull);
  });

  testWidgets('scrubbing commits the tab under the finger on release', (
    tester,
  ) async {
    int? picked;
    await _pump(tester, index: 0, onChanged: (i) => picked = i);

    final start = tester.getCenter(find.text('Showcase'));
    final end = tester.getCenter(find.text('Lab'));
    await tester.dragFrom(start, end - start);
    await tester.pumpAndSettle();

    expect(picked, 3);
  });

  testWidgets('the selected tab is announced as selected', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, index: 1, onChanged: (_) {});

    expect(
      tester.getSemantics(find.text('Components')),
      matchesSemantics(
        label: 'Components',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('fits a 320 pt screen at twice the text size', (tester) async {
    await _pump(
      tester,
      index: 0,
      onChanged: (_) {},
      textScale: 2,
      size: const Size(320, 640),
    );

    expect(tester.takeException(), isNull);
  });
}
