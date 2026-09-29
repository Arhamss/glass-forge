import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

/// [child] at the top of a 400-wide column, at a text scale of [scale].
Widget _at(double scale, Widget child) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => GlassLayer(
            tier: GeometryTier.none,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(width: 400, child: child),
            ),
          ),
        ),
      ],
    ),
  ),
);

/// The laid-out height of the text in [finder]'s paragraph — its lines,
/// not the box it was squeezed into.
double _lineHeight(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderParagraph>(finder).textSize.height;

void main() {
  for (final scale in [1.0, 2.0, 3.0, 5.0]) {
    testWidgets('segmented control at ${scale}x: labels fit the pill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _at(
          scale,
          GlassSegmentedControl<int>(
            segments: const [
              GlassSegment(
                value: 0,
                label: Text('Day', style: TextStyle(fontSize: 13)),
              ),
              GlassSegment(
                value: 1,
                label: Text('Week', style: TextStyle(fontSize: 13)),
              ),
            ],
            selected: 0,
            onChanged: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final control = tester.getRect(find.byType(GlassSegmentedControl<int>));
      final text = tester.getRect(find.text('Week'));
      expect(text.top, greaterThanOrEqualTo(control.top));
      expect(text.bottom, lessThanOrEqualTo(control.bottom));
      // The test font's line is exactly its size: 13 pt, scaled up to 1.5.
      expect(
        _lineHeight(tester, find.text('Week')),
        closeTo(13 * (scale < 1.5 ? scale : 1.5), 1),
      );
    });

    testWidgets('app bar at ${scale}x: the title fits the bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _at(
          scale,
          const GlassAppBar(
            title: Text('Title', style: TextStyle(fontSize: 17)),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final bar = tester.getRect(find.byType(GlassAppBar));
      final text = tester.getRect(find.text('Title'));
      expect(text.top, greaterThanOrEqualTo(bar.top));
      expect(text.bottom, lessThanOrEqualTo(bar.bottom));
      expect(
        _lineHeight(tester, find.text('Title')),
        closeTo(17 * (scale < 1.5 ? scale : 1.5), 1),
      );
    });

    testWidgets('text field at ${scale}x: the field grows around its text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _at(scale, const GlassTextField(placeholder: 'Search')),
      );
      expect(tester.takeException(), isNull);
      final field = tester.getRect(find.byType(GlassTextField));
      final editable = tester.getRect(find.byType(EditableText));
      expect(field.height, greaterThanOrEqualTo(44));
      expect(editable.top, greaterThanOrEqualTo(field.top));
      expect(editable.bottom, lessThanOrEqualTo(field.bottom));
      // 17 pt text, scaled without a cap: the field's job is to hold it.
      expect(editable.height, greaterThanOrEqualTo(17 * scale - 1));
    });
  }
}
