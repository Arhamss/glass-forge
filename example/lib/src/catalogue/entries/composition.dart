import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';
import 'package:glass_forge_example/src/theme.dart';

/// The Composition group: how several surfaces, or several passes, share
/// one screen.
///
/// Four entries. `GlassPresence` and `GlassHostScope` are the two ways a
/// single surface avoids the flutter#187820 stacked-backdrop-filter bug on
/// its own; `GlassGlow` is the one thing that deliberately spills across a
/// pass's surfaces; the fourth entry is the diagnostic that fires when
/// nothing above avoided the bug.
///
/// Nothing in a `///` in this file reaches the app — a [CatalogueEntry] has
/// no prose field beyond `purpose` — so anything a reader needs in order to
/// read a specimen correctly is said in `purpose` or in the snippet's own
/// comment slot, and what is left here is for whoever maintains the entry.
final List<CatalogueEntry> compositionEntries = <CatalogueEntry>[
  _glassPresence,
  _glassHostScope,
  _glassGlow,
  _crossPassOverlap,
];

double _asDouble(Knob<Object?> knob) => knob.value! as double;

/// The silhouette `GlassPresence` and `GlassHostScope`'s on-content chip
/// sit on.
const _shape = GlassSuperellipse(
  radius: BorderRadius.all(Radius.circular(40)),
);

/// The silhouette both `GlassGlow` surfaces sit on — the exact shape,
/// size and separation `test/src/composition/glow_gating_test.dart` proves
/// a 320-radius glow reaches at: two 120-square shapes 40 apart, 160
/// centre to centre.
///
/// The knob runs to 200, which is 320 centre to centre — the far end of
/// that same reach. The falloff is `(1 - smoothstep(0, 320, d))²` from the
/// finger, so the spill thins the whole way out and only reaches the noise
/// floor near a separation of 155: the top quarter of the slider is where
/// the neighbour stops visibly brightening. A reader who was not told the
/// light has a radius would read that as a broken feature, so the
/// snippet's comment slot says it.
const _glowShape = GlassRoundedRectangle(
  radius: BorderRadius.all(Radius.circular(24)),
);

// ---------------------------------------------------------------------------
// GlassPresence
// ---------------------------------------------------------------------------

final CatalogueEntry _glassPresence = CatalogueEntry(
  api: 'GlassPresence',
  purpose:
      'Ramps a glass subtree in or out, then drops the backdrop pass '
      'entirely below the epsilon — glass has no alpha to fade.',
  group: 'Composition',
  knobs: <Knob<Object?>>[
    Knob<double>(name: 'presence', value: 1, min: 0, max: 1),
  ],
  build: (knobs) {
    final presence = _asDouble(knobs[0]);
    return SizedBox.square(
      dimension: 200,
      child: GlassPresence(
        presence: AlwaysStoppedAnimation<double>(presence),
        child: const Glass(shape: _shape),
      ),
    );
  },
  code: (knobs) {
    final presence = _asDouble(knobs[0]).toStringAsFixed(2);
    return 'GlassPresence(\n'
        '  presence: AlwaysStoppedAnimation<double>($presence),\n'
        '  child: const Glass(\n'
        '    shape: GlassSuperellipse(\n'
        '      radius: BorderRadius.all(Radius.circular(40)),\n'
        '    ),\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>['GlassHostScope', 'Glass'],
);

// ---------------------------------------------------------------------------
// GlassHostScope
// ---------------------------------------------------------------------------

/// The one control this entry places twice — directly on content, and
/// inside a glass toolbar.
///
/// Mirrors `GlassHostScope`'s own class-doc example: off glass it is a
/// real `Glass`; on glass it paints, because nesting a second `Glass`
/// inside the first's child is the one composition this renderer refuses
/// to draw (`Glass.build` asserts on it).
class _HostAwareChip extends StatelessWidget {
  const _HostAwareChip({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    if (GlassHostScope.isOnGlass(context)) {
      return SizedBox.square(
        dimension: 96,
        child: ColoredBox(color: context.inkFill),
      );
    }
    return SizedBox.square(
      dimension: 96,
      child: Glass(
        shape: GlassRoundedRectangle(
          radius: BorderRadius.all(Radius.circular(radius)),
        ),
      ),
    );
  }
}

final CatalogueEntry _glassHostScope = CatalogueEntry(
  api: 'GlassHostScope',
  purpose:
      'One control, aware of whether it already sits on glass — real '
      'glass on content, painted inside a glass toolbar.',
  group: 'Composition',
  knobs: <Knob<Object?>>[
    Knob<double>(name: 'radius', value: 20, min: 4, max: 40),
  ],
  build: (knobs) {
    final radius = _asDouble(knobs[0]);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // On content: nothing above it is glass yet, so the control
        // draws its own.
        _HostAwareChip(radius: radius),
        // Inside a glass toolbar: the same control paints instead of
        // nesting a second Glass inside this one's child.
        SizedBox.square(
          dimension: 160,
          child: Glass(
            shape: const GlassSuperellipse(
              radius: BorderRadius.all(Radius.circular(32)),
            ),
            child: Center(child: _HostAwareChip(radius: radius)),
          ),
        ),
      ],
    );
  },
  code: (knobs) {
    final radius = _asDouble(knobs[0]).toStringAsFixed(1);
    // Both placements below run this exact ternary at their own position
    // — the same control, not two — so the snippet repeats it rather
    // than hiding the second copy behind a comment.
    final chip =
        'GlassHostScope.isOnGlass(context)\n'
        '        ? SizedBox.square(\n'
        '            dimension: 96,\n'
        '            child: ColoredBox(color: context.inkFill),\n'
        '          )\n'
        '        : SizedBox.square(\n'
        '            dimension: 96,\n'
        '            child: Glass(\n'
        '              shape: GlassRoundedRectangle(\n'
        '                radius: BorderRadius.all(\n'
        '                  Radius.circular($radius),\n'
        '                ),\n'
        '              ),\n'
        '            ),\n'
        '          )';
    return 'Row(\n'
        '  children: [\n'
        '    // On content: nothing above it is glass yet.\n'
        '    $chip,\n'
        '    // Inside a glass toolbar: the same control paints.\n'
        '    // Not a preference: Glass.build asserts on a Glass\n'
        '    // built anywhere inside the subtree another Glass\n'
        '    // returns, which is the stacked backdrop filter.\n'
        '    SizedBox.square(\n'
        '      dimension: 160,\n'
        '      child: Glass(\n'
        '        shape: const GlassSuperellipse(\n'
        '          radius: BorderRadius.all(Radius.circular(32)),\n'
        '        ),\n'
        '        child: Center(child: $chip),\n'
        '      ),\n'
        '    ),\n'
        '  ],\n'
        ')';
  },
  seeAlso: const <String>['Glass', 'GlassLayer'],
);

// ---------------------------------------------------------------------------
// GlassGlow
// ---------------------------------------------------------------------------

final CatalogueEntry _glassGlow = CatalogueEntry(
  api: 'GlassGlow',
  purpose:
      'The light under a held finger spreads onto a neighbour sharing '
      'the same backdrop pass — press one, watch the other brighten.',
  group: 'Composition',
  knobs: <Knob<Object?>>[
    Knob<double>(name: 'separation', value: 40, min: 0, max: 200),
  ],
  build: (knobs) {
    final separation = _asDouble(knobs[0]);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox.square(
          dimension: 120,
          child: InteractiveGlass(child: Glass(shape: _glowShape)),
        ),
        SizedBox(width: separation),
        const SizedBox.square(
          dimension: 120,
          child: InteractiveGlass(child: Glass(shape: _glowShape)),
        ),
      ],
    );
  },
  code: (knobs) {
    final separation = _asDouble(knobs[0]).toStringAsFixed(1);
    final centres = (_asDouble(knobs[0]) + 120).toStringAsFixed(1);
    return '// GlassGlow is not constructed by a caller. InteractiveGlass\n'
        '// publishes one under the finger, at a radius of its own —\n'
        '// 320 points — onto the channel every Glass in the same\n'
        '// GlassLayer reads. These two centres are $centres apart;\n'
        '// slide them past that radius and the neighbour is out of\n'
        '// reach, which is the knob running out rather than the\n'
        '// light failing.\n'
        'Row(\n'
        '  mainAxisAlignment: MainAxisAlignment.center,\n'
        '  children: [\n'
        '    const SizedBox.square(\n'
        '      dimension: 120,\n'
        '      child: InteractiveGlass(\n'
        '        child: Glass(\n'
        '          shape: GlassRoundedRectangle(\n'
        '            radius: BorderRadius.all(Radius.circular(24)),\n'
        '          ),\n'
        '        ),\n'
        '      ),\n'
        '    ),\n'
        '    SizedBox(width: $separation),\n'
        '    const SizedBox.square(\n'
        '      dimension: 120,\n'
        '      child: InteractiveGlass(\n'
        '        child: Glass(\n'
        '          shape: GlassRoundedRectangle(\n'
        '            radius: BorderRadius.all(Radius.circular(24)),\n'
        '          ),\n'
        '        ),\n'
        '      ),\n'
        '    ),\n'
        '  ],\n'
        ')';
  },
  seeAlso: const <String>['InteractiveGlass', 'GlassLayer'],
);

// ---------------------------------------------------------------------------
// Cross-pass overlap
// ---------------------------------------------------------------------------

/// Two overlapping shapes in differing materials, with the real
/// `debugPrint` warning `RenderGlassLayer` fires for them captured and
/// shown on screen rather than left in the console.
///
/// `debugPrint` is a plain top-level field
/// (`DebugPrintCallback debugPrint`), so this borrows it in `initState`
/// and hands it back in `dispose` — the technique the brief asks for,
/// and the only way to put a package diagnostic on screen rather than
/// merely describe it.
class _OverlapWarningDemo extends StatefulWidget {
  const _OverlapWarningDemo({required this.offset});

  /// How far the second shape sits from the first, in logical pixels.
  final double offset;

  @override
  State<_OverlapWarningDemo> createState() => _OverlapWarningDemoState();
}

class _OverlapWarningDemoState extends State<_OverlapWarningDemo> {
  /// What [debugPrint] pointed at before this widget borrowed it.
  late final DebugPrintCallback _previousDebugPrint;

  /// The warning's own text, once `RenderGlassLayer` has printed one.
  String? _captured;

  @override
  void initState() {
    super.initState();
    _previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null && message.startsWith('glass_forge:')) {
        // The warning fires from inside paint, where a synchronous
        // setState is not legal — the frame it fires in is still
        // building the tree a rebuild would need. Deferred to the next
        // frame instead.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _captured = message);
          }
        });
      }
      _previousDebugPrint(message, wrapWidth: wrapWidth);
    };
  }

  @override
  void dispose() {
    debugPrint = _previousDebugPrint;
    super.dispose();
  }

  /// How far right the second shape's `Positioned` can ever sit — the
  /// knob's own `max` — plus a shape's own width. A `Stack` whose only
  /// children are `Positioned` takes `constraints.biggest` under an
  /// unbounded-width parent (a `FittedBox`, as every index-page thumbnail
  /// is one: `_EntryRow` wraps `entry.build` in exactly that) and never
  /// lays out at all. A fixed width here is what keeps this entry alive
  /// in that slot, at every knob value, rather than only recovering after
  /// the first-frame geometry exception the way its siblings do.
  static const double _stackWidth = 240;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _stackWidth,
          height: 100,
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                child: SizedBox.square(
                  dimension: 100,
                  child: Glass(shape: GlassOval()),
                ),
              ),
              Positioned(
                left: widget.offset,
                child: const SizedBox.square(
                  dimension: 100,
                  child: Glass(
                    shape: GlassOval(),
                    // Not `GlassMaterial.clear()`: its frost is 0, so on a
                    // backend without shader-filter support
                    // `GlassComposition.willRender` — the same gate the
                    // overlap check itself defers to — would call it
                    // incapable of drawing anything and the two shapes
                    // would never be judged as overlapping passes at all.
                    // A nonzero frost keeps this entry honest everywhere.
                    material: GlassMaterial(
                      variant: GlassVariant.clear,
                      frost: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Scrollable, not clipped: the warning is the entry's whole
        // payload, and `RenderGlassLayer`'s own message runs past 400
        // characters — far more than any fixed box here could show
        // without either truncating mid-word or crowding the shapes
        // above out of the specimen's own budget.
        SizedBox(
          height: 140,
          width: _stackWidth,
          child: SingleChildScrollView(
            child: Text(
              _captured ?? 'watching for the paint-time warning…',
              textAlign: TextAlign.center,
              style: context.mono.copyWith(color: context.inkSecondary),
            ),
          ),
        ),
      ],
    );
  }
}

final CatalogueEntry _crossPassOverlap = CatalogueEntry(
  api: 'Cross-pass overlap',
  purpose:
      'Two materials whose shapes overlap sample last frame across '
      'passes — deliberately provoked here, with the debug warning '
      'captured live.',
  group: 'Composition',
  knobs: <Knob<Object?>>[
    Knob<double>(name: 'offset', value: 30, min: 0, max: 140),
  ],
  build: (knobs) {
    final offset = _asDouble(knobs[0]);
    return _OverlapWarningDemo(offset: offset);
  },
  code: (knobs) {
    final offset = _asDouble(knobs[0]).toStringAsFixed(1);
    return '// The text under the shapes is not something this package\n'
        '// draws. RenderGlassLayer prints that warning through\n'
        '// debugPrint, to the console; the catalogue borrows\n'
        '// debugPrint for the life of this page to put it on screen.\n'
        'Stack(\n'
        '  children: [\n'
        '    const Positioned(\n'
        '      left: 0,\n'
        '      child: SizedBox.square(\n'
        '        dimension: 100,\n'
        '        child: Glass(shape: GlassOval()),\n'
        '      ),\n'
        '    ),\n'
        '    Positioned(\n'
        '      left: $offset,\n'
        '      child: const SizedBox.square(\n'
        '        dimension: 100,\n'
        '        child: Glass(\n'
        '          shape: GlassOval(),\n'
        '          material: GlassMaterial(\n'
        '            variant: GlassVariant.clear,\n'
        '            frost: 8,\n'
        '          ),\n'
        '        ),\n'
        '      ),\n'
        '    ),\n'
        '  ],\n'
        ')';
  },
  seeAlso: const <String>['GlassLayer', 'GlassBlendGroup', 'GlassPresence'],
);
