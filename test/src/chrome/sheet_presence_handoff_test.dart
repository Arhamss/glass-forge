import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

/// The arrangement the spec's C5 handoff paragraph is about: a detent sheet
/// floating over the bottom bar it is going to cover, with the bar's
/// `GlassPresence` driven from the sheet's own height.
///
/// A package test rather than an example one, and deliberately. The example's
/// `SheetScene` is the only place this arrangement is assembled today, and
/// the last time it was tuned it was tuned wrong — the ramp held the bar at
/// full presence through heights where the sheet's glass was already sitting
/// on top of it, and two backdrop passes over one region is flutter#187820.
/// Nothing in the example is tested, so nothing caught it. The arrangement
/// needs no example harness: a `Stack`, a bar and a sheet is the whole of it,
/// and that is what this file builds.
///
/// C5: "The A4 overlap check must stay quiet through the whole drag. If it
/// warns mid-drag, the handoff is wrong, and that is the test."

/// How tall the covered bar is.
const _barHeight = 52.0;

/// The sheet's floating gap, which must clear [_barHeight].
///
/// This is the number the whole handoff rests on. The sheet's bottom edge
/// floats `gap * (1 - progress)` above the frame's bottom, and the bar owns
/// the bottom [_barHeight] of it, so a gap no larger than the bar means the
/// two are on top of each other at the lowest detent — before the drag has
/// even started, with no ramp able to rescue it. Twelve points of daylight
/// at rest is what 64 against 52 buys.
const _bottomGap = 64.0;

/// The sheet's side inset, which has nothing to do with the bar.
///
/// Deliberately much smaller than [_bottomGap], and the reason the two are
/// separate parameters: the clearance the bar dictates is a property of the
/// bottom edge alone, and charging the sides for it would take
/// `2 * (64 - 16)` points off the sheet's width to buy nothing.
const _sideGap = 16.0;

/// The sheet's morph progress at which the shrinking gap sets the
/// sheet's bottom edge down exactly on the bar's top edge.
///
/// `metrics.gap` is `lerp(gap, 0, progress)`, so contact is where
/// `gap * (1 - progress) == barHeight`.
const double _contact = 1 - _barHeight / _bottomGap;

/// Where the bar's presence ramp starts: eight points of gap earlier, so the
/// bar is already at presence 0 by the time the two shapes meet rather than
/// arriving at 0 on the same frame.
const double _clearance = 1 - (_barHeight + 8) / _bottomGap;

const _detents = <GlassDetent>[
  GlassDetent.fraction(0.1),
  GlassDetent.fraction(0.5),
  GlassDetent.fraction(1),
];

/// The lowest detent's fraction, and the span between lowest and top — the
/// two numbers that progress is measured between.
const double _lowestFraction = 0.1;
const double _spanFraction = 1.0 - _lowestFraction;

/// The presence ramp for a sheet with [available] logical pixels to grow in.
///
/// Kept here rather than in the package because it is a property of a
/// *caller's* arrangement — how tall their bar is and how far their sheet
/// floats — and `GlassDetentSheet` has no way to know either. The example's
/// `SheetScene` derives the same two numbers the same way; this is the
/// authority for them.
Animation<double> _ramp(
  GlassDetentSheetController controller,
  double available,
) {
  final lowest = available * _lowestFraction;
  final span = available * _spanFraction;
  return controller.presenceUnder(
    start: lowest + _clearance * span,
    end: lowest + _contact * span,
  );
}

Finder get _sheet => find.descendant(
  of: find.byType(GlassDetentSheet),
  matching: find.byType(Glass),
);

Widget _host(
  GlassDetentSheetController controller,
  Animation<double> presence,
) {
  return MaterialApp(
    home: GlassLayer(
      // `GeometryTier.none` for the reason every other file in this
      // directory gives: off Impeller the runtime producer rasterises the
      // SDF on the CPU, seconds per bake, once per frame of a moving sheet.
      // Nothing here reads the matte — the overlap check runs on registered
      // geometry, which the shapes still register at this tier.
      tier: GeometryTier.none,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const ColoredBox(color: Color(0xFF203040)),
          Align(
            alignment: Alignment.bottomCenter,
            child: GlassPresence(
              presence: presence,
              child: const SizedBox(
                height: _barHeight,
                // A different role and a different backdrop from the
                // sheet's, which is what puts it in a different backdrop
                // pass — the only arrangement the overlap check has an
                // opinion about.
                child: GlassSurface.navigationBar(
                  backdrop: Color(0xFF203040),
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
          GlassDetentSheet(
            controller: controller,
            detents: _detents,
            gap: _sideGap,
            bottomGap: _bottomGap,
            backdrop: const Color(0xFF101820),
            child: const SizedBox.expand(),
          ),
        ],
      ),
    ),
  );
}

/// Runs [body] with `debugPrint` captured, and returns the overlap warnings.
///
/// Restored in a `finally` rather than an `addTearDown`, because
/// flutter_test's end-of-test check that `debugPrint` was not left changed
/// runs before tear-downs and would throw first.
Future<List<String>> _warningsFrom(Future<void> Function() body) async {
  final printed = <String>[];
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    if (message != null) {
      printed.add(message);
    }
  };
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return printed.where((message) => message.contains('187820')).toList();
}

void main() {
  late GlassDetentSheetController controller;

  setUp(() {
    controller = GlassDetentSheetController(vsync: const TestVSync());
    addTearDown(controller.dispose);
  });

  testWidgets('the bar and the sheet never share a region at rest', (
    tester,
  ) async {
    // The 600-high test window has no top inset, so the sheet's available
    // height is the whole of it.
    final presence = _ramp(controller, 600);

    final warnings = await _warningsFrom(() async {
      await tester.pumpWidget(_host(controller, presence));
      await tester.pumpAndSettle();

      for (var index = 0; index < _detents.length; index++) {
        controller.animateToDetent(index);
        await tester.pumpAndSettle();
      }
    });

    expect(warnings, isEmpty, reason: warnings.join('\n'));
  });

  testWidgets('and never during the drag between them', (tester) async {
    final presence = _ramp(controller, 600);

    final warnings = await _warningsFrom(() async {
      await tester.pumpWidget(_host(controller, presence));
      await tester.pumpAndSettle();

      // Up the whole way and back down again: the handoff has to hold in
      // both directions, and a ramp tuned only for the rise reads as correct
      // until someone drags back down through it.
      final gesture = await tester.startGesture(tester.getCenter(_sheet));
      for (var i = 0; i < 30; i++) {
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump(const Duration(milliseconds: 8));
      }
      for (var i = 0; i < 30; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    });

    expect(warnings, isEmpty, reason: warnings.join('\n'));
  });
}
