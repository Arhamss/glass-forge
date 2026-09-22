import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';

/// The Surfaces group: `Glass`, `GlassLayer`, `GlassMaterial` and the
/// presets that shape them.
///
/// Six entries, one per capability in this group's inventory. The eight
/// numeric fields on `GlassMaterial` — refraction, frost, tint, saturation,
/// highlight, contour, thickness, dispersion — are parameters of one type,
/// not eight types, so they share a single entry ("Material knobs") rather
/// than each claiming a row of their own.
final List<CatalogueEntry> surfacesEntries = <CatalogueEntry>[
  _glass,
  _glassLayer,
  _glassMaterial,
  _glassVariant,
  _glassProfile,
  _materialKnobs,
];

/// The silhouette every specimen in this file sits on. Fixed rather than a
/// knob of its own — `GlassShape` and its concrete silhouettes are the
/// Shapes group's inventory (Task 6), not this one's.
const _shape = GlassSuperellipse(
  radius: BorderRadius.all(Radius.circular(40)),
);

double _asDouble(Knob<Object?> knob) => knob.value! as double;

// ---------------------------------------------------------------------------
// Glass
// ---------------------------------------------------------------------------

final CatalogueEntry _glass = CatalogueEntry(
  api: 'Glass',
  purpose: 'One glass surface: a shape, a material, and what sits inside it.',
  group: 'Surfaces',
  knobs: <Knob<Object?>>[
    Knob<Clip>(
      name: 'clipBehavior',
      value: Clip.antiAlias,
      options: const <Clip>[Clip.antiAlias, Clip.hardEdge, Clip.none],
    ),
  ],
  build: (knobs) {
    final clip = knobs[0].value! as Clip;
    return SizedBox.square(
      dimension: 200,
      child: Glass(
        shape: _shape,
        clipBehavior: clip,
        // A plain fill, not a label: it exists only to show where
        // `clipBehavior` does and does not cut it to `shape` — at
        // `Clip.none` its square corners escape the rounded silhouette.
        child: const ColoredBox(color: Color(0x33FFFFFF)),
      ),
    );
  },
  code: (knobs) {
    final clip = knobs[0].value! as Clip;
    return 'Glass(\n'
        '  shape: const GlassSuperellipse(\n'
        '    radius: BorderRadius.all(Radius.circular(40)),\n'
        '  ),\n'
        '  clipBehavior: $clip,\n'
        '  child: const ColoredBox(color: Color(0x33FFFFFF)),\n'
        ')';
  },
  seeAlso: const <String>['GlassLayer', 'GlassMaterial', 'GlassSuperellipse'],
);

// ---------------------------------------------------------------------------
// GlassLayer
// ---------------------------------------------------------------------------

final CatalogueEntry _glassLayer = CatalogueEntry(
  api: 'GlassLayer',
  purpose:
      'One backdrop capture per material, shared by every Glass beneath it.',
  group: 'Surfaces',
  knobs: <Knob<Object?>>[
    Knob<GlassVariant>(
      name: 'variant',
      value: GlassVariant.regular,
      options: GlassVariant.values,
    ),
  ],
  build: (knobs) {
    final variant = knobs[0].value! as GlassVariant;
    return SizedBox(
      width: 220,
      height: 140,
      child: GlassLayer(
        material: GlassMaterial(variant: variant),
        // Neither shape declares a material of its own: both inherit the
        // layer's, which is the whole point — one capture serves both.
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Glass(shape: GlassOval()),
            Glass(shape: GlassOval()),
          ],
        ),
      ),
    );
  },
  code: (knobs) {
    final variant = knobs[0].value! as GlassVariant;
    return 'GlassLayer(\n'
        '  material: GlassMaterial(variant: $variant),\n'
        '  child: const Row(\n'
        '    mainAxisAlignment: MainAxisAlignment.spaceEvenly,\n'
        '    children: [\n'
        '      Glass(shape: GlassOval()),\n'
        '      Glass(shape: GlassOval()),\n'
        '    ],\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>['Glass', 'GlassMaterial'],
);

// ---------------------------------------------------------------------------
// GlassMaterial — regular / clear / dome
// ---------------------------------------------------------------------------

/// A fitted look, its constructor call and the material it builds carried
/// together — one declaration, read by both `build` and `code`, so there is
/// nothing left to keep in sync between them.
typedef _MaterialPreset = ({String constructorCode, GlassMaterial material});

final List<_MaterialPreset> _materialPresets = <_MaterialPreset>[
  (
    constructorCode: 'GlassMaterial.regular(brightness: Brightness.dark)',
    material: GlassMaterial.regular(brightness: Brightness.dark),
  ),
  (constructorCode: 'GlassMaterial.clear()', material: GlassMaterial.clear()),
  (constructorCode: 'GlassMaterial.dome()', material: GlassMaterial.dome()),
];

final CatalogueEntry _glassMaterial = CatalogueEntry(
  api: 'GlassMaterial',
  purpose:
      "How a glass surface looks — Apple's two fitted presets, or a "
      'lens.',
  group: 'Surfaces',
  knobs: <Knob<Object?>>[
    Knob<_MaterialPreset>(
      name: 'preset',
      value: _materialPresets[0],
      options: _materialPresets,
    ),
  ],
  build: (knobs) {
    final preset = knobs[0].value! as _MaterialPreset;
    return SizedBox.square(
      dimension: 200,
      child: Glass(shape: _shape, material: preset.material),
    );
  },
  code: (knobs) {
    final preset = knobs[0].value! as _MaterialPreset;
    return 'Glass(\n'
        '  shape: const GlassSuperellipse(\n'
        '    radius: BorderRadius.all(Radius.circular(40)),\n'
        '  ),\n'
        '  material: ${preset.constructorCode},\n'
        ')';
  },
  seeAlso: const <String>['GlassVariant', 'GlassProfile', 'Material knobs'],
);

// ---------------------------------------------------------------------------
// GlassVariant
// ---------------------------------------------------------------------------

final CatalogueEntry _glassVariant = CatalogueEntry(
  api: 'GlassVariant',
  purpose: 'Regular adapts to what is behind it; clear does not.',
  group: 'Surfaces',
  knobs: <Knob<Object?>>[
    Knob<GlassVariant>(
      name: 'variant',
      value: GlassVariant.regular,
      options: GlassVariant.values,
    ),
  ],
  build: (knobs) {
    final variant = knobs[0].value! as GlassVariant;
    return SizedBox.square(
      dimension: 200,
      child: Glass(
        shape: _shape,
        material: GlassMaterial(variant: variant, tintOpacity: 0.3),
      ),
    );
  },
  code: (knobs) {
    final variant = knobs[0].value! as GlassVariant;
    return 'Glass(\n'
        '  shape: const GlassSuperellipse(\n'
        '    radius: BorderRadius.all(Radius.circular(40)),\n'
        '  ),\n'
        '  material: GlassMaterial(variant: $variant, tintOpacity: 0.3),\n'
        ')';
  },
  seeAlso: const <String>['GlassMaterial', 'GlassProfile'],
);

// ---------------------------------------------------------------------------
// GlassProfile
// ---------------------------------------------------------------------------

final CatalogueEntry _glassProfile = CatalogueEntry(
  api: 'GlassProfile',
  purpose:
      'Refraction confined to the rim, or a dome bending its whole interior.',
  group: 'Surfaces',
  knobs: <Knob<Object?>>[
    Knob<GlassProfile>(
      name: 'profile',
      value: GlassProfile.edgeBand,
      options: GlassProfile.values,
    ),
  ],
  build: (knobs) {
    final profile = knobs[0].value! as GlassProfile;
    return SizedBox.square(
      dimension: 200,
      child: Glass(
        shape: _shape,
        material: GlassMaterial(profile: profile, edgeRefraction: 40),
      ),
    );
  },
  code: (knobs) {
    final profile = knobs[0].value! as GlassProfile;
    return 'Glass(\n'
        '  shape: const GlassSuperellipse(\n'
        '    radius: BorderRadius.all(Radius.circular(40)),\n'
        '  ),\n'
        '  material: GlassMaterial(\n'
        '    profile: $profile,\n'
        '    edgeRefraction: 40,\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>['GlassMaterial', 'GlassVariant'],
);

// ---------------------------------------------------------------------------
// Material knobs — the eight parameters of GlassMaterial, together
// ---------------------------------------------------------------------------

final CatalogueEntry _materialKnobs = CatalogueEntry(
  api: 'Material knobs',
  purpose: 'The eight fields that shape a GlassMaterial, moved together.',
  group: 'Surfaces',
  knobs: <Knob<Object?>>[
    Knob<double>(name: 'edgeRefraction', value: 27.42, min: 0, max: 64),
    Knob<double>(name: 'frost', value: 5, min: 0, max: 24),
    Knob<double>(name: 'tintOpacity', value: 0, min: 0, max: 1),
    Knob<double>(name: 'saturation', value: 1, min: 0, max: 3),
    Knob<double>(name: 'highlight', value: 1, min: 0, max: 2),
    Knob<double>(name: 'contour', value: 0, min: 0, max: 0.3),
    Knob<double>(name: 'thickness', value: 12, min: 4, max: 24),
    Knob<double>(name: 'chromaticAberration', value: 0, min: 0, max: 0.3),
  ],
  build: (knobs) {
    final material = GlassMaterial(
      edgeRefraction: _asDouble(knobs[0]),
      frost: _asDouble(knobs[1]),
      tintOpacity: _asDouble(knobs[2]),
      saturation: _asDouble(knobs[3]),
      highlight: _asDouble(knobs[4]),
      contour: _asDouble(knobs[5]),
      thickness: _asDouble(knobs[6]),
      chromaticAberration: _asDouble(knobs[7]),
    );
    return SizedBox.square(
      dimension: 200,
      child: Glass(shape: _shape, material: material),
    );
  },
  code: (knobs) {
    String fixed(Knob<Object?> knob) => _asDouble(knob).toStringAsFixed(2);
    return 'GlassMaterial(\n'
        '  edgeRefraction: ${fixed(knobs[0])},\n'
        '  frost: ${fixed(knobs[1])},\n'
        '  tintOpacity: ${fixed(knobs[2])},\n'
        '  saturation: ${fixed(knobs[3])},\n'
        '  highlight: ${fixed(knobs[4])},\n'
        '  contour: ${fixed(knobs[5])},\n'
        '  thickness: ${fixed(knobs[6])},\n'
        '  chromaticAberration: ${fixed(knobs[7])},\n'
        ')';
  },
  seeAlso: const <String>['GlassMaterial', 'GlassProfile', 'GlassVariant'],
);
