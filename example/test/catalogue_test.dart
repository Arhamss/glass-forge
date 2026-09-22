import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/backdrop_info.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';
import 'package:glass_forge_example/src/catalogue/entries/adaptation.dart';
import 'package:glass_forge_example/src/catalogue/entries/chrome.dart';
import 'package:glass_forge_example/src/catalogue/entries/composition.dart';
import 'package:glass_forge_example/src/catalogue/entries/design_system.dart';
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

    testWidgets(
      'GlassMaterial — moving the preset changes the built material and '
      'the printed constructor',
      (tester) async {
        final entry = entryNamed('GlassMaterial');

        /// The material [variant]'s specimen actually resolved to, with
        /// the platform pinned.
        ///
        /// `copyWith` off the real `MediaQuery` inside the app, the same
        /// way designSystemEntries pins a scheme, so the view's own size
        /// and padding survive and the brightness is the only thing moved.
        /// Keyed on the knob *and* the brightness so every mount replaces
        /// the specimen rather than updating it in place — `regular` reads
        /// the scheme through the element tree, and an updated subtree
        /// would leave one assertion passing for an earlier mount's
        /// reasons.
        Future<GlassMaterial?> materialUnder(
          CatalogueEntry variant, {
          required Brightness platformBrightness,
        }) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(platformBrightness: platformBrightness),
                  child: GlassLayer(
                    tier: GeometryTier.none,
                    child: Center(
                      child: KeyedSubtree(
                        key: ValueKey<String>(
                          '$platformBrightness|'
                          '${variant.knobs.map(
                            (knob) => '${knob.value}',
                          ).join('|')}',
                        ),
                        child: variant.build(variant.knobs),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          return tester.widget<Glass>(find.byType(Glass)).material;
        }

        // What each preset must build, and what it must print, stated
        // here rather than read back off the entry.
        //
        // Reading `preset.constructorCode` and asserting the snippet
        // contains it is the assertion this replaces: `code` interpolates
        // that same field, so it compared a string to itself and passed
        // for a preset that printed `GlassMaterial.clear()` while
        // building `GlassMaterial.dome()`. An expectation taken from the
        // thing under test cannot observe the thing under test. The
        // materials below are constructed independently and compared to
        // what `build` really resolved to on screen, which costs one
        // pump per preset — three, at `GeometryTier.none`.
        //
        // `regular` is pinned to light here because the loop mounts in
        // light; the two-scheme assertions below are what prove it is
        // resolved rather than pinned.
        final expected = <String, ({GlassMaterial material, String printed})>{
          'regular': (
            material: GlassMaterial.regular(brightness: Brightness.light),
            printed:
                'material: GlassMaterial.regular(\n'
                '    brightness: GlassTheme.brightnessOf(context),\n'
                '  ),',
          ),
          'clear': (
            material: GlassMaterial.clear(),
            printed: 'material: GlassMaterial.clear(),',
          ),
          'dome': (
            material: GlassMaterial.dome(),
            printed: 'material: GlassMaterial.dome(),',
          ),
        };

        expect(
          entry.knobs[0].options.map(entry.knobs[0].labelFor).toSet(),
          expected.keys.toSet(),
          reason:
              'a preset with no expectation here would otherwise be '
              'carried by the loop without being checked at all',
        );

        for (final preset in entry.knobs[0].options) {
          final name = entry.knobs[0].labelFor(preset);
          final moved = entry.withKnob(0, preset);
          final built = await materialUnder(
            moved,
            platformBrightness: Brightness.light,
          );

          expect(
            built,
            expected[name]!.material,
            reason: '$name built a material that is not the one it names',
          );
          expect(
            renderSnippet(moved),
            contains(expected[name]!.printed),
            reason: '$name printed a constructor it does not build',
          );
        }

        // `regular` is the one preset that takes a brightness, and it is
        // the knob's default — the first line a reader copies. It reads
        // the scheme it is actually in rather than a value this file
        // pinned, so the specimen and the snippet are both right in light
        // mode and in dark. A pinned `Brightness.dark` would fit frost,
        // saturation, tint and tint opacity to the wrong scheme for half
        // of readers, and the snippet would print that wrong value.
        expect(
          entry.knobs[0].labelFor(entry.knobs[0].value),
          'regular',
          reason: 'sanity: the default position is the adaptive one',
        );

        final inLight = await materialUnder(
          entry,
          platformBrightness: Brightness.light,
        );
        final inDark = await materialUnder(
          entry,
          platformBrightness: Brightness.dark,
        );

        expect(inLight, GlassMaterial.regular(brightness: Brightness.light));
        expect(inDark, GlassMaterial.regular(brightness: Brightness.dark));
        expect(
          inLight,
          isNot(inDark),
          reason:
              'the two fitted schemes differ, so a preset that pinned one '
              'would be wrong wherever the reader is in the other',
        );

        final snippet = renderSnippet(entry);
        expect(snippet, contains('GlassTheme.brightnessOf(context)'));
        expect(
          snippet,
          isNot(contains('Brightness.dark')),
          reason:
              'the snippet hands a reader the call that resolves their own '
              'scheme, never a literal fitted to one of the two',
        );
        expect(snippet, isNot(contains('Brightness.light')));
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
            otherPreset!
                as ({
                  String name,
                  String constructorCode,
                  GlassMotion motion,
                });

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
        expect(
          renderSnippet(moved),
          contains('jiggle is left'),
          // The disclosure itself, not the word. The snippet says
          // "the velocity jiggle reads" a line later, so `contains('jiggle')`
          // survives deleting the clause this guards and asserts nothing.
          reason:
              'the entry shows one channel resolved explicitly and one '
              'neutralised for free, and the snippet is the only place a '
              'reader can be told about the second — leave it out and the '
              'untouched jiggle reads as an oversight',
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
        // unbounded width") — found in Cross-pass overlap.
        //
        // A single `tester.takeException()` right after `pumpWidget`
        // cannot guard this: both the known, tolerated first-frame
        // `getTransformTo` exception (docs/TODO.md bug #1 — every entry
        // here has a `Glass`, so every entry hits it) *and* the Stack
        // regression this test exists to catch fire during that same
        // `pumpWidget` call, and calling `takeException()` once
        // discards whichever it returns without telling them apart —
        // confirmed by reverting the fix with this test left as
        // originally written and watching it still report "All tests
        // passed!". So every individual `FlutterErrorDetails` raised
        // during that call is captured here instead, and each one is
        // checked against the known bug's own exact signature —
        // `RenderGlassShape._syncGeometry` calling `getTransformTo`
        // into a not-yet-laid-out ancestor — rather than merely
        // counting or discarding them.
        for (final entry in compositionEntries) {
          final caught = <FlutterErrorDetails>[];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = caught.add;
          try {
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
          } finally {
            FlutterError.onError = originalOnError;
          }

          for (final details in caught) {
            final isKnownFirstFrameBug =
                details.exception.toString().contains(
                  "Failed assertion: line 2251 pos 12: 'hasSize'",
                ) &&
                details.stack.toString().contains(
                  'RenderGlassShape._syncGeometry',
                );
            expect(
              isKnownFirstFrameBug,
              isTrue,
              reason:
                  '${entry.api} threw under an unbounded-width FittedBox '
                  'with something other than the known, tolerated '
                  'first-frame geometry exception: ${details.exception}',
            );
          }

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
        expect(
          row.mainAxisAlignment,
          MainAxisAlignment.center,
          reason: 'sanity: the specimen centres its pair',
        );
        expect(
          renderSnippet(moved),
          contains('mainAxisAlignment: MainAxisAlignment.center'),
          reason:
              'and the snippet says so — a copied Row defaults to start, '
              'which puts the two shapes somewhere else entirely',
        );
        expect(
          renderSnippet(moved),
          contains('centres are 240.0 apart'),
          reason:
              'the distance the glow has to cross is the gap plus a '
              "shape's width, and it moves with the knob — a fixed number "
              'in the comment would be right at one position only',
        );
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
        expect(
          renderSnippet(entry),
          contains('${glow!.value.radius.toStringAsFixed(0)} points'),
          reason:
              'the reach is what the top of this knob runs out of, and it '
              "is InteractiveGlass's own private constant — so the snippet "
              'has to name the number the widget actually published, or a '
              'reader reads a dark neighbour as a broken feature',
        );

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

    // The frame is the one thing on these pages that is not the reader's
    // own code, and it changes what every fraction and gap printed below
    // it means. A `///` saying so reaches nobody — `CatalogueEntry` has no
    // prose field past `purpose` — so the snippet has to say it, and this
    // is what stops it being deleted as noise. `GlassDetent` is named
    // explicitly rather than skipped: it resolves three detents against a
    // knob instead of standing a sheet in a frame, so a note about a frame
    // there would be false.
    test('every snippet that stands a sheet in the frame discloses it', () {
      for (final api in <String>[
        'GlassDetentSheet',
        'GlassDetentSheetController',
        'GlassSheetScrollPhysics',
      ]) {
        final snippet = renderSnippet(entryNamed(api));
        expect(
          snippet,
          contains('248-point tall frame'),
          reason: '$api prints fractions of a frame it never names',
        );
        expect(
          snippet,
          contains('MediaQuery.paddingOf(context).top'),
          reason:
              '$api says the specimen is framed but not what a real sheet '
              'measures against instead',
        );
        // The one omitted argument a reader is worse off without. The
        // other four — gap, floatingRadius, flushRadius, backdrop — are
        // miniatures fitted to this frame, and the note above licenses
        // leaving them out. A sheet with no semanticLabel is unlabelled
        // to a screen reader, and nothing on the page would say so.
        expect(
          snippet,
          contains('semanticLabel:'),
          reason: '$api would be copied into an unlabelled sheet',
        );
      }

      expect(
        renderSnippet(entryNamed('GlassDetent')),
        isNot(contains('248-point tall frame')),
        reason:
            'GlassDetent resolves against its own knob, so claiming a '
            'frame would be claiming something untrue',
      );
    });

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
  group('designSystemEntries', () {
    test('the group has its promised five entries', () {
      expect(designSystemEntries, hasLength(5));
    });

    test('every entry names its api, its purpose and at least one knob', () {
      for (final entry in designSystemEntries) {
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

    test('every entry names the Design system group', () {
      for (final entry in designSystemEntries) {
        expect(entry.group, 'Design system');
      }
    });

    test('every entry api is unique', () {
      final names = designSystemEntries.map((entry) => entry.api).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test(
      'entry.build(entry.knobs) constructs without throwing, for every '
      "entry's default knobs",
      () {
        for (final entry in designSystemEntries) {
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
        // Keyed by api, same as the groups above: four of these five build
        // a `GlassSurface`, and without a key Flutter would update one
        // entry's surface in place into the next entry's — which is not
        // what the real app does, since one catalogue page never turns
        // into another without a route push between them.
        for (final entry in designSystemEntries) {
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
        // The same unbounded-width slot compositionEntries is checked
        // against, and for the same reason: `FittedBox` hands its child
        // infinite width, so a specimen whose root takes
        // `constraints.biggest` never lays out. Every root in this group
        // is a doubly-tight `SizedBox`, and this is what says so.
        //
        // Every individual `FlutterErrorDetails` is captured and matched
        // against the known first-frame bug's own signature, rather than
        // one `tester.takeException()` discarding whichever of them it
        // returns. That shortcut cannot fail: the binding collapses
        // several errors from one `pumpWidget` into a synthetic
        // "Multiple exceptions" string and throws the originals away, and
        // every entry here has a `Glass`, so the known bug fires at least
        // once before any regression exists to be seen. Same collector and
        // same signature as compositionEntries — see the long note there.
        for (final entry in designSystemEntries) {
          final caught = <FlutterErrorDetails>[];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = caught.add;
          try {
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
          } finally {
            FlutterError.onError = originalOnError;
          }

          for (final details in caught) {
            final isKnownFirstFrameBug =
                details.exception.toString().contains(
                  "Failed assertion: line 2251 pos 12: 'hasSize'",
                ) &&
                details.stack.toString().contains(
                  'RenderGlassShape._syncGeometry',
                );
            expect(
              isKnownFirstFrameBug,
              isTrue,
              reason:
                  '${entry.api} threw under an unbounded-width FittedBox '
                  'with something other than the known, tolerated '
                  'first-frame geometry exception: ${details.exception}',
            );
          }

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
      for (final entry in designSystemEntries) {
        expect(
          renderSnippet(entry),
          isNotEmpty,
          reason: '${entry.api} rendered no snippet',
        );
      }
    });

    // --- moving a knob moves both build and code -------------------------

    CatalogueEntry entryNamed(String api) =>
        designSystemEntries.firstWhere((entry) => entry.api == api);

    /// Mounts [variant] with the platform pinned to [platformBrightness].
    ///
    /// Pinned rather than left to the test binding, because three of these
    /// entries resolve a scheme and every number they land on — a tint
    /// opacity, a label colour, a contrast — is a different number in the
    /// other one. `copyWith` off the real `MediaQuery` rather than a bare
    /// `MediaQueryData`, so the view's own size and padding survive.
    ///
    /// Keyed on the knob values so that mounting a second variant replaces
    /// the specimen rather than updating the first in place: a
    /// `GlassSurface` reads its theme through `dependOnInheritedWidget`,
    /// and an updated-in-place subtree would leave an assertion about the
    /// second variant passing for reasons belonging to the first.
    ///
    /// `GeometryTier.none` for the reason chromeEntries gives: off
    /// Impeller the signed-distance field is baked on the CPU, and nothing
    /// below reads the matte — these assertions are about materials,
    /// radii and painted colours. The group's `mounts and paints` test
    /// above is where real geometry is exercised.
    Future<void> pump(
      WidgetTester tester,
      CatalogueEntry variant, {
      Brightness platformBrightness = Brightness.light,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(platformBrightness: platformBrightness),
              child: GlassLayer(
                tier: GeometryTier.none,
                child: Center(
                  child: KeyedSubtree(
                    key: ValueKey<String>(
                      variant.knobs.map((knob) => '${knob.value}').join('|'),
                    ),
                    child: variant.build(variant.knobs),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// The material [glass] was actually given.
    ///
    /// `Glass.material` is nullable because a bare `Glass` inherits its
    /// layer's, and every `Glass` read below was built by a `GlassSurface`,
    /// which always names one. Asserting that rather than reaching through
    /// it with `!` means a surface that ever stopped resolving its own
    /// material fails here with a sentence instead of a null error.
    GlassMaterial materialOf(Glass glass) {
      final material = glass.material;
      expect(
        material,
        isNotNull,
        reason: 'a GlassSurface resolves its own material, never inherits',
      );
      return material!;
    }

    /// The one [Glass] the `GlassSurface` under [key] built.
    Glass glassUnder(WidgetTester tester, String key) {
      return tester.widget<Glass>(
        find.descendant(
          of: find.byKey(ValueKey<String>(key)),
          matching: find.byType(Glass),
        ),
      );
    }

    testWidgets(
      'GlassTheme — moving brightness moves the scheme every surface '
      'under it resolves in, and the snippet',
      (tester) async {
        final entry = entryNamed('GlassTheme');
        expect(entry.knobs[0].value, 'platform', reason: 'sanity: default');

        final light = entry.withKnob(0, 'light');
        await pump(tester, light, platformBrightness: Brightness.dark);
        expect(
          materialOf(glassUnder(tester, 'card')).tint,
          GlassTintRamp.appleLight.color,
          reason:
              'a pinned brightness wins over the platform, or the theme '
              'would not be the thing deciding',
        );
        expect(
          materialOf(glassUnder(tester, 'control')).tint,
          GlassTintRamp.appleLight.color,
          reason: 'and it reaches every surface underneath, not just one',
        );

        final dark = entry.withKnob(0, 'dark');
        await pump(tester, dark, platformBrightness: Brightness.dark);
        expect(
          materialOf(glassUnder(tester, 'card')).tint,
          GlassTintRamp.appleDark.color,
        );
        expect(
          materialOf(glassUnder(tester, 'control')).tint,
          GlassTintRamp.appleDark.color,
        );
        expect(renderSnippet(dark), contains('brightness: Brightness.dark'));
        expect(
          renderSnippet(entry),
          contains('follows the platform'),
          reason: 'the default position says what null means',
        );
        expect(
          renderSnippet(entry),
          contains('Neither surface is given a backdrop'),
          reason:
              'a reader who adds one finds the knob stops reaching the '
              'control, which is the size gate doing its job and not the '
              'theme failing — and the snippet is the only place they can '
              'be told',
        );
      },
    );

    testWidgets(
      'GlassSurface — moving role changes the resolved radius the built '
      'Glass carries, and the snippet',
      (tester) async {
        final entry = entryNamed('GlassSurface');
        expect(
          entry.knobs[0].value,
          GlassSurfaceRole.card,
          reason: 'sanity: default',
        );

        BorderRadius radiusOf(WidgetTester tester) {
          final glass = tester.widget<Glass>(find.byType(Glass));
          return (glass.shape as GlassSuperellipse).radius;
        }

        await pump(tester, entry);
        expect(
          radiusOf(tester),
          BorderRadius.circular(const GlassRadiusScale().medium),
          reason: 'GlassSurfaceSpec.card asks for the medium rung',
        );

        final moved = entry.withKnob(0, GlassSurfaceRole.navigationBar);
        await pump(tester, moved);
        expect(
          radiusOf(tester),
          BorderRadius.circular(const GlassRadiusScale().large),
          reason:
              'GlassSurfaceSpec.navigationBar asks for the large rung — '
              'the knob reached the resolved style, not only the enum',
        );
        expect(renderSnippet(moved), contains('GlassSurface.navigationBar('));
        expect(
          renderSnippet(moved),
          contains('radius large'),
          reason: "the snippet's facts come off the role's real spec",
        );
      },
    );

    testWidgets(
      'GlassSurface — every role resolves, and the surface prints the '
      'contrast it actually reached over the measured backdrop',
      (tester) async {
        final entry = entryNamed('GlassSurface');
        for (final role in GlassSurfaceRole.values) {
          await pump(tester, entry.withKnob(0, role));
          expect(
            find.text(role.name),
            findsOneWidget,
            reason: '$role did not name itself',
          );
          expect(
            find.textContaining(':1'),
            findsOneWidget,
            reason:
                '$role printed no contrast, so the backdrop never reached '
                'GlassSurfaceStyle.labelContrast',
          );
        }
      },
    );

    testWidgets(
      'GlassTokens — moving a rung changes the frost and the radius the '
      'built Glass carries, and the snippet',
      (tester) async {
        final entry = entryNamed('GlassTokens');
        expect(entry.knobs[0].value, 14.0, reason: 'sanity: blur.thick');
        expect(entry.knobs[1].value, 44.0, reason: 'sanity: radius.xl');

        await pump(tester, entry);
        final atDefault = tester.widget<Glass>(find.byType(Glass));
        expect(
          (atDefault.shape as GlassSuperellipse).radius,
          BorderRadius.circular(44),
        );

        final moved = entry.withKnob(0, 28.0).withKnob(1, 20.0);
        await pump(tester, moved);
        final atMoved = tester.widget<Glass>(find.byType(Glass));

        expect(
          materialOf(atMoved).frost,
          closeTo(materialOf(atDefault).frost * 2, 1e-9),
          reason:
              'blur steps are a ratio to the scale own regular, which the '
              'knob left at 7 — so doubling thick doubles the sheet frost',
        );
        expect(
          (atMoved.shape as GlassSuperellipse).radius,
          BorderRadius.circular(20),
        );
        expect(renderSnippet(moved), contains('GlassBlurScale(thick: 28.0)'));
        expect(
          renderSnippet(moved),
          contains('GlassRadiusScale(extraLarge: 20.0)'),
        );
        // The radius knob stops well short of what GlassRadiusScale takes,
        // and the reason is this specimen's own height rather than the
        // token: a corner radius clamps to half the shorter side. A
        // ceiling with no stated reason reads as the token's limit.
        expect(entry.knobs[1].max, 58.0, reason: 'sanity: the ceiling');
        expect(
          renderSnippet(moved),
          contains('stops at 58.0'),
          reason: 'the snippet names the ceiling the knob actually has',
        );
        expect(
          renderSnippet(moved),
          contains('clamps to half the shorter side'),
          reason: 'and says whose limit it is, not just that there is one',
        );
      },
    );

    testWidgets(
      'GlassTintStep — moving the step changes the tint opacity the built '
      'Glass carries, and the snippet',
      (tester) async {
        final entry = entryNamed('GlassTintStep');
        expect(
          entry.knobs[0].value,
          GlassTintStep.regular,
          reason: 'sanity: default',
        );

        double opacityOf(WidgetTester tester) =>
            materialOf(tester.widget<Glass>(find.byType(Glass))).tintOpacity;

        // Pinned light, so the ramp these numbers come off is a stated
        // one rather than whatever the binding defaulted to.
        const ramp = GlassTintRamp.appleLight;

        await pump(tester, entry);
        expect(opacityOf(tester), closeTo(ramp.regular, 1e-9));

        final moved = entry.withKnob(0, GlassTintStep.opaque);
        await pump(tester, moved);
        expect(
          opacityOf(tester),
          closeTo(ramp.opaque, 1e-9),
          reason:
              'the step reached GlassSurfaceSpec.card through the theme '
              'and came out the other side as a real tint opacity',
        );
        expect(
          opacityOf(tester),
          greaterThan(ramp.regular),
          reason: 'and the ramp is monotone, so the surface got thicker',
        );
        expect(renderSnippet(moved), contains('GlassTintStep.opaque'));
        expect(
          renderSnippet(moved),
          contains('No backdrop on the card'),
          reason:
              'the tintOpacity printed beside the specimen is the number a '
              'reader would copy, and in an app that supplies a backdrop '
              'the solver raises it — so the snippet has to say the '
              'backdrop is missing on purpose',
        );
      },
    );

    testWidgets(
      'GlassLegibility — moving the target changes the solved opacity, '
      'the colour painted from it, and the snippet',
      (tester) async {
        final entry = entryNamed('GlassLegibility');
        expect(entry.knobs[0].value, 4.5, reason: 'sanity: default');

        final backdrop = backdropFor(catalogueBackdropPhoto).panelBackdrop;
        const tints = GlassTints();
        // The scheme that *lost* — the one an adapting role is stuck with,
        // and the only one the solver ever has work to do for. Over these
        // photographs the winning scheme clears 7:1 with no tint at all,
        // so a test written against it would pass with the knob disabled.
        final ramp = tints.of(
          tints.schemeFor(backdrop) == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        );

        Color raisedSwatch(WidgetTester tester) => tester
            .widget<ColoredBox>(
              find.byKey(const ValueKey<String>('raised')),
            )
            .color;

        await pump(tester, entry);
        final atDefault = raisedSwatch(tester);
        expect(
          GlassLegibility.contrastRatio(atDefault, ramp.label),
          greaterThanOrEqualTo(4.5),
          reason: 'the solver reached the target it was given',
        );
        expect(
          find.text('The floor already clears it'),
          findsOneWidget,
          reason:
              'at 4.5 the legible step is enough over this backdrop, and '
              'the panel says which of the two rules is in force',
        );

        final moved = entry.withKnob(0, 7.0);
        await pump(tester, moved);
        final atMoved = raisedSwatch(tester);

        expect(
          atMoved,
          isNot(atDefault),
          reason:
              'a higher target takes more tint, and the swatch is painted '
              'with exactly the colour surfaceOver returns for it',
        );
        expect(
          GlassLegibility.contrastRatio(atMoved, ramp.label),
          greaterThanOrEqualTo(7),
        );
        expect(
          find.text('Raised above the floor to reach it'),
          findsOneWidget,
          reason: 'and the caption crossed over with the solved opacity',
        );
        expect(
          tester
              .widget<ColoredBox>(find.byKey(const ValueKey<String>('floor')))
              .color,
          GlassLegibility.surfaceOver(
            tint: ramp.color,
            opacity: ramp.legible,
            backdrop: backdrop,
          ),
          reason:
              'the floor never moves — opacityForContrast only ever '
              'raises tint, never lowers it',
        );
        expect(renderSnippet(moved), contains('target: 7.0'));
      },
    );
  });

  group('adaptationEntries', () {
    test('the group has its promised three entries', () {
      expect(adaptationEntries, hasLength(3));
    });

    test('every entry names its api, its purpose and at least one knob', () {
      for (final entry in adaptationEntries) {
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

    test('every entry names the Adaptation group', () {
      for (final entry in adaptationEntries) {
        expect(entry.group, 'Adaptation');
      }
    });

    test('every entry api is unique', () {
      final names = adaptationEntries.map((entry) => entry.api).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test(
      'entry.build(entry.knobs) constructs without throwing, for every '
      "entry's default knobs",
      () {
        for (final entry in adaptationEntries) {
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
        // Keyed by api, same as the groups above, and with one extra
        // reason here: two of these three own a `GlassTierEngine`, which
        // is a `ChangeNotifier` with three live signals behind it. An
        // updated-in-place subtree would hand the second entry the first
        // entry's engine state instead of disposing it and starting one.
        for (final entry in adaptationEntries) {
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
        // The same unbounded-width slot compositionEntries and
        // designSystemEntries are checked against, for the same reason:
        // `FittedBox` hands its child infinite width, so a specimen whose
        // root takes `constraints.biggest` never lays out. Every root in
        // this group is a doubly-tight `SizedBox`, and this is what says
        // so. The `GeometryTier` specimen is the one that would have been
        // caught here — its `Stack` is exactly the shape of the original
        // bug, and it lays out only because the `SizedBox` above it is
        // tight in both axes.
        //
        // Every individual `FlutterErrorDetails` is captured and matched
        // against the known first-frame bug's own signature, rather than
        // one `tester.takeException()` discarding whichever of them it
        // returns. That shortcut cannot fail: the binding collapses
        // several errors from one `pumpWidget` into a synthetic
        // "Multiple exceptions" string and throws the originals away, and
        // every entry here has a `Glass`, so the known bug fires at least
        // once before any regression exists to be seen. Same collector and
        // same signature as compositionEntries — see the long note there.
        for (final entry in adaptationEntries) {
          final caught = <FlutterErrorDetails>[];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = caught.add;
          try {
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
          } finally {
            FlutterError.onError = originalOnError;
          }

          for (final details in caught) {
            final isKnownFirstFrameBug =
                details.exception.toString().contains(
                  "Failed assertion: line 2251 pos 12: 'hasSize'",
                ) &&
                details.stack.toString().contains(
                  'RenderGlassShape._syncGeometry',
                );
            expect(
              isKnownFirstFrameBug,
              isTrue,
              reason:
                  '${entry.api} threw under an unbounded-width FittedBox '
                  'with something other than the known, tolerated '
                  'first-frame geometry exception: ${details.exception}',
            );
          }

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
      for (final entry in adaptationEntries) {
        expect(
          renderSnippet(entry),
          isNotEmpty,
          reason: '${entry.api} rendered no snippet',
        );
      }
    });

    // --- moving a knob moves both build and code -------------------------

    CatalogueEntry entryNamed(String api) =>
        adaptationEntries.firstWhere((entry) => entry.api == api);

    /// Mounts [variant], keyed on its knob values.
    ///
    /// Keyed so that mounting a second variant replaces the specimen
    /// rather than updating the first in place. That matters more here
    /// than anywhere else in this file: two of these specimens own a
    /// `GlassTierEngine`, and an engine carried across a variant would
    /// bring the previous verdict's dome hysteresis with it.
    ///
    /// `GeometryTier.none` on the *enclosing* layer for the reason
    /// chromeEntries gives — off Impeller the field is baked on the CPU,
    /// and nothing below reads the matte. It does not reach the
    /// `GeometryTier` specimen's own layer, which pins its own.
    Future<void> pump(WidgetTester tester, CatalogueEntry variant) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GlassLayer(
            tier: GeometryTier.none,
            child: Center(
              child: KeyedSubtree(
                key: ValueKey<String>(
                  variant.knobs.map((knob) => '${knob.value}').join('|'),
                ),
                child: variant.build(variant.knobs),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// The verdict the scope in the mounted specimen is publishing.
    ///
    /// Read off the engine the specimen handed its `GlassTierScope`, so
    /// this is `resolveTier`'s own output over four real signals — not a
    /// value the entry stored for the test to find.
    ResolvedTier resolvedOf(WidgetTester tester) {
      final engine = tester
          .widget<GlassTierScope>(find.byType(GlassTierScope))
          .engine;
      expect(
        engine,
        isNotNull,
        reason: 'the specimen owns its engine, so the scope is given one',
      );
      return engine!.value;
    }

    testWidgets(
      'GlassTierScope — moving requested moves the resolved tier, the '
      'material the glass renders with, and the snippet',
      (tester) async {
        final entry = entryNamed('GlassTierScope');
        expect(entry.knobs[0].value, 'auto', reason: 'sanity: default');

        await pump(tester, entry);
        final atDefault = resolvedOf(tester);
        expect(
          atDefault.tier,
          GlassTier.full,
          reason:
              'nothing pinned, and the pinned capability report plus three '
              'quiet signals leave the top rung',
        );
        expect(atDefault.geometry, GeometryTier.accelerated);
        expect(atDefault.dome, isTrue);

        final moved = entry.withKnob(0, 'reduced');
        await pump(tester, moved);
        final atMoved = resolvedOf(tester);

        expect(atMoved.tier, GlassTier.reduced);
        expect(
          atMoved.geometry,
          GeometryTier.portable,
          reason: 'the rung moved the geometry axis with it',
        );
        expect(
          atMoved.dome,
          isFalse,
          reason: 'reduced is where a dome flattens to an edge band',
        );

        // And the verdict reached the glass, rather than only the readout:
        // the material this shape is drawn with is the one the tier left.
        final glass = tester.widget<Glass>(find.byType(Glass));
        final asked = glass.material;
        expect(
          asked,
          isNotNull,
          reason: 'the specimen overrides its layer material by name',
        );
        final effective = atMoved.materialFor(
          asked!,
          brightness: Brightness.light,
        );
        expect(
          effective.edgeRefraction,
          lessThan(asked.edgeRefraction),
          reason: 'reduced halves the lensing it was asked for',
        );
        expect(
          find.text(effective.edgeRefraction.toStringAsFixed(1)),
          findsOneWidget,
          reason: 'and the specimen prints the number it is drawn with',
        );
        expect(find.text('tier reduced'), findsOneWidget);
        expect(renderSnippet(moved), contains('GlassTier.reduced'));
        expect(
          renderSnippet(entry),
          contains('the four signals decide'),
          reason: 'the default position says what null means',
        );
      },
    );

    testWidgets(
      'GlassTierEngine — the capability report moves the ceiling, a '
      'request clears it, and one report it cannot clear',
      (tester) async {
        final entry = entryNamed('GlassTierEngine');
        expect(
          entry.knobs[0].value,
          GraphicsBackend.metal,
          reason: 'sanity: default capabilities',
        );
        expect(entry.knobs[1].value, 'auto', reason: 'sanity: no pin');

        await pump(tester, entry);
        expect(resolvedOf(tester).capabilityCeiling, GlassTier.full);
        expect(resolvedOf(tester).tier, GlassTier.full);

        final gles = entry.withKnob(0, GraphicsBackend.openGLES);
        await pump(tester, gles);
        final atGles = resolvedOf(tester);
        expect(
          atGles.capabilityCeiling,
          GlassTier.balanced,
          reason:
              'a complete report with no accelerated geometry is exactly '
              'the balanced ceiling',
        );
        expect(atGles.tier, GlassTier.balanced);
        expect(find.text('tier balanced'), findsOneWidget);
        expect(
          find.text('false'),
          findsOneWidget,
          reason:
              'acceleratedGeometry is the one false in this report, and '
              'the panel prints the booleans the ceiling is read from',
        );

        final pinned = gles.withKnob(1, 'full');
        await pump(tester, pinned);
        final atPinned = resolvedOf(tester);
        expect(
          atPinned.tier,
          GlassTier.full,
          reason: 'a request beats a capability ceiling',
        );
        expect(
          atPinned.capabilityCeiling,
          GlassTier.balanced,
          reason:
              'the ceiling is still there and still reported — the '
              'request went over it rather than removing it',
        );

        final skia = entry
            .withKnob(0, GraphicsBackend.skia)
            .withKnob(1, 'full');
        await pump(tester, skia);
        final atSkia = resolvedOf(tester);
        expect(atSkia.capabilityCeiling, GlassTier.off);
        expect(
          atSkia.tier,
          GlassTier.off,
          reason:
              'the one ceiling a request cannot lift: without shader '
              'filters the composite pass throws rather than running slow',
        );
        expect(atSkia.requested, GlassTier.full);
        expect(find.text('tier off'), findsOneWidget);

        expect(renderSnippet(skia), contains('shaderFilters: false'));
        expect(renderSnippet(pinned), contains('GlassTier.full'));
        expect(
          renderSnippet(gles),
          contains('acceleratedGeometry: false'),
          reason: 'the snippet quotes the report the specimen was given',
        );
      },
    );

    testWidgets(
      'GeometryTier — moving the tier moves the pin on the layer the '
      'entry builds, what it says it baked, and the snippet',
      (tester) async {
        final entry = entryNamed('GeometryTier');
        expect(
          entry.knobs[0].value,
          GeometryTier.accelerated,
          reason: 'sanity: default',
        );

        GlassLayer pinnedLayer(WidgetTester tester) =>
            tester.widget<GlassLayer>(
              find.byKey(const ValueKey<String>('layer')),
            );

        await pump(tester, entry);
        expect(pinnedLayer(tester).tier, GeometryTier.accelerated);
        expect(find.text('accelerated'), findsOneWidget);
        expect(find.text('baked'), findsOneWidget);

        final moved = entry.withKnob(0, GeometryTier.none);
        await pump(tester, moved);
        expect(
          pinnedLayer(tester).tier,
          GeometryTier.none,
          reason:
              'the knob reached GlassLayer.tier, which is the whole call '
              'site this enum has',
        );
        expect(find.text('none'), findsOneWidget);
        expect(
          find.text('not baked'),
          findsOneWidget,
          reason: 'and the strip says which of the two cases it is in',
        );
        expect(renderSnippet(moved), contains('tier: GeometryTier.none'));

        final portable = entry.withKnob(0, GeometryTier.portable);
        await pump(tester, portable);
        expect(pinnedLayer(tester).tier, GeometryTier.portable);
        expect(
          find.text('baked'),
          findsOneWidget,
          reason: 'portable bakes the same matte by the other route',
        );
        expect(
          renderSnippet(portable),
          contains('tier: GeometryTier.portable'),
        );
      },
    );
  });
}
