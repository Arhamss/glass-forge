import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

/// The style `MaterialApp` hands a `WidgetsApp` in debug mode: what text
/// with no `Material` above it draws in. Glass pages must not show it.
const TextStyle _debugFallback = TextStyle(
  color: Color(0xD0FF0000),
  fontFamily: 'monospace',
  fontSize: 48,
  fontWeight: FontWeight.w900,
  decoration: TextDecoration.underline,
  decorationColor: Color(0xFFFFFF00),
  decorationStyle: TextDecorationStyle.double,
);

/// [home] in a bare `WidgetsApp` — no Material, no Cupertino — whose only
/// text style is [_debugFallback].
Widget _app(Widget home) {
  return GlassTierScope(
    requested: GlassTier.off,
    child: WidgetsApp(
      color: const Color(0xFF000000),
      textStyle: _debugFallback,
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, _) => builder(context),
      ),
      home: home,
    ),
  );
}

/// A widget that records the text style in effect where it is built.
class _Probe extends StatelessWidget {
  const _Probe(this.name, this.styles);

  final String name;
  final Map<String, TextStyle> styles;

  @override
  Widget build(BuildContext context) {
    styles[name] = DefaultTextStyle.of(context).style;
    return Text(name);
  }
}

void _expectRealStyle(TextStyle? style) {
  expect(style, isNotNull);
  expect(style!.decoration, TextDecoration.none);
  expect(style.fontFamily, isNot('monospace'));
  expect(style.fontSize, 17);
  expect(style.color, isNotNull);
  expect(style.color, isNot(_debugFallback.color));
}

void main() {
  testWidgets('a scaffold gives its body and bars a real text style', (
    tester,
  ) async {
    final styles = <String, TextStyle>{};
    await tester.pumpWidget(
      _app(
        GlassScaffold(
          background: const ColoredBox(color: Color(0xFFFFFFFF)),
          topBar: GlassAppBar(title: _Probe('title', styles)),
          bottomBar: SizedBox(height: 44, child: _Probe('bottom', styles)),
          body: Center(child: _Probe('body', styles)),
        ),
      ),
    );

    _expectRealStyle(styles['body']);
    _expectRealStyle(styles['bottom']);
    _expectRealStyle(styles['title']);
    // Light scheme, over plain content: the theme's black label.
    expect(styles['body']!.color, const Color(0xFF000000));
    // iOS's navigation title is semibold.
    expect(styles['title']!.fontWeight, FontWeight.w600);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showGlassSheet content has a real text style', (tester) async {
    final styles = <String, TextStyle>{};
    late BuildContext pageContext;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            pageContext = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );

    unawaited(
      showGlassSheet<void>(
        context: pageContext,
        builder: (context) =>
            SizedBox(height: 120, child: _Probe('sheet', styles)),
      ),
    );
    await tester.pumpAndSettle();

    _expectRealStyle(styles['sheet']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GlassDetentSheet content has a real text style', (
    tester,
  ) async {
    final styles = <String, TextStyle>{};
    await tester.pumpWidget(
      _app(
        GlassLayer(
          tier: GeometryTier.none,
          child: GlassDetentSheet(
            detents: const [
              GlassDetent.fraction(0.3),
              GlassDetent.fraction(1),
            ],
            child: _Probe('detent', styles),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    _expectRealStyle(styles['detent']);
    expect(tester.takeException(), isNull);
  });
}
