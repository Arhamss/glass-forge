import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';
import 'package:glass_forge_example/src/catalogue/entries/chrome.dart';
import 'package:glass_forge_example/src/catalogue/entries/composition.dart';
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

  group('compositionEntries', () {
    test('the group has its promised four entries', () {
      expect(compositionEntries, hasLength(4));
    });

    test('every entry names its api, its purpose and at least one knob', () {
      for (final entry in compositionEntries) {
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

    test('every entry names the Composition group', () {
      for (final entry in compositionEntries) {
        expect(entry.group, 'Composition');
      }
    });

    test('every entry api is unique', () {
      final names = compositionEntries.map((entry) => entry.api).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test(
      'entry.build(entry.knobs) constructs without throwing, for every '
      "entry's default knobs",
      () {
        for (final entry in compositionEntries) {
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
        // Keyed by api, same as motionEntries' equivalent test: GlassGlow
        // mounts two `InteractiveGlass`es, and a mismatched tree shape
        // between two entries sharing a slot is exactly what this repo's
        // InteractiveGlass tree-shape bug (docs/TODO.md) reaches.
        for (final entry in compositionEntries) {
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

    testWidgets(
      'every entry lays out inside the FittedBox thumbnail slot '
      '_EntryRow uses, at default knobs',
      (tester) async {
        // `_EntryRow` (index_page.dart) puts every entry's specimen in a
        // fixed 44x44 slot via FittedBox(fit: BoxFit.cover, child: ...),
        // and FittedBox gives its child unbounded constraints in the
        // axis it scales. A Stack whose only children are Positioned
        // then takes constraints.biggest, gets infinite width and never
        // lays out at all (docs/TODO.md, "the FittedBox also imposes
        // unbounded width") — found in Cross-pass overlap, which used
        // to keep throwing every frame there, unlike its three siblings.
        for (final entry in compositionEntries) {
          await tester.pumpWidget(
            MaterialApp(
              home: GlassLayer(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(10),
                    ),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: KeyedSubtree(
                        key: ValueKey(entry.api),
                        child: entry.build(entry.knobs),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          // A not-yet-laid-out transform ancestor (FittedBox included)
          // makes `getTransformTo` throw on the very first frame — a
          // known, unfixed package bug (docs/TODO.md) unrelated to this
          // test, which every entry hits here and recovers from once its
          // geometry re-syncs on its own next paint. Tolerated, not
          // asserted away: this test exists to catch the *other*
          // failure, one that keeps throwing past that first frame.
          tester.takeException();
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason:
                '${entry.api} kept throwing under an unbounded-width '
                'FittedBox past the first, known frame',
          );
        }
      },
    );

    // Not a compile check — see the equivalent comment in surfacesEntries.
    // The knob-move tests below guard the drift-free property.
    test("every entry's code is non-empty at its default knobs", () {
      for (final entry in compositionEntries) {
        expect(
          renderSnippet(entry),
          isNotEmpty,
          reason: '${entry.api} rendered no snippet',
        );
      }
    });

    // --- moving a knob moves both build and code -------------------------

    CatalogueEntry entryNamed(String api) =>
        compositionEntries.firstWhere((entry) => entry.api == api);

    test(
      'GlassPresence — moving presence changes the built animation value '
      'and the snippet',
      () {
        final entry = entryNamed('GlassPresence');
        expect(entry.knobs[0].value, 1.0, reason: 'sanity: default');

        final moved = entry.withKnob(0, 0.0);
        final built =
            (moved.build(moved.knobs) as SizedBox).child! as GlassPresence;

        expect(built.presence.value, 0.0);
        expect(
          renderSnippet(moved),
          contains('AlwaysStoppedAnimation<double>(0.00)'),
        );
      },
    );

    testWidgets(
      'GlassHostScope — moving radius changes the on-content Glass and '
      'the snippet',
      (tester) async {
        final entry = entryNamed('GlassHostScope');
        expect(entry.knobs[0].value, 20.0, reason: 'sanity: default');

        final moved = entry.withKnob(0, 36.0);
        await tester.pumpWidget(
          MaterialApp(
            home: GlassLayer(child: Center(child: moved.build(moved.knobs))),
          ),
        );
        await tester.pumpAndSettle();

        bool isRoundedRectGlass(Widget widget) =>
            widget is Glass && widget.shape is GlassRoundedRectangle;
        final onContent = tester.widget<Glass>(
          find.byWidgetPredicate(isRoundedRectGlass),
        );
        expect(
          (onContent.shape as GlassRoundedRectangle).radius,
          const BorderRadius.all(Radius.circular(36)),
        );
        expect(renderSnippet(moved), contains('Radius.circular(36.0)'));
      },
    );

    testWidgets(
      'GlassHostScope — the on-content control is real glass and the '
      'toolbar one paints instead, with no assertion thrown',
      (tester) async {
        final entry = entryNamed('GlassHostScope');
        await tester.pumpWidget(
          MaterialApp(
            home: GlassLayer(child: Center(child: entry.build(entry.knobs))),
          ),
        );
        await tester.pumpAndSettle();

        // On content: exactly one real Glass draws the rounded-rect
        // control. If the toolbar's copy also drew a Glass, nesting one
        // inside the toolbar's own Glass would have asserted below.
        bool isRoundedRectGlass(Widget widget) =>
            widget is Glass && widget.shape is GlassRoundedRectangle;
        expect(
          find.byWidgetPredicate(isRoundedRectGlass),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    test(
      'GlassGlow — moving separation changes the built gap and the '
      'snippet',
      () {
        final entry = entryNamed('GlassGlow');
        expect(entry.knobs[0].value, 40.0, reason: 'sanity: default');

        final moved = entry.withKnob(0, 120.0);
        final row = moved.build(moved.knobs) as Row;
        final gap = row.children[1] as SizedBox;

        expect(gap.width, 120.0);
        expect(renderSnippet(moved), contains('SizedBox(width: 120.0)'));
      },
    );

    testWidgets(
      'GlassGlow — pressing one surface publishes into the shared layer '
      "channel the neighbour's pass reads",
      (tester) async {
        final entry = entryNamed('GlassGlow');
        ValueNotifier<GlassGlow>? glow;

        await tester.pumpWidget(
          MaterialApp(
            home: GlassLayer(
              child: Center(
                child: Builder(
                  builder: (context) {
                    glow = GlassGlowScope.maybeOf(context)?.glow;
                    return entry.build(entry.knobs);
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(glow, isNotNull);
        expect(glow!.value.strength, 0, reason: 'sanity: nothing pressed');

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(InteractiveGlass).first),
        );
        // Several short pumps, not one long one: the press spring's
        // `Ticker` advances from its own last tick, so one 150ms jump
        // evaluates a single simulation step while ten 16ms ones (roughly
        // a frame each) let it climb the way a real press would.
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(
          glow!.value.strength,
          greaterThan(0),
          reason:
              'both surfaces share one GlassLayer, so a press on '
              "either writes into the same channel the neighbour's pass "
              'reads every paint — the mechanism the 320-radius reach in '
              'glow_gating_test.dart proves lands on screen',
        );
        expect(glow!.value.radius, 320);

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Cross-pass overlap — moving offset changes the built position and '
      'the snippet',
      (tester) async {
        final entry = entryNamed('Cross-pass overlap');
        expect(entry.knobs[0].value, 30.0, reason: 'sanity: default');

        final moved = entry.withKnob(0, 100.0);
        await tester.pumpWidget(
          MaterialApp(
            home: GlassLayer(child: Center(child: moved.build(moved.knobs))),
          ),
        );
        await tester.pumpAndSettle();

        bool isOffsetShape(Widget widget) =>
            widget is Positioned && widget.left != 0;
        final positioned = tester.widget<Positioned>(
          find.byWidgetPredicate(isOffsetShape),
        );
        expect(positioned.left, 100.0);
        expect(renderSnippet(moved), contains('left: 100.0'));
      },
    );

    testWidgets(
      'Cross-pass overlap — the demo captures the real debugPrint '
      'warning on screen',
      (tester) async {
        final entry = entryNamed('Cross-pass overlap');
        await tester.pumpWidget(
          MaterialApp(
            home: GlassLayer(child: Center(child: entry.build(entry.knobs))),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('glass_forge: two glass shapes'),
          findsOneWidget,
          reason:
              'the default offset overlaps two differing materials, '
              'so the real RenderGlassLayer warning must have fired and '
              'been captured on screen, not just described',
        );
      },
    );

    testWidgets(
      'Cross-pass overlap — separating the shapes leaves the warning '
      'unfired',
      (tester) async {
        final entry = entryNamed('Cross-pass overlap');
        final separated = entry.withKnob(0, 140.0);
        await tester.pumpWidget(
          MaterialApp(
            home: GlassLayer(
              child: Center(child: separated.build(separated.knobs)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('glass_forge: two glass shapes'),
          findsNothing,
        );
      },
    );
  });

  group('chromeEntries', () {
    test('the group has its promised four entries', () {
      expect(chromeEntries, hasLength(4));
    });

    test('every entry names its api, its purpose and at least one knob', () {
      for (final entry in chromeEntries) {
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

    test('every entry names the Chrome group', () {
      for (final entry in chromeEntries) {
        expect(entry.group, 'Chrome');
      }
    });

    test('every entry api is unique', () {
      final names = chromeEntries.map((entry) => entry.api).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test(
      'entry.build(entry.knobs) constructs without throwing, for every '
      "entry's default knobs",
      () {
        for (final entry in chromeEntries) {
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
        // Keyed by api, same as the motion and composition groups: three
        // of these four build a `GlassDetentSheet` and one builds a row of
        // bare `Glass`, and without a key Flutter's element diffing would
        // update one entry's sheet in place into the next entry's — which
        // is not what the real app does, since one catalogue page never
        // turns into another without a route push between them.
        for (final entry in chromeEntries) {
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

    // Not a compile check — see the equivalent comment in surfacesEntries.
    // The knob-move tests below guard the drift-free property.
    test("every entry's code is non-empty at its default knobs", () {
      for (final entry in chromeEntries) {
        expect(
          renderSnippet(entry),
          isNotEmpty,
          reason: '${entry.api} rendered no snippet',
        );
      }
    });

    // --- moving a knob moves both build and code -------------------------

    CatalogueEntry entryNamed(String api) =>
        chromeEntries.firstWhere((entry) => entry.api == api);

    /// Mounts [entry] and hands back the controller the sheet it built is
    /// actually driven by, read off the real `GlassDetentSheetScope` the
    /// sheet publishes to its own content.
    ///
    /// Keyed by the knob's value so that mounting a second variant in one
    /// test replaces the sheet rather than updating the first one in place
    /// — which would leave the controller from the first mount attached and
    /// make the assertion about the second meaningless.
    ///
    /// `GeometryTier.none`, the same tier the package's own chrome tests
    /// use and for the same reason: off Impeller the runtime producer
    /// rasterises the signed-distance field on the CPU, seconds per bake,
    /// once per frame of a moving sheet. Nothing below reads the matte —
    /// these assertions are about fields and heights — and the group's
    /// `every entry mounts and paints` test above is where real geometry is
    /// exercised.
    Future<GlassDetentSheetController> mountSheet(
      WidgetTester tester,
      CatalogueEntry entry,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GlassLayer(
            tier: GeometryTier.none,
            child: Center(
              child: KeyedSubtree(
                key: ValueKey<Object?>(entry.knobs.first.value),
                child: entry.build(entry.knobs),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester
          .widget<GlassDetentSheetScope>(find.byType(GlassDetentSheetScope))
          .controller;
    }

    testWidgets(
      'GlassDetentSheet — moving lowest changes the built detent list, the '
      'height it resolves to and the snippet',
      (tester) async {
        final entry = entryNamed('GlassDetentSheet');
        expect(entry.knobs[0].value, 0.3, reason: 'sanity: default');

        final atDefault = await mountSheet(tester, entry);
        final lowestAtDefault = atDefault.lowest;

        final moved = entry.withKnob(0, 0.42);
        final atMoved = await mountSheet(tester, moved);
        final sheet = tester.widget<GlassDetentSheet>(
          find.byType(GlassDetentSheet),
        );

        expect(sheet.detents.first, const GlassDetent.fraction(0.42));
        expect(
          atMoved.lowest,
          greaterThan(lowestAtDefault),
          reason:
              'the knob reached the resolved pixel heights, not only the '
              'list of detents the sheet was handed',
        );
        expect(renderSnippet(moved), contains('GlassDetent.fraction(0.42)'));
      },
    );

    testWidgets(
      'GlassDetentSheet — the tab row hands off rather than rendering a '
      'second backdrop pass under the sheet',
      (tester) async {
        final entry = entryNamed('GlassDetentSheet');
        final controller = await mountSheet(tester, entry);

        expect(
          find.text('Explore'),
          findsOneWidget,
          reason:
              'at the lowest detent the sheet still clears the row, so the '
              'row is there to be handed off from',
        );

        controller.animateToDetent(2);
        await tester.pumpAndSettle();

        expect(
          find.text('Explore'),
          findsNothing,
          reason:
              "a flush sheet covers the row's pixels, so the presence ramp "
              'must have taken the row out of the tree before the sheet '
              'arrived — two backdrop passes over one region is '
              'flutter#187820',
        );
      },
    );

    testWidgets(
      'GlassDetent — moving available rescales the fraction, clamps the '
      'fixed height and leaves the content one where it was',
      (tester) async {
        final entry = entryNamed('GlassDetent');
        expect(entry.knobs[0].value, 200.0, reason: 'sanity: default');

        // `GeometryTier.none` for the reason [mountSheet] gives: these are
        // laid-out heights, and baking three signed-distance fields on the
        // CPU to read them back costs seconds and proves nothing extra.
        Future<Map<String, double>> barHeights(CatalogueEntry variant) async {
          await tester.pumpWidget(
            MaterialApp(
              home: GlassLayer(
                tier: GeometryTier.none,
                child: Center(child: variant.build(variant.knobs)),
              ),
            ),
          );
          await tester.pumpAndSettle();
          return <String, double>{
            for (final name in const <String>['fraction', 'height', 'content'])
              name: tester
                  .getSize(
                    find.descendant(
                      of: find.byKey(ValueKey<String>(name)),
                      matching: find.byType(Glass),
                    ),
                  )
                  .height,
          };
        }

        expect(await barHeights(entry), <String, double>{
          'fraction': 100,
          'height': 180,
          'content': 96,
        });

        final moved = entry.withKnob(0, 140.0);
        expect(
          await barHeights(moved),
          <String, double>{'fraction': 70, 'height': 140, 'content': 96},
          reason:
              'the fraction is half of whatever is available, the fixed '
              'height is clamped down to it, and the content height is '
              'below both and so unmoved',
        );
        expect(renderSnippet(moved), contains('available: 140.0'));
      },
    );

    testWidgets(
      'GlassDetentSheetController — moving the knob animates the real '
      'controller to that detent, and the snippet says so',
      (tester) async {
        final entry = entryNamed('GlassDetentSheetController');
        expect(entry.knobs[0].value, 'Peek', reason: 'sanity: default');

        // Deliberately unkeyed, unlike [mountSheet]: this entry's knob is
        // applied in `didUpdateWidget`, so the second pump has to *update*
        // the same element rather than replace it — which is exactly what
        // the entry page does when a knob moves. `GeometryTier.none` for
        // the reason [mountSheet] gives.
        Future<void> pump(CatalogueEntry variant) async {
          await tester.pumpWidget(
            MaterialApp(
              home: GlassLayer(
                tier: GeometryTier.none,
                child: Center(child: variant.build(variant.knobs)),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await pump(entry);
        final controller = tester
            .widget<GlassDetentSheetScope>(find.byType(GlassDetentSheetScope))
            .controller;
        expect(controller.detent, 0, reason: 'sanity: opened at Peek');
        expect(controller.value, controller.lowest);

        final moved = entry.withKnob(0, 'Full');
        await pump(moved);

        expect(controller.detent, 2);
        expect(
          controller.value,
          controller.top,
          reason: 'the spring actually carried the sheet there',
        );
        expect(renderSnippet(moved), contains('animateToDetent(2)'));
      },
    );

    testWidgets(
      "GlassSheetScrollPhysics — moving the knob changes the built list's "
      'physics and the snippet',
      (tester) async {
        final entry = entryNamed('GlassSheetScrollPhysics');
        expect(entry.knobs[0].value, 'inherited', reason: 'sanity: default');

        await mountSheet(tester, entry);
        // `AlwaysScrollableScrollPhysics`, not null: `ScrollView` fills a
        // null `physics` in for a vertical list with no controller of its
        // own, and that stand-in does not override
        // `applyPhysicsToUserOffset` — so it delegates to its parent, which
        // is the sheet's `GlassSheetScrollPhysics`, and the handoff still
        // runs. The entry's snippet says `physics: null` because that is
        // what the caller writes; this is what the widget records.
        expect(
          tester.widget<ListView>(find.byType(ListView)).physics,
          isA<AlwaysScrollableScrollPhysics>(),
          reason:
              'inherited means the list takes whatever the sheet put in '
              'its ScrollConfiguration',
        );

        final moved = entry.withKnob(0, 'overridden');
        await mountSheet(tester, moved);
        expect(
          tester.widget<ListView>(find.byType(ListView)).physics,
          isA<BouncingScrollPhysics>(),
        );
        expect(
          renderSnippet(moved),
          contains('physics: const BouncingScrollPhysics()'),
        );
      },
    );

    testWidgets(
      'GlassSheetScrollPhysics — inherited, a drag on the list carries the '
      'sheet; overridden, the same drag does not reach it',
      (tester) async {
        final entry = entryNamed('GlassSheetScrollPhysics');

        /// How far the sheet rose while a drag on the list was still down.
        ///
        /// Measured mid-gesture rather than after it: the drag is well
        /// short of the next detent, so a released sheet springs back to
        /// where it started and a rise measured afterwards would be zero
        /// in both cases.
        Future<double> riseUnderDrag(CatalogueEntry variant) async {
          final controller = await mountSheet(tester, variant);
          final before = controller.value;
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(ListView)),
          );
          await tester.pump();
          // Two moves, not one. `Scrollable` recognises a drag with
          // `DragStartBehavior.start`, which rebases the gesture's origin on
          // the frame it wins the arena — so the move that crosses the touch
          // slop is consumed entirely by the start and carries no delta.
          // Only the second one is a scroll offset anything sees.
          await gesture.moveBy(const Offset(0, -kDragSlopDefault));
          await tester.pump();
          await gesture.moveBy(const Offset(0, -60));
          await tester.pump();
          final rise = controller.value - before;
          await gesture.up();
          await tester.pumpAndSettle();
          return rise;
        }

        expect(
          await riseUnderDrag(entry),
          greaterThan(0),
          reason:
              'below the top detent the sheet owns every vertical delta, '
              'and the physics is what hands them over',
        );
        expect(
          await riseUnderDrag(entry.withKnob(0, 'overridden')),
          0,
          reason:
              "a list that names its own physics becomes the handoff's "
              'parent and never delegates to it — the documented opt-out '
              'this knob exists to show',
        );
      },
    );
  });
}
