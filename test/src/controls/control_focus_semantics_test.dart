import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

Widget _onLayer(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: GlassLayer(
    tier: GeometryTier.none,
    child: Center(
      child: SizedBox(width: 300, child: Center(child: child)),
    ),
  ),
);

const List<GlassSegment<int>> _segments = [
  GlassSegment(value: 0, label: Text('Day')),
  GlassSegment(value: 1, label: Text('Week')),
  GlassSegment(value: 2, label: Text('Month')),
];

void main() {
  testWidgets("a switch's focusNode is the one Space toggles through", (
    tester,
  ) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    bool? reported;
    await tester.pumpWidget(
      _onLayer(
        GlassSwitch(
          value: false,
          focusNode: node,
          onChanged: (next) => reported = next,
        ),
      ),
    );
    node.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(reported, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('a switch with autofocus takes focus on insertion', (
    tester,
  ) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      _onLayer(
        GlassSwitch(
          value: false,
          focusNode: node,
          autofocus: true,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(node.hasFocus, isTrue);
  });

  testWidgets("a slider's focusNode and autofocus reach its frame", (
    tester,
  ) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      _onLayer(
        GlassSlider(
          value: 0.5,
          focusNode: node,
          autofocus: true,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(node.hasFocus, isTrue);
  });

  testWidgets('a slider formats its semantic value through '
      'semanticValueFormatter', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _onLayer(
        GlassSlider(
          value: 0.5,
          semanticValueFormatter: (v) => '${(v * 100).round()} percent',
          onChanged: (_) {},
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(GlassSlider)).value,
      '50 percent',
    );
    handle.dispose();
  });

  group('segmented control', () {
    testWidgets('the segments form one named group, each segment in a '
        'mutually exclusive set', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _onLayer(
          GlassSegmentedControl<int>(
            segments: _segments,
            selected: 1,
            semanticLabel: 'Range',
            onChanged: (_) {},
          ),
        ),
      );
      final group = tester.getSemantics(find.bySemanticsLabel('Range'));
      final names = <String>[];
      group.visitChildren((child) {
        final data = child.getSemanticsData();
        names.add(data.label);
        expect(
          data.flagsCollection.isInMutuallyExclusiveGroup,
          isTrue,
          reason: data.label,
        );
        return true;
      });
      expect(names, ['Day', 'Week', 'Month']);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Week'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      handle.dispose();
    });

    testWidgets('autofocus focuses the selected segment', (tester) async {
      int? reported;
      await tester.pumpWidget(
        _onLayer(
          GlassSegmentedControl<int>(
            segments: _segments,
            selected: 1,
            autofocus: true,
            onChanged: (next) => reported = next,
          ),
        ),
      );
      await tester.pump();
      // The right arrow steps on from whichever segment holds focus.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(reported, 2);
      await tester.pumpAndSettle();
    });
  });
}
