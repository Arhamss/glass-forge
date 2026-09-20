# GlassDetentSheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `GlassDetentSheet` — a persistent bottom sheet the user drags
between fixed heights, floating (inset, large radius) at its low detents and
flush (no gap, display corners) at its top one, with a scroll handoff at the
top detent and a presence handoff with whatever glass chrome it covers.

**Architecture:** Four pure, separately testable pieces under one widget. A
detent is a value type that resolves to a pixel height (`glass_detent.dart`).
The morph — gap and radius as continuous functions of the sheet's current
height — is a pure metrics class (`detent_geometry.dart`), as is the snap
decision, which projects fling velocity through `GlassDecay` before picking a
detent. A controller owns one `SpringAxis` and publishes the live height as an
`Animation<double>`, so nothing calls `setState` while a finger is down
(`glass_detent_sheet_controller.dart`). A `ScrollPhysics` reports its
scrollable's overscroll back to that controller, which is how one gesture
crosses from sheet to list and back without a lifted finger
(`glass_sheet_scroll_physics.dart`). The widget composes them, renders through
`GlassSurface.sheet`, and derives the covered-chrome presence from the same
height animation that drives the morph.

**Tech Stack:** Flutter (widgets, rendering, physics), `motor` via the
package's own `GlassMotion`/`SpringAxis`, no new dependencies.

**Spec:** `docs/superpowers/specs/2026-09-14-glass-widgets-design.md`, section
**C5 `GlassDetentSheet` — the Apple Maps sheet** (L444–L520). Read it
alongside this plan; the plan argues from it.

## Global Constraints

- **No new dependencies.** `pubspec.yaml` is publish-gated; the plan adds no
  package.
- **No lint ignores.** `analysis_options.yaml` is strict and the project rule
  is to fix the underlying issue, never to suppress it. `flutter analyze`
  must be clean at every commit.
- **Every public member gets a doc comment**, in the voice the rest of `lib/`
  uses: say what it is, then why it is that and not the obvious alternative.
- **Reduce Motion resolves to an instant settle**, never to a shorter spring
  — `GlassReduceMotion.instance`, never `MediaQuery.disableAnimations`.
- **Never two backdrop passes over the same region.** The sheet and any glass
  chrome it covers hand presence off; they do not cross-fade. This is
  flutter#187820, the bug the package exists to avoid.
- **Springs come from the theme by role**, not from hand-written stiffness:
  `GlassTheme.motionOf(context, GlassMotionRole.settle)` for the snap,
  `GlassMotionRole.follow` for anything running under a finger.
- Files live in a new `lib/src/chrome/` directory; tests mirror it at
  `test/src/chrome/`.

## A correction to the spec, carried into this plan

C5's test list asks for "`GlassRenderCounters` shows one matte produce for the
whole drag, not one per frame". **That is not achievable and this plan does not
attempt it.** `RenderGlassLayer._refreshMatte`
(`lib/src/rendering/render_glass_layer.dart:1055`) rebakes whenever
`pass.scene.revision` changes, and the revision changes when a registered
shape's geometry changes. A translating surface is free — that is what
`test/src/motion/matte_lag_test.dart` pins — but this sheet genuinely *resizes*
and *changes radius* every frame of a drag, because the floating gap and the
corner morph are the feature. A per-frame rebake while a finger is down is the
honest cost.

What is true, testable, and what Task 6 asserts instead:

- **One backdrop pass** for the sheet across the whole drag, never two.
- **Zero matte produces once settled** — a sheet resting at a detent
  registers unchanged geometry and bakes nothing per frame.
- Under Reduce Motion the morph is a step, so a detent change costs **one**
  produce, not a spring's worth.

---

### Task 1: `GlassDetent` and its resolution to pixels

**Files:**
- Create: `lib/src/chrome/glass_detent.dart`
- Test: `test/src/chrome/glass_detent_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `sealed class GlassDetent` with `const factory
  GlassDetent.fraction(double amount)`, `const factory
  GlassDetent.height(double logical)`, `const factory GlassDetent.content()`;
  the subclasses `GlassDetentFraction`, `GlassDetentHeight`,
  `GlassDetentContent`; instance method `double resolve({required double
  available, required double contentHeight})`; and the top-level `List<double>
  resolveGlassDetents(List<GlassDetent> detents, {required double available,
  required double contentHeight})` returning heights in ascending order,
  each clamped to `available`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/chrome/glass_detent.dart';

void main() {
  group('resolving one detent', () {
    test('a fraction is a fraction of the available height', () {
      expect(
        const GlassDetent.fraction(0.1).resolve(available: 800, contentHeight: 0),
        80,
      );
    });

    test('a height is itself, clamped to what there is', () {
      expect(
        const GlassDetent.height(200).resolve(available: 800, contentHeight: 0),
        200,
      );
      expect(
        const GlassDetent.height(2000).resolve(available: 800, contentHeight: 0),
        800,
      );
    });

    test('content measures the child, clamped to what there is', () {
      expect(
        const GlassDetent.content().resolve(available: 800, contentHeight: 260),
        260,
      );
      expect(
        const GlassDetent.content().resolve(available: 800, contentHeight: 900),
        800,
      );
    });

    // An unbounded child — a ListView with no height — has an infinite
    // intrinsic. Resolving that to infinity would put the sheet's top edge at
    // negative infinity and take the whole layout with it, so it saturates at
    // the available height instead, which is the answer a caller who wrote
    // `content()` around a scrollable actually wanted.
    test('an unmeasurable child falls back to the available height', () {
      expect(
        const GlassDetent.content()
            .resolve(available: 800, contentHeight: double.infinity),
        800,
      );
    });
  });

  group('resolving a list', () {
    test('returns heights in ascending order', () {
      expect(
        resolveGlassDetents(
          const <GlassDetent>[
            GlassDetent.fraction(0.1),
            GlassDetent.fraction(0.5),
            GlassDetent.fraction(1),
          ],
          available: 800,
          contentHeight: 0,
        ),
        <double>[80, 400, 800],
      );
    });

    // Two detents that resolve to the same pixel height are one detent with a
    // dead zone between them: a drag released anywhere near either snaps to
    // whichever the nearest-search happened to reach first, and a caller
    // watching `onDetentChanged` sees an index that never changes. Collapsing
    // them is the only reading that keeps the index meaningful.
    test('collapses detents that resolve to the same height', () {
      expect(
        resolveGlassDetents(
          const <GlassDetent>[
            GlassDetent.height(400),
            GlassDetent.fraction(0.5),
            GlassDetent.fraction(1),
          ],
          available: 800,
          contentHeight: 0,
        ),
        <double>[400, 800],
      );
    });

    test('a zero available height resolves everything to zero', () {
      expect(
        resolveGlassDetents(
          const <GlassDetent>[GlassDetent.fraction(0.1), GlassDetent.fraction(1)],
          available: 0,
          contentHeight: 0,
        ),
        <double>[0],
      );
    });
  });

  group('what is rejected', () {
    test('a fraction outside (0, 1]', () {
      expect(() => GlassDetent.fraction(0), throwsAssertionError);
      expect(() => GlassDetent.fraction(1.5), throwsAssertionError);
    });

    test('a non-positive height', () {
      expect(() => GlassDetent.height(0), throwsAssertionError);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/src/chrome/glass_detent_test.dart`
Expected: FAIL — `Target of URI doesn't exist:
'package:glass_forge/src/chrome/glass_detent.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'dart:ui' show clampDouble;

import 'package:flutter/foundation.dart';

/// One height a [GlassDetentSheet] rests at.
///
/// Three kinds, because the three questions a caller actually has are
/// different: "a tenth of the screen", "exactly 200 points", and "however
/// tall its contents are". Resolving all three to pixels needs the available
/// height and the measured content height, so [resolve] takes both and each
/// kind ignores the one it does not need.
@immutable
sealed class GlassDetent {
  /// Allows subclasses to be const.
  const GlassDetent();

  /// A fraction of the height available to the sheet, in `(0, 1]`.
  const factory GlassDetent.fraction(double amount) = GlassDetentFraction;

  /// A fixed height in logical pixels.
  const factory GlassDetent.height(double logical) = GlassDetentHeight;

  /// However tall the sheet's child measures.
  const factory GlassDetent.content() = GlassDetentContent;

  /// This detent in logical pixels, never taller than [available].
  double resolve({required double available, required double contentHeight});
}

/// A detent stated as a fraction of the available height.
class GlassDetentFraction extends GlassDetent {
  /// Creates a fractional detent.
  const GlassDetentFraction(this.amount)
    : assert(
        amount > 0 && amount <= 1,
        'a fraction detent runs from just above 0 to 1; a sheet of height 0 '
        'is not a detent, it is a dismissal',
      );

  /// The fraction of the available height, in `(0, 1]`.
  final double amount;

  @override
  double resolve({required double available, required double contentHeight}) =>
      available * amount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlassDetentFraction && other.amount == amount);

  @override
  int get hashCode => Object.hash(GlassDetentFraction, amount);

  @override
  String toString() => 'GlassDetent.fraction($amount)';
}

/// A detent stated in logical pixels.
class GlassDetentHeight extends GlassDetent {
  /// Creates a fixed-height detent.
  const GlassDetentHeight(this.logical)
    : assert(logical > 0, 'a detent must have a positive height');

  /// The height in logical pixels, before the clamp to what is available.
  final double logical;

  @override
  double resolve({required double available, required double contentHeight}) =>
      clampDouble(logical, 0, available);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlassDetentHeight && other.logical == logical);

  @override
  int get hashCode => Object.hash(GlassDetentHeight, logical);

  @override
  String toString() => 'GlassDetent.height($logical)';
}

/// A detent as tall as the sheet's own child.
class GlassDetentContent extends GlassDetent {
  /// Creates a content-measured detent.
  const GlassDetentContent();

  @override
  double resolve({required double available, required double contentHeight}) {
    if (!contentHeight.isFinite) {
      // An unbounded child. See the test: infinity here would take the whole
      // layout with it, and the available height is what the caller meant.
      return available;
    }
    return clampDouble(contentHeight, 0, available);
  }

  @override
  bool operator ==(Object other) => other is GlassDetentContent;

  @override
  int get hashCode => (GlassDetentContent).hashCode;

  @override
  String toString() => 'GlassDetent.content()';
}

/// [detents] in logical pixels, ascending, with duplicates collapsed.
///
/// Sorted rather than asserted-ascending because the three kinds do not
/// commute: `height(400)` and `fraction(0.5)` swap order the moment the
/// window resizes, so a list a caller wrote in ascending order on a phone is
/// descending on a tablet. The order that matters is the resolved one.
List<double> resolveGlassDetents(
  List<GlassDetent> detents, {
  required double available,
  required double contentHeight,
}) {
  final heights =
      detents
          .map(
            (detent) => detent.resolve(
              available: available,
              contentHeight: contentHeight,
            ),
          )
          .toList()
        ..sort();
  final unique = <double>[];
  for (final height in heights) {
    if (unique.isEmpty || height != unique.last) {
      unique.add(height);
    }
  }
  return unique;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/src/chrome/glass_detent_test.dart` — Expected: PASS.
Run: `flutter analyze` — Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/chrome/glass_detent.dart test/src/chrome/glass_detent_test.dart
git commit -m "feat(chrome): GlassDetent resolves fractions, heights and content to pixels"
```

---

### Task 2: The morph — gap and radius as functions of height

**Files:**
- Create: `lib/src/chrome/detent_geometry.dart`
- Test: `test/src/chrome/detent_geometry_test.dart`

**Interfaces:**
- Consumes: nothing from Task 1; the metrics take plain doubles.
- Produces: `@immutable class GlassDetentSheetMetrics` with final fields
  `double height`, `double gap`, `double radius`, `double progress`, and the
  factory `GlassDetentSheetMetrics.at({required double height, required double
  lowest, required double top, double gap = 12, double floatingRadius = 44,
  double flushRadius = 55})`.

The default `flushRadius` of 55 is a stand-in: no platform API exposes the
display's corner radius, and 55 is what modern iPhones use. Task 6 puts it on
the widget so an app that knows better can say so.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/chrome/detent_geometry.dart';

void main() {
  group('the morph is continuous in height, not stepped by detent', () {
    test('at the lowest detent the sheet floats: full gap, floating radius', () {
      final metrics = GlassDetentSheetMetrics.at(
        height: 80,
        lowest: 80,
        top: 800,
        gap: 12,
        floatingRadius: 44,
        flushRadius: 55,
      );
      expect(metrics.progress, 0);
      expect(metrics.gap, 12);
      expect(metrics.radius, 44);
    });

    test('at the top detent it is flush: no gap, the display radius', () {
      final metrics = GlassDetentSheetMetrics.at(
        height: 800,
        lowest: 80,
        top: 800,
        gap: 12,
        floatingRadius: 44,
        flushRadius: 55,
      );
      expect(metrics.progress, 1);
      expect(metrics.gap, 0);
      expect(metrics.radius, 55);
    });

    // The point of the whole class. Half way up is half the morph, whether or
    // not a detent lives there — a finger dragging through this height sees
    // the gap tighten under it rather than jump when a detent is passed.
    test('half way up is half the gap and half the radius', () {
      final metrics = GlassDetentSheetMetrics.at(
        height: 440,
        lowest: 80,
        top: 800,
        gap: 12,
        floatingRadius: 44,
        flushRadius: 55,
      );
      expect(metrics.progress, closeTo(0.5, 1e-9));
      expect(metrics.gap, closeTo(6, 1e-9));
      expect(metrics.radius, closeTo(49.5, 1e-9));
    });

    test('dragged below the lowest detent it stays fully floating', () {
      final metrics = GlassDetentSheetMetrics.at(
        height: 20,
        lowest: 80,
        top: 800,
      );
      expect(metrics.progress, 0);
    });

    test('dragged above the top detent it stays flush', () {
      final metrics = GlassDetentSheetMetrics.at(
        height: 900,
        lowest: 80,
        top: 800,
      );
      expect(metrics.progress, 1);
    });

    // A single detent, or a window so short that every detent collapsed into
    // one. Dividing by the span would be a divide by zero and put NaN into a
    // shader uniform, which paints nothing at all rather than painting wrong.
    test('a degenerate span resolves to flush rather than to NaN', () {
      final metrics = GlassDetentSheetMetrics.at(
        height: 400,
        lowest: 400,
        top: 400,
      );
      expect(metrics.progress, 1);
      expect(metrics.gap, 0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/src/chrome/detent_geometry_test.dart`
Expected: FAIL — the URI does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'dart:ui' show clampDouble, lerpDouble;

import 'package:flutter/foundation.dart';

/// The sheet's shape at one height: how far it is inset, and how round it is.
///
/// Both are functions of [height] and nothing else — not of which detent is
/// current, and not of which detent is being travelled to. That is the
/// difference between a morph that tracks a finger and one that plays an
/// animation when a detent is reached: only the *snap* is discrete.
@immutable
class GlassDetentSheetMetrics {
  /// Creates metrics directly. [GlassDetentSheetMetrics.at] is the usual way.
  const GlassDetentSheetMetrics({
    required this.height,
    required this.gap,
    required this.radius,
    required this.progress,
  });

  /// The metrics for a sheet [height] logical pixels tall.
  ///
  /// [lowest] and [top] are the resolved first and last detents, which is
  /// what the morph is measured between: a sheet whose detents are 0.1 and
  /// 1.0 floats fully at a tenth of the screen, not at zero.
  factory GlassDetentSheetMetrics.at({
    required double height,
    required double lowest,
    required double top,
    double gap = 12,
    double floatingRadius = 44,
    double flushRadius = 55,
  }) {
    final span = top - lowest;
    // A degenerate span means one detent. Flush is the right answer for it:
    // a sheet that cannot be dragged anywhere is not floating between
    // anything, and the alternative is NaN in a shader uniform.
    final progress = span > 0
        ? clampDouble((height - lowest) / span, 0, 1)
        : 1.0;
    return GlassDetentSheetMetrics(
      height: height,
      gap: lerpDouble(gap, 0, progress)!,
      radius: lerpDouble(floatingRadius, flushRadius, progress)!,
      progress: progress,
    );
  }

  /// How tall the sheet is, in logical pixels.
  final double height;

  /// How far the sheet is inset from the screen's side and bottom edges.
  final double gap;

  /// The corner radius, on all four corners.
  final double radius;

  /// How far between the lowest detent (0) and the top one (1) this is.
  final double progress;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassDetentSheetMetrics &&
        other.height == height &&
        other.gap == gap &&
        other.radius == radius &&
        other.progress == progress;
  }

  @override
  int get hashCode => Object.hash(height, gap, radius, progress);

  @override
  String toString() =>
      'GlassDetentSheetMetrics(height: $height, gap: $gap, radius: $radius)';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/src/chrome/detent_geometry_test.dart` — Expected: PASS.
Run: `flutter analyze` — Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/chrome/detent_geometry.dart test/src/chrome/detent_geometry_test.dart
git commit -m "feat(chrome): the detent sheet's gap and radius morph, driven by height"
```

---

### Task 3: The snap — nearest detent, with fling projected through friction

**Files:**
- Modify: `lib/src/chrome/detent_geometry.dart` (append; same file, the
  geometry of a release belongs with the geometry of a height)
- Modify: `test/src/chrome/detent_geometry_test.dart` (append a group)

**Interfaces:**
- Consumes: `GlassDecay` from `lib/src/motion/glass_decay.dart` — specifically
  `double restingPoint({required double start, required double velocity})`.
- Produces: top-level `int nearestDetentIndex(List<double> heights, double
  height, {double velocity = 0, GlassDecay decay = const GlassDecay()})`.

Sign convention, fixed here and obeyed everywhere after: **height increases
upward**. A drag up raises the height; a fling up is a positive velocity in
logical pixels per second.

- [ ] **Step 1: Write the failing test**

```dart
// Append to test/src/chrome/detent_geometry_test.dart, inside main().
// Add this import at the top of the file:
//   import 'package:glass_forge/src/motion/glass_decay.dart';

  group('snapping on release', () {
    const detents = <double>[80, 400, 800];

    test('a slow release goes to the nearest detent', () {
      expect(nearestDetentIndex(detents, 150), 0);
      expect(nearestDetentIndex(detents, 300), 1);
      expect(nearestDetentIndex(detents, 700), 2);
    });

    test('exactly on a detent stays there', () {
      expect(nearestDetentIndex(detents, 400), 1);
    });

    // The reason velocity is projected through friction rather than compared
    // against a threshold: a flick is a statement about where the sheet was
    // going, and the decay already knows where that is. A threshold would
    // need a second constant nobody can tune from first principles.
    test('a flick up carries past the nearest detent to the next', () {
      // From just above the lowest detent, nearest is 0. A hard flick up
      // coasts most of the way to the middle detent, so it should land there.
      expect(nearestDetentIndex(detents, 120), 0);
      expect(nearestDetentIndex(detents, 120, velocity: 1800), 1);
    });

    test('a flick down carries past the nearest detent to the one below', () {
      expect(nearestDetentIndex(detents, 760), 2);
      expect(nearestDetentIndex(detents, 760, velocity: -1800), 1);
    });

    test('a fling never leaves the detent list', () {
      expect(nearestDetentIndex(detents, 700, velocity: 100000), 2);
      expect(nearestDetentIndex(detents, 200, velocity: -100000), 0);
    });

    test('a single detent is always the answer', () {
      expect(nearestDetentIndex(const <double>[400], 90, velocity: 4000), 0);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/src/chrome/detent_geometry_test.dart`
Expected: FAIL — `The function 'nearestDetentIndex' isn't defined`.

- [ ] **Step 3: Write minimal implementation**

```dart
// Append to lib/src/chrome/detent_geometry.dart.
// Add this import at the top of the file:
//   import 'package:glass_forge/src/motion/glass_decay.dart';

/// Which of [heights] a sheet released at [height] with [velocity] belongs at.
///
/// The velocity is projected forward through [decay] first, so a flick lands
/// where the fling would have come to rest and then snaps from *there*. That
/// is why a hard flick carries past the nearest detent without any threshold
/// to tune: friction already encodes how far a given speed travels, and iOS
/// uses the same 0.135 retention factor for exactly this judgement.
///
/// [heights] must be ascending and non-empty — [resolveGlassDetents] returns
/// it that way.
int nearestDetentIndex(
  List<double> heights,
  double height, {
  double velocity = 0,
  GlassDecay decay = const GlassDecay(),
}) {
  assert(heights.isNotEmpty, 'a sheet with no detents has nowhere to go');
  final projected = velocity == 0
      ? height
      : decay.restingPoint(start: height, velocity: velocity);
  var best = 0;
  var bestDistance = (heights[0] - projected).abs();
  for (var i = 1; i < heights.length; i++) {
    final distance = (heights[i] - projected).abs();
    if (distance < bestDistance) {
      best = i;
      bestDistance = distance;
    }
  }
  return best;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/src/chrome/detent_geometry_test.dart` — Expected: PASS.
Run: `flutter analyze` — Expected: no issues.

If the two flick tests fail, the projected resting point is landing short or
long of what the test assumed. Do not weaken the assertion — print
`const GlassDecay().restingPoint(start: 120, velocity: 1800)` in a scratch
test and pick flick velocities that straddle the real midpoint (which is 240,
half way between 80 and 400). The physics is the specification here; the
numbers in the test exist to pin it.

- [ ] **Step 5: Commit**

```bash
git add lib/src/chrome/detent_geometry.dart test/src/chrome/detent_geometry_test.dart
git commit -m "feat(chrome): snap to the detent a fling would have reached"
```

---

### Task 4: `GlassDetentSheetController` — one spring, published as an Animation

**Files:**
- Create: `lib/src/chrome/glass_detent_sheet_controller.dart`
- Test: `test/src/chrome/glass_detent_sheet_controller_test.dart`

**Interfaces:**
- Consumes: `resolveGlassDetents` and `nearestDetentIndex` (Tasks 1 and 3);
  `SpringAxis` (`lib/src/motion/spring_axis.dart`); `GlassMotion`,
  `GlassDecay`, `GlassReduceMotion`.
- Produces: `class GlassDetentSheetController extends Animation<double>` whose
  `value` is the live height in logical pixels, with:
  - `GlassDetentSheetController({required TickerProvider vsync, GlassMotion
    settleMotion = const GlassMotion.smooth(duration: Duration(milliseconds:
    400)), GlassDecay decay = const GlassDecay(), bool respectReduceMotion =
    true})`
  - `void setDetents(List<double> heights, {int? initialDetent})`
  - `List<double> get detents`
  - `int get detent`
  - `double get lowest` / `double get top`
  - `void animateToDetent(int index)`
  - `void beginDrag()` / `void dragBy(double delta)` / `void
    endDrag({double velocity = 0})`
  - `ValueChanged<int>? onDetentChanged`
  - `bool get isDragging`
  - `void dispose()`

`delta` on `dragBy` is in the sheet's own sign convention: **positive raises
the sheet**, so a widget wiring a `DragUpdateDetails` passes
`-details.delta.dy`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/chrome/glass_detent_sheet_controller.dart';

const Duration _frame = Duration(milliseconds: 8);

Future<void> settle(
  WidgetTester tester,
  GlassDetentSheetController controller,
) async {
  var frames = 0;
  while (controller.isAnimating && frames < 1200) {
    await tester.pump(_frame);
    frames++;
  }
}

void main() {
  late GlassDetentSheetController controller;

  void build({bool respectReduceMotion = true}) {
    controller = GlassDetentSheetController(
      vsync: const TestVSync(),
      respectReduceMotion: respectReduceMotion,
    )..setDetents(const <double>[80, 400, 800]);
    addTearDown(controller.dispose);
  }

  testWidgets('starts at the initial detent with no motion', (tester) async {
    controller = GlassDetentSheetController(vsync: const TestVSync())
      ..setDetents(const <double>[80, 400, 800], initialDetent: 1);
    addTearDown(controller.dispose);

    expect(controller.value, 400);
    expect(controller.detent, 1);
    expect(controller.isAnimating, isFalse);
  });

  testWidgets('a drag moves the sheet under the finger, one to one', (
    tester,
  ) async {
    build();
    controller
      ..beginDrag()
      ..dragBy(60);
    expect(controller.value, 140);
    expect(controller.isDragging, isTrue);
  });

  testWidgets('a release snaps to the nearest detent', (tester) async {
    build();
    controller
      ..beginDrag()
      ..dragBy(220) // 300, nearer 400 than 80
      ..endDrag();
    await settle(tester, controller);

    expect(controller.value, 400);
    expect(controller.detent, 1);
  });

  testWidgets('a fling carries past the nearest detent', (tester) async {
    build();
    controller
      ..beginDrag()
      ..dragBy(40) // 120, nearest is still the lowest
      ..endDrag(velocity: 1800);
    await settle(tester, controller);

    expect(controller.detent, 1);
  });

  testWidgets('onDetentChanged fires once, when the detent actually changes', (
    tester,
  ) async {
    build();
    final seen = <int>[];
    controller.onDetentChanged = seen.add;

    controller
      ..beginDrag()
      ..dragBy(220)
      ..endDrag();
    await settle(tester, controller);
    expect(seen, <int>[1]);

    // Releasing again at the same place is not a change.
    controller
      ..beginDrag()
      ..dragBy(2)
      ..endDrag();
    await settle(tester, controller);
    expect(seen, <int>[1]);
  });

  testWidgets('listeners fire while the spring runs, not only at the end', (
    tester,
  ) async {
    build();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.animateToDetent(2);
    await tester.pump(_frame);
    await tester.pump(_frame);
    expect(notifications, greaterThan(1));
    expect(controller.value, greaterThan(80));
    expect(controller.value, lessThan(800));

    await settle(tester, controller);
    expect(controller.value, 800);
  });

  // The accessibility contract is "no elastic properties", which is a
  // statement about simulations. A faster spring is still motion.
  testWidgets('Reduce Motion snaps with no frames in between', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    build();
    controller.animateToDetent(2);

    expect(controller.value, 800);
    expect(controller.isAnimating, isFalse);
  });

  testWidgets('respectReduceMotion: false keeps the spring', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    build(respectReduceMotion: false);
    controller.animateToDetent(2);

    expect(controller.value, lessThan(800));
    expect(controller.isAnimating, isTrue);
    await settle(tester, controller);
  });

  testWidgets('re-resolving detents keeps the current one', (tester) async {
    build();
    controller.animateToDetent(1);
    await settle(tester, controller);
    expect(controller.value, 400);

    // A rotation: the same three fractions against a shorter window.
    controller.setDetents(const <double>[40, 200, 400]);
    expect(controller.detent, 1);
    expect(controller.value, 200);
  });

  testWidgets('a drag started mid-spring takes the sheet over', (tester) async {
    build();
    controller.animateToDetent(2);
    await tester.pump(_frame);
    await tester.pump(_frame);
    final caught = controller.value;

    controller.beginDrag();
    expect(controller.isAnimating, isFalse);
    expect(controller.value, caught);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/src/chrome/glass_detent_sheet_controller_test.dart`
Expected: FAIL — the URI does not exist.

- [ ] **Step 3: Write minimal implementation**

Model it on `GlassMotionController`
(`lib/src/motion/glass_motion_controller.dart`): an `Animation` with the three
local-listener mixins, one `Ticker`, springs resolved once in the constructor
rather than per frame, and `_maxStep` clamping so a backgrounded app does not
teleport on resume.

```dart
import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:glass_forge/src/chrome/detent_geometry.dart';
import 'package:glass_forge/src/motion/glass_decay.dart';
import 'package:glass_forge/src/motion/glass_motion.dart';
import 'package:glass_forge/src/motion/reduce_motion.dart';
import 'package:glass_forge/src/motion/spring_axis.dart';

/// Drives one detent sheet's height.
///
/// An [Animation] of logical pixels, therefore a [ValueListenable], therefore
/// something a `GlassPresence` can be driven from and a render object can
/// subscribe to. Nothing here calls `setState`: the widget rebuilds its
/// layout from this value through an [AnimatedBuilder] scoped to the sheet
/// alone, and the covered chrome's presence is derived from the same object
/// rather than pushed to it.
///
/// Height increases upward. A drag that raises the sheet is a positive
/// [dragBy]; a fling upward is a positive velocity.
class GlassDetentSheetController extends Animation<double>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin {
  /// Creates a controller with no detents yet. Call [setDetents] before use.
  GlassDetentSheetController({
    required TickerProvider vsync,
    this.settleMotion = const GlassMotion.smooth(
      duration: Duration(milliseconds: 400),
    ),
    this.decay = const GlassDecay(),
    this.respectReduceMotion = true,
  }) {
    _ticker = vsync.createTicker(_tick);
    _spring = settleMotion.spring;
    _tolerance = settleMotion.tolerance;
    if (respectReduceMotion) {
      GlassReduceMotion.instance.addListener(_onReduceMotionChanged);
    }
  }

  /// The spring the snap runs on.
  ///
  /// Defaults to the same values `GlassMotionDefaults.present` carries, and
  /// for the same reason stated there: a sheet that springs past its detent
  /// and comes back reads as a mistake rather than as liveliness.
  final GlassMotion settleMotion;

  /// How a fling's velocity is projected forward before the snap is chosen.
  final GlassDecay decay;

  /// Whether Reduce Motion collapses the snap to an instant settle.
  final bool respectReduceMotion;

  /// Called when the resting detent changes, never on every frame.
  ValueChanged<int>? onDetentChanged;

  /// The longest step the physics is advanced by in one frame.
  ///
  /// A resume guard, not a stability one: the spring is closed-form and exact
  /// at any step, but a sheet mid-snap when the app went to the background
  /// would otherwise fast-forward the whole elapsed wall clock in one frame.
  static const double _maxStep = 1 / 30;

  late final Ticker _ticker;
  late final SpringDescription _spring;
  late final Tolerance _tolerance;

  final SpringAxis _axis = SpringAxis();
  List<double> _detents = const <double>[];
  int _detent = 0;
  bool _dragging = false;
  Duration _lastTick = Duration.zero;
  AnimationStatus _status = AnimationStatus.dismissed;

  @override
  double get value => _axis.position;

  @override
  AnimationStatus get status => _status;

  @override
  bool get isAnimating => _ticker.isActive;

  /// Whether a finger is currently carrying the sheet.
  bool get isDragging => _dragging;

  /// The resolved detent heights, ascending.
  List<double> get detents => _detents;

  /// Which detent the sheet is resting at, or heading to.
  int get detent => _detent;

  /// The lowest detent's height.
  double get lowest => _detents.isEmpty ? 0 : _detents.first;

  /// The top detent's height.
  double get top => _detents.isEmpty ? 0 : _detents.last;

  /// Replaces the detent heights, keeping the current detent *index*.
  ///
  /// Index, not height: a rotation re-resolves every fraction against a new
  /// window, and a sheet that was half open should still be half open
  /// afterwards. Keeping the pixel height instead would leave it at whatever
  /// fraction of the new window that number happens to be.
  void setDetents(List<double> heights, {int? initialDetent}) {
    assert(heights.isNotEmpty, 'a sheet needs at least one detent');
    final wasEmpty = _detents.isEmpty;
    _detents = List<double>.unmodifiable(heights);
    final index = initialDetent ?? _detent;
    _detent = index.clamp(0, _detents.length - 1);
    final target = _detents[_detent];
    _axis.target = target;
    if (wasEmpty || !_dragging && !isAnimating) {
      _axis
        ..position = target
        ..velocity = 0;
      _publish();
    }
  }

  /// Takes the sheet over from whatever was moving it.
  void beginDrag() {
    _dragging = true;
    _axis
      ..endFling()
      ..velocity = 0;
    _stopTicker();
  }

  /// Moves the sheet by [delta] logical pixels. Positive raises it.
  void dragBy(double delta) {
    if (_detents.isEmpty) {
      return;
    }
    // Clamped to the detent range rather than rubber-banded. A sheet dragged
    // past its top detent has nowhere to go — the screen ends — and one
    // dragged below its lowest is asking to be dismissed, which this widget
    // does not do. `GlassOverdrag` is the right tool the day either of those
    // becomes a gesture.
    _axis
      ..position = (_axis.position + delta).clamp(lowest, top)
      ..target = _axis.position
      ..velocity = 0;
    _publish();
  }

  /// Ends the drag and snaps, carrying [velocity] forward through friction.
  void endDrag({double velocity = 0}) {
    _dragging = false;
    if (_detents.isEmpty) {
      return;
    }
    final index = nearestDetentIndex(
      _detents,
      _axis.position,
      velocity: velocity,
      decay: decay,
    );
    _axis.velocity = velocity;
    _goTo(index);
  }

  /// Springs to [index].
  void animateToDetent(int index) {
    assert(
      index >= 0 && index < _detents.length,
      'no detent at index $index; there are ${_detents.length}',
    );
    _goTo(index);
  }

  void _goTo(int index) {
    final changed = index != _detent;
    _detent = index;
    _axis.target = _detents[index];

    if (respectReduceMotion && GlassReduceMotion.instance.value) {
      _axis.settleInstantly();
      _stopTicker();
      _publish();
    } else if (_axis.position != _axis.target || _axis.velocity != 0) {
      _startTicker();
    }

    if (changed) {
      onDetentChanged?.call(index);
    }
  }

  void _startTicker() {
    if (_ticker.isActive) {
      return;
    }
    _lastTick = Duration.zero;
    _status = AnimationStatus.forward;
    _ticker.start();
    notifyStatusListeners(_status);
  }

  void _stopTicker() {
    if (!_ticker.isActive) {
      return;
    }
    _ticker.stop();
    _status = AnimationStatus.completed;
    notifyStatusListeners(_status);
  }

  void _tick(Duration elapsed) {
    final seconds = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final dt = seconds > _maxStep ? _maxStep : seconds;
    if (dt <= 0) {
      return;
    }
    final moving = _axis.advance(
      dt: dt,
      spring: _spring,
      tolerance: _tolerance,
    );
    _publish();
    if (!moving) {
      _stopTicker();
    }
  }

  void _publish() => notifyListeners();

  void _onReduceMotionChanged() {
    if (!GlassReduceMotion.instance.value || !isAnimating) {
      return;
    }
    _axis.settleInstantly();
    _stopTicker();
    _publish();
  }

  @override
  void dispose() {
    if (respectReduceMotion) {
      GlassReduceMotion.instance.removeListener(_onReduceMotionChanged);
    }
    _ticker.dispose();
    super.dispose();
  }

  @override
  String toString() =>
      'GlassDetentSheetController(${value.toStringAsFixed(1)}px, '
      'detent $_detent of ${_detents.length})';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/src/chrome/glass_detent_sheet_controller_test.dart`
Expected: PASS.
Run: `flutter analyze` — Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/chrome/glass_detent_sheet_controller.dart test/src/chrome/glass_detent_sheet_controller_test.dart
git commit -m "feat(chrome): GlassDetentSheetController drives sheet height as an Animation"
```

---

### Task 5: The presence handoff, derived from the same height

**Files:**
- Modify: `lib/src/chrome/glass_detent_sheet_controller.dart` (append a method
  and a private `Animatable`)
- Modify: `test/src/chrome/glass_detent_sheet_controller_test.dart` (append a
  group)

**Interfaces:**
- Consumes: `GlassDetentSheetController` from Task 4.
- Produces: `Animation<double> presenceUnder({required double start, required
  double end})` on the controller — 1 while the sheet's top edge is below
  `start`, falling to 0 once it reaches `end`. Both are distances from the
  bottom of the sheet's available area, the same units the height is in.

This is the stub for C4. Until `GlassScaffold` exists, an app wires this into
a `GlassPresence` around its own bottom bar by hand; when C4 lands it does the
wiring itself and this method does not change.

- [ ] **Step 1: Write the failing test**

```dart
// Append to test/src/chrome/glass_detent_sheet_controller_test.dart.

  group('the presence handoff with covered chrome', () {
    // A bottom bar 88 px tall sitting on the bottom edge: its top edge is at
    // 88, and the sheet has fully covered it by the time its own top edge
    // reaches 88. The ramp starts a little earlier so the bar is gone before
    // the sheet's glass reaches it, never during.
    testWidgets('ramps to zero as the sheet covers the bar', (tester) async {
      controller = GlassDetentSheetController(vsync: const TestVSync())
        ..setDetents(const <double>[40, 400, 800]);
      addTearDown(controller.dispose);

      final presence = controller.presenceUnder(start: 60, end: 88);
      expect(presence.value, 1);

      controller
        ..beginDrag()
        ..dragBy(34); // height 74, three-quarters of the way through the ramp
      expect(presence.value, closeTo(0.5, 1e-9));

      controller.dragBy(40); // height 114, past the end
      expect(presence.value, 0);
    });

    testWidgets('the presence animation notifies its own listeners', (
      tester,
    ) async {
      controller = GlassDetentSheetController(vsync: const TestVSync())
        ..setDetents(const <double>[40, 400, 800]);
      addTearDown(controller.dispose);

      final presence = controller.presenceUnder(start: 60, end: 88);
      var notifications = 0;
      presence.addListener(() => notifications++);

      controller
        ..beginDrag()
        ..dragBy(30);
      expect(notifications, greaterThan(0));
    });

    testWidgets('a degenerate ramp is a step, not a divide by zero', (
      tester,
    ) async {
      build();
      final presence = controller.presenceUnder(start: 88, end: 88);
      expect(presence.value, 1);

      controller
        ..beginDrag()
        ..dragBy(20); // height 100, past the step
      expect(presence.value, 0);
    });
  });
```

Every test in this group builds its own controller with a 40-pixel lowest
detent rather than using `build()`, whose 80 sits inside the ramp under test.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/src/chrome/glass_detent_sheet_controller_test.dart`
Expected: FAIL — `The method 'presenceUnder' isn't defined`.

- [ ] **Step 3: Write minimal implementation**

```dart
// Append inside GlassDetentSheetController, before dispose().

  /// How present glass chrome between [start] and [end] should be.
  ///
  /// 1 while the sheet's top edge is below [start], 0 once it has reached
  /// [end], linear in between — both measured, like the height itself, from
  /// the bottom of the sheet's available area.
  ///
  /// This is the handoff, not a cross-fade. Where the sheet floats above a
  /// bottom bar, both want to be glass over the same pixels, and two backdrop
  /// filters over one region is flutter#187820: the upper pass samples the
  /// lower one's output and white-washes over time. So the bar's presence
  /// reaches 0 *before* the sheet's glass arrives, driven by the same height
  /// that drives the morph, which is what keeps the two in step through a
  /// drag that stops and reverses half way.
  Animation<double> presenceUnder({
    required double start,
    required double end,
  }) {
    assert(end >= start, 'the ramp ends above where it starts');
    return drive(_CoverTween(start: start, end: end));
  }

// Append at the end of the file, outside the class.

/// Maps a sheet height to how present the chrome under it should be.
class _CoverTween extends Animatable<double> {
  const _CoverTween({required this.start, required this.end});

  final double start;
  final double end;

  @override
  double transform(double height) {
    if (height <= start) {
      return 1;
    }
    if (end <= start || height >= end) {
      // A zero-width ramp is a step. Dividing by the span would be a divide
      // by zero, and NaN in a presence uniform paints nothing at all.
      return 0;
    }
    return 1 - (height - start) / (end - start);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/src/chrome/glass_detent_sheet_controller_test.dart`
Expected: PASS.
Run: `flutter analyze` — Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/chrome/glass_detent_sheet_controller.dart test/src/chrome/glass_detent_sheet_controller_test.dart
git commit -m "feat(chrome): derive covered-chrome presence from the sheet's height"
```

---

### Task 6: The `GlassDetentSheet` widget

**Files:**
- Create: `lib/src/chrome/glass_detent_sheet.dart`
- Modify: `lib/glass_forge.dart` (add three exports)
- Test: `test/src/chrome/glass_detent_sheet_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1–5; `GlassSurface`, `GlassTheme`,
  `GlassRoundedRectangle`, `Glass`, `GlassLayer`, `GlassPresence`.
- Produces:

```dart
const GlassDetentSheet({
  required List<GlassDetent> detents,
  required Widget child,
  int initialDetent = 0,
  ValueChanged<int>? onDetentChanged,
  GlassDetentSheetController? controller,
  Color? backdrop,
  double gap = 12,
  double? floatingRadius,   // null resolves to the theme's extraLarge step
  double flushRadius = 55,
  bool showHandle = true,
  String? semanticLabel,
  Key? key,
});
```

Composition rules the widget must obey, all of them from the spec:

- The sheet renders through `GlassSurface.sheet` **inside the caller's
  `GlassLayer`**, never its own. One layer, one capture.
- The shape is not the role's ladder step — the radius morphs continuously —
  so the widget resolves the style with `GlassTheme.surfaceOf` and renders a
  `Glass` with a `GlassRoundedRectangle` built from
  `GlassDetentSheetMetrics.radius`, keeping the style's material, shadows and
  label colour.
- Only the sheet's own subtree rebuilds per frame: an `AnimatedBuilder` on the
  controller wraps the `Positioned`, not the page.
- Bottom safe-area inset is built in; the gap is added to it.
- Semantics: the sheet is a slider-like draggable with increase and decrease
  actions that step the detent.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/diagnostics/render_counters.dart';
import 'package:glass_forge/src/rendering/render_glass_shape.dart';

/// The sheet's visible box.
///
/// Not `find.byType(GlassDetentSheet)`: the widget returns an `Align` under
/// the `Stack`'s loose constraints, so its element fills the whole window
/// whatever the detent is. Its `getSize` is the window's height at every
/// detent, and its centre is empty space well above the sheet — a `drag` there
/// misses the gesture detector entirely. The `Glass` inside it is the thing
/// that is actually the size of the sheet.
Finder get _sheet => find.descendant(
  of: find.byType(GlassDetentSheet),
  matching: find.byType(Glass),
);

Widget _host({
  List<GlassDetent> detents = const <GlassDetent>[
    GlassDetent.fraction(0.1),
    GlassDetent.fraction(0.5),
    GlassDetent.fraction(1),
  ],
  GlassDetentSheetController? controller,
  ValueChanged<int>? onDetentChanged,
  int initialDetent = 0,
  Widget? child,
}) {
  return MaterialApp(
    home: GlassLayer(
      child: Stack(
        children: <Widget>[
          const SizedBox.expand(child: ColoredBox(color: Color(0xFF203040))),
          GlassDetentSheet(
            detents: detents,
            controller: controller,
            initialDetent: initialDetent,
            onDetentChanged: onDetentChanged,
            child: child ?? const SizedBox.expand(),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('opens at its initial detent', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    // A tenth of the 600-high test window, less nothing: the test window has
    // no safe-area inset.
    expect(tester.getSize(_sheet).height, closeTo(60, 0.5));
  });

  testWidgets('opens at a non-zero initial detent', (tester) async {
    await tester.pumpWidget(_host(initialDetent: 1));
    await tester.pumpAndSettle();

    expect(tester.getSize(_sheet).height, closeTo(300, 0.5));
  });

  testWidgets('a drag up moves the sheet and it snaps to the next detent', (
    tester,
  ) async {
    final changed = <int>[];
    await tester.pumpWidget(_host(onDetentChanged: changed.add));
    await tester.pumpAndSettle();

    await tester.drag(_sheet, const Offset(0, -220));
    await tester.pumpAndSettle();

    expect(changed, <int>[1]);
    expect(tester.getSize(_sheet).height, closeTo(300, 0.5));
  });

  testWidgets('the gap closes and the radius grows as it rises', (
    tester,
  ) async {
    final controller = GlassDetentSheetController(vsync: const TestVSync());
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller: controller));
    await tester.pumpAndSettle();

    double radius() {
      final shape = tester.renderObject<RenderGlassShape>(_sheet);
      return shape.shape.resolveRadius(shape.size);
    }

    double left() => tester.getTopLeft(_sheet).dx;

    final lowRadius = radius();
    final lowLeft = left();
    expect(lowLeft, closeTo(12, 0.5)); // the floating gap

    controller.animateToDetent(2);
    await tester.pumpAndSettle();

    expect(left(), closeTo(0, 0.5)); // flush
    expect(radius(), greaterThan(lowRadius));
  });

  // The claim the spec makes about cost, in the form that is actually true.
  // See "A correction to the spec" at the top of this plan: a resizing,
  // radius-morphing shape rebakes its matte per frame while it moves. What
  // must hold is that it stops when the sheet does, and that the sheet is one
  // backdrop pass throughout, never two.
  testWidgets('a settled sheet bakes nothing per frame', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    GlassRenderCounters.instance.reset();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(GlassRenderCounters.instance.matteProduceCount, 0);
  });

  // The A4 overlap warning fires on two *different* backdrop passes covering
  // one region. Nothing in this test has a second pass, so a warning here
  // means the sheet created a layer of its own instead of joining the page's.
  testWidgets('the overlap check stays quiet through a whole drag', (
    tester,
  ) async {
    final warnings = <String>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        warnings.add(message);
      }
    };
    addTearDown(() => debugPrint = previous);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(_sheet));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      warnings.where((w) => w.contains('overlap')),
      isEmpty,
      reason: warnings.join('\n'),
    );
  });

  testWidgets('Reduce Motion makes the snap instant', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final controller = GlassDetentSheetController(vsync: const TestVSync());
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller: controller));
    await tester.pumpAndSettle();

    controller.animateToDetent(2);
    await tester.pump();

    expect(tester.getSize(_sheet).height, closeTo(600, 0.5));
  });

  testWidgets('semantics expose a draggable with increase and decrease', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byType(GlassDetentSheet)),
      // `containsSemantics`, not `matchesSemantics`: the latter is exhaustive
      // and this node also carries a label and a value, which this test has no
      // opinion about.
      containsSemantics(
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the increase action raises it one detent', (tester) async {
    final handle = tester.ensureSemantics();
    final changed = <int>[];
    await tester.pumpWidget(_host(onDetentChanged: changed.add));
    await tester.pumpAndSettle();

    final id = tester.getSemantics(find.byType(GlassDetentSheet)).id;
    tester.binding.pipelineOwner.semanticsOwner!
        .performAction(id, SemanticsAction.increase);
    await tester.pumpAndSettle();

    expect(changed, <int>[1]);
    handle.dispose();
  });

  testWidgets('a controller the caller owns is not disposed by the widget', (
    tester,
  ) async {
    final controller = GlassDetentSheetController(vsync: const TestVSync());
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller: controller));
    await tester.pumpWidget(const SizedBox.shrink());

    // Still usable: disposing it here would throw.
    expect(controller.value, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/src/chrome/glass_detent_sheet_test.dart`
Expected: FAIL — `GlassDetentSheet` is undefined.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/chrome/detent_geometry.dart';
import 'package:glass_forge/src/chrome/glass_detent.dart';
import 'package:glass_forge/src/chrome/glass_detent_sheet_controller.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/design/glass_tokens.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';

/// A sheet that lives at the bottom of the screen and is dragged between
/// fixed heights — Apple Maps, Find My, `UISheetPresentationController`.
///
/// Not the other kind of sheet. `showGlassSheet` presents one over a page and
/// takes it away; this one is always there, and the interesting behaviour is
/// what it does on the way up: below the top detent it floats, inset from the
/// screen's edges with a large radius on all four corners, and as it rises
/// the gap closes and the radius grows toward the display's own, so at the
/// top detent it is flush.
///
/// The morph is a function of the sheet's current height, not of which detent
/// it is heading to, which is what makes it track a finger instead of playing
/// when a detent is reached. Only the snap is discrete.
///
/// Belongs inside the screen's single `GlassLayer`, alongside whatever other
/// chrome the page has — not in a layer of its own. Where it covers other
/// glass, drive that chrome's `GlassPresence` from
/// [GlassDetentSheetController.presenceUnder] so the two hand off rather than
/// both rendering: two backdrop filters over one region is flutter#187820.
///
/// ```dart
/// GlassLayer(
///   child: Stack(
///     children: [
///       const Map(),
///       GlassDetentSheet(
///         detents: const [
///           GlassDetent.fraction(0.1),
///           GlassDetent.fraction(0.5),
///           GlassDetent.fraction(1),
///         ],
///         child: ListView(children: results),
///       ),
///     ],
///   ),
/// )
/// ```
class GlassDetentSheet extends StatefulWidget {
  /// Creates a detent sheet.
  const GlassDetentSheet({
    required this.detents,
    required this.child,
    this.initialDetent = 0,
    this.onDetentChanged,
    this.controller,
    this.backdrop,
    this.gap = 12,
    this.floatingRadius,
    this.flushRadius = 55,
    this.showHandle = true,
    this.semanticLabel,
    super.key,
  }) : assert(detents.length >= 2, 'a sheet that cannot move is a panel');

  /// The heights the sheet rests at. Resolved and sorted ascending.
  final List<GlassDetent> detents;

  /// What the sheet carries.
  final Widget child;

  /// Which detent the sheet opens at.
  final int initialDetent;

  /// Called when the resting detent changes.
  final ValueChanged<int>? onDetentChanged;

  /// Drives the sheet from outside. Created internally when null, and only
  /// disposed when created internally.
  final GlassDetentSheetController? controller;

  /// What is behind the sheet, where the app knows — see `GlassSurface`.
  final Color? backdrop;

  /// How far the floating sheet is inset from the screen's edges.
  final double gap;

  /// The corner radius while floating. Null takes the theme's
  /// [GlassRadiusStep.extraLarge], which is the sheet role's own step.
  final double? floatingRadius;

  /// The corner radius when flush.
  ///
  /// Nominally the display's own corner radius, so the sheet's corners match
  /// the screen's at the top detent. No platform API exposes that number, so
  /// this defaults to 55 — what modern iPhones use — and an app that knows
  /// its device better should say so rather than accept the guess.
  final double flushRadius;

  /// Whether to draw the grab handle at the top of the sheet.
  final bool showHandle;

  /// What a screen reader calls this sheet.
  final String? semanticLabel;

  @override
  State<GlassDetentSheet> createState() => _GlassDetentSheetState();
}

class _GlassDetentSheetState extends State<GlassDetentSheet>
    with SingleTickerProviderStateMixin {
  GlassDetentSheetController? _internal;
  GlassDetentSheetController get _controller =>
      widget.controller ?? (_internal ??= _createController());

  List<double> _resolved = const <double>[];

  GlassDetentSheetController _createController() =>
      GlassDetentSheetController(vsync: this);

  @override
  void initState() {
    super.initState();
    _controller.onDetentChanged = _onDetentChanged;
  }

  @override
  void didUpdateWidget(GlassDetentSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.onDetentChanged = null;
      _controller.onDetentChanged = _onDetentChanged;
    }
  }

  void _onDetentChanged(int index) => widget.onDetentChanged?.call(index);

  @override
  void dispose() {
    // Only the one this state made. A caller's controller outlives the widget
    // by construction — that is what passing one in is for.
    _internal?.dispose();
    widget.controller?.onDetentChanged = null;
    super.dispose();
  }

  void _syncDetents(double available) {
    // Captured before `_resolved` is reassigned below. Reading it after would
    // always be false, and `initialDetent` would never reach the controller.
    final isFirst = _resolved.isEmpty;
    final resolved = resolveGlassDetents(
      widget.detents,
      available: available,
      // Content detents measure the child. Nothing measures it yet, so a
      // `content()` detent resolves to the available height — the documented
      // fallback in `GlassDetentContent.resolve`. Wiring a real intrinsic
      // measurement is its own task; see the plan's closing note.
      contentHeight: double.infinity,
    );
    if (resolved.length == _resolved.length) {
      var same = true;
      for (var i = 0; i < resolved.length; i++) {
        if (resolved[i] != _resolved[i]) {
          same = false;
          break;
        }
      }
      if (same) {
        return;
      }
    }
    _resolved = resolved;
    _controller.setDetents(
      resolved,
      initialDetent: isFirst ? widget.initialDetent : null,
    );
  }

  void _stepDetent(int by) {
    final next = (_controller.detent + by).clamp(0, _resolved.length - 1);
    if (next != _controller.detent) {
      _controller.animateToDetent(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final radius =
        widget.floatingRadius ??
        GlassTheme.of(context).tokens.radius.radiusOf(
          GlassRadiusStep.extraLarge,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight - padding.top;
        _syncDetents(available);

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final metrics = GlassDetentSheetMetrics.at(
              height: _controller.value,
              lowest: _controller.lowest,
              top: _controller.top,
              gap: widget.gap,
              floatingRadius: radius,
              flushRadius: widget.flushRadius,
            );
            return Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  left: metrics.gap,
                  right: metrics.gap,
                  bottom: metrics.gap,
                ),
                child: SizedBox(
                  height: metrics.height,
                  child: _sheet(context, metrics, padding),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheet(
    BuildContext context,
    GlassDetentSheetMetrics metrics,
    EdgeInsets padding,
  ) {
    // The role's style, but not the role's shape: the radius morphs
    // continuously, and the ladder has steps. Everything else — material,
    // shadows, the vibrant label colour — comes from the role as it should.
    final style = GlassTheme.surfaceOf(
      context,
      GlassSurfaceRole.sheet,
      size: Size(
        MediaQuery.sizeOf(context).width - metrics.gap * 2,
        metrics.height,
      ),
      backdrop: widget.backdrop,
    );

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      value: '${_controller.detent + 1} of ${_resolved.length}',
      onIncrease: () => _stepDetent(1),
      onDecrease: () => _stepDetent(-1),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => _controller.beginDrag(),
        onVerticalDragUpdate: (details) =>
            _controller.dragBy(-details.delta.dy),
        onVerticalDragEnd: (details) => _controller.endDrag(
          velocity: -details.velocity.pixelsPerSecond.dy,
        ),
        onVerticalDragCancel: _controller.endDrag,
        child: Glass(
          shape: GlassRoundedRectangle(
            radius: BorderRadius.circular(metrics.radius),
          ),
          material: style.material,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: style.labelColor),
            child: IconTheme.merge(
              data: IconThemeData(color: style.labelColor),
              child: Column(
                children: <Widget>[
                  if (widget.showHandle)
                    _Handle(color: style.labelColor),
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: metrics.gap > 0 ? 0 : padding.bottom,
                        ),
                        child: widget.child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The grab indicator.
///
/// Drawn, not a `Glass` of its own: a capsule of glass on a sheet of glass is
/// a second refraction over the first, which is the stacked filter this
/// package exists to avoid. `GlassHostScope` is the general form of this rule.
class _Handle extends StatelessWidget {
  const _Handle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            // Apple's own indicator is a low-contrast fill, not the label
            // colour at full strength: it is an affordance, not content.
            color: color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ),
    );
  }
}
```

Add to `lib/glass_forge.dart`, in alphabetical position among the exports:

```dart
export 'src/chrome/detent_geometry.dart' show GlassDetentSheetMetrics;
export 'src/chrome/glass_detent.dart';
export 'src/chrome/glass_detent_sheet.dart';
export 'src/chrome/glass_detent_sheet_controller.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/src/chrome/glass_detent_sheet_test.dart`
Expected: PASS.
Run: `flutter test` — Expected: the whole suite still green.
Run: `flutter analyze` — Expected: no issues.

Expect to iterate on the layout here, and do not weaken a test to settle it:
the `Align`/`SizedBox` pair must produce a sheet whose `getSize().height` is
exactly `metrics.height`, which is what every size assertion in this file
reads. The theme accessor used above is the real one —
`GlassTheme.of(context).tokens.radius.radiusOf(...)`, see
`lib/src/design/glass_theme.dart:149` and `glass_tokens.dart:202`.

- [ ] **Step 5: Commit**

```bash
git add lib/src/chrome/glass_detent_sheet.dart lib/glass_forge.dart test/src/chrome/glass_detent_sheet_test.dart
git commit -m "feat(chrome): GlassDetentSheet, the Apple Maps sheet"
```

---

### Task 7: The scroll handoff

**Files:**
- Create: `lib/src/chrome/glass_sheet_scroll_physics.dart`
- Modify: `lib/src/chrome/glass_detent_sheet.dart` (provide the controller to
  descendants through an `InheritedWidget` so a scrollable can find it)
- Modify: `lib/glass_forge.dart` (one export)
- Test: `test/src/chrome/glass_sheet_scroll_physics_test.dart`

**Interfaces:**
- Consumes: `GlassDetentSheetController`.
- Produces:
  - `class GlassDetentSheetScope extends InheritedWidget` with `static
    GlassDetentSheetController? maybeOf(BuildContext context)` — in
    `glass_detent_sheet.dart`, wrapped around the sheet's child. The physics
    do not read it: the sheet installs them directly through a
    `ScrollConfiguration`, which needs no lookup. The scope is how a *caller's*
    widget deep inside the sheet reaches the controller — to drive its own
    presence, or to animate to a detent from a button in the content.
  - `class GlassSheetScrollPhysics extends ScrollPhysics` with `const
    GlassSheetScrollPhysics({required GlassDetentSheetController controller,
    ScrollPhysics? parent})` and `@override GlassSheetScrollPhysics
    applyTo(ScrollPhysics? ancestor)`.

**The behaviour, restated as three rules the tests pin:**

1. Below the top detent, a vertical drag moves the sheet and the inner
   scrollable does not scroll.
2. At the top detent, the inner scrollable scrolls.
3. Scrolled back to its own zero and still dragging down, the sheet takes the
   gesture back and descends — within the same gesture, with no lifted finger.

`DraggableScrollableSheet` in the framework solves this exact shape
(`packages/flutter/lib/src/widgets/draggable_scrollable_sheet.dart`, see
`_DraggableScrollableSheetScrollPosition.applyUserOffset`). Read it before
writing this; the mechanism below is the same one, reduced to a `ScrollPhysics`
because this sheet's position lives in a controller rather than in the scroll
position.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

void main() {
  late GlassDetentSheetController controller;

  Widget host() {
    return MaterialApp(
      home: GlassLayer(
        child: Stack(
          children: <Widget>[
            const SizedBox.expand(),
            GlassDetentSheet(
              controller: controller,
              detents: const <GlassDetent>[
                GlassDetent.fraction(0.2),
                GlassDetent.fraction(1),
              ],
              child: ListView.builder(
                itemCount: 60,
                itemBuilder: (context, i) =>
                    SizedBox(height: 40, child: Text('row $i')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  setUp(() {
    controller = GlassDetentSheetController(vsync: const TestVSync());
    addTearDown(controller.dispose);
  });

  testWidgets('below the top detent a drag moves the sheet, not the list', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.pixels, 0);

    await tester.drag(find.text('row 0'), const Offset(0, -80));
    await tester.pump();

    expect(position.pixels, 0, reason: 'the list must not have scrolled');
    expect(controller.value, greaterThan(controller.lowest));
  });

  testWidgets('at the top detent the list scrolls', (tester) async {
    await tester.pumpWidget(host());
    controller.animateToDetent(1);
    await tester.pumpAndSettle();

    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    await tester.drag(find.text('row 0'), const Offset(0, -80));
    await tester.pump();

    expect(position.pixels, closeTo(80, 1));
    expect(controller.value, controller.top);
  });

  // The rule that needs one gesture rather than two: scroll the list down,
  // hit its own zero, keep dragging, and the sheet takes over.
  testWidgets('at scroll zero, dragging down hands back to the sheet', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    controller.animateToDetent(1);
    await tester.pumpAndSettle();

    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;

    final gesture = await tester.startGesture(tester.getCenter(find.text('row 2')));
    await gesture.moveBy(const Offset(0, -120)); // scroll the list down
    await tester.pump();
    expect(position.pixels, greaterThan(0));

    await gesture.moveBy(const Offset(0, 120)); // back to its own zero
    await tester.pump();
    expect(position.pixels, closeTo(0, 1));
    expect(controller.value, controller.top, reason: 'sheet has not moved yet');

    await gesture.moveBy(const Offset(0, 120)); // still dragging down
    await tester.pump();
    expect(
      controller.value,
      lessThan(controller.top),
      reason: 'the sheet should have taken the gesture back',
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('dragging up from a descended sheet raises it before scrolling', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    final gesture = await tester.startGesture(tester.getCenter(find.text('row 1')));
    await gesture.moveBy(const Offset(0, -400));
    await tester.pump();

    expect(controller.value, controller.top);
    expect(position.pixels, 0, reason: 'the list waits until the sheet is up');

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/src/chrome/glass_sheet_scroll_physics_test.dart`
Expected: FAIL — the first test fails because the `ListView` scrolls under a
drag that should have moved the sheet.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/chrome/glass_detent_sheet_controller.dart';

/// The physics that makes one gesture cross from a sheet to the list inside
/// it and back, with no lifted finger.
///
/// Position and direction decide, in that order. Below the top detent the
/// sheet owns every vertical delta and the list does not move. At the top
/// detent the list owns them — until it is scrolled back to its own zero and
/// the finger is *still* going down, at which point the sheet takes the
/// gesture back and descends.
///
/// This is `NestedScrollView`'s problem shape and not its API. The framework
/// solves the same one in `DraggableScrollableSheet`, by overriding
/// `applyUserOffset` on a private `ScrollPosition`; here the sheet's position
/// lives in a [GlassDetentSheetController] rather than in a scroll position,
/// so the interception is a `ScrollPhysics` instead and the controller is the
/// thing both consumers agree about.
class GlassSheetScrollPhysics extends ScrollPhysics {
  /// Creates physics that report their overscroll to [controller].
  const GlassSheetScrollPhysics({required this.controller, super.parent});

  /// The sheet this scrollable is inside.
  final GlassDetentSheetController controller;

  @override
  GlassSheetScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      GlassSheetScrollPhysics(
        controller: controller,
        parent: buildParent(ancestor),
      );

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // `offset` is in scroll-delta units: positive means the content moves
    // down, i.e. the finger moved down. The sheet's own convention is the
    // opposite, which is where every sign below comes from.
    final atTop = controller.value >= controller.top;
    final draggingDown = offset > 0;
    final atScrollZero = position.pixels <= position.minScrollExtent;

    if (!atTop) {
      // Rule 1: the sheet owns the gesture.
      controller.dragBy(-offset);
      return 0;
    }
    if (draggingDown && atScrollZero) {
      // Rule 3: the handoff back, mid-gesture.
      controller.dragBy(-offset);
      return 0;
    }
    // Rule 2.
    return super.applyPhysicsToUserOffset(position, offset);
  }
}
```

Then in `glass_detent_sheet.dart`, add the scope and wrap the child:

```dart
/// Carries the sheet's controller down to the scrollables inside it.
class GlassDetentSheetScope extends InheritedWidget {
  /// Creates a scope.
  const GlassDetentSheetScope({
    required this.controller,
    required super.child,
    super.key,
  });

  /// The sheet's controller.
  final GlassDetentSheetController controller;

  /// The nearest enclosing sheet's controller, if any.
  static GlassDetentSheetController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<GlassDetentSheetScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(GlassDetentSheetScope oldWidget) =>
      !identical(oldWidget.controller, controller);
}
```

Wrap `widget.child` in `_sheet` with
`GlassDetentSheetScope(controller: _controller, child: ...)`, and make the
sheet install the physics on descendant scrollables by wrapping the child in a
`ScrollConfiguration` whose `ScrollBehavior.getScrollPhysics` returns
`GlassSheetScrollPhysics(controller: _controller, parent: super.getScrollPhysics(context))`.

**Leave Task 6's body-wide `GestureDetector` exactly as it is.** It does not
compete with the inner scrollable: Flutter's gesture arena gives a pointer on
the list to the inner `Scrollable`, which is the descendant, and the physics
above route those deltas to the controller; a pointer on the handle, on padding,
or on any non-scrolling chrome falls through to the ancestor detector. Both
paths end at the same `dragBy`. Restricting the detector to the handle would
leave a sheet whose child is not scrollable undraggable — which is exactly what
Task 6's own tests exercise.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/src/chrome/glass_sheet_scroll_physics_test.dart`
Expected: PASS.
Run: `flutter test` — Expected: the whole suite green, Task 6's drag tests
included and unchanged.
Run: `flutter analyze` — Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/chrome/glass_sheet_scroll_physics.dart lib/src/chrome/glass_detent_sheet.dart lib/glass_forge.dart test/src/chrome/glass_sheet_scroll_physics_test.dart
git commit -m "feat(chrome): hand one gesture between the detent sheet and its list"
```

---

### Task 8: The example scene, the changelog, and the resume file

**Files:**
- Create: `example/lib/src/scenes/sheet_scene.dart`
- Modify: `example/lib/main.dart` (register the scene)
- Modify: `CHANGELOG.md`
- Modify: `docs/TODO.md`
- Test: covered by `test/src/widgets/glass_widgets_test.dart`'s existing
  doc-example guard — no new test file.

- [ ] **Step 1: Read the existing scenes and match them**

Read `example/lib/src/scene.dart` and `example/lib/src/scenes/system_scene.dart`
first. A scene supplies a `SceneInfo` — name, blurb, photo, and the two
measured backdrop colours — and the stage builds it. Match that contract
exactly; do not invent a second one.

- [ ] **Step 2: Write the scene**

A map-like photo behind, a `GlassDetentSheet` with the three detents from the
spec (0.1, 0.5, 1.0) carrying a list of rows, and — this is the part worth
demonstrating — the page's own bottom bar wrapped in a `GlassPresence` driven
by `controller.presenceUnder(...)`, so the handoff is visible rather than
merely implemented.

- [ ] **Step 3: Run it**

Run: `cd example && flutter run -d <simulator>` — resolve the simulator with
`xcrun simctl list devices | grep '17e'`; the UUID is per-machine and must not
be pinned in a file.

Check by eye, against the spec: the gap tightens continuously under the finger
rather than stepping at each detent; the corners grow into the display's; the
bottom bar is gone before the sheet's glass reaches it, with no moment where
both are rendering; a flick carries past the nearest detent.

- [ ] **Step 4: Mirror the doc example into the guard**

`test/readme_examples_test.dart` is the hand-maintained guard for every `dart`
code block in a `lib/` doc comment: the block is copied there so the analyzer
and the test run actually compile it, with real widgets substituted wherever the
original names a hypothetical one (`NavBarContents`, and here `Map()` and
`results`). Add a `testWidgets('the GlassDetentSheet example builds', ...)` in
the same shape as the file's existing cases, ending in
`expect(tester.takeException(), isNull);`.

Without this the class doc rots silently, which is the exact failure that file
exists to prevent.

Run: `flutter test test/readme_examples_test.dart` — Expected: PASS.

- [ ] **Step 5: Write the docs**

`CHANGELOG.md`, under Unreleased: one entry naming `GlassDetentSheet`,
`GlassDetent`, `GlassDetentSheetController` and `GlassSheetScrollPhysics`.

`docs/TODO.md`: move C5 out of "Added after sign-off" into a landed state, note
that C4/C1/C2/C3 are still unwritten and that C5 landed ahead of them, and
record the spec correction about matte produces from the top of this plan.

- [ ] **Step 6: Commit**

```bash
git add example test/readme_examples_test.dart CHANGELOG.md docs/TODO.md
git commit -m "docs(chrome): the detent sheet scene, changelog and resume notes"
```

---

## Known gaps, stated rather than hidden

Three things this plan deliberately does not finish. Each is a task of its own
and none of them blocks the sheet being useful.

1. **`GlassDetent.content()` is not measured.** The value type resolves it
   correctly and is tested, but Task 6 passes `double.infinity` as the content
   height, so a content detent resolves to the available height. Measuring it
   needs a custom `RenderBox` that lays the child out against
   `getMaxIntrinsicHeight`, and an intrinsic pass every time the child changes
   is a real cost that deserves its own decision.
2. **The bottom-bar handoff is wired by the app, not by the sheet.**
   `presenceUnder` exists and is tested; `GlassScaffold` (C4) is what will call
   it automatically. Until then the example does it by hand, which is also the
   honest documentation of what C4 will be doing.
3. **No overdrag past the top detent.** `dragBy` clamps. `GlassOverdrag` is
   the right tool the day a rubber band past the top, or a drag-to-dismiss
   below the bottom, becomes a wanted gesture.
