import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_example/src/chrome.dart';

/// The width every catalogue knob control is laid out in.
///
/// `_KnobRow` (entry_page.dart) pads its controls by 20 on each side, so on
/// a 375-point phone this is what a `SegmentedControl` is handed.
const double _phoneControlWidth = 335;

/// The five `GlassSurfaceRole` names, which is the longest set of labels any
/// knob in the catalogue carries and the one that found this bug.
const List<String> _roleNames = <String>[
  'navigationBar',
  'sheet',
  'card',
  'control',
  'scrim',
];

void main() {
  /// How wide [text] wants to be, measured the way the control measures it.
  ///
  /// Widget tests render with a square fallback font rather than the app's
  /// Geist, so every number here is that font's. That is exactly why these
  /// assertions are written against *measured* natural widths rather than
  /// against point values: the layout rule is what is being pinned, and it
  /// has to hold whatever the glyphs turn out to be.
  double naturalWidth(WidgetTester tester, String text) {
    final style = DefaultTextStyle.of(
      tester.element(find.text(text)),
    ).style.copyWith(fontWeight: FontWeight.w600);
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
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
      // Wide enough that all five labels fit end to end, but not wide
      // enough for the longest to fit in one fifth of it — which is the
      // whole failure: on a phone, `navigationBar` needed about 84 points
      // and an equal share gave it 67, so the reader saw it fade out
      // mid-symbol. A name shown truncated is a name they cannot search
      // for.
      const width = 700.0;
      await pump(tester, options: _roleNames, width: width);

      final longest = naturalWidth(tester, 'navigationBar');
      expect(
        longest,
        greaterThan(width / _roleNames.length),
        reason:
            'sanity: this width is one where the old equal-share layout '
            'would have clipped the longest label',
      );

      for (final name in _roleNames) {
        expect(
          tester.getSize(find.text(name)).width,
          greaterThanOrEqualTo(naturalWidth(tester, name) - 0.5),
          reason: '$name was laid out narrower than it needs, so it fades',
        );
      }
    },
  );

  testWidgets(
    'short labels still divide the width into near-equal segments',
    (tester) async {
      // The other ten knobs in the catalogue. Their labels are short
      // enough that the slack dominates, so the content-aware split has to
      // come out as the equal-share layout they have always had — within
      // the difference between the labels themselves.
      const options = <String>['Peek', 'Half', 'Full'];
      await pump(tester, options: options, width: _phoneControlWidth);

      final segments = <double>[
        for (var i = 0; i < options.length; i++)
          tester.getSize(find.byType(GestureDetector).at(i)).width,
      ];
      const share = _phoneControlWidth / 3;

      for (var i = 0; i < options.length; i++) {
        expect(
          segments[i],
          closeTo(share, 1),
          reason:
              '${options[i]} is the same length as its neighbours, so its '
              'segment should be the same width as theirs',
        );
      }
    },
  );

  testWidgets(
    'the segments always fill exactly the width they were given, with no '
    'overflow',
    (tester) async {
      for (final options in <List<String>>[
        _roleNames,
        <String>['Off', 'On'],
        <String>['legible', 'regular', 'readable', 'opaque'],
        // A label far wider than the whole control — the case two of this
        // catalogue's knobs hit, because they are typed with records whose
        // `toString()` runs past a hundred characters. The control must
        // divide what it has rather than grow.
        <String>['x' * 200, 'short'],
      ]) {
        await pump(
          tester,
          options: options,
          width: _phoneControlWidth,
        );
        expect(tester.takeException(), isNull, reason: '$options overflowed');

        final total = <double>[
          for (var i = 0; i < options.length; i++)
            tester.getSize(find.byType(GestureDetector).at(i)).width,
        ].fold<double>(0, (sum, width) => sum + width);
        expect(
          total,
          closeTo(_phoneControlWidth, 1),
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
