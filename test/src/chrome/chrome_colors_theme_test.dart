// The chrome's painted colours — the sheet scrim, the grab handle — come
// from the theme's `GlassTokens.chrome`, and the defaults are the colours
// the chrome drew before that token existed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/chrome/glass_sheet_handle.dart';

const Color _scrim = Color(0x80102030);
const Color _handle = Color(0xFFFF9500);

const ValueKey<String> _openKey = ValueKey('open');

/// A page under [chrome] with a button that shows a glass sheet.
Future<void> _showSheet(
  WidgetTester tester, {
  GlassChromeColors chrome = const GlassChromeColors(),
}) async {
  await tester.pumpWidget(
    // Tier off: nothing here is about the matte, and a sliding sheet
    // rebakes it every frame on the CPU off Impeller.
    GlassTierScope(
      requested: GlassTier.off,
      child: GlassTheme(
        data: GlassThemeData(tokens: GlassTokens(chrome: chrome)),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: GestureDetector(
                key: _openKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => showGlassSheet<void>(
                  context: context,
                  builder: (context) => const SizedBox(height: 200),
                ),
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(_openKey));
  await tester.pumpAndSettle();
}

/// The colour the scrim is drawn at, at full strength.
Color? _scrimColor(WidgetTester tester) => tester
    .widgetList<ModalBarrier>(find.byType(ModalBarrier))
    .map((barrier) => barrier.color)
    .whereType<Color>()
    .single;

/// The grab handle's colour.
Color _handleColor(WidgetTester tester) =>
    tester.widget<GlassSheetHandle>(find.byType(GlassSheetHandle)).color;

/// A detent sheet under [chrome].
Widget _detentSheet(GlassChromeColors chrome) => GlassTheme(
  data: GlassThemeData(tokens: GlassTokens(chrome: chrome)),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(400, 800)),
      child: GlassLayer(
        tier: GeometryTier.none,
        // Not const: the sheet asserts on its detents' length.
        child: Stack(
          children: <Widget>[
            GlassDetentSheet(
              detents: const <GlassDetent>[
                GlassDetent.fraction(0.2),
                GlassDetent.fraction(0.5),
              ],
              child: const SizedBox.expand(),
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  test('the defaults are the colours the chrome drew before', () {
    const chrome = GlassChromeColors();
    expect(chrome.scrim, const Color(0x52000000));
    expect(chrome.handle, isNull);
    expect(const GlassTokens().chrome, chrome);
  });

  test('GlassChromeColors is a value, and a GlassTokens field', () {
    expect(
      const GlassChromeColors(scrim: _scrim, handle: _handle),
      const GlassChromeColors().copyWith(scrim: _scrim, handle: _handle),
    );
    expect(
      const GlassChromeColors(handle: _handle).hashCode,
      const GlassChromeColors(handle: _handle).hashCode,
    );
    expect(
      const GlassTokens(),
      isNot(const GlassTokens(chrome: GlassChromeColors(scrim: _scrim))),
    );
    expect(
      const GlassTokens().copyWith(
        chrome: const GlassChromeColors(scrim: _scrim),
      ),
      const GlassTokens(chrome: GlassChromeColors(scrim: _scrim)),
    );
  });

  group('showGlassSheet', () {
    testWidgets('dims with the default scrim and a label-coloured handle', (
      tester,
    ) async {
      await _showSheet(tester);
      expect(_scrimColor(tester), const Color(0x52000000));
      final label = DefaultTextStyle.of(
        tester.element(find.byType(GlassSheetHandle)),
      ).style.color;
      expect(label, isNotNull);
      expect(_handleColor(tester), label);
    });

    testWidgets('takes the scrim and handle from the theme', (tester) async {
      await _showSheet(
        tester,
        chrome: const GlassChromeColors(scrim: _scrim, handle: _handle),
      );
      expect(_scrimColor(tester), _scrim);
      expect(_handleColor(tester), _handle);
    });
  });

  group('GlassDetentSheet', () {
    testWidgets('draws its handle in the label colour by default', (
      tester,
    ) async {
      await tester.pumpWidget(_detentSheet(const GlassChromeColors()));
      final label = DefaultTextStyle.of(
        tester.element(find.byType(GlassSheetHandle)),
      ).style.color;
      expect(_handleColor(tester), label);
      expect(_handleColor(tester), isNot(_handle));
    });

    testWidgets('takes its handle colour from the theme', (tester) async {
      await tester.pumpWidget(
        _detentSheet(const GlassChromeColors(handle: _handle)),
      );
      expect(_handleColor(tester), _handle);
    });
  });
}
