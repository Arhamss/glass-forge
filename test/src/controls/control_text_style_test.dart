import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

/// The style `MaterialApp` hands a `WidgetsApp` in debug mode: what text
/// with no `Material` above it draws in. A control's own labels must not
/// show it.
const TextStyle _debugFallback = TextStyle(
  color: Color(0xD0FF0000),
  fontFamily: 'monospace',
  fontSize: 48,
  fontWeight: FontWeight.w900,
  decoration: TextDecoration.underline,
  decorationColor: Color(0xFFFFFF00),
  decorationStyle: TextDecorationStyle.double,
);

/// [child], [width] wide, in a bare `WidgetsApp` — no Material, no
/// Cupertino, no scaffold — whose text style is [textStyle], if any.
Widget _app(Widget child, {double width = 300, TextStyle? textStyle}) {
  return GlassTierScope(
    requested: GlassTier.off,
    child: WidgetsApp(
      color: const Color(0xFF000000),
      textStyle: textStyle,
      builder: (context, _) => GlassLayer(
        tier: GeometryTier.none,
        child: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

const List<GlassSegment<int>> _sizes = [
  GlassSegment(value: 0, label: Text('Compact')),
  GlassSegment(value: 1, label: Text('Regular')),
  GlassSegment(value: 2, label: Text('Roomy')),
];

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text));

void main() {
  for (final textStyle in <TextStyle?>[null, _debugFallback]) {
    final where = textStyle == null ? 'no text style' : 'the debug fallback';

    testWidgets('segment labels are 13 pt under $where', (tester) async {
      await tester.pumpWidget(
        _app(
          GlassSegmentedControl<int>(
            segments: _sizes,
            selected: 1,
            onChanged: (_) {},
          ),
          textStyle: textStyle,
        ),
      );

      for (final label in ['Compact', 'Regular', 'Roomy']) {
        final paragraph = _paragraph(tester, label);
        final style = paragraph.text.style!;
        expect(style.fontSize, 13, reason: label);
        expect(style.decoration, TextDecoration.none, reason: label);
      }
      expect(
        _paragraph(tester, 'Regular').text.style!.fontWeight,
        FontWeight.w600,
      );
      expect(
        _paragraph(tester, 'Compact').text.style!.fontWeight,
        FontWeight.w400,
      );
    });

    testWidgets('a 300-wide control shows whole labels under $where', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          GlassSegmentedControl<int>(
            segments: _sizes,
            selected: 1,
            onChanged: (_) {},
          ),
          textStyle: textStyle,
        ),
      );

      expect(tester.takeException(), isNull);
      for (final label in ['Compact', 'Regular', 'Roomy']) {
        final paragraph = _paragraph(tester, label);
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        // Laid out on one line, as wide as the whole label wants.
        final full = TextPainter(
          text: paragraph.text,
          textDirection: TextDirection.ltr,
          textScaler: paragraph.textScaler,
        )..layout();
        expect(paragraph.size.width, greaterThanOrEqualTo(full.width));
        expect(paragraph.size.height, lessThanOrEqualTo(full.height));
        full.dispose();
      }
    });

    testWidgets('a text field placeholder is not underlined under $where', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const GlassTextField(placeholder: 'Name'),
          textStyle: textStyle,
        ),
      );

      final style = _paragraph(tester, 'Name').text.style!;
      expect(style.decoration, TextDecoration.none);
      expect(style.fontSize, 17);
    });
  }

  testWidgets("segment labels keep the app's font family", (tester) async {
    await tester.pumpWidget(
      _app(
        DefaultTextStyle(
          style: const TextStyle(fontFamily: 'Geist', fontSize: 30),
          child: GlassSegmentedControl<int>(
            segments: _sizes,
            selected: 1,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final style = _paragraph(tester, 'Compact').text.style!;
    expect(style.fontFamily, 'Geist');
    expect(style.fontSize, 13);
  });
}
