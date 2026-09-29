import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

const Color _black = Color(0xFF000000);

Widget _light(Widget child) => MediaQuery(
  data: const MediaQueryData(),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: GlassLayer(tier: GeometryTier.none, child: child),
  ),
);

/// The colour a surface of [size] resolves its label to over black, as
/// `GlassSurface` would for a control that really is that size.
Color _expected(WidgetTester tester, Finder at, Size size) =>
    GlassTheme.surfaceOf(
      tester.element(at),
      GlassSurfaceRole.control,
      size: size,
      backdrop: _black,
    ).labelColor;

void main() {
  testWidgets(
    'a small button in a list resolves its label for its own size, not the '
    "list's unbounded height",
    (tester) async {
      await tester.pumpWidget(
        _light(
          ListView(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GlassButton(
                  onPressed: () {},
                  backdrop: _black,
                  child: const Text('Go'),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      final label = find.text('Go');
      final size = tester.getSize(find.byType(Glass));
      expect(
        DefaultTextStyle.of(tester.element(label)).style.color,
        _expected(tester, label, size),
      );
    },
  );

  testWidgets('a button bigger than the flip limit resolves for its '
      'measured size', (tester) async {
    await tester.pumpWidget(
      _light(
        Center(
          child: GlassButton(
            onPressed: () {},
            backdrop: _black,
            child: const SizedBox(
              width: 200,
              height: 200,
              child: Text('Big'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final label = find.text('Big');
    final size = tester.getSize(find.byType(Glass));
    expect(size.shortestSide, greaterThan(96));
    expect(
      DefaultTextStyle.of(tester.element(label)).style.color,
      _expected(tester, label, size),
    );
  });
}
