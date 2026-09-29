import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/design/glass_backdrop_sampler.dart';
import 'package:glass_forge/src/design/glass_surface.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

const Color _white = Color(0xFFFFFFFF);
const Color _black = Color(0xFF000000);

/// A background whose colour the test can change, and a surface over it.
class _Harness extends StatelessWidget {
  const _Harness({
    required this.background,
    required this.surface,
    this.hysteresis = 0.06,
    this.platformBrightness = Brightness.light,
  });

  final ValueListenable<Color> background;
  final Widget surface;
  final double hysteresis;
  final Brightness platformBrightness;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(platformBrightness: platformBrightness),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: GlassBackdropSampler(
          hysteresis: hysteresis,
          child: Stack(
            children: [
              Positioned.fill(
                child: GlassBackdropSource(
                  child: ValueListenableBuilder<Color>(
                    valueListenable: background,
                    builder: (context, color, _) => ColoredBox(color: color),
                  ),
                ),
              ),
              Positioned.fill(
                child: GlassLayer(child: Center(child: surface)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets a snapshot started in the last frame finish, then builds with it.
Future<void> _settleSample(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

/// A surface small enough to flip, recording the backdrop it built with.
Widget _probe(List<Color?> seen, {Color? backdrop}) {
  return SizedBox(
    width: 120,
    height: 44,
    child: GlassBackdropBuilder(
      backdrop: backdrop,
      builder: (context, backdrop) {
        seen.add(backdrop);
        return const SizedBox.expand();
      },
    ),
  );
}

/// The label colour [text] was given by the surface around it.
Color? _labelOf(WidgetTester tester, String text) =>
    DefaultTextStyle.of(tester.element(find.text(text))).style.color;

/// The label colour the fitted control role gives in [brightness].
Color _labelIn(Brightness brightness) =>
    GlassTheme.fallback.tokens.tint.of(brightness).label;

/// A grey whose relative luminance is [luminance], to within a code value.
Color _greyOf(double luminance) {
  var best = _black;
  for (var v = 0; v < 256; v++) {
    final grey = Color.fromARGB(255, v, v, v);
    if ((grey.computeLuminance() - luminance).abs() <
        (best.computeLuminance() - luminance).abs()) {
      best = grey;
    }
  }
  return best;
}

/// The backdrop luminance at which the fitted scheme choice swaps.
double _flipLuminance() {
  final tints = GlassTheme.fallback.tokens.tint;
  var low = 0.0;
  var high = 1.0;
  for (var i = 0; i < 20; i++) {
    final middle = (low + high) / 2;
    final scheme = tints.schemeFor(_greyOf(middle));
    if (scheme == tints.schemeFor(_black)) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return (low + high) / 2;
}

void main() {
  setUp(() => GlassBackdropSampler.debugSnapshotCount = 0);

  testWidgets('a surface reads the colour of the source beneath it', (
    tester,
  ) async {
    final background = ValueNotifier<Color>(_white);
    addTearDown(background.dispose);
    final seen = <Color?>[];
    await tester.pumpWidget(
      _Harness(background: background, surface: _probe(seen)),
    );
    expect(seen.last, isNull);
    await _settleSample(tester);
    expect(seen.last, _white);
  });

  group('a GlassSurface with no backdrop of its own', () {
    // Sized from outside: a surface resolves against its constraints, and
    // only a small one may flip.
    Widget surface() => const SizedBox(
      width: 80,
      height: 44,
      child: GlassSurface.control(child: Text('label')),
    );

    Widget harness(Color color, Brightness platform) {
      return _Harness(
        background: ValueNotifier<Color>(color),
        platformBrightness: platform,
        surface: surface(),
      );
    }

    testWidgets('over white, flips to the light scheme on a dark platform', (
      tester,
    ) async {
      await tester.pumpWidget(harness(_white, Brightness.dark));
      // Unmeasured, it follows the platform.
      expect(_labelOf(tester, 'label'), _labelIn(Brightness.dark));
      await _settleSample(tester);
      expect(_labelOf(tester, 'label'), _labelIn(Brightness.light));
    });

    testWidgets('over black, flips to the dark scheme on a light platform', (
      tester,
    ) async {
      await tester.pumpWidget(harness(_black, Brightness.light));
      expect(_labelOf(tester, 'label'), _labelIn(Brightness.light));
      await _settleSample(tester);
      expect(_labelOf(tester, 'label'), _labelIn(Brightness.dark));
    });

    testWidgets('an explicit backdrop wins over the sample', (tester) async {
      final background = ValueNotifier<Color>(_white);
      addTearDown(background.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: _Harness(
            background: background,
            surface: const SizedBox(
              width: 80,
              height: 44,
              child: GlassSurface.control(
                backdrop: _black,
                child: Text('label'),
              ),
            ),
          ),
        ),
      );
      await _settleSample(tester);
      // The sample says white, which would keep the light scheme; the
      // explicit black says dark.
      expect(_labelOf(tester, 'label'), _labelIn(Brightness.dark));
    });
  });

  testWidgets('an explicit backdrop is what the builder sees', (
    tester,
  ) async {
    final background = ValueNotifier<Color>(_white);
    addTearDown(background.dispose);
    final seen = <Color?>[];
    await tester.pumpWidget(
      _Harness(
        background: background,
        surface: _probe(seen, backdrop: _black),
      ),
    );
    await _settleSample(tester);
    expect(seen, everyElement(_black));
    // Nothing listening, so nothing snapshotted.
    expect(GlassBackdropSampler.debugSnapshotCount, 0);
  });

  group('throttling', () {
    testWidgets('many repaints inside one window cost one snapshot, and the '
        'last of them is still read when the window closes', (tester) async {
      final background = ValueNotifier<Color>(_white);
      addTearDown(background.dispose);
      final seen = <Color?>[];
      await tester.pumpWidget(
        _Harness(background: background, surface: _probe(seen)),
      );
      await _settleSample(tester);
      expect(GlassBackdropSampler.debugSnapshotCount, 1);

      for (var i = 0; i < 10; i++) {
        background.value = i.isEven ? _black : const Color(0xFF202020);
        await tester.pump(const Duration(milliseconds: 10));
        await _settleSample(tester);
      }
      expect(GlassBackdropSampler.debugSnapshotCount, 1);
      expect(seen.last, _white);

      await tester.pump(const Duration(milliseconds: 200));
      await _settleSample(tester);
      expect(GlassBackdropSampler.debugSnapshotCount, 2);
      expect(seen.last, const Color(0xFF202020));
    });

    testWidgets('a surface repainting over a still source costs no snapshot', (
      tester,
    ) async {
      final background = ValueNotifier<Color>(_white);
      final surfaceTint = ValueNotifier<Color>(_black);
      addTearDown(background.dispose);
      addTearDown(surfaceTint.dispose);
      await tester.pumpWidget(
        _Harness(
          background: background,
          surface: SizedBox(
            width: 120,
            height: 44,
            child: GlassBackdropBuilder(
              builder: (context, backdrop) => ValueListenableBuilder<Color>(
                valueListenable: surfaceTint,
                builder: (context, tint, _) => ColoredBox(color: tint),
              ),
            ),
          ),
        ),
      );
      await _settleSample(tester);
      expect(GlassBackdropSampler.debugSnapshotCount, 1);
      for (var i = 0; i < 5; i++) {
        // Past the window each time, so only the dirty check can refuse.
        await tester.pump(const Duration(seconds: 1));
        surfaceTint.value = Color(0xFF000000 + i);
        await tester.pump();
        await _settleSample(tester);
      }
      expect(GlassBackdropSampler.debugSnapshotCount, 1);
    });
  });

  group('hysteresis', () {
    Future<List<Brightness>> schemesWhileOscillating(
      WidgetTester tester, {
      required double hysteresis,
    }) async {
      final pivot = _flipLuminance();
      final below = _greyOf(pivot - 0.02);
      final above = _greyOf(pivot + 0.02);
      final tints = GlassTheme.fallback.tokens.tint;
      // The two greys really do sit on opposite sides of the flip.
      expect(tints.schemeFor(below), isNot(tints.schemeFor(above)));

      final background = ValueNotifier<Color>(below);
      addTearDown(background.dispose);
      final seen = <Color?>[];
      await tester.pumpWidget(
        _Harness(
          background: background,
          hysteresis: hysteresis,
          surface: _probe(seen),
        ),
      );
      await _settleSample(tester);
      final schemes = <Brightness>[tints.schemeFor(seen.last!)];
      for (var i = 0; i < 6; i++) {
        background.value = i.isEven ? above : below;
        await tester.pump(const Duration(milliseconds: 250));
        await _settleSample(tester);
        schemes.add(tints.schemeFor(seen.last!));
      }
      return schemes;
    }

    testWidgets('a backdrop oscillating inside the band keeps its scheme', (
      tester,
    ) async {
      final schemes = await schemesWhileOscillating(tester, hysteresis: 0.06);
      expect(schemes.toSet(), hasLength(1));
      expect(GlassBackdropSampler.debugSnapshotCount, greaterThan(3));
    });

    testWidgets('without a band the same backdrop flips every time', (
      tester,
    ) async {
      final schemes = await schemesWhileOscillating(tester, hysteresis: 0);
      expect(schemes.toSet(), hasLength(2));
    });
  });

  testWidgets('disposing mid-snapshot neither throws nor leaves work behind', (
    tester,
  ) async {
    final background = ValueNotifier<Color>(_white);
    addTearDown(background.dispose);
    final seen = <Color?>[];
    await tester.pumpWidget(
      _Harness(background: background, surface: _probe(seen)),
    );
    // The first frame's end started a snapshot; tear the tree down before
    // it can complete.
    expect(GlassBackdropSampler.debugSnapshotCount, 1);
    await tester.pumpWidget(const SizedBox());
    await _settleSample(tester);
    expect(tester.takeException(), isNull);
    expect(seen, everyElement(isNull));
  });

  test('the mean ignores what the source did not draw', () {
    // Two pixels: opaque white, and fully transparent.
    final pixels = ByteData(8)
      ..setUint32(0, 0xFFFFFFFF)
      ..setUint32(4, 0);
    expect(
      meanOf(pixels, width: 2, left: 0, top: 0, right: 2, bottom: 1),
      _white,
    );
    // Only the transparent one: less than half covered, so unknown.
    expect(
      meanOf(pixels, width: 2, left: 1, top: 0, right: 2, bottom: 1),
      isNull,
    );
  });
}
