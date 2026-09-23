import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/backdrop_info.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';
import 'package:glass_forge_example/src/theme.dart';

/// The Adaptation group: the scope every glass layer takes its tier from,
/// the engine that resolves that tier out of four signals, and the one
/// axis of the resulting profile a layer can pin for itself.
///
/// Three entries, and they read in order. `GlassTierScope` is the whole
/// consumer-facing surface — one widget around an app, and every
/// `GlassLayer` beneath it degrades on its own. `GlassTierEngine` is what
/// is inside it: `RenderCapabilities`, `ThermalSignal`, `FrameWatchdog`
/// and `AccessibilitySignalSource`, four objects with four lifecycles,
/// collapsed by `resolveTier` into one `ResolvedTier`. `GeometryTier` is
/// the axis of that verdict a caller is most likely to overrule by hand,
/// because it is the one whose cost they can know in advance.
///
/// `ResolvedTier`, `GlassTier` and `TierProfile` get no entries of their
/// own. None of the three is something a caller *writes*: a consumer hands
/// `GlassTier` to `requested:` and reads the other two back off the scope,
/// so they are named in the copy and printed on the specimens below rather
/// than claiming rows of their own.
final List<CatalogueEntry> adaptationEntries = <CatalogueEntry>[
  _glassTierScope,
  _glassTierEngine,
  _geometryTier,
];

/// The photograph the whole catalogue sits over, and the colours measured
/// off it.
///
/// The same sample the Chrome and Design system groups use. Everything here
/// that supplies a `backdrop`, or paints a colour behind glass, takes it
/// from this one record rather than naming a hex nobody measured.
final BackdropInfo _backdrop = backdropFor(catalogueBackdropPhoto);

/// How wide every specimen in this file is.
const double _panelWidth = 216;

/// How far a panel's facts sit from its top and bottom edges.
///
/// Named on its own as well as folded into [_panelPadding] because the
/// specimen heights below are `const` arithmetic over it, and
/// `EdgeInsets.vertical` is an instance getter no constant expression can
/// reach.
const double _panelInsetY = 12;

/// The inset between a panel's edge and the facts printed on it.
const EdgeInsets _panelPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: _panelInsetY,
);

/// How tall one [_Fact] row is: the label's own line box, plus its top
/// padding.
///
/// Stated rather than measured, because every specimen here is a
/// doubly-tight `SizedBox` — `_EntryRow`'s `FittedBox` hands a thumbnail
/// unbounded width, so a root that sized itself from its children would
/// never lay out — and a panel's height is then this number times its rows.
const double _factHeight = 19;

/// How tall a [_PanelTitle]'s line box is.
///
/// `context.label` is 13 points on a 17-point line, and the style states
/// that height explicitly, so this is the same number under Geist and under
/// the square fallback a widget test renders with.
const double _titleHeight = 17;

/// The allowance every stated panel height below carries over the content
/// it was measured from.
///
/// A height fitted exactly to its rows overflows the moment anything adds a
/// point — a reader scaling text up, a font whose line box rounds the other
/// way — and an overflow inside a specimen is a red-and-yellow bar across
/// the catalogue rather than a layout that merely looks tight.
const double _panelSlack = 8;

/// The capability report the scope specimen pins, and the first of the
/// three the engine specimen offers.
///
/// Pinned rather than measured, and this file is the one place in the
/// catalogue that constructs a [RenderCapabilities] by hand. A real app
/// never does:
/// `RenderCapabilityProbe` measures it once per process, after the first
/// frame. The catalogue pins it so that the tier ladder these three entries
/// demonstrate is the same ladder on every device the catalogue runs on —
/// including a `flutter test` run, where
/// `ui.ImageFilter.isShaderFilterSupported` is false and *every* tier would
/// otherwise resolve to [GlassTier.off].
const RenderCapabilities _fullCapabilities = RenderCapabilities(
  shaderFilters: true,
  backend: GraphicsBackend.metal,
  acceleratedGeometry: true,
  complete: true,
);

/// A colour as the Dart literal a snippet would quote.
///
/// Derived from the value rather than typed beside it: every colour in this
/// file comes out of [backdrops], and a hand-written hex is one edit away
/// from describing a photograph nobody is looking at.
String _hex(Color color) =>
    '0x${color.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}';

/// [material] as the Dart literal a snippet would quote.
///
/// Matched against the calls `GlassMaterial` exposes rather than typed
/// beside the value, for the reason [_hex] gives one line up: every
/// specimen in this file is built with `_backdrop.material`, and a literal
/// `GlassMaterial.dome()` written into a snippet goes on saying dome long
/// after the material it claims to describe has moved.
///
/// Throws rather than guessing. A material this cannot name is one no
/// snippet here can quote truthfully, and the group's own "every entry's
/// code is non-empty" test is where that shows up — in a test run, rather
/// than in front of a reader.
String _materialCode(GlassMaterial material) {
  final named = <GlassMaterial, String>{
    const GlassMaterial(): 'const GlassMaterial()',
    GlassMaterial.dome(): 'GlassMaterial.dome()',
    GlassMaterial.clear(): 'GlassMaterial.clear()',
    GlassMaterial.regular(brightness: Brightness.dark):
        'GlassMaterial.regular(brightness: Brightness.dark)',
    GlassMaterial.regular(brightness: Brightness.light):
        'GlassMaterial.regular(brightness: Brightness.light)',
  };
  final code = named[material];
  if (code == null) {
    throw UnsupportedError(
      'no GlassMaterial call names $material — add it here before a '
      'backdrop is measured with it, or no snippet can quote it',
    );
  }
  return code;
}

/// [capabilities] as the Dart literal a snippet would quote, with every
/// line after the first carrying [indent].
String _capabilitiesCode(RenderCapabilities capabilities, String indent) {
  return 'const RenderCapabilities(\n'
      '$indent  shaderFilters: ${capabilities.shaderFilters},\n'
      '$indent  backend: GraphicsBackend.${capabilities.backend.name},\n'
      '$indent  acceleratedGeometry: '
      '${capabilities.acceleratedGeometry},\n'
      '$indent  complete: ${capabilities.complete},\n'
      '$indent)';
}

/// A field name on the left, what it resolved to on the right.
///
/// Lifted from the Design system group's own `_Fact` rather than shared with
/// it: these names run long — `accessibility` is thirteen characters — and
/// a row of two intrinsically-sized `Text`s overflows the moment the font
/// changes, which it does between the app's Geist and the square fallback a
/// widget test renders with.
class _Fact extends StatelessWidget {
  const _Fact(this.name, this.value);

  /// What the package calls it.
  final String name;

  /// What it came out as here.
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.label.copyWith(color: context.inkSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.mono,
          ),
        ],
      ),
    );
  }
}

/// The heading on a specimen — the verdict, in the surface's own ink.
class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.label,
    );
  }
}

/// A painted strip carrying a caption across the bottom of a bare [Glass].
///
/// Painted, and painted *inside* the glass rather than beside it. A
/// `GlassSurface` would have resolved a tint that keeps its own labels
/// readable; a raw `Glass` makes no such promise, and the dome preset in
/// particular has no frost at all, so a label on it is a label on the
/// photograph. [Tone.captionScrim] is what closes that gap, and it is the
/// only legal way to close it — a second piece of glass on top of the first
/// is the one composition this renderer refuses.
class _CaptionStrip extends StatelessWidget {
  const _CaptionStrip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ColoredBox(
        color: Tone.captionScrim,
        child: Padding(padding: _panelPadding, child: child),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GlassTierScope
// ---------------------------------------------------------------------------

/// The knob's five positions, spelled the way a caller says them.
///
/// `auto` is the pin left null, which is the default and the case an app is
/// normally in: nothing pinned, and the four signals decide. The other four
/// are [GlassTier]'s own member names. The specimen sets the pin through
/// [GlassTierEngine.requested] rather than [GlassTierScope.requested],
/// because a scope handed an engine takes its instructions from whoever
/// owns it — see the entry's own note on why this one owns an engine.
///
/// [GlassTier.off] is deliberately not among them. It is not a rung on the
/// ladder — `GlassTier.lowered` will never step there — but the honest
/// answer on a backend where `ui.ImageFilter.shader` throws, and a segment
/// whose whole result is an empty box teaches nothing the `GlassTierEngine`
/// entry's `skia` capability report does not teach better.
const List<String> _requestNames = <String>[
  'auto',
  'full',
  'balanced',
  'reduced',
  'flat',
];

/// The [GlassTier] each position pins, or null for `auto`.
GlassTier? _tierFor(String name) => switch (name) {
  'full' => GlassTier.full,
  'balanced' => GlassTier.balanced,
  'reduced' => GlassTier.reduced,
  'flat' => GlassTier.flat,
  _ => null,
};

/// How tall the scope specimen is.
///
/// The caption strip plus enough clear glass above it to see a dome as a
/// dome. Three facts and a title in the strip; the rest is the specimen.
const double _scopeHeight = 168;

/// The corner radius of the scope specimen's silhouette.
const double _scopeRadius = 28;

/// What the scope resolved, and what that leaves the glass around it
/// rendering with.
///
/// [ResolvedTier.materialFor] is the same call `Glass` makes internally on
/// an overridden material, run a second time here so the two numbers under
/// the verdict are the ones this very shape is being drawn with rather than
/// a description of them.
class _ScopeFacts extends StatelessWidget {
  const _ScopeFacts({required this.material});

  /// The material the specimen asked for, before the tier took its cut.
  final GlassMaterial material;

  @override
  Widget build(BuildContext context) {
    final resolved = GlassTierScope.of(context);
    final effective = resolved.materialFor(
      material,
      brightness:
          MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light,
    );
    return _CaptionStrip(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle('tier ${resolved.tier.name}'),
          _Fact('geometry', resolved.geometry.name),
          _Fact('dome', resolved.dome ? 'kept' : 'flat'),
          _Fact(
            'edgeRefraction',
            effective.edgeRefraction.toStringAsFixed(1),
          ),
        ],
      ),
    );
  }
}

/// The scope, its engine, and the one piece of glass that adopts it.
///
/// Stateful because an engine is a `ChangeNotifier` with a lifecycle: it
/// owns three live signals and has to be disposed, which a `build` function
/// returning a widget cannot do. Moving the knob sets
/// [GlassTierEngine.requested] on the engine already in scope rather than
/// building a second one — re-creating it would restart the frame watchdog
/// and the two platform channels on every tap.
class _ScopeSpecimen extends StatefulWidget {
  const _ScopeSpecimen({required this.requested, required this.material});

  /// The tier pinned on the engine, or null to let the signals decide.
  final GlassTier? requested;

  /// The material the specimen's glass asks for.
  final GlassMaterial material;

  @override
  State<_ScopeSpecimen> createState() => _ScopeSpecimenState();
}

class _ScopeSpecimenState extends State<_ScopeSpecimen> {
  late final GlassTierEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = GlassTierEngine(
      requested: widget.requested,
      capabilities: _fullCapabilities,
    );
    // Fire-and-forget, exactly as `GlassTierScope` starts an engine it owns
    // itself: every signal's value is already valid before it starts, so
    // the first build renders a real tier rather than waiting on a channel.
    unawaited(_engine.start());
  }

  @override
  void didUpdateWidget(_ScopeSpecimen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requested != widget.requested) {
      _engine.requested = widget.requested;
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassTierScope(
      engine: _engine,
      child: Glass(
        material: widget.material,
        shape: const GlassSuperellipse(
          radius: BorderRadius.all(Radius.circular(_scopeRadius)),
        ),
        child: _ScopeFacts(material: widget.material),
      ),
    );
  }
}

/// **One widget around an app, and every layer beneath it degrades.**
///
/// That is the whole consumer-facing surface of the tier system. A
/// `GlassLayer` under a scope adopts both halves of the verdict — the
/// geometry producer it may run and the material it may render — and a
/// `Glass` that overrides its layer's material has that override degraded
/// too, because the accessibility half of a tier is not a preference to opt
/// out of. With no scope above it, nothing is adopted and a layer renders
/// exactly what it was given, which is why tiering costs an app that never
/// asked for it nothing at all.
///
/// The knob is [GlassTierScope.requested] in every position but the first,
/// and the first is what an app normally ships: nothing pinned, four
/// signals deciding. A pin beats capability, heat and frame health; it does
/// not beat accessibility, and it cannot lift a backend that cannot run the
/// shader. The `GlassTierEngine` entry is where both of those are visible.
///
/// **Why the specimen hands the scope an engine instead of writing
/// `GlassTierScope(requested: ...)`.** An engine built here can be given a
/// [RenderCapabilities] report, and one that the scope builds for itself
/// cannot. Left to measure, the report is whatever the reader's device
/// answers — which on a `flutter test` run is "no shader filters", and
/// every rung of this knob would resolve to [GlassTier.off]. The pin is the
/// only thing separating a ladder from a flat line; see [_fullCapabilities].
final CatalogueEntry _glassTierScope = CatalogueEntry(
  api: 'GlassTierScope',
  purpose:
      'One resolved tier in scope, adopted by every glass layer beneath '
      'it — and the rung a caller can pin instead.',
  group: 'Adaptation',
  knobs: <Knob<Object?>>[
    Knob<String>(
      name: 'requested',
      value: _requestNames.first,
      options: _requestNames,
    ),
  ],
  build: (knobs) {
    final name = knobs[0].value! as String;
    return SizedBox(
      width: _panelWidth,
      height: _scopeHeight,
      child: _ScopeSpecimen(
        requested: _tierFor(name),
        material: _backdrop.material,
      ),
    );
  },
  code: (knobs) {
    final name = knobs[0].value! as String;
    final tier = _tierFor(name);
    final requested = tier == null
        ? 'requested: null, // auto: the four signals decide'
        : 'requested: GlassTier.${tier.name},';
    return 'final engine = GlassTierEngine(\n'
        '  $requested\n'
        '  // Pinned so the catalogue resolves the same tier wherever it\n'
        '  // runs. An app leaves this out and lets RenderCapabilityProbe\n'
        '  // measure it.\n'
        '  capabilities: ${_capabilitiesCode(_fullCapabilities, '  ')},\n'
        ');\n'
        '\n'
        'GlassTierScope(\n'
        '  engine: engine,\n'
        '  child: Glass(\n'
        '    material: ${_materialCode(_backdrop.material)},\n'
        '    shape: const GlassSuperellipse(\n'
        '      radius: BorderRadius.all(Radius.circular($_scopeRadius)),\n'
        '    ),\n'
        '    child: facts,\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>[
    'GlassTierEngine',
    'GeometryTier',
    'GlassLayer',
    'GlassMaterial',
  ],
);

// ---------------------------------------------------------------------------
// GlassTierEngine
// ---------------------------------------------------------------------------

/// The three capability reports the engine specimen chooses between.
///
/// Constructed, not measured — see [_fullCapabilities] — and chosen because
/// they are the three answers `resolveTier`'s capability ceiling can give.
/// `shaderFilters` and `acceleratedGeometry` are what decide it; the
/// [GraphicsBackend] on each one labels the device shape the package
/// expects to meet that pair on, and is itself diagnostic — the resolver
/// never reads it.
const Map<GraphicsBackend, RenderCapabilities> _capabilityReports =
    <GraphicsBackend, RenderCapabilities>{
      GraphicsBackend.metal: _fullCapabilities,
      GraphicsBackend.openGLES: RenderCapabilities(
        shaderFilters: true,
        backend: GraphicsBackend.openGLES,
        acceleratedGeometry: false,
        complete: true,
      ),
      GraphicsBackend.skia: RenderCapabilities(
        shaderFilters: false,
        backend: GraphicsBackend.skia,
        acceleratedGeometry: false,
        complete: true,
      ),
    };

/// The backends the knob offers, in ceiling order: full, balanced, off.
const List<GraphicsBackend> _backends = <GraphicsBackend>[
  GraphicsBackend.metal,
  GraphicsBackend.openGLES,
  GraphicsBackend.skia,
];

/// The second knob's positions: no pin, the top rung, the bottom rung.
///
/// Two rungs and `auto` are enough to show both halves of what a pin does.
/// `full` on the `openGLES` report lifts a ceiling that capability imposed
/// and on the `skia` report does not lift one it cannot; `flat` pins a rung
/// *below* every ceiling, which is the direction nothing else here moves.
const List<String> _engineRequestNames = <String>['auto', 'full', 'flat'];

/// How tall the engine specimen is.
///
/// A title and seven facts, the panel's own vertical padding, and
/// [_panelSlack]. Stated, for the reason [_factHeight] gives.
const double _engineHeight =
    _titleHeight + 7 * _factHeight + 2 * _panelInsetY + _panelSlack;

/// Every input the engine had, and the one verdict they resolved to.
///
/// [ResolvedTier] keeps each signal's ceiling beside the answer rather than
/// discarding it once consulted, which is what makes "why is this device at
/// `reduced`?" a question with an answer. All seven rows come off the one
/// [GlassTierEngine.value] this entry's scope is publishing.
class _EngineFacts extends StatelessWidget {
  const _EngineFacts({required this.capabilities});

  /// The report the engine was built with, printed so the two booleans the
  /// capability ceiling is actually read from are visible.
  final RenderCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final resolved = GlassTierScope.of(context);
    return Padding(
      padding: _panelPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle('tier ${resolved.tier.name}'),
          _Fact('requested', resolved.requested?.name ?? 'none'),
          _Fact('shaderFilters', '${capabilities.shaderFilters}'),
          _Fact(
            'acceleratedGeometry',
            '${capabilities.acceleratedGeometry}',
          ),
          _Fact('capabilityCeiling', resolved.capabilityCeiling.name),
          _Fact('thermalCeiling', resolved.thermalCeiling.name),
          _Fact('accessibility', resolved.accessibilityCeiling.name),
          _Fact('frameSteps', '-${resolved.frameSteps}'),
        ],
      ),
    );
  }
}

/// The engine, the scope it publishes through, and the card it renders on.
///
/// The engine is rebuilt when the capability report changes and kept when
/// only the pin does, because [RenderCapabilities] is a constructor
/// argument — a measured fact about a device, which nothing revisits — while
/// [GlassTierEngine.requested] is a setter, because pinning a rung is
/// something a settings screen does at any time.
class _EngineSpecimen extends StatefulWidget {
  const _EngineSpecimen({
    required this.capabilities,
    required this.requested,
  });

  /// The capability report the engine is built with.
  final RenderCapabilities capabilities;

  /// The tier pinned on it, or null.
  final GlassTier? requested;

  @override
  State<_EngineSpecimen> createState() => _EngineSpecimenState();
}

class _EngineSpecimenState extends State<_EngineSpecimen> {
  late GlassTierEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = _start();
  }

  GlassTierEngine _start() {
    final engine = GlassTierEngine(
      requested: widget.requested,
      capabilities: widget.capabilities,
    );
    unawaited(engine.start());
    return engine;
  }

  @override
  void didUpdateWidget(_EngineSpecimen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.capabilities != widget.capabilities) {
      _engine.dispose();
      _engine = _start();
      return;
    }
    if (oldWidget.requested != widget.requested) {
      _engine.requested = widget.requested;
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassTierScope(
      engine: _engine,
      // A card rather than a painted panel: it resolves its own label
      // colour against the measured backdrop, and being glass it is itself
      // degraded by the verdict printed on it. On the `skia` report that
      // shows — `GlassTier.off` renders nothing, and the facts are left
      // standing on the photograph, which is the honest picture of what
      // that report costs.
      child: GlassSurface.card(
        backdrop: _backdrop.panelBackdrop,
        child: _EngineFacts(capabilities: widget.capabilities),
      ),
    );
  }
}

/// **Four signals, four lifecycles, one verdict.**
///
/// The engine owns [RenderCapabilities] — measured once, by
/// `RenderCapabilityProbe`, after the first frame — and three live ones:
/// [ThermalSignal], [FrameWatchdog] and [AccessibilitySignalSource]. Each is
/// a separate object rather than a field, so a bug in one can be found
/// without a device and a bug in the combination can be found without any of
/// them. The engine starts them, listens, and hands the result to
/// `resolveTier`.
///
/// **They do not combine the same way, and that is the whole entry.**
/// Capability, heat and accessibility each impose an absolute *ceiling* —
/// each is a statement about the device or the user, true whatever tier the
/// app happened to be at. Frame health steps down *relatively*, because it
/// is a statement about the current workload rather than about the device:
/// it moves down from wherever the ceilings already put things.
///
/// **And a pin does not beat all four.** `requested` beats capability, heat
/// and frame health. It does **not** beat accessibility, because Reduce
/// Transparency and Increase Contrast are correctness requirements and a
/// developer lifting them would be lifting them on their users' behalf. Nor
/// does it lift a backend where `ui.ImageFilter.shader` throws, which is not
/// a preference either — pin `full` on the `skia` report and the verdict
/// stays [GlassTier.off].
///
/// The two live signals this catalogue cannot move are still live here:
/// `thermalCeiling` and `accessibility` are read off the reader's own
/// device, and both read `full` on a machine that is cool and has neither
/// setting on. That is why a reader needs to be told what those two rows
/// mean before a permanently-`full` one reads as a broken knob — and why
/// the asymmetry is stated in this entry's `purpose` and in its snippet's
/// comment slot rather than here. Nothing in this comment reaches the app:
/// a [CatalogueEntry] has no prose field beyond `purpose`, so `///` here is
/// for whoever maintains the entry, never for whoever reads it.
final CatalogueEntry _glassTierEngine = CatalogueEntry(
  api: 'GlassTierEngine',
  purpose:
      'Four signals — capabilities, heat, frame health and accessibility '
      '— resolved to one tier, and the pin that overrules the first '
      'three but never the last.',
  group: 'Adaptation',
  knobs: <Knob<Object?>>[
    Knob<GraphicsBackend>(
      name: 'capabilities',
      value: _backends.first,
      options: _backends,
    ),
    Knob<String>(
      name: 'requested',
      value: _engineRequestNames.first,
      options: _engineRequestNames,
    ),
  ],
  build: (knobs) {
    final backend = knobs[0].value! as GraphicsBackend;
    final requested = knobs[1].value! as String;
    return SizedBox(
      width: _panelWidth,
      height: _engineHeight,
      child: _EngineSpecimen(
        capabilities: _capabilityReports[backend]!,
        requested: _tierFor(requested),
      ),
    );
  },
  code: (knobs) {
    final backend = knobs[0].value! as GraphicsBackend;
    final capabilities = _capabilityReports[backend]!;
    final tier = _tierFor(knobs[1].value! as String);
    final requested = tier == null
        ? 'requested: null, // nothing pinned'
        : 'requested: GlassTier.${tier.name},';
    return 'final engine = GlassTierEngine(\n'
        '  $requested\n'
        '  // The other three signals are built and owned by the engine:\n'
        '  // a ThermalSignal, a FrameWatchdog and an\n'
        '  // AccessibilitySignalSource, each injectable the same way.\n'
        '  // All three are live, which is why their ceilings do not move\n'
        '  // with the knobs above — and why a pin never lifts the\n'
        '  // accessibility one.\n'
        '  //\n'
        '  // This report is written out. An app omits it and lets\n'
        '  // RenderCapabilityProbe measure one after the first frame.\n'
        '  capabilities: ${_capabilitiesCode(capabilities, '  ')},\n'
        ');\n'
        'await engine.start();\n'
        '\n'
        'GlassTierScope(\n'
        '  engine: engine, // the host owns it, so the host disposes it\n'
        '  child: GlassSurface.card(\n'
        '    backdrop: const Color(${_hex(_backdrop.panelBackdrop)}),\n'
        '    child: facts,\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>[
    'GlassTierScope',
    'RenderCapabilities',
    'ThermalSignal',
    'FrameWatchdog',
    // The source object the engine owns and this snippet's own comment
    // names, not the immutable `AccessibilitySignals` reading it hands
    // out. Both are real symbols; only one of them is what `accessibility`
    // takes.
    'AccessibilitySignalSource',
  ],
);

// ---------------------------------------------------------------------------
// GeometryTier
// ---------------------------------------------------------------------------

/// How tall the geometry specimen is.
const double _geometryHeight = 156;

/// How wide the glass shape inside it is.
const double _geometryShapeWidth = 184;

/// How tall that shape is.
///
/// Enough for the caption strip with [_panelSlack] over it, and no more:
/// what the reader is here to watch is the band line behind the shape, so
/// the shape should not cover more of it than it has to.
const double _geometryShapeHeight =
    _titleHeight + _factHeight + 2 * _panelInsetY + _panelSlack + 22;

/// The corner radius of that shape.
const double _geometryRadius = 22;

/// The tier that baked this shape's matte, and whether one was baked.
class _GeometryFacts extends StatelessWidget {
  const _GeometryFacts({required this.tier});

  final GeometryTier tier;

  @override
  Widget build(BuildContext context) {
    return _CaptionStrip(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(tier.name),
          _Fact(
            'matte',
            tier == GeometryTier.none ? 'not baked' : 'baked',
          ),
        ],
      ),
    );
  }
}

/// **The one axis of a verdict a layer may overrule for itself.**
///
/// `GlassTier` is five rungs; `TierProfile` is the dozen axes a rung moves;
/// [GeometryTier] is the single axis of it that says how much work may go
/// into baking the matte — the signed-distance field that gives a glass
/// shape its silhouette. It is the axis with the cost a caller can know in
/// advance, which is why `GlassLayer.tier` exists to pin it and nothing pins
/// the rest.
///
/// Pinning is a *producer* decision, not a material one: a layer that pins
/// [GeometryTier.portable] still has its material degraded by whatever the
/// enclosing `GlassTierScope` resolved, because the accessibility half of
/// that degradation is not a preference to opt out of.
///
/// **What the reader should watch is `none`.** The other two bake the same
/// matte by different routes and look alike by design — that is the point of
/// a portable fallback. `none` bakes nothing, and with no coverage the
/// composite pass has nothing to cut the effect to, so it blurs the layer's
/// whole rectangle instead of a rounded rectangle inside it. The two
/// measured bands behind the shape are what make that visible: at
/// `accelerated` and `portable` only the silhouette disturbs the line
/// between them, and at `none` the whole specimen does.
final CatalogueEntry _geometryTier = CatalogueEntry(
  api: 'GeometryTier',
  purpose:
      'How much work a layer may spend baking the matte — accelerated, '
      'portable, or none at all.',
  group: 'Adaptation',
  knobs: <Knob<Object?>>[
    Knob<GeometryTier>(
      name: 'tier',
      value: GeometryTier.accelerated,
      options: GeometryTier.values,
    ),
  ],
  build: (knobs) {
    final tier = knobs[0].value! as GeometryTier;
    return SizedBox(
      width: _panelWidth,
      height: _geometryHeight,
      child: GlassLayer(
        key: const ValueKey<String>('layer'),
        tier: tier,
        material: _backdrop.material,
        // Two measured bands, inside the layer rather than behind it. A
        // backdrop filter bends what is already beneath it *within its own
        // layer*, and the catalogue's photograph belongs to the layer the
        // entry page put around the whole screen — so a nested layer with
        // nothing in it would have nothing to refract and this knob would
        // have nothing to show.
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                Expanded(
                  child: ColoredBox(color: _backdrop.panelBackdrop),
                ),
                Expanded(child: ColoredBox(color: _backdrop.barBackdrop)),
              ],
            ),
            Center(
              child: SizedBox(
                width: _geometryShapeWidth,
                height: _geometryShapeHeight,
                child: Glass(
                  shape: const GlassSuperellipse(
                    radius: BorderRadius.all(
                      Radius.circular(_geometryRadius),
                    ),
                  ),
                  child: _GeometryFacts(tier: tier),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
  code: (knobs) {
    final tier = knobs[0].value! as GeometryTier;
    return 'GlassLayer(\n'
        '  // Null adopts the enclosing GlassTierScope answer, or\n'
        '  // GeometryTier.accelerated where there is no scope.\n'
        '  tier: GeometryTier.${tier.name},\n'
        '  material: ${_materialCode(_backdrop.material)},\n'
        '  child: Stack(\n'
        '    fit: StackFit.expand,\n'
        '    children: [\n'
        '      bands, // two measured colours, for the glass to bend\n'
        '      Center(\n'
        '        child: SizedBox(\n'
        '          width: $_geometryShapeWidth,\n'
        '          height: $_geometryShapeHeight,\n'
        '          child: Glass(\n'
        '            shape: const GlassSuperellipse(\n'
        '              radius: BorderRadius.all(\n'
        '                Radius.circular($_geometryRadius),\n'
        '              ),\n'
        '            ),\n'
        '            child: facts,\n'
        '          ),\n'
        '        ),\n'
        '      ),\n'
        '    ],\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>[
    'GlassTierScope',
    'GlassTierEngine',
    'GlassLayer',
  ],
);
