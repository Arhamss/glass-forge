import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/catalogue/catalogue.dart';
import 'package:glass_forge_example/src/catalogue/snippet.dart';
import 'package:glass_forge_example/src/theme.dart';

/// Every snippet the catalogue prints, compiled.
///
/// The detail page shows the Dart that produces the specimen beside it, and
/// the copy button hands the reader that whole string — so a snippet naming
/// a constructor that does not exist is a paste that does not build. That
/// has happened in this package before: `GlassShape.capsule()`, which never
/// existed, sat in shipped doc comments long enough to be copied into an
/// implementation plan. `test/readme_examples_test.dart` at the package
/// root is the same guard over README and `lib/` doc comments; this is that
/// guard over the 33 catalogue entries, which are the larger surface,
/// because every one of them is a thing a reader is invited to paste.
///
/// **This file is a second copy, and nothing here makes the compiler read
/// an entry's own `code` closure.** Change a `code` closure, leave its
/// mirror below alone, and every test in this file still compiles and still
/// passes while proving nothing about the string the app now prints. Dart
/// cannot read its own source text, so there is no way to hand the real
/// snippet to the compiler. Keep the two in lockstep: change a snippet in
/// `example/lib/src/catalogue/entries/`, change its mirror here.
///
/// The last test, `every symbol a snippet names is named here too`, narrows
/// that gap without closing it. It renders all 33 snippets through
/// [renderSnippet], strips their comments and string literals, pulls every
/// capitalised identifier out of what is left, and fails if one of those
/// names appears nowhere in this file's own text. A `code` closure that
/// starts emitting `GlassShape.capsule()` therefore fails that test, and
/// the only way to satisfy it is to write that name here — where the
/// compiler rejects it. What it does not cover: argument names, argument
/// values, nesting, and a symbol *dropped* from a snippet; and the match is
/// file-wide rather than per entry, so a name some other entry already uses
/// satisfies it. It catches new phantoms, not silent divergence.
///
/// Where a snippet names something only the running app has — `facts`,
/// `places`, `controller`, `context` — the mirror substitutes a real
/// equivalent so it actually compiles, exactly as the README guard does.
void main() {
  // -- Surfaces ------------------------------------------------------------

  testWidgets('Surfaces | Glass', (tester) async {
    await _pumpGlass(
      tester,
      Glass(
        shape: const GlassSuperellipse(
          radius: BorderRadius.all(Radius.circular(40)),
        ),
        clipBehavior: _knob(Clip.antiAlias),
        child: const ColoredBox(color: Color(0x33FFFFFF)),
      ),
    );
  });

  testWidgets('Surfaces | GlassLayer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          material: GlassMaterial(variant: _knob(GlassVariant.regular)),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Glass(shape: GlassOval()),
              Glass(shape: GlassOval()),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Surfaces | GlassMaterial', (tester) async {
    await _pumpGlass(
      tester,
      Builder(
        builder: (context) => Glass(
          shape: const GlassSuperellipse(
            radius: BorderRadius.all(Radius.circular(40)),
          ),
          material: GlassMaterial.regular(
            brightness: GlassTheme.brightnessOf(context),
          ),
        ),
      ),
    );
  });

  testWidgets('Surfaces | GlassVariant', (tester) async {
    await _pumpGlass(
      tester,
      Glass(
        shape: const GlassSuperellipse(
          radius: BorderRadius.all(Radius.circular(40)),
        ),
        material: GlassMaterial(
          variant: _knob(GlassVariant.regular),
          tintOpacity: _knob(0.3),
        ),
      ),
    );
  });

  testWidgets('Surfaces | GlassProfile', (tester) async {
    await _pumpGlass(
      tester,
      Glass(
        shape: const GlassSuperellipse(
          radius: BorderRadius.all(Radius.circular(40)),
        ),
        material: GlassMaterial(
          profile: _knob(GlassProfile.edgeBand),
          edgeRefraction: _knob(40),
        ),
      ),
    );
  });

  testWidgets('Surfaces | Material knobs', (tester) async {
    // The entry prints a bare `GlassMaterial(...)`; it is put on a `Glass`
    // here so the values are laid out and painted rather than only typed.
    await _pumpGlass(
      tester,
      Glass(
        shape: const GlassOval(),
        material: GlassMaterial(
          edgeRefraction: _knob(27.42),
          frost: _knob(5),
          tintOpacity: _knob(0),
          saturation: _knob(1),
          highlight: _knob(1),
          contour: _knob(0),
          thickness: _knob(12),
          chromaticAberration: _knob(0),
        ),
      ),
    );
  });

  // -- Shapes --------------------------------------------------------------

  testWidgets('Shapes | GlassRoundedRectangle', (tester) async {
    await _pumpGlass(
      tester,
      Glass(
        shape: GlassRoundedRectangle(
          radius: BorderRadius.all(Radius.circular(_knob(32))),
        ),
      ),
    );
  });

  testWidgets('Shapes | GlassOval', (tester) async {
    await _pumpGlass(
      tester,
      SizedBox(
        width: _knob(200),
        height: 160,
        child: const Glass(shape: GlassOval()),
      ),
    );
  });

  testWidgets('Shapes | GlassSuperellipse', (tester) async {
    await _pumpGlass(
      tester,
      Glass(
        shape: GlassSuperellipse(
          radius: BorderRadius.all(Radius.circular(_knob(40))),
        ),
      ),
    );
  });

  testWidgets('Shapes | GlassBlendGroup', (tester) async {
    await _pumpGlass(
      tester,
      GlassBlendGroup(
        blend: _knob(28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(
              dimension: 120,
              child: Glass(shape: GlassOval()),
            ),
            SizedBox(width: _knob(40)),
            const SizedBox.square(
              dimension: 120,
              child: Glass(shape: GlassOval()),
            ),
          ],
        ),
      ),
    );
  });

  // -- Motion --------------------------------------------------------------

  testWidgets('Motion | InteractiveGlass', (tester) async {
    await _pumpGlass(
      tester,
      InteractiveGlass(
        pressScale: _knob(0.96),
        child: const Glass(
          shape: GlassSuperellipse(
            radius: BorderRadius.all(Radius.circular(46)),
          ),
        ),
      ),
    );
  });

  testWidgets('Motion | GlassJiggle', (tester) async {
    await _pumpGlass(
      tester,
      InteractiveGlass(
        drag: const GlassDrag(overdrag: GlassOverdrag(limit: 96)),
        jiggle: GlassJiggle(maxStretch: _knob(1.18)),
        child: const Glass(
          shape: GlassSuperellipse(
            radius: BorderRadius.all(Radius.circular(46)),
          ),
        ),
      ),
    );
  });

  testWidgets('Motion | GlassPressStretch', (tester) async {
    await _pumpGlass(
      tester,
      InteractiveGlass(
        pressStretch: GlassPressStretch(
          intensity: _knob(0.50),
          squash: _knob(0.30),
          travel: _knob(0.15),
        ),
        child: const Glass(
          shape: GlassSuperellipse(
            radius: BorderRadius.all(Radius.circular(46)),
          ),
        ),
      ),
    );
  });

  testWidgets('Motion | GlassOverdrag', (tester) async {
    await _pumpGlass(
      tester,
      InteractiveGlass(
        drag: GlassDrag(
          overdrag: GlassOverdrag(
            limit: _knob(56),
            resistance: _knob(0.55),
          ),
        ),
        child: const Glass(
          shape: GlassSuperellipse(
            radius: BorderRadius.all(Radius.circular(46)),
          ),
        ),
      ),
    );
  });

  testWidgets('Motion | GlassDecay', (tester) async {
    await _pumpGlass(
      tester,
      InteractiveGlass(
        drag: GlassDrag(
          returnsHome: _knob(false),
          decay: GlassDecay(drag: _knob(0.135)),
        ),
        child: const Glass(
          shape: GlassSuperellipse(
            radius: BorderRadius.all(Radius.circular(46)),
          ),
        ),
      ),
    );
  });

  testWidgets('Motion | GlassMotion', (tester) async {
    await _pumpGlass(
      tester,
      InteractiveGlass(
        drag: const GlassDrag(overdrag: GlassOverdrag(limit: 96)),
        settleMotion: _knob(const GlassMotion.bouncy()),
        child: const Glass(
          shape: GlassSuperellipse(
            radius: BorderRadius.all(Radius.circular(46)),
          ),
        ),
      ),
    );
  });

  testWidgets('Motion | GlassReduceMotion', (tester) async {
    await _pumpGlass(
      tester,
      InteractiveGlass(
        pressStretch: _knob(
          const GlassPressStretch(
            intensity: 0.6,
            squash: 0.4,
            travel: 0.18,
          ),
        ),
        child: const Glass(
          shape: GlassSuperellipse(
            radius: BorderRadius.all(Radius.circular(46)),
          ),
        ),
      ),
    );
  });

  // -- Composition ---------------------------------------------------------

  testWidgets('Composition | GlassPresence', (tester) async {
    await _pumpGlass(
      tester,
      GlassPresence(
        presence: AlwaysStoppedAnimation<double>(_knob(1)),
        child: const Glass(
          shape: GlassSuperellipse(
            radius: BorderRadius.all(Radius.circular(40)),
          ),
        ),
      ),
    );
  });

  testWidgets('Composition | GlassHostScope', (tester) async {
    // `control` stands for the caller's own control — the snippet writes the
    // same conditional out twice, once on content and once inside the
    // toolbar, because that is what the reader pastes in two places.
    Widget control(BuildContext context) => GlassHostScope.isOnGlass(context)
        ? SizedBox.square(
            dimension: 96,
            child: ColoredBox(color: context.inkFill),
          )
        : SizedBox.square(
            dimension: 96,
            child: Glass(
              shape: GlassRoundedRectangle(
                radius: BorderRadius.all(
                  Radius.circular(_knob(20)),
                ),
              ),
            ),
          );

    await _pumpGlass(
      tester,
      Row(
        children: [
          Builder(builder: control),
          SizedBox.square(
            dimension: 160,
            child: Glass(
              shape: const GlassSuperellipse(
                radius: BorderRadius.all(Radius.circular(32)),
              ),
              child: Center(child: Builder(builder: control)),
            ),
          ),
        ],
      ),
    );
  });

  testWidgets('Composition | GlassGlow', (tester) async {
    await _pumpGlass(
      tester,
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox.square(
            dimension: 120,
            child: InteractiveGlass(
              child: Glass(
                shape: GlassRoundedRectangle(
                  radius: BorderRadius.all(Radius.circular(24)),
                ),
              ),
            ),
          ),
          SizedBox(width: _knob(40)),
          const SizedBox.square(
            dimension: 120,
            child: InteractiveGlass(
              child: Glass(
                shape: GlassRoundedRectangle(
                  radius: BorderRadius.all(Radius.circular(24)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  });

  testWidgets('Composition | Cross-pass overlap', (tester) async {
    // This one overlaps two glass shapes on purpose. `RenderGlassLayer`
    // warns through `debugPrint` rather than throwing, so there is still no
    // exception to take.
    await _pumpGlass(
      tester,
      Stack(
        children: [
          const Positioned(
            left: 0,
            child: SizedBox.square(
              dimension: 100,
              child: Glass(shape: GlassOval()),
            ),
          ),
          Positioned(
            left: _knob(30),
            child: const SizedBox.square(
              dimension: 100,
              child: Glass(
                shape: GlassOval(),
                material: GlassMaterial(
                  variant: GlassVariant.clear,
                  frost: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  });

  // -- Chrome --------------------------------------------------------------

  testWidgets('Chrome | GlassDetentSheet', (tester) async {
    final controller = GlassDetentSheetController(vsync: const TestVSync());
    addTearDown(controller.dispose);
    // `lowest` and `span` are the sheet's own resolved heights in the app;
    // two plain numbers stand in for them here.
    const lowest = 74.4;
    const span = 173.6;
    await _pumpGlass(
      tester,
      Stack(
        children: [
          GlassPresence(
            presence: controller.presenceUnder(
              start: lowest + 0.125 * span,
              end: lowest + 0.25 * span,
            ),
            child: const GlassSurface.navigationBar(child: _tabs),
          ),
          GlassDetentSheet(
            detents: const [
              GlassDetent.fraction(0.30),
              GlassDetent.fraction(0.62),
              GlassDetent.fraction(1),
            ],
            controller: controller,
            bottomGap: _knob(48),
            semanticLabel: 'Nearby places',
            child: ListView(children: _places),
          ),
        ],
      ),
    );
  });

  test('Chrome | GlassDetent', () {
    final heights =
        <GlassDetent>[
              const GlassDetent.fraction(0.5),
              const GlassDetent.height(180),
              const GlassDetent.content(),
            ]
            .map(
              (detent) => detent.resolve(
                available: _knob(200),
                contentHeight: _knob(96),
              ),
            )
            .toList();
    expect(heights, <double>[100, 180, 96]);
  });

  testWidgets('Chrome | GlassDetentSheetController', (tester) async {
    final controller = GlassDetentSheetController(vsync: const TestVSync());
    addTearDown(controller.dispose);

    await _pumpGlass(
      tester,
      GlassDetentSheet(
        detents: const [
          GlassDetent.fraction(0.3),
          GlassDetent.fraction(0.62),
          GlassDetent.fraction(1),
        ],
        controller: controller,
        initialDetent: _knob(0),
        semanticLabel: 'Nearby places',
        child: ListView(children: _places),
      ),
    );

    // Afterwards, from anywhere holding the controller:
    controller.animateToDetent(0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chrome | GlassSheetScrollPhysics', (tester) async {
    // Both positions of the entry's one knob: the sheet's own physics
    // reaching the list, and a list that names its own and opts out.
    for (final physics in <ScrollPhysics?>[
      null,
      const BouncingScrollPhysics(),
    ]) {
      await _pumpGlass(
        tester,
        GlassDetentSheet(
          detents: const [
            GlassDetent.fraction(0.45),
            GlassDetent.fraction(1),
          ],
          semanticLabel: 'Nearby places',
          child: ListView(physics: physics, children: _places),
        ),
      );
    }
  });

  // -- Design system -------------------------------------------------------

  testWidgets('Design system | GlassTheme', (tester) async {
    await _pumpGlass(
      tester,
      GlassTheme(
        data: _knob(const GlassThemeData()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _knob(84),
              child: const GlassSurface.card(child: _cardBody),
            ),
            SizedBox(height: _knob(14)),
            SizedBox(
              height: _knob(44),
              child: const GlassSurface.control(child: _controlLabel),
            ),
          ],
        ),
      ),
    );
  });

  testWidgets('Design system | GlassSurface', (tester) async {
    await _pumpGlass(
      tester,
      const SizedBox(
        width: 216,
        height: 96,
        child: GlassSurface.card(
          backdrop: Color(0xFF29364C),
          child: _facts,
        ),
      ),
    );
  });

  testWidgets('Design system | GlassTokens', (tester) async {
    await _pumpGlass(
      tester,
      GlassTheme(
        data: GlassThemeData(
          tokens: GlassTokens(
            blur: GlassBlurScale(thick: _knob(14)),
            radius: GlassRadiusScale(extraLarge: _knob(44)),
          ),
        ),
        child: const GlassSurface.sheet(child: _facts),
      ),
    );
  });

  testWidgets('Design system | GlassTintStep', (tester) async {
    await _pumpGlass(
      tester,
      GlassTheme(
        data: GlassThemeData(
          surfaces: GlassSurfaces(
            card: GlassSurfaceSpec.card.copyWith(
              tint: _knob(GlassTintStep.regular),
            ),
          ),
        ),
        child: const GlassSurface.card(child: _facts),
      ),
    );
  });

  test('Design system | GlassLegibility', () {
    const backdrop = Color(0xFF29364C);
    const tints = GlassTints();

    final ramp = tints.of(Brightness.light);

    final opacity = GlassLegibility.opacityForContrast(
      tint: ramp.color,
      backdrop: backdrop,
      label: ramp.label,
      target: _knob(4.5),
      floor: ramp.legible,
      ceiling: ramp.opaque,
    );
    expect(opacity, inInclusiveRange(ramp.legible, ramp.opaque));
  });

  // -- Adaptation ----------------------------------------------------------

  testWidgets('Adaptation | GlassTierScope', (tester) async {
    final engine = GlassTierEngine(
      requested: _knob(null),
      capabilities: const RenderCapabilities(
        shaderFilters: true,
        backend: GraphicsBackend.metal,
        acceleratedGeometry: true,
        complete: true,
      ),
    );
    addTearDown(engine.dispose);

    await _pumpGlass(
      tester,
      GlassTierScope(
        engine: engine,
        child: Glass(
          material: GlassMaterial.dome(),
          shape: GlassSuperellipse(
            radius: BorderRadius.all(Radius.circular(_knob(28))),
          ),
          child: _facts,
        ),
      ),
    );
  });

  testWidgets('Adaptation | GlassTierEngine', (tester) async {
    // This is the one snippet that starts an engine, and starting one asks
    // the host for its thermal and accessibility readings. A widget test has
    // no host, so the two event channels are answered here — the device the
    // snippet is written for, stood in for like any other caller-side thing.
    _answerPlatformChannels();

    final engine = GlassTierEngine(
      requested: _knob(null),
      capabilities: const RenderCapabilities(
        shaderFilters: true,
        backend: GraphicsBackend.metal,
        acceleratedGeometry: true,
        complete: true,
      ),
    );
    addTearDown(engine.dispose);
    // The snippet writes a bare `await engine.start();`, which is what a
    // caller in an async context writes. It is run through `runAsync` here
    // because `start` waits on the thermal and accessibility channels, and
    // a channel reply never lands inside a widget test's fake clock.
    await tester.runAsync(engine.start);

    await _pumpGlass(
      tester,
      GlassTierScope(
        engine: engine,
        child: const GlassSurface.card(
          backdrop: Color(0xFF29364C),
          child: _facts,
        ),
      ),
    );
  });

  testWidgets('Adaptation | GeometryTier', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          tier: _knob(GeometryTier.accelerated),
          material: GlassMaterial.dome(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _bands,
              Center(
                child: SizedBox(
                  width: _knob(184),
                  height: _knob(90),
                  child: Glass(
                    shape: GlassSuperellipse(
                      radius: BorderRadius.all(
                        Radius.circular(_knob(22)),
                      ),
                    ),
                    child: _facts,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  // -- The tie back to the entries -----------------------------------------

  test('every symbol a snippet names is named here too', () {
    final mirror = File('test/snippet_compiles_test.dart');
    expect(
      mirror.existsSync(),
      isTrue,
      reason:
          'this test reads its own file, so it has to run from the example '
          'package root; ${Directory.current.path} is not it',
    );
    // Comments off, and this file's own prose with them. The first draft
    // compared against the whole file and passed a deliberately broken
    // snippet, because the header above names `GlassShape.capsule()` while
    // explaining it — a mention is not a thing the compiler has read.
    final source = _withoutComments(mirror.readAsStringSync());

    final missing = <String, Set<String>>{};
    final silent = <String>[];
    var entryCount = 0;
    for (final group in catalogueGroups) {
      for (final entry in entriesIn(group)) {
        entryCount++;
        final named = _symbolsIn(renderSnippet(entry));
        if (named.isEmpty) {
          silent.add('${entry.group} | ${entry.api}');
        }
        final unnamed = named
            .where((symbol) => !source.contains(symbol))
            .toSet();
        if (unnamed.isNotEmpty) {
          missing['${entry.group} | ${entry.api}'] = unnamed;
        }
      }
    }

    expect(entryCount, 33, reason: 'every entry has to be mirrored');
    // Without this, a `_symbolsIn` that quietly matched nothing would leave
    // `missing` empty and the whole check would pass by asking nothing.
    expect(
      silent,
      isEmpty,
      reason:
          'these snippets yielded no symbol at all, which is what a broken '
          'extractor looks like from here',
    );
    expect(
      missing,
      isEmpty,
      reason:
          'each of these names is printed by a catalogue snippet and appears '
          'nowhere in this file, so nothing has compiled it — mirror the '
          'snippet above and let the compiler judge the name',
    );
  });
}

/// Pumps [child] the way the catalogue does: inside a [GlassLayer], which is
/// what every `Glass` in these snippets is drawn into.
Future<void> _pumpGlass(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: GlassLayer(child: child)));
  expect(tester.takeException(), isNull);
}

/// Answers the plugin's two event channels with nothing, for the length of
/// the calling test.
///
/// Without this, `GlassTierEngine.start` reaches a host that is not there
/// and the `MissingPluginException` it raises is what the test would be
/// reading instead of the snippet.
void _answerPlatformChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in const <String>[
    'glass_forge/thermal',
    'glass_forge/reduce_transparency',
  ]) {
    final channel = MethodChannel(name);
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }
}

/// A value the entry page's controls supply.
///
/// Returned through a function rather than written as a literal so the
/// mirror keeps the argument the snippet shows. A literal equal to the
/// parameter's own default is a redundant argument, and deleting it to
/// satisfy the analyzer would delete the name this file exists to compile.
T _knob<T>(T value) => value;

/// Stand-ins for the widgets a caller brings. The snippets name `facts`,
/// `places`, `tabs`, `bands`, `cardBody` and `controlLabel`; none of them is
/// part of this package's API, and what they hold does not change what the
/// surrounding call has to compile to.
const Widget _facts = SizedBox.shrink();
const Widget _cardBody = SizedBox.shrink();
const Widget _controlLabel = SizedBox.shrink();
const Widget _tabs = SizedBox(height: 48);
const Widget _bands = SizedBox.expand();
const List<Widget> _places = <Widget>[SizedBox(height: 40)];

/// [source] with every `//` comment taken off, line by line.
String _withoutComments(String source) => source
    .split('\n')
    .map((line) {
      final comment = line.indexOf('//');
      return comment == -1 ? line : line.substring(0, comment);
    })
    .join('\n');

/// Every capitalised identifier [snippet] names, dotted member included.
///
/// Comments come off first, so the prose in a snippet's own notes is not
/// mistaken for code; string literals come off second, because by then the
/// only apostrophes left are the ones that open and close a string.
Set<String> _symbolsIn(String snippet) {
  final code = _withoutComments(
    snippet,
  ).replaceAll(RegExp("'[^']*'"), '').replaceAll(RegExp('"[^"]*"'), '');
  return RegExp(r'\b[A-Z][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?\b')
      .allMatches(code)
      .map((match) => match[0]!)
      .toSet();
}
