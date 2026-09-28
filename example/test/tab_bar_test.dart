import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/tab_bar.dart';

void main() {
  Future<List<int>> pumpBar(WidgetTester tester) async {
    final picked = <int>[];
    var selected = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GlassLayer(
          child: Center(
            child: StatefulBuilder(
              builder: (context, setState) => GlassTabBar(
                tabs: const [
                  SceneTab('Lens', 'lens'),
                  SceneTab('Liquid', 'liquid'),
                  SceneTab('Kit', 'kit'),
                ],
                selected: selected,
                onSelected: (i) {
                  picked.add(i);
                  setState(() => selected = i);
                },
                presence: kAlwaysCompleteAnimation,
              ),
            ),
          ),
        ),
      ),
    );
    return picked;
  }

  testWidgets('dragging the lens across the bar selects where it lands', (
    tester,
  ) async {
    final picked = await pumpBar(tester);
    final from = tester.getCenter(find.text('Lens'));
    final to = tester.getCenter(find.text('Kit'));
    final gesture = await tester.startGesture(from);
    // In steps, as a finger does, so the drag is recognised and followed.
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Nothing is committed while the finger is still down.
    expect(picked, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(picked, [2]);
  });

  testWidgets('a drag released where it began changes nothing', (
    tester,
  ) async {
    final picked = await pumpBar(tester);
    final from = tester.getCenter(find.text('Lens'));
    final gesture = await tester.startGesture(from);
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(picked, isEmpty);
  });
}
