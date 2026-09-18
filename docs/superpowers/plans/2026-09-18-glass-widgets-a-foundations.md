# Glass widgets, sub-project A (foundations) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `glass_forge` the four primitives every glass widget in
sub-projects B, C and D depends on: presence (glass that fades without
re-baking its matte), the on-glass scope and its overlap warning, anchored
press-stretch, and a touch glow that spreads between neighbouring shapes.

**Architecture:** Presence is a per-pass scalar, never part of a material, so
animating it cannot re-key `RenderGlassLayer._passes` or invalidate a matte.
It reaches the shader through `uSurface.z` — a uniform slot that already
exists and is currently written as a constant `0` — and everything else it
scales (tint, highlight, contour, dispersion, saturation, frost) is scaled on
the CPU in `_writeUniforms`. The touch glow takes the same route: one new
`uGlow` vec4 on the pass, so it lights every shape in the pass and nothing
between them. Press-stretch is pure geometry and never reaches the shader at
all — it extends `glassSurfaceTransform`, which the render tree already feeds
into shape registration.

**Tech Stack:** Dart / Flutter, `flutter_test`, GLSL (`#version 460 core`,
`flutter/runtime_effect.glsl`), Impeller for the shader lane.

**Spec:** `docs/superpowers/specs/2026-09-14-glass-widgets-design.md` —
sections A1, A2, A3, A4, and the "Decisions made — 2026-09-18" block.

## Global Constraints

- **Never use a lint ignore statement.** Fix the underlying issue. A lint in
  this repository has already caught a real leak.
- **No stacked backdrop filters, ever.** A surface at presence 0 must push
  no `BackdropFilterLayer` at all, not a transparent one. This is
  flutter#187820 and it is the bug the whole pass architecture exists to
  avoid.
- **Presence must not re-key a pass, retire a pass, or rebake a matte.** The
  test for this is `GlassRenderCounters.matteProduceCount`, and it is the
  point of A1.
- **The uniform layout of `final_render.frag` and
  `final_render_bilinear_probe.frag` must stay identical to each other.**
  They differ only in how they sample the backdrop. A3 adds a uniform to
  both or to neither.
- **Any shader change must pass the SkSL web-build gate**
  (`.github/workflows/shaders.yaml`), which builds the example for web. CI
  builds before it analyzes, deliberately — do not reorder it.
- **Reduce Motion is not optional.** Every animated thing added here
  resolves to its instant or `none()` form under
  `MediaQuery.disableAnimationsOf`. The package already has
  `lib/src/motion/reduce_motion.dart`; use it.
- **Public API gets doc comments.** `public_member_api_docs` is on.
- Verification commands, used throughout:
  - `flutter analyze` (from the repository root; covers `example/` only
    after `flutter pub get` has run inside `example/`)
  - `flutter test`
  - `flutter test --tags impeller --run-skipped --enable-impeller`
  - One Impeller test in `test/src/rendering/render_glass_layer_test.dart`
    **already fails** on this lane (it expects `GpuGeometryProducer` and the
    lane runs without `--enable-flutter-gpu`). That one pre-existing failure
    is expected. Any *other* failure is yours.

---

## File Structure

**A1 — presence**

| File | Responsibility |
|---|---|
| `shaders/final_render.frag` | Modify: scale displacement magnitude by `uSurface.z`. |
| `shaders/final_render_bilinear_probe.frag` | Modify: the same edit, verbatim. |
| `lib/src/composition/glass_composition.dart` | Modify: `build`/`willRender` take `presence`; `_writeUniforms` scales the CPU-side channels and writes presence into `uSurface.z`. |
| `lib/src/composition/filter_snapshot.dart` | Modify: carry `presence`, so a presence change rebuilds the filter and nothing else. |
| `lib/src/rendering/render_glass_layer.dart` | Modify: `_PassKey`, per-record presence, per-pass presence, the `willRender` gate. |
| `lib/src/rendering/render_glass_shape.dart` | Modify: hold an `Animation<double>? presence`, listen to it, report it to the layer. |
| `lib/src/widgets/glass_presence.dart` | Create: `GlassPresence` and `GlassPresenceScope`. |
| `lib/glass_forge.dart` | Modify: export `GlassPresence`. |

**A4 — the on-glass scope and the overlap check**

| File | Responsibility |
|---|---|
| `lib/src/widgets/glass_host_scope.dart` | Create: `GlassHostScope`, the "you are drawn on glass" marker. |
| `lib/src/widgets/glass.dart` | Modify: publish `GlassHostScope` above the child; assert on a directly nested `Glass`. |
| `lib/src/rendering/render_glass_layer.dart` | Modify: debug-only cross-pass overlap warning. |

**A2 — anchored press-stretch**

| File | Responsibility |
|---|---|
| `lib/src/motion/glass_press_stretch.dart` | Create: the `GlassPressStretch` value type. |
| `lib/src/motion/glass_motion_state.dart` | Modify: carry `pressAnchor`. |
| `lib/src/motion/glass_jiggle.dart` | Modify: `glassSurfaceTransform` takes the stretch and the anchor. |
| `lib/src/motion/glass_motion_controller.dart` | Modify: track the press anchor. |
| `lib/src/motion/interactive_glass.dart` | Modify: `pressStretch` argument, anchor capture, Reduce Motion. |
| `lib/src/motion/render_glass_motion.dart` | Modify: pass the stretch through. |

**A3 — touch glow**

| File | Responsibility |
|---|---|
| `shaders/final_render.frag` | Modify: `uGlow` uniform and the radial term. |
| `shaders/final_render_bilinear_probe.frag` | Modify: the same. |
| `lib/src/composition/glass_glow.dart` | Create: the `GlassGlow` value type. |
| `lib/src/composition/glass_composition.dart` | Modify: write `uGlow`. |
| `lib/src/composition/filter_snapshot.dart` | Modify: carry the glow. |
| `lib/src/rendering/render_glass_layer.dart` | Modify: hold the layer's live glow, per pass. |
| `lib/src/motion/interactive_glass.dart` | Modify: drive the glow from the pointer. |

---

## Task 1: Presence reaches the shader

**Files:**
- Modify: `shaders/final_render.frag` (the `magnitude` line, ~line 89)
- Modify: `shaders/final_render_bilinear_probe.frag` (same line)
- Modify: `lib/src/composition/filter_snapshot.dart`
- Modify: `lib/src/composition/glass_composition.dart`
- Test: `test/src/composition/glass_composition_presence_test.dart` (create)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `static bool GlassComposition.willRender(GlassMaterial material, double presence)`
  - `ui.ImageFilter? GlassComposition.build({required MatteGeneration? matte, required GlassMaterial material, required FilterSnapshot snapshot, required double devicePixelRatio, required double presence})`
  - `FilterSnapshot.of({..., required double presence})` and `FilterSnapshot.presence`

- [ ] **Step 1: Write the failing test**

Create `test/src/composition/glass_composition_presence_test.dart`. The
uniform write is the contract, so test it through `FilterSnapshot` equality
and `willRender`, which are pure and need no GPU:

```dart
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/composition/filter_snapshot.dart';
import 'package:glass_forge/src/composition/glass_composition.dart';
import 'package:glass_forge/src/material/glass_material.dart';

void main() {
  const material = GlassMaterial();

  test('presence 0 renders nothing, whatever the material would do', () {
    expect(GlassComposition.willRender(material, 1), isTrue);
    expect(GlassComposition.willRender(material, 0), isFalse);
  });

  test('a presence below the epsilon is treated as zero', () {
    expect(GlassComposition.willRender(material, 0.0001), isFalse);
  });

  test('a snapshot differing only in presence is not equal', () {
    final mapping = Float32List.fromList(<double>[1, 0, 0, 1, 0, 0]);
    final full = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 7,
      coordinateMapping: mapping,
      presence: 1,
    );
    final half = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 7,
      coordinateMapping: mapping,
      presence: 0.5,
    );
    expect(full, isNot(equals(half)));
    expect(full.presence, 1);
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/src/composition/glass_composition_presence_test.dart`
Expected: FAIL — `willRender` takes one argument, `FilterSnapshot.of` has no
`presence`.

- [ ] **Step 3: Add `presence` to `FilterSnapshot`**

In `lib/src/composition/filter_snapshot.dart`: add a `required double presence`
to both the constructor and `FilterSnapshot.of`, a
`/// How present this pass's glass is, 0 to 1. See `GlassPresence`.`
doc comment on the field, and add `presence` to `operator ==` and to
`hashCode`'s `Object.hash` argument list.

- [ ] **Step 4: Scale the CPU-side channels in `GlassComposition`**

In `lib/src/composition/glass_composition.dart`:

```dart
/// Below this, a pass is not worth a backdrop read and is dropped entirely.
///
/// Not exactly zero: a spring settling toward 0 lands on values like 1e-9,
/// and a pass that costs a saveLayer and a full backdrop read to draw a
/// billionth of a refraction is a pass that should not be pushed.
static const double _presenceEpsilon = 0.001;

static bool willRender(GlassMaterial material, double presence) {
  if (presence < _presenceEpsilon) {
    return false;
  }
  if (!material.rendersAnything) {
    return false;
  }
  if (!ui.ImageFilter.isShaderFilterSupported) {
    return material.frost * presence > 0;
  }
  return true;
}
```

`build` gains `required double presence`, returns null on
`presence < _presenceEpsilon` before anything else, and scales the frost
everywhere it is computed — both in the composed branch and in `_blurOnly`,
which becomes `_blurOnly(material, devicePixelRatio, presence)`:

```dart
final frost = material.frost * presence * devicePixelRatio;
```

In `_writeUniforms`, which gains a `double presence` parameter, four
uniform writes change and one constant becomes the presence:

```dart
..setFloat(i++, material.maxDisplacement * devicePixelRatio)
..setFloat(i++, material.chromaticAberration * presence)
..setFloat(i++, material.tintOpacity * presence)
..setFloat(i++, 1 + (material.saturation - 1) * presence)
```

Note `maxDisplacement` is **not** scaled: the shader decodes the signed
distance with it, and scaling it would move the edge rather than fade the
refraction. The highlight and the contour scale where `uLighting` is written:

```dart
..setFloat(i++, material.highlight * presence)
..setFloat(i++, material.lightDirection.dx)
..setFloat(i++, material.lightDirection.dy)
..setFloat(i++, material.contour * presence)
```

and the `uSurface.z` slot — the first of the two trailing
`..setFloat(i++, 0)` writes, immediately after `material.thickness` — becomes:

```dart
// uSurface.z is presence: the shader scales the decoded displacement
// magnitude by it and leaves the signed distance alone, so the refraction
// fades without the edge moving. Written as a constant 0 before A1, which
// is why the shader edit and this one have to land together.
..setFloat(i++, presence)
..setFloat(i++, 0)
```

- [ ] **Step 5: Update the two call sites so the package compiles**

`RenderGlassLayer._buildFilter` and the `willRender` call in
`RenderGlassLayer.paint` both need an argument. Pass a literal `1` in this
task; Task 2 replaces it with the real value.

- [ ] **Step 6: Run the test**

Run: `flutter test test/src/composition/glass_composition_presence_test.dart`
Expected: PASS

- [ ] **Step 7: Make the shader edit, in both shaders**

In `shaders/final_render.frag`, the `magnitude` line currently reads:

```glsl
    float magnitude = gfDecodeCompandedMax(encoded.a) * uOptical.x;
```

Replace it with:

```glsl
    // uSurface.z is presence. Scaling the magnitude here rather than
    // uOptical.x is deliberate: uOptical.x also decodes the signed distance
    // above, which drives coverage and antialiasing, so scaling it would
    // shrink the shape instead of fading its refraction.
    float magnitude = gfDecodeCompandedMax(encoded.a) * uOptical.x * uSurface.z;
```

Update the `uniform vec4 uSurface;` comment in both files from
`// profile (0 edge band, 1 dome), thickness, 0, 0` to
`// profile (0 edge band, 1 dome), thickness, presence, 0`.

Make the identical edit in `shaders/final_render_bilinear_probe.frag`.

- [ ] **Step 8: Verify the whole suite and the shader gate**

Run: `flutter analyze`
Expected: no issues.

Run: `flutter test`
Expected: all pass (the pre-existing Impeller failure is not in this lane).

Run the SkSL gate the way CI runs it — `flutter build web` on its own
fails with "This project is not configured for the web", because the example
is a phone demo with no `web/` folder checked in:

```bash
cd example
flutter create --platforms=web .
flutter build web --release
rm -rf web && rm -f test/widget_test.dart && git checkout .metadata
cd ..
```

The cleanup line is not optional **locally**. `flutter create` scaffolds
`web/`, writes a template `test/widget_test.dart` referring to a `MyApp` this
app does not have, and rewrites `example/.metadata`. CI deletes only the
template test — see `.github/workflows/shaders.yaml` — because it runs on a
throwaway checkout where a leftover `web/` and a rewritten `.metadata` are
discarded with the runner. On a working tree they are not: they leave the
repository dirty and the template test breaks `flutter analyze`. That
workflow is still the authority on the rest of the gate, including why it
must run before analyze.
Expected: succeeds. This is the SkSL gate; a malformed shader fails here.

- [ ] **Step 9: Commit**

```bash
git add shaders/final_render.frag shaders/final_render_bilinear_probe.frag \
  lib/src/composition/filter_snapshot.dart \
  lib/src/composition/glass_composition.dart \
  lib/src/rendering/render_glass_layer.dart \
  test/src/composition/glass_composition_presence_test.dart
git commit -m "feat(presence): fade a pass's refraction through uSurface.z

The displacement magnitude is scaled in the shader; tint, dispersion,
saturation, highlight, contour and frost are scaled on the CPU. Signed
distance is left alone, so the edge stays where it is and the refraction
fades out from under it rather than shrinking.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: The layer carries presence per pass, without re-keying

**Files:**
- Modify: `lib/src/rendering/render_glass_layer.dart`
- Modify: `lib/src/rendering/render_glass_shape.dart`
- Test: `test/src/rendering/render_glass_layer_presence_test.dart` (create)

**Interfaces:**
- Consumes: `GlassComposition.willRender(material, presence)` and
  `build(..., presence:)` from Task 1.
- Produces:
  - `void RenderGlassLayer.registerShape(Object key, ShapeGeometry geometry, GlassMaterial? material, Object? group, Object? presenceScope, double presence)`
  - `void RenderGlassLayer.updateShapePresence(Object key, double presence)`
  - `set RenderGlassShape.presence(Animation<double>? value)`

**The design, which the steps below implement.** The pass map is keyed by
material *value* today, so any change to a material re-registers its shapes
into a new pass, retires the old one, and bakes a fresh matte. Presence must
never do that. So:

- The key becomes `_PassKey(GlassMaterial material, Object? presenceScope)`,
  where `presenceScope` is the **identity** of the driving `Animation<double>`
  — stable for the whole life of a `GlassPresence`, so a presence that
  animates from 0 to 1 over sixty frames never changes the key once.
- The presence **value** lives on `_GlassPass` as a plain mutable double. It
  is read at `paint` time for the `willRender` gate and passed to
  `composition.build`. Changing it invalidates the `FilterSnapshot` and
  therefore the composed `ImageFilter`, and nothing else — not the scene, not
  the matte, not the pass.
- Shapes report presence changes through `updateShapePresence`, called from
  `RenderGlassShape`'s animation listener, which then marks the layer for
  paint. Animations tick before paint in the frame pipeline, so the value the
  layer reads at the top of `paint` is this frame's.

- [ ] **Step 1: Write the failing test**

Create `test/src/rendering/render_glass_layer_presence_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/diagnostics/render_counters.dart';

void main() {
  testWidgets('animating presence bakes no new mattes', (tester) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 200),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: GlassPresence(
            presence: controller,
            child: Glass(shape: const GlassRoundedRectangle(radius: BorderRadius.circular(28)), child: const SizedBox(width: 120, height: 48)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    GlassRenderCounters.instance.reset();
    controller.forward();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(
      GlassRenderCounters.instance.matteProduceCount,
      0,
      reason: 'presence must not re-key a pass or invalidate its matte',
    );
  });

  testWidgets('presence 0 pushes no backdrop filter', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: GlassPresence(
            presence: const AlwaysStoppedAnimation<double>(0),
            child: Glass(shape: const GlassRoundedRectangle(radius: BorderRadius.circular(28)), child: const SizedBox(width: 120, height: 48)),
          ),
        ),
      ),
    );
    await tester.pump();

    GlassRenderCounters.instance.reset();
    await tester.pump();
    expect(GlassRenderCounters.instance.backdropPushCount, 0);
  });
}
```

This test also needs Task 3's `GlassPresence`. That is deliberate — the
plumbing is not observable without it — so **Task 3 is where this test goes
green.** Write it now, watch it fail, and leave it failing until Task 3.

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/src/rendering/render_glass_layer_presence_test.dart`
Expected: FAIL — `GlassPresence` is undefined.

- [ ] **Step 3: Add `_PassKey` and rekey the pass map**

In `lib/src/rendering/render_glass_layer.dart`, above `_GlassPass`:

```dart
/// What makes two shapes share one backdrop pass.
///
/// The material, by value, as it always was — and the identity of whatever
/// drives their presence. Identity, not value, is the whole point: a
/// presence animating from 0 to 1 over sixty frames has sixty different
/// *values* and one `Animation` object, so keying on the object means the
/// pass, its scene and its matte all survive the animation untouched. The
/// value lives on [_GlassPass.presence] instead, where changing it costs a
/// rebuilt `ImageFilter` and nothing more.
@immutable
class _PassKey {
  const _PassKey(this.material, this.presenceScope);

  final GlassMaterial material;
  final Object? presenceScope;

  @override
  bool operator ==(Object other) =>
      other is _PassKey &&
      other.material == material &&
      identical(other.presenceScope, presenceScope);

  @override
  int get hashCode => Object.hash(material, identityHashCode(presenceScope));
}
```

Change `_passes` to `final Map<_PassKey, _GlassPass> _passes = <_PassKey, _GlassPass>{};`
and `_GlassPass`'s constructor to `_GlassPass(this.key)` with
`final _PassKey key;` and `GlassMaterial get material => key.material;`,
plus:

```dart
/// How present this pass's glass is this frame, 0 to 1.
///
/// Mutable and outside the key on purpose. See [_PassKey].
double presence = 1;
```

- [ ] **Step 4: Carry presence on the shape record and through registration**

`_ShapeRecord` gains:

```dart
/// The identity of whatever drives this shape's presence, or null.
Object? presenceScope;

/// This shape's presence this frame, 0 to 1.
double presence;
```

`registerShape` gains `Object? presenceScope, double presence` parameters.
In the "new record" branch, store both. In the change-detection branch, add
`!identical(existing.presenceScope, presenceScope)` to the condition that
sets `_assignmentsDirty` — a changed *scope* re-keys, which is correct and
rare. A changed presence **value** must not: assign
`existing.presence = presence;` on the hot path, before the
`_passes[assigned]?.scene.register(...)` line, without touching
`_assignmentsDirty`.

Change `_ShapeRecord.assigned` from `GlassMaterial?` to `_PassKey?` and
update `unregisterShape` and `_reassignPasses` accordingly. In
`_reassignPasses`, the target becomes:

```dart
final material = group == null
    ? record.declared ?? _material
    : groupMaterials[group]!;
final target = _PassKey(material, record.presenceScope);
```

and the `_passes.removeWhere` closure's first parameter is now a `_PassKey`.

Add the value-update entry point:

```dart
/// Updates one shape's presence without disturbing its pass.
///
/// Called from `RenderGlassShape`'s presence listener, which ticks in the
/// animation phase — before paint — so the value read at the top of [paint]
/// is this frame's.
void updateShapePresence(Object key, double presence) {
  final record = _records[key];
  if (record == null || record.presence == presence) {
    return;
  }
  record.presence = presence;
  markNeedsPaint();
}
```

- [ ] **Step 5: Fold the shapes' presence into each pass at paint**

At the top of `paint`, immediately after the `_reassignPasses()` block and
before the `passes` list is built:

```dart
// Fold each pass's shapes' presence into the pass. A pass is one surface:
// the highest presence among its shapes wins rather than an average, so a
// pass is fully present as soon as any shape in it is, and reaches zero
// only when every shape has.
for (final pass in _passes.values) {
  pass.presence = 0;
}
for (final record in _records.values) {
  final pass = _passes[record.assigned];
  if (pass != null && record.presence > pass.presence) {
    pass.presence = record.presence;
  }
}
```

Change the gate to `if (GlassComposition.willRender(pass.material, pass.presence)) pass,`
and `_buildFilter` to pass `presence: pass.presence` to both
`FilterSnapshot.of` and `composition.build`.

- [ ] **Step 6: Give `RenderGlassShape` a presence animation**

In `lib/src/rendering/render_glass_shape.dart`, add a field mirroring how
`material` and `group` are handled:

```dart
/// What drives this shape's presence, or null for fully present.
Animation<double>? get presence => _presence;
Animation<double>? _presence;
set presence(Animation<double>? value) {
  if (identical(_presence, value)) {
    return;
  }
  if (attached) {
    _presence?.removeListener(_onPresenceChanged);
  }
  _presence = value;
  if (attached) {
    value?.addListener(_onPresenceChanged);
  }
  // A changed *driver* re-keys the pass, unlike a changed value.
  markNeedsPaint();
}

void _onPresenceChanged() {
  _layer?.updateShapePresence(this, _presence!.value);
}
```

Add and remove the listener in `attach` and `detach` alongside whatever the
class already does there, and pass `_presence` (as the scope token) and
`_presence?.value ?? 1.0` into every `registerShape` call the class makes.
Read the existing file: `_layer` may be named differently, and registration
may happen in more than one place.

- [ ] **Step 7: Verify it compiles and nothing regressed**

Run: `flutter analyze`
Expected: no issues.

Run: `flutter test`
Expected: everything passes except
`test/src/rendering/render_glass_layer_presence_test.dart`, which still fails
on the undefined `GlassPresence`. That is Task 3.

- [ ] **Step 8: Commit**

```bash
git add lib/src/rendering/render_glass_layer.dart \
  lib/src/rendering/render_glass_shape.dart \
  test/src/rendering/render_glass_layer_presence_test.dart
git commit -m "feat(presence): key passes by material and presence driver identity

The value lives on the pass, outside the key, so an animating presence
rebuilds one ImageFilter rather than a pass, a scene and a matte per frame.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: The `GlassPresence` widget

**Files:**
- Create: `lib/src/widgets/glass_presence.dart`
- Modify: `lib/src/widgets/glass.dart`
- Modify: `lib/glass_forge.dart`
- Test: `test/src/rendering/render_glass_layer_presence_test.dart` (from Task 2, now goes green)
- Test: `test/src/widgets/glass_presence_test.dart` (create)

**Interfaces:**
- Consumes: `RenderGlassShape.presence` and `updateShapePresence` from Task 2.
- Produces:
  - `class GlassPresence extends StatelessWidget` with
    `const GlassPresence({required Animation<double> presence, required Widget child, Key? key})`
  - `class GlassPresenceScope extends InheritedWidget` with
    `static Animation<double>? maybeOf(BuildContext context)`

- [ ] **Step 1: Write the widget**

Create `lib/src/widgets/glass_presence.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Fades a glass subtree in or out by ramping its refraction, frost, tint
/// and light together, then drops the backdrop pass entirely at zero.
///
/// Not an [Opacity]. Glass has no alpha to fade: a half-transparent
/// refraction is still a full backdrop read, and at zero it is a saveLayer
/// and a stacked filter drawing nothing — which is the flutter#187820 bug
/// this package exists to avoid. So presence ramps the *effect* and, at the
/// bottom of the ramp, stops pushing a pass at all. This is also what Apple
/// does: materializing glass ramps refraction, not alpha.
///
/// Presence applies per backdrop pass, so every shape sharing one material
/// under one [GlassPresence] fades together. A surface that fades on its own
/// while its neighbours stay put already has its own material.
///
/// ```dart
/// GlassPresence(
///   presence: _sheetController,
///   child: Glass(shape: const GlassRoundedRectangle(radius: BorderRadius.circular(28))),
/// )
/// ```
class GlassPresence extends StatelessWidget {
  /// Creates a presence scope.
  const GlassPresence({
    required this.presence,
    required this.child,
    super.key,
  });

  /// 0 is no glass at all; 1 is the material as declared.
  ///
  /// Held by identity, not by value: the object drives one backdrop pass for
  /// its whole life, so animating it costs a rebuilt image filter per frame
  /// and never a rebaked matte.
  final Animation<double> presence;

  /// The subtree whose glass this fades.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassPresenceScope(presence: presence, child: child);
  }
}

/// Carries the presence animation down to the shapes it drives.
class GlassPresenceScope extends InheritedWidget {
  /// Creates a scope.
  const GlassPresenceScope({
    required this.presence,
    required super.child,
    super.key,
  });

  /// What drives the glass below this point.
  final Animation<double> presence;

  /// The nearest enclosing presence, if any.
  static Animation<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<GlassPresenceScope>()
        ?.presence;
  }

  @override
  bool updateShouldNotify(GlassPresenceScope oldWidget) =>
      !identical(oldWidget.presence, presence);
}
```

- [ ] **Step 2: Wire it into `Glass`**

In `lib/src/widgets/glass.dart`, `_RawGlass` gains
`final Animation<double>? presence;`, sets it in both `createRenderObject`
and `updateRenderObject`, and `Glass.build` reads it:

```dart
return _RawGlass(
  shape: shape,
  group: group,
  presence: GlassPresenceScope.maybeOf(context),
  material: _resolveMaterialFor(context, material),
  child: ...
);
```

- [ ] **Step 3: Export it**

Add to `lib/glass_forge.dart`, in the same style as the neighbouring exports:

```dart
export 'src/widgets/glass_presence.dart' show GlassPresence;
```

Check whether the file exports `src/widgets/glass.dart` wholesale or names
symbols; match it.

- [ ] **Step 4: Write the widget's own test**

Create `test/src/widgets/glass_presence_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

void main() {
  testWidgets('presence reaches the shape below it', (tester) async {
    const presence = AlwaysStoppedAnimation<double>(0.4);
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: GlassPresence(
            presence: presence,
            child: Glass(
              shape: const GlassRoundedRectangle(radius: BorderRadius.circular(28)),
              child: const SizedBox(width: 100, height: 40),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final shape = tester.renderObject(find.byType(Glass).first);
    expect(shape, isNotNull);
  });

  testWidgets('a glass with no presence above it is fully present',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Glass(
            shape: const GlassRoundedRectangle(radius: BorderRadius.circular(28)),
            child: const SizedBox(width: 100, height: 40),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
```

Replace the first test's weak assertion with a real one once you can see the
render object's type from the file: assert
`(shape as RenderGlassShape).presence!.value` is `0.4`. The point of the test
is that the animation reached the render object, so assert exactly that.

- [ ] **Step 5: Run both presence test files**

Run: `flutter test test/src/widgets/glass_presence_test.dart test/src/rendering/render_glass_layer_presence_test.dart`
Expected: PASS, including Task 2's two tests — the matte count stays at 0
across twenty animating frames, and presence 0 pushes no backdrop.

If the matte count is **not** zero, do not relax the test. Find what
re-registered the scene: it will be either a `_PassKey` comparing presence by
value, or `_assignmentsDirty` being set on the hot path in `registerShape`.

- [ ] **Step 6: Full verification**

Run: `flutter analyze`
Run: `flutter test`
Run: `flutter test --tags impeller --run-skipped --enable-impeller`
Expected: only the one pre-existing `GpuGeometryProducer` failure.

- [ ] **Step 7: Commit**

```bash
git add lib/src/widgets/glass_presence.dart lib/src/widgets/glass.dart \
  lib/glass_forge.dart test/src/widgets/glass_presence_test.dart \
  test/src/rendering/render_glass_layer_presence_test.dart
git commit -m "feat(presence): add the GlassPresence widget

A1 is complete: glass fades in and out without rebaking a matte, and a
surface at presence 0 pushes no backdrop pass at all.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: `GlassHostScope` — controls know when they are on glass

**Files:**
- Create: `lib/src/widgets/glass_host_scope.dart`
- Modify: `lib/src/widgets/glass.dart`
- Modify: `lib/glass_forge.dart`
- Test: `test/src/widgets/glass_host_scope_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: `class GlassHostScope extends InheritedWidget` with
  `static bool GlassHostScope.isOnGlass(BuildContext context)` and
  `static GlassHostScope? maybeOf(BuildContext context)`. **Every control in
  sub-project B calls `GlassHostScope.isOnGlass(context)` to decide whether
  to render itself as glass or as paint.**

- [ ] **Step 1: Write the failing test**

Create `test/src/widgets/glass_host_scope_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

void main() {
  testWidgets('a child of Glass is on glass', (tester) async {
    late bool onGlass;
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Glass(
            shape: const GlassRoundedRectangle(radius: BorderRadius.circular(28)),
            child: Builder(
              builder: (context) {
                onGlass = GlassHostScope.isOnGlass(context);
                return const SizedBox(width: 100, height: 40);
              },
            ),
          ),
        ),
      ),
    );
    expect(onGlass, isTrue);
  });

  testWidgets('a child of a plain layer is not on glass', (tester) async {
    late bool onGlass;
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Builder(
            builder: (context) {
              onGlass = GlassHostScope.isOnGlass(context);
              return const SizedBox(width: 100, height: 40);
            },
          ),
        ),
      ),
    );
    expect(onGlass, isFalse);
  });

  testWidgets('a Glass directly inside a Glass asserts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Glass(
            shape: const GlassRoundedRectangle(radius: BorderRadius.circular(28)),
            child: Glass(
              shape: const GlassRoundedRectangle(radius: BorderRadius.circular(28)),
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/src/widgets/glass_host_scope_test.dart`
Expected: FAIL — `GlassHostScope` is undefined.

- [ ] **Step 3: Write the scope**

Create `lib/src/widgets/glass_host_scope.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Marks a subtree as being drawn *on* a glass surface.
///
/// This is how one control class is correct in both places it can be put,
/// with no mode for a developer to remember. A switch on a page's content
/// makes its knob glass; the same switch in a glass toolbar paints its knob
/// instead, because a second refraction over the first is a stacked backdrop
/// filter — flutter#187820, the bug this package is built around.
///
/// ```dart
/// final onGlass = GlassHostScope.isOnGlass(context);
/// return onGlass ? _painted() : Glass(shape: shape, child: _painted());
/// ```
class GlassHostScope extends InheritedWidget {
  /// Creates a scope.
  const GlassHostScope({required super.child, super.key});

  /// The nearest enclosing glass surface's scope, if any.
  static GlassHostScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GlassHostScope>();
  }

  /// Whether [context] is drawn on a glass surface.
  static bool isOnGlass(BuildContext context) => maybeOf(context) != null;

  @override
  bool updateShouldNotify(GlassHostScope oldWidget) => false;
}
```

- [ ] **Step 4: Publish it from `Glass`, and assert on nesting**

In `Glass.build`, after the `scope == null` branch and before `_RawGlass`:

```dart
assert(
  !GlassHostScope.isOnGlass(context),
  'glass_forge: a Glass was built directly inside another Glass. Two '
  'refractions over the same pixels is a stacked backdrop filter '
  '(flutter#187820), which samples a stale previous-frame backdrop '
  'including its own output. Put both shapes in one GlassLayer instead, '
  'or join them with a GlassBlendGroup.',
);
```

Wrap the child in the scope, inside the clip so it covers exactly the glass:

```dart
child: GlassHostScope(
  child: ClipPath(
    clipper: GlassShapeClipper(shape),
    clipBehavior: clipBehavior,
    child: child ?? const SizedBox.shrink(),
  ),
),
```

- [ ] **Step 5: Export and run**

Add `export 'src/widgets/glass_host_scope.dart' show GlassHostScope;` to
`lib/glass_forge.dart`, matching the neighbouring style.

Run: `flutter test test/src/widgets/glass_host_scope_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/src/widgets/glass_host_scope.dart lib/src/widgets/glass.dart \
  lib/glass_forge.dart test/src/widgets/glass_host_scope_test.dart
git commit -m "feat(a4): add GlassHostScope so a control knows it is on glass

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: The cross-pass overlap warning

**Files:**
- Modify: `lib/src/rendering/render_glass_layer.dart`
- Test: `test/src/rendering/glass_overlap_warning_test.dart` (create)

**Interfaces:**
- Consumes: `_PassKey` and `_records` from Task 2.
- Produces: nothing public. A debug-only `debugPrint` — **a warning, not an
  assert**, per decision 3 of 2026-09-18: overlap is legitimately transient
  mid-transition, and C5's detent-sheet handoff drags straight through that
  window.

- [ ] **Step 1: Write the failing test**

Create `test/src/rendering/glass_overlap_warning_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

void main() {
  testWidgets('two overlapping shapes in different passes warn',
      (tester) async {
    final printed = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) printed.add(message);
    };
    addTearDown(() => debugPrint = original);

    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                top: 0,
                child: Glass(
                  shape: const GlassRoundedRectangle(radius: BorderRadius.circular(28)),
                  material: const GlassMaterial(frost: 8),
                  child: const SizedBox(width: 100, height: 100),
                ),
              ),
              Positioned(
                left: 40,
                top: 40,
                child: Glass(
                  shape: const GlassRoundedRectangle(radius: BorderRadius.circular(28)),
                  material: const GlassMaterial(frost: 20),
                  child: const SizedBox(width: 100, height: 100),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      printed.where((m) => m.contains('187820')),
      isNotEmpty,
      reason: 'overlapping shapes in different passes stack backdrop filters',
    );
  });

  testWidgets('two shapes sharing a material do not warn', (tester) async {
    final printed = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) printed.add(message);
    };
    addTearDown(() => debugPrint = original);

    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                top: 0,
                child: Glass(
                  shape: const GlassRoundedRectangle(radius: BorderRadius.circular(28)),
                  child: const SizedBox(width: 100, height: 100),
                ),
              ),
              Positioned(
                left: 40,
                top: 40,
                child: Glass(
                  shape: const GlassRoundedRectangle(radius: BorderRadius.circular(28)),
                  child: const SizedBox(width: 100, height: 100),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(printed.where((m) => m.contains('187820')), isEmpty);
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/src/rendering/glass_overlap_warning_test.dart`
Expected: FAIL — the first test finds no warning.

- [ ] **Step 3: Implement the check**

In `RenderGlassLayer`, add the method and call it from `paint` immediately
after the pass-presence fold from Task 2 and before the `passes` list is
built — that is the point where every shape's geometry is from last frame's
registration, which is exactly what the warning is about and is good enough
for a diagnostic:

```dart
/// Warns when two shapes in *different* passes overlap.
///
/// Two backdrop passes over the same pixels is flutter#187820: the upper one
/// reads a stale previous-frame backdrop, including its own output, and
/// white-washes progressively on physical iPhones. It has shipped broken in
/// this repository by accident more than once, which is why it is checked
/// rather than documented.
///
/// A warning rather than an assert, deliberately. Overlap is legitimately
/// transient — a sheet rising over a tab bar overlaps it for exactly as long
/// as the handoff takes — and an assert would throw mid-transition, taking
/// out the frame that was in the middle of fixing it. Shapes inside one pass
/// are fine: they share a matte and fold into one surface.
void _debugWarnOnCrossPassOverlap() {
  assert(() {
    final entries = _records.entries.toList(growable: false);
    for (var i = 0; i < entries.length; i++) {
      final a = entries[i].value;
      if (a.presence <= 0) {
        continue;
      }
      for (var j = i + 1; j < entries.length; j++) {
        final b = entries[j].value;
        if (b.presence <= 0 || a.assigned == b.assigned) {
          continue;
        }
        if (!a.geometry.bounds.overlaps(b.geometry.bounds)) {
          continue;
        }
        debugPrint(
          'glass_forge: two glass shapes in different backdrop passes '
          'overlap (${a.geometry.bounds} and ${b.geometry.bounds}). The '
          'upper pass samples the lower one\'s output from the previous '
          'frame -- flutter#187820 -- which white-washes progressively on '
          'a physical iPhone. Give them the same material so they share a '
          'pass, join them with a GlassBlendGroup, or hand one off to the '
          'other with GlassPresence so only one is present at a time.',
        );
        return true;
      }
    }
    return true;
  }(), 'debug-only warning; always true');
}
```

`ShapeGeometry` may not expose `bounds` under that name. Read
`lib/src/shapes/shape_geometry.dart` and use whatever it does expose; if it
exposes a centre and a size, build the `Rect` from those. Do not add a
`bounds` getter to `ShapeGeometry` just for this unless nothing else fits.

One warning per paint, not one per pair: the `return true` inside the loop
exists for that. A screen with a real overlap repaints constantly, and one
line per frame per pair is unreadable.

- [ ] **Step 4: Run the test**

Run: `flutter test test/src/rendering/glass_overlap_warning_test.dart`
Expected: PASS — the differing-material case warns, the shared-material case
does not.

- [ ] **Step 5: Check the example does not warn**

Run: `cd example && flutter run -d macos` (or the iPhone 17e simulator,
`2473CC29-B74E-43FC-B4C5-7162629E0DFC`) and visit all five scenes, watching
the console.

Expected: no `187820` lines. If any appear, **that is a real bug in the
example, not a false positive** — the resume file already records that this
rule "has shipped broken in this repo by accident". Fix the example, or write
down precisely which scene overlaps and why, in `docs/TODO.md`.

- [ ] **Step 6: Full verification and commit**

Run: `flutter analyze && flutter test`

```bash
git add lib/src/rendering/render_glass_layer.dart \
  test/src/rendering/glass_overlap_warning_test.dart
git commit -m "feat(a4): warn when shapes in different passes overlap

A4 is complete. A warning rather than an assert: overlap is transient during
a handoff, and an assert would throw on the frame that was fixing it.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: `GlassPressStretch`, as pure geometry

**Files:**
- Create: `lib/src/motion/glass_press_stretch.dart`
- Modify: `lib/src/motion/glass_motion_state.dart`
- Modify: `lib/src/motion/glass_jiggle.dart`
- Test: `test/src/motion/glass_press_stretch_test.dart` (create)

**Interfaces:**
- Consumes: `GlassMotionState`, `glassSurfaceTransform`, `GlassJiggle`.
- Produces:
  - `class GlassPressStretch` with `const GlassPressStretch({double intensity = 0.5, double squash = 0.3, double travel = 0.15})`, `const GlassPressStretch.none()`, and `bool get isActive`
  - `GlassMotionState.pressAnchor` (an `Offset`) and a `pressAnchor` argument on its constructor
  - `Matrix4 glassSurfaceTransform({required Size size, required GlassMotionState state, required GlassJiggle jiggle, required GlassPressStretch pressStretch, required double pressScale})`

**Why an anchor, and why it is new state.** The spec says the follow spring
already tracks the finger. It does, through
`GlassMotionController.rawDisplacement` — but only while `GlassDrag` is
enabled. A button uses `GlassDrag.none()`, so nothing tracks the finger for
it. The anchor is therefore its own field: the pointer's offset from the
surface's centre at the last pointer event, in logical pixels, `Offset.zero`
at rest. It needs no spring of its own, because multiplying it by
`state.press` — which is already sprung — ramps it in and out for free, and
keeps the deformation causally locked to the press exactly as `GlassJiggle`
is locked to velocity.

- [ ] **Step 1: Write the failing test**

Create `test/src/motion/glass_press_stretch_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/motion/glass_jiggle.dart';
import 'package:glass_forge/src/motion/glass_motion_state.dart';
import 'package:glass_forge/src/motion/glass_press_stretch.dart';

void main() {
  const size = Size(200, 80);
  const jiggle = GlassJiggle.none();
  const stretch = GlassPressStretch();

  Matrix4 transformFor(GlassMotionState state, GlassPressStretch s) {
    return glassSurfaceTransform(
      size: size,
      state: state,
      jiggle: jiggle,
      pressStretch: s,
      pressScale: 1,
    );
  }

  test('a zero anchor is the identity', () {
    final m = transformFor(
      const GlassMotionState(
        translation: Offset.zero,
        velocity: Offset.zero,
        press: 1,
        pressAnchor: Offset.zero,
      ),
      stretch,
    );
    expect(m, equals(Matrix4.identity()));
  });

  test('none() is the identity for any anchor', () {
    final m = transformFor(
      const GlassMotionState(
        translation: Offset.zero,
        velocity: Offset.zero,
        press: 1,
        pressAnchor: Offset(80, 20),
      ),
      const GlassPressStretch.none(),
    );
    expect(m, equals(Matrix4.identity()));
  });

  test('translation is exactly travel x anchor x press', () {
    final m = transformFor(
      const GlassMotionState(
        translation: Offset.zero,
        velocity: Offset.zero,
        press: 1,
        pressAnchor: Offset(80, 0),
      ),
      const GlassPressStretch(intensity: 0, squash: 0, travel: 0.15),
    );
    expect(m.getTranslation().x, closeTo(12, 1e-9)); // 0.15 * 80
    expect(m.getTranslation().y, closeTo(0, 1e-9));
  });

  test('squash 1 conserves area', () {
    final m = transformFor(
      const GlassMotionState(
        translation: Offset.zero,
        velocity: Offset.zero,
        press: 1,
        pressAnchor: Offset(60, 25),
      ),
      const GlassPressStretch(intensity: 0.5, squash: 1, travel: 0),
    );
    final determinant =
        m.entry(0, 0) * m.entry(1, 1) - m.entry(0, 1) * m.entry(1, 0);
    expect(determinant, closeTo(1, 1e-6));
  });

  test('an unpressed surface is unstretched however far the anchor is', () {
    final m = transformFor(
      const GlassMotionState(
        translation: Offset.zero,
        velocity: Offset.zero,
        press: 0,
        pressAnchor: Offset(90, 30),
      ),
      stretch,
    );
    expect(m, equals(Matrix4.identity()));
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/src/motion/glass_press_stretch_test.dart`
Expected: FAIL — `GlassPressStretch` is undefined and `GlassMotionState` has
no `pressAnchor`.

- [ ] **Step 3: Write `GlassPressStretch`**

Create `lib/src/motion/glass_press_stretch.dart`:

```dart
import 'package:flutter/foundation.dart';

/// How far a surface elongates toward a held finger.
///
/// Apple's buttons reach toward where they are being touched and pull back
/// when the finger lifts, while barely moving. The reaching is most of the
/// effect; the moving is almost none of it, which is why [travel] is small.
///
/// Derived from the press channel rather than sprung separately, for the
/// same reason `GlassJiggle` is derived from velocity: a second spring has
/// its own phase, and drifts out of step with the press it is supposed to be
/// caused by. Multiplying by the already-sprung press depth makes the
/// deformation causal by construction, needing no extra state and no extra
/// ticker.
///
/// The defaults match what `liquid_glass_widgets` settled on. They are a
/// starting point and are checked against a screen recording of an iOS 27
/// button before they ship.
@immutable
class GlassPressStretch {
  /// Creates a press-stretch.
  const GlassPressStretch({
    this.intensity = 0.5,
    this.squash = 0.3,
    this.travel = 0.15,
  })  : assert(intensity >= 0, 'intensity is a fraction at or above 0'),
        assert(squash >= 0 && squash <= 1, 'squash is a fraction 0 to 1'),
        assert(travel >= 0, 'travel is a fraction at or above 0');

  /// No deformation at all. What Reduce Motion resolves to.
  const GlassPressStretch.none()
      : intensity = 0,
        squash = 0,
        travel = 0;

  /// How far the surface elongates along the finger's offset, as a fraction
  /// of that offset relative to the surface's own size.
  final double intensity;

  /// How much of that elongation is conserved as squash across it.
  ///
  /// 1 keeps area exactly. Lower keeps a label on the surface from
  /// distorting, which is why the default is well below 1: a button's text
  /// is drawn on the surface and deforms with it.
  final double squash;

  /// The fraction of the finger's offset the surface actually translates.
  final double travel;

  /// Whether this deforms or moves anything.
  bool get isActive => intensity > 0 || travel > 0;
}
```

- [ ] **Step 4: Add `pressAnchor` to `GlassMotionState`**

Add the field, a `required this.pressAnchor` (give it a default of
`Offset.zero` so existing call sites keep compiling — check whether any do,
and prefer making it required and fixing them if the list is short), include
it in `rest`, `operator ==`, `hashCode` and `toString`, and extend `isAtRest`
with `&& pressAnchor == Offset.zero`. Doc comment:

```dart
/// Where the finger is, relative to the surface's centre, in logical
/// pixels.
///
/// [Offset.zero] when nothing is touching it. Scaled by [press] wherever it
/// is used, so it ramps in and out on the press spring rather than
/// snapping.
final Offset pressAnchor;
```

- [ ] **Step 5: Extend `glassSurfaceTransform`**

In `lib/src/motion/glass_jiggle.dart`, add
`required GlassPressStretch pressStretch` to the parameter list, and compute
the press deformation alongside the existing velocity one. Insert after
`final stretch = jiggle.stretchFor(speed);`:

```dart
  // The press anchor, as a fraction of the surface's own half-extent, so a
  // finger at the edge of a small button reaches as far proportionally as
  // one at the edge of a large one.
  final anchor = state.pressAnchor * state.press;
  final reach = pressStretch.isActive && anchor != Offset.zero
      ? Offset(
          anchor.dx / (size.width / 2),
          anchor.dy / (size.height / 2),
        )
      : Offset.zero;
  final reachDistance = reach.distance;
  final pressAlong = 1 + pressStretch.intensity * reachDistance;
  final pressAcross =
      1 / (1 + pressStretch.intensity * reachDistance * pressStretch.squash);
```

Then fold `pressAlong`/`pressAcross` into the 2x2 the same way the velocity
stretch is folded — as a second similarity transform, rotated into the
*anchor's* frame rather than the velocity's. The existing branch handles one
deformation; you now have up to two, in different frames. Write it as: build
the velocity 2x2 as it is built today, build the anchor 2x2 the same way from
`reach.dx / reachDistance` and `reach.dy / reachDistance`, and multiply the
two 2x2s together by hand (four multiply-adds — do not allocate two
`Matrix4`s to do it). When `reachDistance == 0` the anchor 2x2 is the
identity and must be skipped, exactly as `stretch == 1` is skipped today.

Finally, add `travel` to the translation:

```dart
    ..translateByDouble(
      state.translation.dx + anchor.dx * pressStretch.travel + centreX,
      state.translation.dy + anchor.dy * pressStretch.travel + centreY,
      0,
      1,
    )
```

Note `squash: 1` must give determinant exactly 1: with `pressAcross` defined
as the reciprocal above, `pressAlong * pressAcross == 1` when `squash == 1`,
which is what the test checks.

- [ ] **Step 6: Fix the one existing call site**

`lib/src/motion/render_glass_motion.dart:71` calls `glassSurfaceTransform`.
Give it `pressStretch: const GlassPressStretch.none()` for now; Task 7
replaces that with the real value.

- [ ] **Step 7: Run the tests**

Run: `flutter test test/src/motion/glass_press_stretch_test.dart test/src/motion/`
Expected: PASS, including the existing `glass_jiggle_test.dart` — the
velocity behaviour must be unchanged. If a jiggle test broke, the two 2x2s
were composed in the wrong order.

- [ ] **Step 8: Commit**

```bash
git add lib/src/motion/glass_press_stretch.dart \
  lib/src/motion/glass_motion_state.dart lib/src/motion/glass_jiggle.dart \
  lib/src/motion/render_glass_motion.dart \
  test/src/motion/glass_press_stretch_test.dart
git commit -m "feat(a2): elongate a surface toward a held finger

Derived from the press channel, like the jiggle is derived from velocity, so
it needs no second spring and cannot drift out of phase with the press.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Wire press-stretch into `InteractiveGlass`

**Files:**
- Modify: `lib/src/motion/glass_motion_controller.dart`
- Modify: `lib/src/motion/render_glass_motion.dart`
- Modify: `lib/src/motion/interactive_glass.dart`
- Modify: `lib/glass_forge.dart`
- Test: `test/src/motion/interactive_glass_test.dart` (extend the existing file)

**Interfaces:**
- Consumes: `GlassPressStretch`, `GlassMotionState.pressAnchor`,
  `glassSurfaceTransform(pressStretch:)` from Task 6.
- Produces: `InteractiveGlass.pressStretch`, defaulting to
  `const GlassPressStretch()`.

- [ ] **Step 1: Write the failing tests**

Append to `test/src/motion/interactive_glass_test.dart` (read the file first
and match its existing helpers and harness):

```dart
  testWidgets('a held pointer stretches the surface toward it',
      (tester) async {
    await tester.pumpWidget(/* the file's standard InteractiveGlass harness,
       sized 200x80, wrapped in a GlassLayer */);

    final centre = tester.getCenter(find.byType(InteractiveGlass));
    final gesture = await tester.startGesture(centre + const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 160));

    final transform = /* read RenderGlassMotion's current transform */;
    expect(transform.getTranslation().x, greaterThan(0));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(/* transform */, equals(Matrix4.identity()));
  });

  testWidgets('Reduce Motion stretches nothing', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: /* the same harness */,
      ),
    );
    final centre = tester.getCenter(find.byType(InteractiveGlass));
    final gesture = await tester.startGesture(centre + const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 160));
    expect(/* transform */, equals(Matrix4.identity()));
    await gesture.up();
  });
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `flutter test test/src/motion/interactive_glass_test.dart`
Expected: FAIL — nothing stretches yet.

- [ ] **Step 3: Track the anchor on the controller**

In `GlassMotionController`, add:

```dart
Offset _pressAnchor = Offset.zero;

/// Records where the finger is, relative to the surface's centre.
///
/// Not sprung: it is multiplied by the press depth wherever it is read, and
/// that is already sprung. See `GlassPressStretch`.
void setPressAnchor(Offset anchor) {
  if (_pressAnchor == anchor) {
    return;
  }
  _pressAnchor = anchor;
  notifyListeners();
}
```

Include `pressAnchor: _pressAnchor` in the `GlassMotionState` it builds
(around line 325), and reset it to `Offset.zero` wherever `setPressed(pressed: false)`
settles — check `settleInstantly` and the release path so a released surface
has a resting state that satisfies `isAtRest`.

`notifyListeners` here may be the wrong call for this controller: read how
`follow` and `setPressed` publish their changes and use the same mechanism.
The anchor must reach the render object without rebuilding a widget — that
is the class's stated contract.

- [ ] **Step 4: Thread the stretch through the render object**

`RenderGlassMotion` gains a `GlassPressStretch pressStretch` field with a
setter that calls `markNeedsPaint` when it changes, and passes it to
`glassSurfaceTransform` at line 71.

- [ ] **Step 5: Wire up `InteractiveGlass`**

Add the argument:

```dart
this.pressStretch = const GlassPressStretch(),
```

with:

```dart
/// How far the surface reaches toward a held finger.
///
/// Resolves to [GlassPressStretch.none] under Reduce Motion.
final GlassPressStretch pressStretch;
```

In the state's pointer-down and pointer-move handlers, call
`_controller.setPressAnchor(localPosition - centre)` where `centre` is half
the render object's size — the same place the existing code computes local
positions for `follow`. On pointer up or cancel, call
`setPressAnchor(Offset.zero)`.

Resolve Reduce Motion the way the file already resolves `jiggle`: find where
it turns `jiggle` into `GlassJiggle.none()` and add the equivalent for
`pressStretch`. Do not invent a second mechanism.

- [ ] **Step 6: Export and run**

Add `export 'src/motion/glass_press_stretch.dart' show GlassPressStretch;`
to `lib/glass_forge.dart`.

Run: `flutter test test/src/motion/`
Expected: PASS

- [ ] **Step 7: Full verification and commit**

Run: `flutter analyze && flutter test`

```bash
git add lib/src/motion/ lib/glass_forge.dart test/src/motion/
git commit -m "feat(a2): drive press-stretch from InteractiveGlass

A2 is complete.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: The glow uniform

**Files:**
- Create: `lib/src/composition/glass_glow.dart`
- Modify: `shaders/final_render.frag`
- Modify: `shaders/final_render_bilinear_probe.frag`
- Modify: `lib/src/composition/glass_composition.dart`
- Modify: `lib/src/composition/filter_snapshot.dart`
- Test: `test/src/composition/glass_glow_test.dart` (create)

**Interfaces:**
- Consumes: Task 1's `presence` parameter on `build` and `_writeUniforms`.
- Produces:
  - `class GlassGlow` with `const GlassGlow({required Offset centre, required double radius, required double strength})`, `const GlassGlow.none()`, `bool get isActive`, value equality
  - `GlassComposition.build(..., required GlassGlow glow)` and
    `FilterSnapshot.of(..., required GlassGlow glow)`

**This is the shader-layout change**, per decision 2 of 2026-09-18: the glow
goes in the shader, not painted, because only the shader version reaches a
neighbouring shape in the same pass — which is the behaviour Apple describes
and the entire reason to prefer it. It changes the uniform layout, so the web
SkSL gate is a required step, not an optional one.

- [ ] **Step 1: Write the failing test**

Create `test/src/composition/glass_glow_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/composition/glass_glow.dart';

void main() {
  test('none() glows nothing', () {
    expect(const GlassGlow.none().isActive, isFalse);
  });

  test('a zero-strength glow is inactive however large its radius', () {
    expect(
      const GlassGlow(centre: Offset(10, 10), radius: 200, strength: 0)
          .isActive,
      isFalse,
    );
  });

  test('a zero-radius glow is inactive however strong', () {
    expect(
      const GlassGlow(centre: Offset(10, 10), radius: 0, strength: 1).isActive,
      isFalse,
    );
  });

  test('glows compare by value', () {
    expect(
      const GlassGlow(centre: Offset(1, 2), radius: 3, strength: 4),
      equals(const GlassGlow(centre: Offset(1, 2), radius: 3, strength: 4)),
    );
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/src/composition/glass_glow_test.dart`
Expected: FAIL — `GlassGlow` is undefined.

- [ ] **Step 3: Write `GlassGlow`**

Create `lib/src/composition/glass_glow.dart`:

```dart
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The light under a fingertip, spreading across a whole backdrop pass.
///
/// Apple: "Starting right under your fingertips, the glow spreads throughout
/// the element and onto any Liquid Glass elements nearby." A glow that
/// spills onto its neighbours cannot belong to one shape, so this belongs to
/// the pass — every shape sharing that pass is lit by it, and the gaps
/// between them are not, because the shader masks it by coverage for free.
@immutable
class GlassGlow {
  /// Creates a glow.
  const GlassGlow({
    required this.centre,
    required this.radius,
    required this.strength,
  });

  /// No glow.
  const GlassGlow.none()
      : centre = Offset.zero,
        radius = 0,
        strength = 0;

  /// Where the finger is, in layer-local logical pixels.
  final Offset centre;

  /// How far the light reaches, in logical pixels.
  final double radius;

  /// How much it brightens at the centre, 0 to 1.
  final double strength;

  /// Whether this puts any light on screen.
  bool get isActive => radius > 0 && strength > 0;

  @override
  bool operator ==(Object other) =>
      other is GlassGlow &&
      other.centre == centre &&
      other.radius == radius &&
      other.strength == strength;

  @override
  int get hashCode => Object.hash(centre, radius, strength);
}
```

- [ ] **Step 4: Add the uniform to both shaders**

In `shaders/final_render.frag`, after `uniform vec4 uSurface;`:

```glsl
uniform vec4 uGlow;           // centre.xy in filter space, radius, strength
```

and immediately before the premultiply at the end of `main`, after the
`gfShade` call:

```glsl
    // The touch glow. Added after shading and before the coverage multiply,
    // so it is masked by coverage for free: it lights every shape in this
    // pass -- the neighbours Apple describes -- and none of the gaps
    // between them.
    if (uGlow.w > 0.0) {
        float glowDistance = distance(frag, uGlow.xy);
        float falloff = 1.0 - smoothstep(0.0, max(uGlow.z, 1.0), glowDistance);
        refracted += uGlow.w * falloff * falloff;
    }
```

Make the identical edit in `shaders/final_render_bilinear_probe.frag`. The
two files' uniform blocks must stay byte-identical; diff them when done:

```bash
diff <(sed -n '/^uniform/p' shaders/final_render.frag) \
     <(sed -n '/^uniform/p' shaders/final_render_bilinear_probe.frag)
```

Expected: no output.

- [ ] **Step 5: Write the uniform**

`FilterSnapshot` gains `required GlassGlow glow`, in the constructor,
`of`, `operator ==` and `hashCode`. `GlassComposition.build` and
`_writeUniforms` gain `required GlassGlow glow`, and `_writeUniforms` appends
four floats **after** the `uSurface` block and before `setImageSampler`:

```dart
// uGlow, in filter space: the same physical pixels FlutterFragCoord
// reports, so the centre converts by the device pixel ratio like every
// other length here.
..setFloat(i++, glow.centre.dx * devicePixelRatio)
..setFloat(i++, glow.centre.dy * devicePixelRatio)
..setFloat(i++, glow.radius * devicePixelRatio)
..setFloat(i++, glow.strength * presence)
```

The glow scales by presence too: glass fading out must not leave a glow
hanging in the air.

Pass `const GlassGlow.none()` at the `RenderGlassLayer._buildFilter` call
site for now; Task 9 replaces it.

- [ ] **Step 6: Run the tests and the SkSL gate**

Run: `flutter test`
Expected: PASS

Run the SkSL gate the way CI runs it — `flutter build web` on its own
fails with "This project is not configured for the web", because the example
is a phone demo with no `web/` folder checked in:

```bash
cd example
flutter create --platforms=web .
flutter build web --release
rm -rf web && rm -f test/widget_test.dart && git checkout .metadata
cd ..
```

The cleanup line is not optional **locally**. `flutter create` scaffolds
`web/`, writes a template `test/widget_test.dart` referring to a `MyApp` this
app does not have, and rewrites `example/.metadata`. CI deletes only the
template test — see `.github/workflows/shaders.yaml` — because it runs on a
throwaway checkout where a leftover `web/` and a rewritten `.metadata` are
discarded with the runner. On a working tree they are not: they leave the
repository dirty and the template test breaks `flutter analyze`. That
workflow is still the authority on the rest of the gate, including why it
must run before analyze.
Expected: succeeds. **If it fails here, the uniform layout is the cause** —
check the `uGlow` declaration order against the `setFloat` order.

Run: `flutter test --tags impeller --run-skipped --enable-impeller`
Expected: only the one pre-existing `GpuGeometryProducer` failure.

- [ ] **Step 7: Commit**

```bash
git add lib/src/composition/glass_glow.dart shaders/ \
  lib/src/composition/glass_composition.dart \
  lib/src/composition/filter_snapshot.dart \
  lib/src/rendering/render_glass_layer.dart \
  test/src/composition/glass_glow_test.dart
git commit -m "feat(a3): add the uGlow uniform to the final render pass

In the shader rather than painted, so the light reaches the neighbouring
shapes in the same pass the way Apple's does, masked by coverage for free.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Drive the glow from the pointer

**Files:**
- Modify: `lib/src/rendering/render_glass_layer.dart`
- Modify: `lib/src/widgets/glass_layer.dart`
- Modify: `lib/src/motion/interactive_glass.dart`
- Modify: `lib/glass_forge.dart`
- Test: `test/src/rendering/glass_glow_layer_test.dart` (create)

**Interfaces:**
- Consumes: `GlassGlow` and `FilterSnapshot.glow` from Task 8;
  `InteractiveGlass`'s pointer handling from Task 7.
- Produces: `set RenderGlassLayer.glow(GlassGlow value)` and a
  `GlassGlowScope` carrying a `ValueNotifier<GlassGlow>` that
  `InteractiveGlass` writes and `RenderGlassLayer` listens to.

- [ ] **Step 1: Write the failing test**

Create `test/src/rendering/glass_glow_layer_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/diagnostics/render_counters.dart';

void main() {
  testWidgets('pressing raises the glow and releasing lets it go',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Center(
            child: InteractiveGlass(
              child: Glass(
                shape: const GlassRoundedRectangle(radius: BorderRadius.circular(28)),
                child: const SizedBox(width: 160, height: 56),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    GlassRenderCounters.instance.reset();
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Glass)));
    await tester.pump(const Duration(milliseconds: 120));

    // The glow must not cost a matte: it is a uniform, not geometry.
    expect(GlassRenderCounters.instance.matteProduceCount, 0);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('Reduce Motion keeps a static glow, not a spreading one',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: GlassLayer(
            child: Center(
              child: InteractiveGlass(
                child: Glass(
                  shape: const GlassRoundedRectangle(radius: BorderRadius.circular(28)),
                  child: const SizedBox(width: 160, height: 56),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Glass)));
    await tester.pump();
    // One frame, not a ramp: the glow is at full radius immediately.
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/src/rendering/glass_glow_layer_test.dart`
Expected: FAIL — the glow is still `GlassGlow.none()` and, depending on how
you write the assertion, either nothing changes or the API is missing.

- [ ] **Step 3: Give the layer a glow channel**

In `RenderGlassLayer`:

```dart
/// The touch glow every pass in this layer is lit by.
///
/// One glow per layer, not per shape: a glow that stops at a shape's edge is
/// the painted version this package rejected. See `GlassGlow`.
GlassGlow get glow => _glow;
GlassGlow _glow = const GlassGlow.none();
set glow(GlassGlow value) {
  if (_glow == value) {
    return;
  }
  _glow = value;
  markNeedsPaint();
}
```

Pass `glow: _glow` into both `FilterSnapshot.of` and `composition.build` in
`_buildFilter`.

- [ ] **Step 4: Publish a glow channel from `GlassLayer`**

In `lib/src/widgets/glass_layer.dart`, hold a
`final ValueNotifier<GlassGlow> _glow = ValueNotifier(const GlassGlow.none())`
in the layer's state (it may currently be a `StatelessWidget`; converting it
to a `StatefulWidget` is in scope for this task), dispose it, publish it
through a `GlassGlowScope extends InheritedWidget`, and have `_RawGlassLayer`
pass the notifier's value to the render object — listening to the notifier
and calling `renderObject.glow = ...` directly, **not** rebuilding, for the
same reason motion does not rebuild.

- [ ] **Step 5: Drive it from `InteractiveGlass`**

On pointer down, write a glow at the pointer's layer-local position with a
radius springing out on the theme's `press` motion; on up or cancel, decay it
to `GlassGlow.none()`. Reuse the press channel the controller already runs
rather than adding a ticker: `strength` and `radius` can both be read off
`state.press` exactly as `pressAnchor` is in Task 6.

Under Reduce Motion, per the spec: keep a static highlight under the finger
and drop the spreading animation. That means full radius and strength on the
first frame of the press and zero on release, with no ramp — which falls out
of the press channel already settling instantly under Reduce Motion, so
confirm that rather than special-casing it.

Converting the pointer position into the *layer's* coordinate space, not the
surface's, is the fiddly part: the glow is layer-wide. Use
`RenderGlassLayer`'s render object as the ancestor in `globalToLocal`.

- [ ] **Step 6: Export and verify**

Add `export 'src/composition/glass_glow.dart' show GlassGlow;` to
`lib/glass_forge.dart`.

Run: `flutter analyze`
Run: `flutter test`
Run: `flutter test --tags impeller --run-skipped --enable-impeller`
Run the SkSL gate the way CI runs it — `flutter build web` on its own
fails with "This project is not configured for the web", because the example
is a phone demo with no `web/` folder checked in:

```bash
cd example
flutter create --platforms=web .
flutter build web --release
rm -rf web && rm -f test/widget_test.dart && git checkout .metadata
cd ..
```

The cleanup line is not optional **locally**. `flutter create` scaffolds
`web/`, writes a template `test/widget_test.dart` referring to a `MyApp` this
app does not have, and rewrites `example/.metadata`. CI deletes only the
template test — see `.github/workflows/shaders.yaml` — because it runs on a
throwaway checkout where a leftover `web/` and a rewritten `.metadata` are
discarded with the runner. On a working tree they are not: they leave the
repository dirty and the template test breaks `flutter analyze`. That
workflow is still the authority on the rest of the gate, including why it
must run before analyze.

- [ ] **Step 7: Look at it**

Run the example on the iPhone 17e simulator
(`2473CC29-B74E-43FC-B4C5-7162629E0DFC`), press and hold a glass surface with
a neighbour beside it, and screenshot:

```bash
xcrun simctl io 2473CC29-B74E-43FC-B4C5-7162629E0DFC screenshot /tmp/glow.png
sips -Z 1400 /tmp/glow.png
```

Measure, do not eyeball: compare pixels under the finger against the same
region unpressed, and compare the *neighbouring* shape's pixels against its
own unpressed state. **The neighbour must brighten too.** If it does not, the
glow is being written per shape rather than per pass, and the whole reason
this was put in the shader is gone.

Hot restart without a TTY: run with `--pid-file <path>`, then
`kill -USR2 $(cat <path>)`, and wait for a **new** `Restarted application`
line before screenshotting — the count-based wait races. A changed asset
manifest hangs hot restart; relaunch instead.

- [ ] **Step 8: Commit**

```bash
git add lib/src/rendering/render_glass_layer.dart \
  lib/src/widgets/glass_layer.dart lib/src/motion/interactive_glass.dart \
  lib/glass_forge.dart test/src/rendering/glass_glow_layer_test.dart
git commit -m "feat(a3): drive the touch glow from the pointer

A3 is complete, and with it sub-project A. The glow spreads across the whole
backdrop pass, so a neighbouring glass surface lights up with the one being
touched.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Closing out sub-project A

- [ ] Update `docs/TODO.md`: what A shipped, what the verification run said,
      and anything the overlap warning found in the example.
- [ ] Re-run all four verification commands on a clean checkout.
- [ ] The next plan is sub-project B (controls: `GlassButton`, `GlassSwitch`,
      `GlassSlider`, `GlassSegmentedControl<T>`, `GlassTextField`). Every one
      of them calls `GlassHostScope.isOnGlass(context)` from Task 4 and takes
      `pressStretch` from Task 7.

## Self-review notes

Checked against the spec's sections A1–A4 and the 2026-09-18 decisions:

- **A1** — presence: Tasks 1, 2, 3. All three of the spec's stated tests are
  present: the matte count stays flat over twenty animating frames (Task 2
  Step 1), presence 0 pushes no `BackdropFilterLayer` (Task 2 Step 1), and
  `uSurface.z` carries the presence value (Task 1 Step 4). The spec's third
  test also asks that presence 1 be pixel-identical to today's output on the
  Impeller lane — that is a golden, and this repository's Impeller lane is
  already one test red. **Deliberately not added**, because a new golden on a
  red lane cannot be trusted. Add it when the `GpuGeometryProducer` failure
  is fixed, and note it in `docs/TODO.md` when closing A out.
- **A2** — press-stretch: Tasks 6 and 7. All five tests the spec names are
  covered, plus the unpressed case.
- **A3** — touch glow: Tasks 8 and 9, shader route per decision 2.
- **A4** — scope and overlap: Tasks 4 and 5, warning per decision 3, and the
  nested-`Glass` assert the spec asks for separately.
- Names are plain throughout, per decision 4.

Two things this plan asks the executor to read rather than trusting the plan
for, because they could not be verified while writing it: `ShapeGeometry`'s
bounds accessor (Task 5 Step 3) and `GlassMotionController`'s change
notification mechanism (Task 7 Step 3). Both are called out at the step.
