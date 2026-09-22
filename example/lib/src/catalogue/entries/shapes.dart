import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';

/// The Shapes group: `GlassShape` and its concrete silhouettes.
///
/// `GlassShape` is a closed set of exactly three silhouettes plus one
/// widget that joins them — one entry per member of that set.
final List<CatalogueEntry> shapesEntries = <CatalogueEntry>[
  _glassRoundedRectangle,
  _glassOval,
  _glassSuperellipse,
  _glassBlendGroup,
];

double _asDouble(Knob<Object?> knob) => knob.value! as double;

// ---------------------------------------------------------------------------
// GlassRoundedRectangle
// ---------------------------------------------------------------------------

final CatalogueEntry _glassRoundedRectangle = CatalogueEntry(
  api: 'GlassRoundedRectangle',
  purpose:
      'A rounded rectangle, its corners clamped to a capsule at the '
      'shortest side.',
  group: 'Shapes',
  knobs: <Knob<Object?>>[
    Knob<double>(name: 'radius', value: 32, min: 0, max: 100),
  ],
  build: (knobs) {
    final radius = _asDouble(knobs[0]);
    return SizedBox.square(
      dimension: 200,
      child: Glass(
        shape: GlassRoundedRectangle(
          radius: BorderRadius.all(Radius.circular(radius)),
        ),
      ),
    );
  },
  code: (knobs) {
    final radius = _asDouble(knobs[0]).toStringAsFixed(1);
    return 'Glass(\n'
        '  shape: const GlassRoundedRectangle(\n'
        '    radius: BorderRadius.all(Radius.circular($radius)),\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>['GlassShape', 'GlassSuperellipse', 'Glass'],
);

// ---------------------------------------------------------------------------
// GlassOval
// ---------------------------------------------------------------------------

final CatalogueEntry _glassOval = CatalogueEntry(
  api: 'GlassOval',
  purpose:
      'An ellipse inscribed in whatever box it is given — no radius '
      'of its own to tune.',
  group: 'Shapes',
  knobs: <Knob<Object?>>[
    Knob<double>(name: 'width', value: 200, min: 80, max: 260),
  ],
  build: (knobs) {
    final width = _asDouble(knobs[0]);
    return SizedBox(
      width: width,
      height: 160,
      child: const Glass(shape: GlassOval()),
    );
  },
  code: (knobs) {
    final width = _asDouble(knobs[0]).toStringAsFixed(1);
    return 'SizedBox(\n'
        '  width: $width,\n'
        '  height: 160,\n'
        '  child: const Glass(shape: GlassOval()),\n'
        ')';
  },
  seeAlso: const <String>['GlassShape', 'Glass'],
);

// ---------------------------------------------------------------------------
// GlassSuperellipse
// ---------------------------------------------------------------------------

final CatalogueEntry _glassSuperellipse = CatalogueEntry(
  api: 'GlassSuperellipse',
  purpose:
      'A rounded superellipse — squarer along the flat sides than a '
      'rounded rectangle at the same radius.',
  group: 'Shapes',
  knobs: <Knob<Object?>>[
    Knob<double>(name: 'radius', value: 40, min: 0, max: 100),
  ],
  build: (knobs) {
    final radius = _asDouble(knobs[0]);
    return SizedBox.square(
      dimension: 200,
      child: Glass(
        shape: GlassSuperellipse(
          radius: BorderRadius.all(Radius.circular(radius)),
        ),
      ),
    );
  },
  code: (knobs) {
    final radius = _asDouble(knobs[0]).toStringAsFixed(1);
    return 'Glass(\n'
        '  shape: const GlassSuperellipse(\n'
        '    radius: BorderRadius.all(Radius.circular($radius)),\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>['GlassShape', 'GlassRoundedRectangle', 'Glass'],
);

// ---------------------------------------------------------------------------
// GlassBlendGroup
// ---------------------------------------------------------------------------

final CatalogueEntry _glassBlendGroup = CatalogueEntry(
  api: 'GlassBlendGroup',
  purpose:
      'Shapes closer than blend join through a smooth neck instead of '
      'stacking as two cut-outs.',
  group: 'Shapes',
  knobs: <Knob<Object?>>[
    Knob<double>(name: 'separation', value: 40, min: 0, max: 80),
  ],
  build: (knobs) {
    final separation = _asDouble(knobs[0]);
    return SizedBox(
      height: 160,
      child: GlassBlendGroup(
        blend: 28,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(
              dimension: 120,
              child: Glass(shape: GlassOval()),
            ),
            SizedBox(width: separation),
            const SizedBox.square(
              dimension: 120,
              child: Glass(shape: GlassOval()),
            ),
          ],
        ),
      ),
    );
  },
  code: (knobs) {
    final separation = _asDouble(knobs[0]).toStringAsFixed(1);
    return 'GlassBlendGroup(\n'
        '  blend: 28,\n'
        '  child: Row(\n'
        '    mainAxisAlignment: MainAxisAlignment.center,\n'
        '    children: [\n'
        '      const SizedBox.square(\n'
        '        dimension: 120,\n'
        '        child: Glass(shape: GlassOval()),\n'
        '      ),\n'
        '      SizedBox(width: $separation),\n'
        '      const SizedBox.square(\n'
        '        dimension: 120,\n'
        '        child: Glass(shape: GlassOval()),\n'
        '      ),\n'
        '    ],\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>['GlassOval', 'Glass'],
);
