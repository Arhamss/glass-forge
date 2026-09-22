import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';

/// The Motion group: `InteractiveGlass`, drag, jiggle and the springs that
/// drive them.
///
/// Seven entries, one per capability in this group's inventory. The last —
/// `GlassReduceMotion` — cannot drive the platform's real accessibility
/// setting from a knob (see its own doc comment below for why, and what
/// this entry shows instead).
final List<CatalogueEntry> motionEntries = <CatalogueEntry>[
  _interactiveGlass,
  _glassJiggle,
  _glassPressStretch,
  _glassOverdrag,
  _glassDecay,
  _glassMotion,
  _glassReduceMotion,
];

/// The silhouette every specimen in this file sits on, matching the size
/// the deleted `MotionScene` used — large enough that a drag or a press
/// reads clearly.
const _shape = GlassSuperellipse(
  radius: BorderRadius.all(Radius.circular(46)),
);

double _asDouble(Knob<Object?> knob) => knob.value! as double;

// ---------------------------------------------------------------------------
// InteractiveGlass
// ---------------------------------------------------------------------------

final CatalogueEntry _interactiveGlass = CatalogueEntry(
  api: 'InteractiveGlass',
  purpose:
      'Glass that answers the pointer: hold it and it settles toward '
      'the layer.',
  group: 'Motion',
  knobs: <Knob<Object?>>[
    Knob<double>(name: 'pressScale', value: 0.96, min: 0.85, max: 1),
  ],
  build: (knobs) {
    final pressScale = _asDouble(knobs[0]);
    return SizedBox.square(
      dimension: 200,
      child: InteractiveGlass(
        pressScale: pressScale,
        child: const Glass(shape: _shape),
      ),
    );
  },
  code: (knobs) {
    final pressScale = _asDouble(knobs[0]).toStringAsFixed(2);
    return 'InteractiveGlass(\n'
        '  pressScale: $pressScale,\n'
        '  child: const Glass(\n'
        '    shape: GlassSuperellipse(\n'
        '      radius: BorderRadius.all(Radius.circular(46)),\n'
        '    ),\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>[
    'GlassPressStretch',
    'GlassJiggle',
    'GlassMotion',
  ],
);

// ---------------------------------------------------------------------------
// GlassJiggle
// ---------------------------------------------------------------------------

final CatalogueEntry _glassJiggle = CatalogueEntry(
  api: 'GlassJiggle',
  purpose:
      'Squash and stretch read off live velocity — largest mid-fling, '
      'gone the instant it stops.',
  group: 'Motion',
  knobs: <Knob<Object?>>[
    Knob<double>(name: 'maxStretch', value: 1.18, min: 1, max: 1.4),
  ],
  build: (knobs) {
    final maxStretch = _asDouble(knobs[0]);
    return SizedBox.square(
      dimension: 200,
      child: InteractiveGlass(
        drag: const GlassDrag(overdrag: GlassOverdrag(limit: 96)),
        jiggle: GlassJiggle(maxStretch: maxStretch),
        child: const Glass(shape: _shape),
      ),
    );
  },
  code: (knobs) {
    final maxStretch = _asDouble(knobs[0]).toStringAsFixed(2);
    return 'InteractiveGlass(\n'
        '  drag: const GlassDrag(overdrag: GlassOverdrag(limit: 96)),\n'
        '  jiggle: GlassJiggle(maxStretch: $maxStretch),\n'
        '  child: const Glass(\n'
        '    shape: GlassSuperellipse(\n'
        '      radius: BorderRadius.all(Radius.circular(46)),\n'
        '    ),\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>['InteractiveGlass', 'GlassOverdrag'],
);

// ---------------------------------------------------------------------------
// GlassPressStretch
// ---------------------------------------------------------------------------

final CatalogueEntry _glassPressStretch = CatalogueEntry(
  api: 'GlassPressStretch',
  purpose:
      'How far a surface elongates toward a held finger, and how much '
      'squash that costs it.',
  group: 'Motion',
  knobs: <Knob<Object?>>[
    Knob<double>(name: 'intensity', value: 0.5, min: 0, max: 2),
    Knob<double>(name: 'squash', value: 0.3, min: 0, max: 1),
    Knob<double>(name: 'travel', value: 0.15, min: 0, max: 0.4),
  ],
  build: (knobs) {
    final stretch = GlassPressStretch(
      intensity: _asDouble(knobs[0]),
      squash: _asDouble(knobs[1]),
      travel: _asDouble(knobs[2]),
    );
    return SizedBox.square(
      dimension: 200,
      child: InteractiveGlass(
        pressStretch: stretch,
        child: const Glass(shape: _shape),
      ),
    );
  },
  code: (knobs) {
    String fixed(Knob<Object?> knob) => _asDouble(knob).toStringAsFixed(2);
    return 'InteractiveGlass(\n'
        '  pressStretch: GlassPressStretch(\n'
        '    intensity: ${fixed(knobs[0])},\n'
        '    squash: ${fixed(knobs[1])},\n'
        '    travel: ${fixed(knobs[2])},\n'
        '  ),\n'
        '  child: const Glass(\n'
        '    shape: GlassSuperellipse(\n'
        '      radius: BorderRadius.all(Radius.circular(46)),\n'
        '    ),\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>['InteractiveGlass', 'GlassReduceMotion'],
);

// ---------------------------------------------------------------------------
// GlassOverdrag
// ---------------------------------------------------------------------------

final CatalogueEntry _glassOverdrag = CatalogueEntry(
  api: 'GlassOverdrag',
  purpose:
      'Rubber-banding: how far past rest a drag may reach, and how '
      'hard it resists getting there.',
  group: 'Motion',
  knobs: <Knob<Object?>>[
    Knob<double>(name: 'limit', value: 56, min: 20, max: 160),
    Knob<double>(name: 'resistance', value: 0.55, min: 0.05, max: 1),
  ],
  build: (knobs) {
    final overdrag = GlassOverdrag(
      limit: _asDouble(knobs[0]),
      resistance: _asDouble(knobs[1]),
    );
    return SizedBox.square(
      dimension: 200,
      child: InteractiveGlass(
        drag: GlassDrag(overdrag: overdrag),
        child: const Glass(shape: _shape),
      ),
    );
  },
  code: (knobs) {
    final limit = _asDouble(knobs[0]).toStringAsFixed(1);
    final resistance = _asDouble(knobs[1]).toStringAsFixed(2);
    return 'InteractiveGlass(\n'
        '  drag: GlassDrag(\n'
        '    overdrag: GlassOverdrag(\n'
        '      limit: $limit,\n'
        '      resistance: $resistance,\n'
        '    ),\n'
        '  ),\n'
        '  child: const Glass(\n'
        '    shape: GlassSuperellipse(\n'
        '      radius: BorderRadius.all(Radius.circular(46)),\n'
        '    ),\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>['InteractiveGlass', 'GlassDecay'],
);

// ---------------------------------------------------------------------------
// GlassDecay
// ---------------------------------------------------------------------------

final CatalogueEntry _glassDecay = CatalogueEntry(
  api: 'GlassDecay',
  purpose:
      'A fling that does not return home: friction carries it, and it '
      'stays wherever it lands.',
  group: 'Motion',
  knobs: <Knob<Object?>>[
    Knob<double>(name: 'drag', value: 0.135, min: 0.02, max: 0.4),
  ],
  build: (knobs) {
    final decay = GlassDecay(drag: _asDouble(knobs[0]));
    return SizedBox.square(
      dimension: 200,
      child: InteractiveGlass(
        drag: GlassDrag(returnsHome: false, decay: decay),
        child: const Glass(shape: _shape),
      ),
    );
  },
  code: (knobs) {
    final drag = _asDouble(knobs[0]).toStringAsFixed(3);
    return 'InteractiveGlass(\n'
        '  drag: GlassDrag(\n'
        '    returnsHome: false,\n'
        '    decay: GlassDecay(drag: $drag),\n'
        '  ),\n'
        '  child: const Glass(\n'
        '    shape: GlassSuperellipse(\n'
        '      radius: BorderRadius.all(Radius.circular(46)),\n'
        '    ),\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>['GlassOverdrag', 'InteractiveGlass'],
);

// ---------------------------------------------------------------------------
// GlassMotion — the spring presets
// ---------------------------------------------------------------------------

/// A spring preset, its name, its constructor call and the motion it builds
/// carried together — one declaration, read by both `build` and `code`, the
/// same way `_MaterialPreset` does in `surfaces.dart`, and carrying `name`
/// for the same reason: a record's `toString()` is a debug dump, not a
/// label a segmented control can put on a 40pt pill.
typedef _SpringPreset = ({
  String name,
  String constructorCode,
  GlassMotion motion,
});

final List<_SpringPreset> _springPresets = <_SpringPreset>[
  (
    name: 'bouncy',
    constructorCode: 'GlassMotion.bouncy()',
    motion: const GlassMotion.bouncy(),
  ),
  (
    name: 'snappy',
    constructorCode: 'GlassMotion.snappy()',
    motion: const GlassMotion.snappy(),
  ),
  (
    name: 'smooth',
    constructorCode: 'GlassMotion.smooth()',
    motion: const GlassMotion.smooth(),
  ),
];

final CatalogueEntry _glassMotion = CatalogueEntry(
  api: 'GlassMotion',
  purpose:
      'A duration and a bounce — the same numbers SwiftUI resolves '
      '.bouncy, .snappy and .smooth to.',
  group: 'Motion',
  knobs: <Knob<Object?>>[
    Knob<_SpringPreset>(
      name: 'settleMotion',
      value: _springPresets[0],
      options: _springPresets,
      labelOf: (option) => (option! as _SpringPreset).name,
    ),
  ],
  build: (knobs) {
    final preset = knobs[0].value! as _SpringPreset;
    return SizedBox.square(
      dimension: 200,
      child: InteractiveGlass(
        drag: const GlassDrag(overdrag: GlassOverdrag(limit: 96)),
        settleMotion: preset.motion,
        child: const Glass(shape: _shape),
      ),
    );
  },
  code: (knobs) {
    final preset = knobs[0].value! as _SpringPreset;
    return 'InteractiveGlass(\n'
        '  drag: const GlassDrag(overdrag: GlassOverdrag(limit: 96)),\n'
        '  settleMotion: ${preset.constructorCode},\n'
        '  child: const Glass(\n'
        '    shape: GlassSuperellipse(\n'
        '      radius: BorderRadius.all(Radius.circular(46)),\n'
        '    ),\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>['InteractiveGlass', 'GlassReduceMotion'],
);

// ---------------------------------------------------------------------------
// GlassReduceMotion
// ---------------------------------------------------------------------------

/// **What this entry can honestly show.**
///
/// `GlassReduceMotion` reads `WidgetsBinding.instance.platformDispatcher
/// .accessibilityFeatures` directly — the real OS setting — and nothing in
/// this catalogue's knob system can drive that from a running app; the
/// usual `MediaQuery(data: MediaQueryData(disableAnimations: true))` trick
/// does not reach it either, since iOS never sets that flag (see the
/// class's own doc comment in `lib/src/motion/reduce_motion.dart`).
///
/// So this toggle does not flip the real setting. It **previews the one
/// resolution `InteractiveGlass` has to make explicitly**: under Reduce
/// Motion it swaps `pressStretch` for `GlassPressStretch.none()` — see
/// `interactive_glass.dart`'s own build method, which this mirrors exactly.
/// `jiggle` is deliberately left untouched by the toggle: the real setting
/// neutralises it for free, because it is derived from velocity and every
/// spring here settles instantly once Reduce Motion is on, so velocity
/// never leaves zero. That asymmetry — one channel resolved explicitly,
/// the other for free — is what this entry exists to show.
final CatalogueEntry _glassReduceMotion = CatalogueEntry(
  api: 'GlassReduceMotion',
  purpose:
      'Previews what Reduce Motion resolves pressStretch to — it '
      'cannot flip the real OS setting from here.',
  group: 'Motion',
  knobs: <Knob<Object?>>[
    Knob<String>(
      name: 'reduceMotion',
      value: 'Off',
      options: const <String>['Off', 'On'],
    ),
  ],
  build: (knobs) {
    final reduced = knobs[0].value! as String == 'On';
    final pressStretch = reduced
        ? const GlassPressStretch.none()
        : const GlassPressStretch(intensity: 0.6, squash: 0.4, travel: 0.18);
    return SizedBox.square(
      dimension: 200,
      child: InteractiveGlass(
        pressStretch: pressStretch,
        // jiggle is left at its default deliberately: the real setting
        // neutralises it for free, by zeroing velocity, not by swapping
        // it out.
        child: const Glass(shape: _shape),
      ),
    );
  },
  code: (knobs) {
    final reduced = knobs[0].value! as String == 'On';
    final pressStretch = reduced
        ? 'const GlassPressStretch.none()'
        : 'const GlassPressStretch(\n'
              '    intensity: 0.6,\n'
              '    squash: 0.4,\n'
              '    travel: 0.18,\n'
              '  )';
    return 'InteractiveGlass(\n'
        '  // GlassReduceMotion.instance.value == $reduced\n'
        '  pressStretch: $pressStretch,\n'
        '  child: const Glass(\n'
        '    shape: GlassSuperellipse(\n'
        '      radius: BorderRadius.all(Radius.circular(46)),\n'
        '    ),\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>[
    'GlassPressStretch',
    'GlassJiggle',
    'InteractiveGlass',
  ],
);
