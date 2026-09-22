import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';
import 'package:glass_forge_example/src/catalogue/entries/motion.dart';
import 'package:glass_forge_example/src/catalogue/entries/shapes.dart';
import 'package:glass_forge_example/src/catalogue/entries/surfaces.dart';
import 'package:glass_forge_example/src/catalogue/snippet.dart';

void main() {
  CatalogueEntry entryWithFrost(double frost) {
    return CatalogueEntry(
      api: 'Glass',
      purpose: 'One glass surface.',
      group: 'Surfaces',
      knobs: <Knob<Object?>>[
        Knob<double>(name: 'frost', value: frost, min: 0, max: 24),
      ],
      build: (knobs) => SizedBox(width: knobs.first.value! as double),
      code: (knobs) =>
          'Glass(material: GlassMaterial(frost: '
          '${knobs.first.value}))',
      seeAlso: const <String>['GlassMaterial'],
    );
  }

  test('the widget and the snippet read the same knob', () {
    final entry = entryWithFrost(8).withKnob(0, 12.0);
    final built = entry.build(entry.knobs) as SizedBox;

    expect(built.width, 12.0, reason: 'the widget reads the new value');
    expect(
      renderSnippet(entry),
      contains('frost: 12.0'),
      reason: 'and so does the snippet, from the same list',
    );
  });

  test('changing a knob cannot move one without the other', () {
    // The drift this design exists to prevent: assert both derive from the
    // same source by checking they agree across several values, not just one.
    for (final value in <double>[0, 4, 16, 24]) {
      final entry = entryWithFrost(0).withKnob(0, value);
      expect((entry.build(entry.knobs) as SizedBox).width, value);
      expect(renderSnippet(entry), contains('frost: $value'));
    }
  });

  test('withKnob leaves the original entry untouched', () {
    final original = entryWithFrost(8)..withKnob(0, 20.0);
    expect(original.knobs.first.value, 8.0);
  });

  test('entry.knobs cannot be mutated through a held reference', () {
    final entry = entryWithFrost(8);

    expect(
      () => entry.knobs[0] = Knob<double>(name: 'frost', value: 99),
      throwsUnsupportedError,
      reason: 'the list is unmodifiable, not just the field',
    );
    expect(
      entry.knobs.first.value,
      8.0,
      reason: 'the failed write left the entry as it was',
    );
  });

  group('surfacesEntries', () {
    test('the group has its promised six entries', () {
      expect(surfacesEntries, hasLength(6));
    });

    test('every entry names its api, its purpose and at least one knob', () {
      for (final entry in surfacesEntries) {
        expect(entry.api, isNotEmpty, reason: 'a nameless entry');
        expect(
          entry.purpose,
          isNotEmpty,
          reason: '${entry.api} has no purpose',
        );
        expect(
          entry.knobs,
          isNotEmpty,
          reason: '${entry.api} has nothing to move',
        );
      }
    });

    test('every entry names the Surfaces group', () {
      for (final entry in surfacesEntries) {
        expect(entry.group, 'Surfaces');
      }
    });

    test('every entry api is unique', () {
      final names = surfacesEntries.map((entry) => entry.api).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test(
      'entry.build(entry.knobs) constructs without throwing, for every '
      "entry's default knobs",
      () {
        for (final entry in surfacesEntries) {
          expect(
            () => entry.build(entry.knobs),
            returnsNormally,
            reason: '${entry.api} threw building its default widget',
          );
        }
      },
    );

    testWidgets(
      'every entry mounts and paints under a real GlassLayer, at default '
      'knobs',
      (tester) async {
        for (final entry in surfacesEntries) {
          await tester.pumpWidget(
            MaterialApp(
              home: GlassLayer(child: Center(child: entry.build(entry.knobs))),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.api} threw once mounted',
          );
        }
      },
    );

    // This does not compile the snippets — Task 11 does that, by feeding
    // them through the analyzer. All this checks is that `code` produced
    // something for each entry's default knobs, which a fabricated,
    // unrelated string would also satisfy. The tests below it are what
    // actually guard the drift-free property this design exists for: that
    // moving a knob moves both `build` and `code` together.
    test("every entry's code is non-empty at its default knobs", () {
      for (final entry in surfacesEntries) {
        expect(
          renderSnippet(entry),
          isNotEmpty,
          reason: '${entry.api} rendered no snippet',
        );
      }
    });

    // --- moving a knob moves both build and code -------------------------

    CatalogueEntry entryNamed(String api) =>
        surfacesEntries.firstWhere((entry) => entry.api == api);

    test(
      'Glass — moving clipBehavior changes the built widget and the '
      'snippet',
      () {
        final entry = entryNamed('Glass');
        expect(
          entry.knobs[0].value,
          Clip.antiAlias,
          reason: 'sanity: default',
        );

        final moved = entry.withKnob(0, Clip.hardEdge);
        final glass = (moved.build(moved.knobs) as SizedBox).child! as Glass;

        expect(glass.clipBehavior, Clip.hardEdge);
        expect(renderSnippet(moved), contains('clipBehavior: Clip.hardEdge'));
      },
    );

    test(
      'GlassLayer — moving variant changes the built material and the '
      'snippet',
      () {
        final entry = entryNamed('GlassLayer');
        expect(
          entry.knobs[0].value,
          GlassVariant.regular,
          reason: 'sanity: default',
        );

        final moved = entry.withKnob(0, GlassVariant.clear);
        final layer =
            (moved.build(moved.knobs) as SizedBox).child! as GlassLayer;

        expect(layer.material.variant, GlassVariant.clear);
        expect(
          renderSnippet(moved),
          contains('variant: GlassVariant.clear'),
        );
      },
    );

    test(
      'GlassMaterial — moving the preset changes the built material and '
      'the printed constructor',
      () {
        final entry = entryNamed('GlassMaterial');
        final defaultPreset = entry.knobs[0].value;
        final otherPreset = entry.knobs[0].options.firstWhere(
          (option) => option != defaultPreset,
        );
        final preset =
            otherPreset! as ({String constructorCode, GlassMaterial material});

        final moved = entry.withKnob(0, otherPreset);
        final glass = (moved.build(moved.knobs) as SizedBox).child! as Glass;

        expect(glass.material, preset.material);
        expect(renderSnippet(moved), contains(preset.constructorCode));
      },
    );

    test(
      'GlassVariant — moving variant changes the built material and the '
      'snippet',
      () {
        final entry = entryNamed('GlassVariant');
        expect(
          entry.knobs[0].value,
          GlassVariant.regular,
          reason: 'sanity: default',
        );

        final moved = entry.withKnob(0, GlassVariant.clear);
        final glass = (moved.build(moved.knobs) as SizedBox).child! as Glass;

        expect(glass.material!.variant, GlassVariant.clear);
        expect(
          renderSnippet(moved),
          contains('variant: GlassVariant.clear'),
        );
      },
    );

    test(
      'GlassProfile — moving profile changes the built material and the '
      'snippet',
      () {
        final entry = entryNamed('GlassProfile');
        expect(
          entry.knobs[0].value,
          GlassProfile.edgeBand,
          reason: 'sanity: default',
        );

        final moved = entry.withKnob(0, GlassProfile.dome);
        final glass = (moved.build(moved.knobs) as SizedBox).child! as Glass;

        expect(glass.material!.profile, GlassProfile.dome);
        expect(renderSnippet(moved), contains('profile: GlassProfile.dome'));
      },
    );

    test(
      'Material knobs — moving frost changes the built material and the '
      'snippet',
      () {
        final entry = entryNamed('Material knobs');
        final frostIndex = entry.knobs.indexWhere(
          (knob) => knob.name == 'frost',
        );
        expect(frostIndex, isNonNegative, reason: 'sanity: knob exists');
        expect(entry.knobs[frostIndex].value, 5.0, reason: 'sanity: default');

        final moved = entry.withKnob(frostIndex, 18.0);
        final glass = (moved.build(moved.knobs) as SizedBox).child! as Glass;

        expect(glass.material!.frost, 18.0);
        expect(renderSnippet(moved), contains('frost: 18.00'));
      },
    );
  });

  group('shapesEntries', () {
    test('the group has its promised four entries', () {
      expect(shapesEntries, hasLength(4));
    });

    test('every entry names its api, its purpose and at least one knob', () {
      for (final entry in shapesEntries) {
        expect(entry.api, isNotEmpty, reason: 'a nameless entry');
        expect(
          entry.purpose,
          isNotEmpty,
          reason: '${entry.api} has no purpose',
        );
        expect(
          entry.knobs,
          isNotEmpty,
          reason: '${entry.api} has nothing to move',
        );
      }
    });

    test('every entry names the Shapes group', () {
      for (final entry in shapesEntries) {
        expect(entry.group, 'Shapes');
      }
    });

    test('every entry api is unique', () {
      final names = shapesEntries.map((entry) => entry.api).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test(
      'entry.build(entry.knobs) constructs without throwing, for every '
      "entry's default knobs",
      () {
        for (final entry in shapesEntries) {
          expect(
            () => entry.build(entry.knobs),
            returnsNormally,
            reason: '${entry.api} threw building its default widget',
          );
        }
      },
    );

    testWidgets(
      'every entry mounts and paints under a real GlassLayer, at default '
      'knobs',
      (tester) async {
        for (final entry in shapesEntries) {
          await tester.pumpWidget(
            MaterialApp(
              home: GlassLayer(child: Center(child: entry.build(entry.knobs))),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.api} threw once mounted',
          );
        }
      },
    );

    // See the equivalent comment in the surfacesEntries group above: this
    // is not a compile check, only an emptiness check. The knob-move tests
    // below are what guard the drift-free property.
    test("every entry's code is non-empty at its default knobs", () {
      for (final entry in shapesEntries) {
        expect(
          renderSnippet(entry),
          isNotEmpty,
          reason: '${entry.api} rendered no snippet',
        );
      }
    });

    // --- moving a knob moves both build and code -------------------------

    CatalogueEntry entryNamed(String api) =>
        shapesEntries.firstWhere((entry) => entry.api == api);

    test(
      'GlassRoundedRectangle — moving radius changes the built shape and '
      'the snippet',
      () {
        final entry = entryNamed('GlassRoundedRectangle');
        expect(entry.knobs[0].value, 32.0, reason: 'sanity: default');

        final moved = entry.withKnob(0, 60.0);
        final glass = (moved.build(moved.knobs) as SizedBox).child! as Glass;
        final shape = glass.shape as GlassRoundedRectangle;

        expect(shape.radius, const BorderRadius.all(Radius.circular(60)));
        expect(renderSnippet(moved), contains('Radius.circular(60.0)'));
      },
    );

    test(
      'GlassOval — moving width changes the built size and the snippet',
      () {
        final entry = entryNamed('GlassOval');
        expect(entry.knobs[0].value, 200.0, reason: 'sanity: default');

        final moved = entry.withKnob(0, 150.0);
        final box = moved.build(moved.knobs) as SizedBox;

        expect(box.width, 150.0);
        expect(renderSnippet(moved), contains('width: 150.0'));
      },
    );

    test(
      'GlassSuperellipse — moving radius changes the built shape and the '
      'snippet',
      () {
        final entry = entryNamed('GlassSuperellipse');
        expect(entry.knobs[0].value, 40.0, reason: 'sanity: default');

        final moved = entry.withKnob(0, 70.0);
        final glass = (moved.build(moved.knobs) as SizedBox).child! as Glass;
        final shape = glass.shape as GlassSuperellipse;

        expect(shape.radius, const BorderRadius.all(Radius.circular(70)));
        expect(renderSnippet(moved), contains('Radius.circular(70.0)'));
      },
    );

    test(
      'GlassBlendGroup — moving separation changes the built layout and '
      'the snippet',
      () {
        final entry = entryNamed('GlassBlendGroup');
        expect(entry.knobs[0].value, 40.0, reason: 'sanity: default');

        final moved = entry.withKnob(0, 65.0);
        final group =
            (moved.build(moved.knobs) as SizedBox).child! as GlassBlendGroup;
        final row = group.child as Row;
        final gap = row.children[1] as SizedBox;

        expect(gap.width, 65.0);
        expect(renderSnippet(moved), contains('SizedBox(width: 65.0)'));
      },
    );
  });

  group('motionEntries', () {
    test('the group has its promised seven entries', () {
      expect(motionEntries, hasLength(7));
    });

    test('every entry names its api, its purpose and at least one knob', () {
      for (final entry in motionEntries) {
        expect(entry.api, isNotEmpty, reason: 'a nameless entry');
        expect(
          entry.purpose,
          isNotEmpty,
          reason: '${entry.api} has no purpose',
        );
        expect(
          entry.knobs,
          isNotEmpty,
          reason: '${entry.api} has nothing to move',
        );
      }
    });

    test('every entry names the Motion group', () {
      for (final entry in motionEntries) {
        expect(entry.group, 'Motion');
      }
    });

    test('every entry api is unique', () {
      final names = motionEntries.map((entry) => entry.api).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test(
      'entry.build(entry.knobs) constructs without throwing, for every '
      "entry's default knobs",
      () {
        for (final entry in motionEntries) {
          expect(
            () => entry.build(entry.knobs),
            returnsNormally,
            reason: '${entry.api} threw building its default widget',
          );
        }
      },
    );

    testWidgets(
      'every entry mounts and paints under a real GlassLayer, at default '
      'knobs',
      (tester) async {
        // Each iteration is keyed by the entry's own api: two entries in
        // this group build structurally different `InteractiveGlass`
        // trees (drag on versus off adds a `GestureDetector`), and without
        // a key Flutter's element diffing updates the previous iteration's
        // render tree in place instead of replacing it — which is not
        // what the real app does, since one catalogue page never turns
        // into another without a route push between them.
        for (final entry in motionEntries) {
          await tester.pumpWidget(
            MaterialApp(
              home: GlassLayer(
                child: Center(
                  child: KeyedSubtree(
                    key: ValueKey(entry.api),
                    child: entry.build(entry.knobs),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.api} threw once mounted',
          );
        }
      },
    );

    // See the equivalent comment in the surfacesEntries group above: this
    // is not a compile check, only an emptiness check. The knob-move tests
    // below are what guard the drift-free property.
    test("every entry's code is non-empty at its default knobs", () {
      for (final entry in motionEntries) {
        expect(
          renderSnippet(entry),
          isNotEmpty,
          reason: '${entry.api} rendered no snippet',
        );
      }
    });

    // --- moving a knob moves both build and code -------------------------

    CatalogueEntry entryNamed(String api) =>
        motionEntries.firstWhere((entry) => entry.api == api);

    test(
      'InteractiveGlass — moving pressScale changes the built widget and '
      'the snippet',
      () {
        final entry = entryNamed('InteractiveGlass');
        expect(entry.knobs[0].value, 0.96, reason: 'sanity: default');

        final moved = entry.withKnob(0, 0.9);
        final built =
            (moved.build(moved.knobs) as SizedBox).child! as InteractiveGlass;

        expect(built.pressScale, 0.9);
        expect(renderSnippet(moved), contains('pressScale: 0.90'));
      },
    );

    test(
      'GlassJiggle — moving maxStretch changes the built widget and the '
      'snippet',
      () {
        final entry = entryNamed('GlassJiggle');
        expect(entry.knobs[0].value, 1.18, reason: 'sanity: default');

        final moved = entry.withKnob(0, 1.3);
        final built =
            (moved.build(moved.knobs) as SizedBox).child! as InteractiveGlass;

        expect(built.jiggle.maxStretch, 1.3);
        expect(renderSnippet(moved), contains('maxStretch: 1.30'));
      },
    );

    test(
      'GlassPressStretch — moving intensity changes the built widget and '
      'the snippet',
      () {
        final entry = entryNamed('GlassPressStretch');
        expect(entry.knobs[0].value, 0.5, reason: 'sanity: default');

        final moved = entry.withKnob(0, 1.2);
        final built =
            (moved.build(moved.knobs) as SizedBox).child! as InteractiveGlass;

        expect(built.pressStretch.intensity, 1.2);
        expect(renderSnippet(moved), contains('intensity: 1.20'));
      },
    );

    test(
      'GlassOverdrag — moving limit changes the built widget and the '
      'snippet',
      () {
        final entry = entryNamed('GlassOverdrag');
        expect(entry.knobs[0].value, 56.0, reason: 'sanity: default');

        final moved = entry.withKnob(0, 100.0);
        final built =
            (moved.build(moved.knobs) as SizedBox).child! as InteractiveGlass;

        expect(built.drag.overdrag.limit, 100.0);
        expect(renderSnippet(moved), contains('limit: 100.0'));
      },
    );

    test(
      'GlassDecay — moving drag changes the built widget and the snippet',
      () {
        final entry = entryNamed('GlassDecay');
        expect(entry.knobs[0].value, 0.135, reason: 'sanity: default');

        final moved = entry.withKnob(0, 0.2);
        final built =
            (moved.build(moved.knobs) as SizedBox).child! as InteractiveGlass;

        expect(built.drag.decay.drag, 0.2);
        expect(
          built.drag.returnsHome,
          isFalse,
          reason: 'a fling only shows anything with returnsHome off',
        );
        expect(renderSnippet(moved), contains('drag: 0.200'));
      },
    );

    test(
      'GlassMotion — moving the preset changes the built settleMotion and '
      'the printed constructor',
      () {
        final entry = entryNamed('GlassMotion');
        final defaultPreset = entry.knobs[0].value;
        final otherPreset = entry.knobs[0].options.firstWhere(
          (option) => option != defaultPreset,
        );
        final preset =
            otherPreset! as ({String constructorCode, GlassMotion motion});

        final moved = entry.withKnob(0, otherPreset);
        final built =
            (moved.build(moved.knobs) as SizedBox).child! as InteractiveGlass;

        expect(built.settleMotion, preset.motion);
        expect(renderSnippet(moved), contains(preset.constructorCode));
      },
    );

    test(
      'GlassReduceMotion — toggling On resolves pressStretch to none, in '
      'both the built widget and the snippet',
      () {
        final entry = entryNamed('GlassReduceMotion');
        expect(entry.knobs[0].value, 'Off', reason: 'sanity: default');

        final off = entry.build(entry.knobs) as SizedBox;
        final offBuilt = off.child! as InteractiveGlass;
        expect(
          offBuilt.pressStretch,
          isNot(const GlassPressStretch.none()),
          reason: 'sanity: Off is not already neutralised',
        );

        final moved = entry.withKnob(0, 'On');
        final built =
            (moved.build(moved.knobs) as SizedBox).child! as InteractiveGlass;

        expect(built.pressStretch, const GlassPressStretch.none());
        expect(
          renderSnippet(moved),
          contains('GlassPressStretch.none()'),
        );
      },
    );
  });
}
