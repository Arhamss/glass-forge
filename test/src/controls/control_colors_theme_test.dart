// The controls take their own colours — the switch's accent, the painted
// knob, thumb and pill, the slider's fill, the focus ring — from the theme's
// `GlassTokens.controls`, and nothing in them hard-codes a colour.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

/// A material that renders nothing, so the composite pass is skipped.
const GlassMaterial _inert = GlassMaterial(
  frost: 0,
  edgeRefraction: 0,
  highlight: 0,
);

const Color _green = Color(0xFF34C759);
const Color _darkGreen = Color(0xFF30D158);
const Color _white = Color(0xFFFFFFFF);

const Color _accent = Color(0xFFFF2D55);
const Color _knob = Color(0xFF202020);
const Color _fill = Color(0xFF5856D6);
const Color _focus = Color(0xFFFF9500);

const GlassControlColors _custom = GlassControlColors(
  accent: _accent,
  knob: _knob,
  fill: _fill,
  focus: _focus,
);

/// [child] on glass (so knobs, thumbs and pills are painted, not glass),
/// under a theme pinned to [brightness] with [controls].
Widget _harness(
  Widget child, {
  GlassControlPalette controls = const GlassControlPalette(),
  Brightness brightness = Brightness.light,
}) {
  return GlassTheme(
    data: GlassThemeData(
      brightness: brightness,
      tokens: GlassTokens(controls: controls),
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: GlassLayer(
        tier: GeometryTier.none,
        material: _inert,
        child: SizedBox(
          width: 300,
          height: 200,
          child: Glass(
            shape: const GlassRoundedRectangle(
              radius: BorderRadius.all(Radius.circular(20)),
            ),
            child: Center(child: SizedBox(width: 240, child: child)),
          ),
        ),
      ),
    ),
  );
}

/// Every flat colour painted by a `DecoratedBox` under [control].
Set<Color> _painted(WidgetTester tester, Type control) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(control),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((box) => (box.decoration as BoxDecoration).color)
    .whereType<Color>()
    .toSet();

Widget _switch({Color? activeTrackColor}) => Align(
  alignment: Alignment.centerLeft,
  child: GlassSwitch(
    value: true,
    activeTrackColor: activeTrackColor,
    onChanged: (_) {},
  ),
);

Widget _slider() => GlassSlider(value: 0.5, onChanged: (_) {});

Widget _segmented() => GlassSegmentedControl<int>(
  segments: const [
    GlassSegment(value: 0, label: Text('A')),
    GlassSegment(value: 1, label: Text('B')),
  ],
  selected: 0,
  onChanged: (_) {},
);

void main() {
  group('defaults are the colours the controls used to hard-code', () {
    test('tokens', () {
      expect(GlassControlColors.appleLight.accent, _green);
      expect(GlassControlColors.appleDark.accent, _darkGreen);
      expect(GlassControlColors.appleLight.knob, _white);
      expect(GlassControlColors.appleDark.knob, _white);
      expect(GlassControlColors.appleLight.fill, isNull);
      expect(GlassControlColors.appleLight.focus, isNull);
      expect(const GlassTokens().controls, const GlassControlPalette());
    });

    testWidgets('switch track and knob, light and dark', (tester) async {
      await tester.pumpWidget(_harness(_switch()));
      expect(_painted(tester, GlassSwitch), {_green, _white});

      await tester.pumpWidget(
        _harness(_switch(), brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester, GlassSwitch), {_darkGreen, _white});
    });

    testWidgets('slider thumb is white, fill is the label colour', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(_slider()));
      final label = GlassTheme.surfaceOf(
        tester.element(find.byType(GlassSlider)),
        GlassSurfaceRole.control,
        size: const Size(240, 28),
      ).labelColor;
      expect(
        _painted(tester, GlassSlider),
        containsAll(<Color>[_white, label]),
      );
    });

    testWidgets('segmented pill is white under a black label', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(_segmented()));
      expect(_painted(tester, GlassSegmentedControl<int>), contains(_white));
      final style = DefaultTextStyle.of(tester.element(find.text('A'))).style;
      expect(style.color, GlassTintRamp.appleLight.label);
    });
  });

  group('a theme override recolours the control', () {
    const palette = GlassControlPalette(light: _custom);

    testWidgets('switch: accent track, knob', (tester) async {
      await tester.pumpWidget(_harness(_switch(), controls: palette));
      expect(_painted(tester, GlassSwitch), {_accent, _knob});
    });

    testWidgets('slider: fill and thumb', (tester) async {
      await tester.pumpWidget(_harness(_slider(), controls: palette));
      final painted = _painted(tester, GlassSlider);
      expect(painted, containsAll(<Color>[_fill, _knob]));
      expect(painted, isNot(contains(_white)));
    });

    testWidgets('segmented control: pill, and a label that reads on it', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(_segmented(), controls: palette));
      expect(_painted(tester, GlassSegmentedControl<int>), contains(_knob));
      expect(
        _painted(tester, GlassSegmentedControl<int>),
        isNot(contains(_white)),
      );
      // A near-black pill takes the scheme label that reads on it: white.
      final style = DefaultTextStyle.of(tester.element(find.text('A'))).style;
      expect(style.color, GlassTintRamp.appleDark.label);
    });

    testWidgets('focus ring', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        _harness(
          Align(
            alignment: Alignment.centerLeft,
            child: GlassSwitch(
              value: false,
              focusNode: node,
              onChanged: (_) {},
            ),
          ),
          controls: palette,
        ),
      );
      // The focus manager applies a request in a microtask. The test
      // binding's pump draws no frame unless one was already scheduled, so
      // apply it first: the ring must then be on the very next frame.
      node.requestFocus();
      FocusManager.instance.applyFocusChangesIfNeeded();
      await tester.pump();
      expect(
        tester.renderObject(find.byType(GlassSwitch)),
        paints..rrect(style: PaintingStyle.stroke, color: _focus),
      );
    });

    testWidgets('the dark scheme reads the dark entry', (tester) async {
      await tester.pumpWidget(
        _harness(
          _switch(),
          controls: const GlassControlPalette(dark: _custom),
          brightness: Brightness.dark,
        ),
      );
      expect(_painted(tester, GlassSwitch), {_accent, _knob});
    });

    testWidgets('a per-widget activeTrackColor beats the theme', (
      tester,
    ) async {
      const own = Color(0xFF007AFF);
      await tester.pumpWidget(
        _harness(_switch(activeTrackColor: own), controls: palette),
      );
      expect(_painted(tester, GlassSwitch), {own, _knob});
    });
  });

  test('GlassControlColors and GlassControlPalette are values', () {
    expect(
      GlassControlColors.appleLight.copyWith(accent: _accent),
      const GlassControlColors(accent: _accent),
    );
    expect(
      _custom.hashCode,
      _custom.copyWith().hashCode,
    );
    expect(_custom, isNot(_custom.copyWith(knob: _white)));
    const palette = GlassControlPalette(dark: _custom);
    expect(palette.of(Brightness.dark), _custom);
    expect(palette.of(Brightness.light), GlassControlColors.appleLight);
    expect(
      const GlassControlPalette().copyWith(dark: _custom),
      palette,
    );
    expect(
      const GlassTokens().copyWith(controls: palette),
      isNot(const GlassTokens()),
    );
  });
}
