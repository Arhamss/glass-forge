import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart' show GlassLayer;
import 'package:glass_forge_example/src/catalogue/catalogue.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';
import 'package:glass_forge_example/src/catalogue/entry_page.dart';
import 'package:glass_forge_example/src/chrome.dart';

/// The width a knob control is laid out in, on a phone [screen] points wide.
///
/// `_KnobRow` (entry_page.dart) pads its controls by 20 a side and
/// `GlassSurface.control` adds none of its own, so this is what a
/// `SegmentedControl` is handed.
double _controlWidth(double screen) => screen - 40;

/// The two phone widths every knob is checked at: 375 points, which is what
/// most of this catalogue was measured on, and 320, the narrowest screen
/// iOS still runs.
const List<double> _phoneWidths = <double>[375, 320];

/// The most characters a segment label may have before it stops being a
/// name and starts being a dump.
///
/// `GlassSheetScrollPhysics` is 23 characters and is the longest identifier
/// in this package's public API, so nothing a knob could honestly put on a
/// 40pt pill reaches 30. A record's synthesised `toString()` — the defect
/// this guards — runs to 108.
const int _longestPlausibleLabel = 30;

/// Every label currently drawn inside a mounted [SegmentedControl].
///
/// Read off the widget tree rather than computed from the knobs, which is
/// the whole point: it is the only way to ask what `_KnobRow` actually put
/// on screen rather than what the model would have said if asked.
List<String> _renderedSegmentLabels(WidgetTester tester) {
  final controls = find.byType(SegmentedControl<Object?>);
  return tester
      .widgetList<Text>(
        find.descendant(of: controls, matching: find.byType(Text)),
      )
      .map((text) => text.data!)
      .toList();
}

/// The five `GlassSurfaceRole` names, which is the longest set of labels any
/// knob in the catalogue carries and the one that found this bug.
const List<String> _roleNames = <String>[
  'navigationBar',
  'sheet',
  'card',
  'control',
  'scrim',
];

/// Registers the app's real Geist, so every width measured in this file is
/// the width that ships.
///
/// Without this a widget test renders the square fallback font, in which
/// every glyph is one width — and that is precisely the font in which a
/// truncation test cannot fail. `Peek`, `Half` and `Full` come out equal
/// there by construction, whatever rule divides the control, so an
/// assertion that they are equal passes under every rule including a broken
/// one. All three weights are registered because the control measures every
/// segment at w600 and draws the unselected ones at w500.
Future<void> _loadGeist() async {
  final loader = FontLoader('Geist');
  for (final path in const <String>[
    'assets/fonts/geist/Geist-Regular.ttf',
    'assets/fonts/geist/Geist-Medium.ttf',
    'assets/fonts/geist/Geist-SemiBold.ttf',
  ]) {
    loader.addFont(
      File(path).readAsBytes().then(ByteData.sublistView),
    );
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadGeist);

  /// How wide [text] wants to be, in the style it is actually drawn in.
  ///
  /// The live style, not the control's measuring style: `SegmentedControl`
  /// sizes every segment at w600 so the boundaries do not breathe as the
  /// selection animates, but an unselected label is *painted* at w500 and
  /// Geist's Medium is the best part of a point narrower than its SemiBold.
  /// Whether a label is cut off is a question about the glyphs on screen,
  /// so it is asked of the weight on screen.
  double naturalWidth(WidgetTester tester, String text) {
    final style = DefaultTextStyle.of(tester.element(find.text(text))).style;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// Whether every label in this control is drawn at its full width.
  ///
  /// A `Text` inside a slot narrower than its glyphs lays out at the slot's
  /// width and fades the rest, so a laid-out width at or above the natural
  /// one is the same statement as "nothing was cut off".
  void expectNothingClipped(
    WidgetTester tester,
    List<String> labels, {
    required String where,
  }) {
    for (final label in labels) {
      expect(
        tester.getSize(find.text(label)).width,
        greaterThanOrEqualTo(naturalWidth(tester, label) - 0.5),
        reason:
            '$where: `$label` is laid out narrower than it needs, so it '
            'fades mid-symbol and the reader cannot search for it',
      );
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    required List<String> options,
    required double width,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: width,
            child: SegmentedControl<String>(
              options: options,
              selected: options.first,
              onChanged: (_) {},
              labelOf: (option) => option,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a long label is laid out in full, where an equal share would have '
    'truncated it',
    (tester) async {
      // The original failure at the width it happened on: five
      // `GlassSurfaceRole` names in the 335 points a phone gives a knob
      // control. An equal share is 67 points and `navigationBar` measures
      // 85.4 in Geist, so the reader saw it fade out mid-symbol. A name
      // shown truncated is a name they cannot search for.
      final width = _controlWidth(375);
      await pump(tester, options: _roleNames, width: width);

      final longest = naturalWidth(tester, 'navigationBar');
      expect(
        longest,
        greaterThan(width / _roleNames.length),
        reason:
            'sanity: this width is one where the old equal-share layout '
            'would have clipped the longest label',
      );

      expectNothingClipped(tester, _roleNames, where: 'GlassSurfaceRole');
    },
  );

  testWidgets(
    'every segmented knob in the catalogue shows all of its labels in full '
    'at phone widths',
    (tester) async {
      // The property that matters, stated over the real catalogue rather
      // than over invented labels: whatever a knob chooses to call its
      // options, all of them have to be legible on a phone. Driving it from
      // `entriesIn` means a knob added later is covered the day it lands,
      // and a knob whose label goes long fails here rather than on someone's
      // screen.
      //
      // Equal-share widths are deliberately *not* asserted, because they
      // are not true. Measured here in Geist at 375 points, segments sit up
      // to 40.5 points off an equal share on `GlassSurface.role` and 17.2
      // on `Glass.clipBehavior` — the labels differ, and the layout gives
      // each one its own glyphs before it splits what is left. Nothing is
      // clipped, which is the promise; breathing is not a defect.
      var knobsChecked = 0;
      for (final group in catalogueGroups) {
        for (final entry in entriesIn(group)) {
          for (final knob in entry.knobs) {
            if (knob.options.isEmpty) {
              continue;
            }
            final labels = <String>[
              for (final option in knob.options) knob.labelFor(option),
            ];
            expect(
              labels.toSet(),
              hasLength(labels.length),
              reason:
                  '${entry.api} — ${knob.name} gives two of its options the '
                  'same label, so those segments name nothing the reader can '
                  'tell apart: $labels',
            );

            for (final screen in _phoneWidths) {
              await pump(
                tester,
                options: labels,
                width: _controlWidth(screen),
              );
              expectNothingClipped(
                tester,
                labels,
                where: '${entry.api} — ${knob.name} at ${screen}pt',
              );
            }
            knobsChecked++;
          }
        }
      }

      // Guards the loop itself: an `entriesIn` that returned nothing, or a
      // knob model that stopped exposing options, would otherwise leave
      // every assertion above unreached and this test green.
      expect(
        knobsChecked,
        greaterThanOrEqualTo(16),
        reason:
            'the catalogue has at least sixteen segmented knobs; this '
            'test reached $knobsChecked of them',
      );
    },
  );

  testWidgets(
    'the entry page puts the label the knob supplies on the pill, whatever '
    "the option's own toString says",
    (tester) async {
      // The layer the defect actually lived in. Every assertion above asks
      // `Knob.labelFor` for a label and then checks the control renders it,
      // which proves the model is right and proves nothing about who asks
      // it. Replacing `labelOf: knob.labelFor` with the old inline rule in
      // `_KnobRow._controlFor` restores the whole defect — both record
      // knobs dump a hundred characters onto the pill again — and leaves
      // every one of those assertions green, because none of them mounts a
      // page.
      //
      // So this mounts one. The entry is synthetic rather than a catalogue
      // one on purpose: its option is a record whose `toString()` is the
      // failure mode itself, and its `build` is a bare `Text`, so the page
      // costs a single cheap pump instead of a full glass specimen. The
      // real catalogue's own two label-supplying knobs are mounted in the
      // test below.
      const dumped = (constructorCode: 'GlassMaterial.regular()', weight: 4);
      final entry = CatalogueEntry(
        api: 'Glass',
        purpose: 'One glass surface.',
        group: 'Surfaces',
        knobs: <Knob<Object?>>[
          Knob<({String constructorCode, int weight})>(
            name: 'preset',
            value: dumped,
            options: const <({String constructorCode, int weight})>[dumped],
            labelOf: (option) => 'regular',
          ),
        ],
        build: (knobs) => const Text('specimen'),
        code: (knobs) => 'Glass()',
      );

      await tester.pumpWidget(
        MaterialApp(home: CatalogueEntryPage(entry: entry)),
      );
      await tester.pumpAndSettle();

      expect(
        _renderedSegmentLabels(tester),
        <String>['regular'],
        reason:
            'the page has to ask the knob what to call its options; the '
            "record's own toString() is `$dumped`",
      );
    },
  );

  testWidgets(
    'every catalogue knob that supplies its own label has that label on '
    'screen, and no rendered label is a dump',
    (tester) async {
      // The same statement against the shipped entries, mounted for real.
      // Only the knobs that supply a `labelOf` are pumped: those are
      // exactly the ones whose label cannot be recovered from the value, so
      // they are exactly the ones where the wiring is load-bearing. A knob
      // that forgets to supply one is caught a different way — its
      // `labelFor` falls through to the value's `toString()`, and a record
      // dump is 108 characters, which the clipping test above fails on at
      // 335 points.
      var pagesMounted = 0;
      for (final group in catalogueGroups) {
        for (final entry in entriesIn(group)) {
          final labelled = entry.knobs
              .where((knob) => knob.labelOf != null)
              .toList();
          if (labelled.isEmpty) {
            continue;
          }

          await tester.pumpWidget(
            MaterialApp(
              home: GlassLayer(child: CatalogueEntryPage(entry: entry)),
            ),
          );
          await tester.pumpAndSettle();

          final rendered = _renderedSegmentLabels(tester);
          for (final knob in labelled) {
            for (final option in knob.options) {
              expect(
                rendered,
                contains(knob.labelFor(option)),
                reason:
                    '${entry.api} — ${knob.name} names an option '
                    '`${knob.labelFor(option)}`, and the page does not show '
                    'it; what it shows is $rendered',
              );
            }
          }
          for (final label in rendered) {
            expect(
              label.length,
              lessThanOrEqualTo(_longestPlausibleLabel),
              reason:
                  '${entry.api} put $label on a 40pt pill. No symbol in '
                  'this package is that long, so it is a dump, not a name',
            );
          }
          pagesMounted++;
        }
      }

      expect(
        pagesMounted,
        greaterThanOrEqualTo(2),
        reason:
            'GlassMaterial and GlassMotion both supply labels; this test '
            'mounted $pagesMounted page(s)',
      );
    },
  );

  testWidgets(
    'the segments always fill exactly the width they were given, with no '
    'overflow',
    (tester) async {
      final width = _controlWidth(375);
      for (final options in <List<String>>[
        _roleNames,
        <String>['Off', 'On'],
        <String>['legible', 'regular', 'readable', 'opaque'],
        // A label far wider than the whole control. No knob in the
        // catalogue has one — `Knob.labelFor` is what keeps it that way —
        // but the control still has to divide the width it has rather than
        // grow past it.
        <String>['x' * 200, 'short'],
      ]) {
        await pump(tester, options: options, width: width);
        expect(tester.takeException(), isNull, reason: '$options overflowed');

        final total = <double>[
          for (var i = 0; i < options.length; i++)
            tester.getSize(find.byType(GestureDetector).at(i)).width,
        ].fold<double>(0, (sum, segment) => sum + segment);
        expect(
          total,
          closeTo(width, 1),
          reason: '$options did not divide the width it was given',
        );
      }
    },
  );

  testWidgets(
    'the selection pill lands on the selected segment, whatever its width',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 700,
              child: SegmentedControl<String>(
                options: _roleNames,
                selected: 'navigationBar',
                onChanged: (_) {},
                labelOf: (option) => option,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The pill is the only `DecoratedBox` in the control. It has to cover
      // the segment it belongs to and no other, which is the property the
      // old `FractionallySizedBox(widthFactor: 1 / count)` gave for free
      // and a content-sized layout has to earn.
      final pill = tester.getRect(find.byType(DecoratedBox));
      final segment = tester.getRect(find.byType(GestureDetector).first);
      expect(pill.left, closeTo(segment.left, 1));
      expect(pill.right, closeTo(segment.right, 1));
    },
  );
}
