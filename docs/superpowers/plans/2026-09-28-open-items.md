# glass_forge open items — Implementation Plan

> **For agentic workers:** execute with the `subagent-driven-development` skill, task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close every open item in `docs/TODO.md`: the renderer limits (shape cap, stair-steps, overlap warning), the widget set (sub-projects B, C, D), the Apple presets, and the benchmark budgets.

**Architecture:** Renderer fixes first, because the widgets sit on them — a
screen of controls hits the 8-shape cap immediately. Then the controls
(B), then the chrome that hosts them (C), then the example rebuilt on the
package's own widgets (D). The presets and the benchmark budgets are last:
both need something only Arham can provide (see Tasks 14 and 15).

**Tech Stack:** Flutter 3.47.2, Dart 3.13, Impeller, `flutter_gpu`, `motor`, `very_good_analysis`.

**Spec:** `docs/superpowers/specs/2026-09-14-glass-widgets-design.md` (sub-projects B, C, D, with the 2026-09-18 decisions). Renderer tasks argue from `docs/TODO.md` and `docs/reference/backdrop_sampling.md`.

**Spec amendment, 2026-09-28 (Arham):** the tab bar's selection must be
glassmorphic. C1's "painted selection pill" becomes: painted at rest, a
glass lens while it travels, faded in and out through `GlassPresence` so
it is never glass-on-glass at rest. The example's `GlassTabBar` already does
this and is the reference implementation.

## Global Constraints

- One `GlassLayer` per screen. At most one glass surface at any point on screen (flutter#187820).
- A control drawn on a glass surface is paint: every widget checks `GlassHostScope.isOnGlass(context)` and never builds a `Glass` inside another `Glass`.
- Widgets depend on `package:flutter/widgets.dart` only — no Material ancestor.
- Every interactive widget: semantics, keyboard focus and activation (Enter and Space), hit target at least 44 × 44 logical pixels.
- Reduce Motion (`GlassReduceMotion.instance.value`) makes every transition instant and removes stretch, bounce and glow.
- Controls resolve `GlassSurfaceRole.control` through `GlassTheme.surfaceOf(context, role, size:, backdrop:)` for material, motion and label colour; they never name a colour of their own.
- Springs come from `GlassMotionDefaults` roles: `follow`, `settle`, `press`, `present`.
- `very_good_analysis`, 80-character lines, no `// ignore:`. `dart format --set-exit-if-changed lib test` clean.
- Every public widget gets a README snippet, compiled by `test/readme_examples_test.dart`.
- Every guard is proven: its test must fail when the code it guards is broken (break it, watch it fail, restore).
- Rendering claims are verified on the Impeller lane: `flutter test --tags impeller --run-skipped --enable-impeller --enable-flutter-gpu`.
- CI must stay green: `.github/workflows/shaders.yaml` and `main.yaml` (coverage floor 80%).

## Review Focus

1. **More than eight controls on one screen** — a settings page of switches and sliders must draw every one of them, not silently drop the ninth. Owned by Task 2; Task 13 adds a screen with more than eight glass controls to the example test.
2. **A control placed on a glass bar** (a `GlassButton.icon` in a `GlassAppBar`) must paint, not stack glass. Owned by Tasks 4 and 11: a test mounts the button inside the app bar and asserts zero `Glass` descendants of the button.
3. **A disabled control** (`onPressed: null`, `onChanged: null`) must neither fire nor animate a press, and must say so to a screen reader. Owned by Tasks 4–8: each has a disabled test.
4. **Reduce Motion mid-animation** — turning it on while a knob or pill is travelling must land it instantly, not freeze it half way. Owned by Tasks 5 and 7.
5. **The keyboard opening under a text field in a bottom bar** — the bar must ride the inset and stay the only glass there. Owned by Tasks 8 and 9.

---

### Task 1: Overlap warning reports every overlapping pass pair

**Files:**
- Modify: `lib/src/rendering/render_glass_layer.dart` (`_debugWarnOnCrossPassOverlap`, ~line 656)
- Test: `test/src/rendering/glass_overlap_warning_test.dart`

**Interfaces:** none new.

- [ ] **Step 1: Implement.** The loop `return`s after the first new warning, so a second overlapping pass pair waits for a later paint that may never come. Remove the early `return true;` inside the inner loop so every new pass pair is reported in the same paint; keep the `_warnedOverlaps` dedupe so each pair still prints once.

- [ ] **Step 2: Test.** Three shapes in three materials, all overlapping one another (three pass pairs), pumped once: expect three distinct warnings containing `187820`. Break it (restore the early return) and confirm the test fails with one warning.

```dart
testWidgets('every overlapping pass pair warns in the same paint', (
  tester,
) async {
  final printed = <String>[];
  final original = debugPrint;
  debugPrint = (m, {wrapWidth}) {
    if (m != null) printed.add(m);
  };
  try {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassLayer(
          child: Stack(
            children: <Widget>[
              for (final (left, frost) in [(0.0, 4.0), (20.0, 8.0), (40.0, 12.0)])
                Positioned(
                  left: left,
                  top: 0,
                  child: Glass(
                    shape: GlassOval(),
                    material: GlassMaterial(frost: frost),
                    child: SizedBox(width: 100, height: 100),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  } finally {
    debugPrint = original;
  }
  expect(printed.where((m) => m.contains('187820')), hasLength(3));
});
```

**Feature test command:** `flutter test test/src/rendering/glass_overlap_warning_test.dart`

- [ ] **Step 3: Commit** — `fix(rendering): report every overlapping pass pair, not the first`

---

### Task 2: More than eight shapes per material

**Files:**
- Create: `lib/src/geometry/shape_clusters.dart`
- Modify: `lib/src/geometry/runtime_geometry_producer.dart`, `lib/src/geometry/gpu_geometry_producer_io.dart`, `lib/src/rendering/render_glass_layer.dart` (the `kMaxShapes` warning added 2026-09-28 now fires only when one *cluster* exceeds the cap), `lib/src/shapes/shape_limits.dart` (doc)
- Test: `test/src/geometry/shape_clusters_test.dart`, `test/src/rendering/glass_shape_limit_warning_test.dart` (update), an Impeller-tagged parity test in `test/src/geometry/`

**Interfaces:**
- Produces:
```dart
/// Shapes grouped so that no two groups' matte regions touch. Shapes in one
/// blend group, or whose padded bounds overlap, share a cluster.
class ShapeCluster {
  const ShapeCluster({required this.shapes, required this.bounds});
  final List<ShapeGeometry> shapes; // in registration order
  final Rect bounds; // union of padded bounds, layer space
}

List<ShapeCluster> clusterShapes(
  List<ShapeGeometry> shapes, {
  required double padding, // request.antialiasWidth + max displacement reach
});
```

- [ ] **Step 1: Implement.** The cap is the shader's uniform budget (12 floats per shape, 96 floats), so it stays; the pass stops being one draw. `clusterShapes` union-finds shapes whose padded `layerBounds` overlap or that share a `blendMarker` group, keeping registration order inside each cluster (smooth-min is not associative — `README.md` "Shapes and blending"). Each producer then:
  1. clears the whole matte allocation to the *outside* encoding `(0.5, 0.5, 1.0, 0.0)` — a zeroed texel decodes as deep interior, which would paint solid glass everywhere between clusters;
  2. draws once per cluster, clipped to that cluster's `bounds`, with only that cluster's shapes in the uniforms.
  A cluster larger than `kMaxShapes` is the only case left that drops shapes; it keeps the first eight and the debug warning (now per cluster) says so.

- [ ] **Step 2: Tests.**
  - `shape_clusters_test.dart`: twelve separate 40 px shapes 100 px apart → twelve clusters; two overlapping → one cluster; three in one blend group far apart → one cluster in registration order; an empty list → empty.
  - Warning test: twelve separate shapes no longer warn; nine overlapping shapes still do.
  - Impeller lane: twelve separate ovals in one material bake a matte whose centre texel of the twelfth oval decodes as inside (`MatteCodec.decode(...).signedDistance < 0`), and a texel between two ovals decodes as outside. Break it (draw only the first cluster) and watch the twelfth fail.

**Feature test command:** `flutter test test/src/geometry/shape_clusters_test.dart test/src/rendering/glass_shape_limit_warning_test.dart && flutter test --tags impeller --run-skipped --enable-impeller --enable-flutter-gpu test/src/geometry/`

- [ ] **Step 3: Commit** — `feat(rendering): draw more than eight shapes per material in clusters`

---

### Task 3: Smooth edge-band refraction (the stair-steps)

**Files:**
- Modify: `shaders/final_render.frag` (the edge-band backdrop read), `shaders/common/sampling.glsl` if needed
- Modify: `docs/reference/backdrop_sampling.md` (record the result)
- Test: Impeller-tagged test in `test/src/composition/final_pass_shading_test.dart`

**Interfaces:** none new.

- [ ] **Step 1: Measure first.** Two candidate causes: the matte's 8-bit displacement (≈0.8% of range per code near zero, 0.05 px at a 6 px band — too small to see) and the backdrop read, which is nearest-neighbour for the edge band and bilinear only for the dome (`backdrop_sampling.md`, "Update, 2026-09-11"). Since 2026-09-28 the edge band's displacement varies continuously across the band, exactly the case that made the dome stair-step. Write the test in Step 2 first and run it on the current shader to see which it is.

- [ ] **Step 2: Test.** Refract a smooth horizontal gradient (0→255 over the canvas width) through a 200 px rounded rectangle with `edgeRefraction: 24`; read back one row across the band. Count *runs*: consecutive texels with identical values. Stair-stepping is runs of 3+ identical texels where the source gradient changes every texel. Assert the longest run inside the band is ≤ 2.

- [ ] **Step 3: Implement.** If the test pins the backdrop read (expected), route the edge band through `gfSampleBilinear` **only where displacement is non-zero** — the flat interior keeps its single tap, so cost stays confined to the band. If it pins the matte, add ordered dither to the displacement channel before encoding in `shaders/common/codec.glsl` and its Dart mirror `lib/src/geometry/matte_codec.dart`, keeping the two in lockstep (`matte_codec_test.dart` tests them against each other).

**Feature test command:** `flutter test --tags impeller --run-skipped --enable-impeller --enable-flutter-gpu test/src/composition/final_pass_shading_test.dart`

- [ ] **Step 4: Commit** — `fix(rendering): read the edge band's backdrop bilinearly`

---

### Task 4: `GlassButton` (B1)

**Files:**
- Create: `lib/src/controls/glass_button.dart`, `lib/src/controls/control_frame.dart`
- Modify: `lib/glass_forge.dart` (export), `README.md` (snippet)
- Test: `test/src/controls/glass_button_test.dart`

**Interfaces:**
- Produces (used by Tasks 5–12):
```dart
/// Semantics, focus, Enter/Space activation and the 44 x 44 minimum hit
/// target, shared by every control. Grows the hit area, never the glass.
class GlassControlFrame extends StatelessWidget {
  const GlassControlFrame({
    required this.child,
    required this.onActivate,       // null = disabled
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    this.button = true,
    super.key,
  });
}

class GlassButton extends StatelessWidget {
  const GlassButton({
    required VoidCallback? onPressed, // null renders disabled
    required Widget child,
    GlassShape? shape,                // defaults to a capsule
    Color? backdrop,
    GlassPressStretch pressStretch = const GlassPressStretch(),
    bool glow = true,
    String? semanticLabel,
    FocusNode? focusNode,
    bool autofocus = false,
    super.key,
  });
  const GlassButton.icon({
    required VoidCallback? onPressed,
    required Widget icon,
    required String semanticLabel,
    Color? backdrop,
    FocusNode? focusNode,
    bool autofocus = false,
    super.key,
  });
}
```

- [ ] **Step 1: Implement.** On content: `InteractiveGlass` (press, anchored stretch, glow) over a `Glass` whose material, shape radius and label colour come from `GlassTheme.surfaceOf(context, GlassSurfaceRole.control, size:, backdrop:)`. Under `GlassHostScope`: the same layout painted — a `DecoratedBox` in the role's tint, a scale-on-press, no `Glass`, no glow. Disabled: 40% label opacity, no press response, `onPressed` never called.

- [ ] **Step 2: Tests** (the spec's list for every control): callback fires on tap; disabled never fires and does not scale; semantics has `isButton`, `isEnabled`, the label; Enter and Space activate when focused; a 24 px icon button's hit area is ≥ 44 × 44 while its glass stays 24 + padding; exactly one `Glass` on content, zero under `GlassHostScope`; Reduce Motion makes the press instant; README snippet compiles.

**Feature test command:** `flutter test test/src/controls/glass_button_test.dart test/readme_examples_test.dart`

- [ ] **Step 3: Commit** — `feat(controls): add GlassButton`

---

### Task 5: `GlassSwitch` (B2)

**Files:**
- Create: `lib/src/controls/glass_switch.dart`
- Modify: `lib/glass_forge.dart`, `README.md`
- Test: `test/src/controls/glass_switch_test.dart`

**Interfaces:**
- Consumes: `GlassControlFrame` (Task 4).
- Produces:
```dart
class GlassSwitch extends StatefulWidget {
  const GlassSwitch({
    required bool value,
    required ValueChanged<bool>? onChanged,
    Color? activeTrackColor,
    Color? backdrop,
    String? semanticLabel,
    super.key,
  });
}
```

- [ ] **Step 1: Implement.** Track 64 × 28, knob 38 × 24 capsule (iOS 26/27 proportions; confirm against a capture if one is available, otherwise keep these and say so in the doc comment). On content the knob is `Glass` with `GlassMaterial.dome()`-style lens — Apple's one lens-profile element — over a painted track; under `GlassHostScope` both are painted. The knob follows a horizontal drag through `GlassDrag(axis: Axis.horizontal)` and on release settles to whichever side it is past on the `settle` spring, calling `onChanged` only if the side changed. Tap toggles.

- [ ] **Step 2: Tests:** tap toggles and reports; drag past half flips, drag short of half does not; disabled ignores tap and drag; semantics `hasToggledState` and `isToggled`; Space toggles when focused; Reduce Motion lands the knob instantly — including when turned on mid-travel (Review Focus 4); one `Glass` on content, none under `GlassHostScope`; README snippet.

**Feature test command:** `flutter test test/src/controls/glass_switch_test.dart test/readme_examples_test.dart`

- [ ] **Step 3: Commit** — `feat(controls): add GlassSwitch`

---

### Task 6: `GlassSlider` (B3)

**Files:**
- Create: `lib/src/controls/glass_slider.dart`
- Modify: `lib/glass_forge.dart`, `README.md`
- Test: `test/src/controls/glass_slider_test.dart`

**Interfaces:**
- Consumes: `GlassControlFrame`.
- Produces:
```dart
class GlassSlider extends StatefulWidget {
  const GlassSlider({
    required double value,
    required ValueChanged<double>? onChanged,
    double min = 0,
    double max = 1,
    int? divisions,
    ValueChanged<double>? onChangeStart,
    ValueChanged<double>? onChangeEnd,
    Color? backdrop,
    String? semanticLabel,
    String Function(double value)? semanticValue,
    super.key,
  });
}
```

- [ ] **Step 1: Implement.** Painted 6 px track and fill; the thumb (28 × 28 capsule) is `Glass` on content and stretches with drag velocity through `GlassJiggle`. Dragging anywhere on the 44 px-tall hit area sets the value; `divisions` snaps. Semantics: slider with increase/decrease stepping one division, or 10% of the range without divisions.

- [ ] **Step 2: Tests:** drag reports values in range and snaps with divisions; `onChangeStart`/`onChangeEnd` bracket a drag; tap-to-set; `min == max` does not divide by zero; disabled ignores input; semantics increase/decrease actions step correctly; arrow keys step when focused; one `Glass` (the thumb) on content, none under `GlassHostScope`; README snippet.

**Feature test command:** `flutter test test/src/controls/glass_slider_test.dart test/readme_examples_test.dart`

- [ ] **Step 3: Commit** — `feat(controls): add GlassSlider`

---

### Task 7: `GlassSegmentedControl<T>` (B4)

**Files:**
- Create: `lib/src/controls/glass_segmented_control.dart`
- Modify: `lib/glass_forge.dart`, `README.md`
- Test: `test/src/controls/glass_segmented_control_test.dart`

**Interfaces:**
- Consumes: `GlassControlFrame`.
- Produces:
```dart
class GlassSegment<T> {
  const GlassSegment({required this.value, required this.label});
  final T value;
  final Widget label;
}

class GlassSegmentedControl<T> extends StatefulWidget {
  const GlassSegmentedControl({
    required List<GlassSegment<T>> segments,
    required T selected,
    required ValueChanged<T>? onChanged,
    Color? backdrop,
    super.key,
  });
}
```

- [ ] **Step 1: Implement.** A painted track; the travelling pill is `Glass` on content (painted under `GlassHostScope`) and travels on the `settle` spring. It can be dragged directly and snaps to the nearest segment on release. Each segment is a selectable button in a semantics group; left/right arrows move the selection when focused.

- [ ] **Step 2: Tests:** tap selects; drag snaps to nearest; `selected` not in `segments` asserts in debug; one segment renders without dividing by zero; semantics `isSelected` on exactly one; arrow keys; Reduce Motion lands the pill instantly, including mid-travel (Review Focus 4); one `Glass` on content, none under `GlassHostScope`; README snippet.

**Feature test command:** `flutter test test/src/controls/glass_segmented_control_test.dart test/readme_examples_test.dart`

- [ ] **Step 3: Commit** — `feat(controls): add GlassSegmentedControl`

---

### Task 8: `GlassTextField` (B5)

**Files:**
- Create: `lib/src/controls/glass_text_field.dart`
- Modify: `lib/glass_forge.dart`, `README.md`
- Test: `test/src/controls/glass_text_field_test.dart`

**Interfaces:**
- Produces:
```dart
class GlassTextField extends StatefulWidget {
  const GlassTextField({
    TextEditingController? controller,
    String? placeholder,
    Widget? leading,
    Widget? trailing,
    GlassShape? shape,                // defaults to a capsule
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    Color? backdrop,
    super.key,
  });
}
```

- [ ] **Step 1: Implement** per spec B5: wraps `EditableText` (IME, composing, selection toolbar untouched); focus animates the resolved material brighter on the `settle` spring; caret and selection painted above the glass, outside the `Glass` subtree; `Scrollable.ensureVisible` on focus so `viewInsets` moves it clear of the keyboard; painted under `GlassHostScope`.

- [ ] **Step 2: Tests:** typing reaches `onChanged`; submit reaches `onSubmitted`; focus changes the `Glass` material and blur restores it; Reduce Motion makes that instant; the `EditableText` is not a descendant of `Glass`; semantics `isTextField` with the placeholder as label; with `viewInsets.bottom: 300` inside a scroll view the field ends up above 300 px from the bottom (Review Focus 5); README snippet.

**Feature test command:** `flutter test test/src/controls/glass_text_field_test.dart test/readme_examples_test.dart`

- [ ] **Step 3: Commit** — `feat(controls): add GlassTextField`

---

### Task 9: `GlassScaffold` (C4)

**Files:**
- Create: `lib/src/chrome/glass_scaffold.dart`
- Modify: `lib/glass_forge.dart`, `README.md`
- Test: `test/src/chrome/glass_scaffold_test.dart`

**Interfaces:**
- Produces (Tasks 10–12 rely on the presence it publishes):
```dart
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    required Widget body,
    Widget? background,
    Widget? topBar,
    Widget? bottomBar,
    GlassMaterial? material,
    super.key,
  });
}
```

- [ ] **Step 1: Implement** per spec C4: `background` and `body` painted behind one `GlassLayer`; `topBar` and `bottomBar` the only glass, inside it, each under a `GlassPresence` driven by `ModalRoute.of(context)?.secondaryAnimation` inverted, so a covering route (Task 12) hands off; the body gets `MediaQuery` padding to scroll clear of both bars; the bottom bar rides `viewInsets.bottom`.

- [ ] **Step 2: Tests:** exactly one `GlassLayer`; background is not inside the layer; bars are; body padding equals bar heights plus safe areas; a pushed route drives bar presence to 0; `viewInsets.bottom` lifts the bottom bar (Review Focus 5); README snippet.

**Feature test command:** `flutter test test/src/chrome/glass_scaffold_test.dart test/readme_examples_test.dart`

- [ ] **Step 3: Commit** — `feat(chrome): add GlassScaffold`

---

### Task 10: `GlassTabBar` (C1, with the 2026-09-28 amendment)

**Files:**
- Create: `lib/src/chrome/glass_tab_bar.dart`
- Modify: `lib/glass_forge.dart`, `README.md`
- Test: `test/src/chrome/glass_tab_bar_test.dart`

**Interfaces:**
- Consumes: `GlassControlFrame` (Task 4), `GlassScaffold` presence (Task 9).
- Produces:
```dart
class GlassTab {
  const GlassTab({required this.icon, this.activeIcon, required this.label});
  final Widget icon;
  final Widget? activeIcon;
  final String label;
}

class GlassTabBar extends StatefulWidget {
  const GlassTabBar({
    required List<GlassTab> tabs,
    required int currentIndex,
    required ValueChanged<int> onTap,
    Color? backdrop,
    super.key,
  });
}
```

- [ ] **Step 1: Implement.** A `GlassSurface.navigationBar` capsule with the bottom safe area built in. Selection: a painted pill at rest; while it travels, a glass lens in its own material rises out of it through `GlassPresence` (0 at rest, 1 in flight), swelling slightly past the bar's edges, and fades back as it lands. Port the motion from the example's `example/lib/src/tab_bar.dart` — **read its current state first; another session was editing it on 2026-09-28.** Tab labels fade with the bar's presence. Each tab is a `GlassControlFrame` selectable button.

- [ ] **Step 2: Tests:** tap reports index; selection semantics on exactly one tab; the lens `GlassPresence` is 0 at rest and > 0 mid-travel; Reduce Motion: no lens, instant pill; bar presence 0 hides labels; bottom safe area applied; README snippet.

**Feature test command:** `flutter test test/src/chrome/glass_tab_bar_test.dart test/readme_examples_test.dart`

- [ ] **Step 3: Commit** — `feat(chrome): add GlassTabBar with a glass selection lens`

---

### Task 11: `GlassAppBar` (C2)

**Files:**
- Create: `lib/src/chrome/glass_app_bar.dart`
- Modify: `lib/glass_forge.dart`, `README.md`
- Test: `test/src/chrome/glass_app_bar_test.dart`

**Interfaces:**
- Produces:
```dart
class GlassAppBar extends StatelessWidget {
  const GlassAppBar({
    Widget? leading,
    Widget? title,
    List<Widget> actions = const <Widget>[],
    Color? backdrop,
    super.key,
  });
}
```

- [ ] **Step 1: Implement:** a `GlassSurface.navigationBar` with the top safe area built in; children wrapped in `GlassHostScope` so `GlassButton.icon` actions paint.

- [ ] **Step 2: Tests:** top safe area applied; a `GlassButton.icon` action has zero `Glass` descendants (Review Focus 2); title centred between leading and actions; README snippet.

**Feature test command:** `flutter test test/src/chrome/glass_app_bar_test.dart test/readme_examples_test.dart`

- [ ] **Step 3: Commit** — `feat(chrome): add GlassAppBar`

---

### Task 12: `showGlassSheet` (C3)

**Files:**
- Create: `lib/src/chrome/glass_sheet_route.dart`
- Modify: `lib/glass_forge.dart`, `README.md`
- Test: `test/src/chrome/glass_sheet_route_test.dart`

**Interfaces:**
- Consumes: `GlassScaffold` bar presence (Task 9).
- Produces:
```dart
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
});
```

- [ ] **Step 1: Implement** per spec C3: a `ModalRoute` presenting a `GlassSurface.sheet` that materialises through `GlassPresence`; a painted scrim dims content; the handoff — covered chrome reaches presence 0 in the first 40% of the route animation, the sheet rises from 0 only after (`Interval(0.4, 1)`), so both are never partially present together. Drag-down and scrim-tap dismiss when `isDismissible`.

- [ ] **Step 2: Tests:** returns the popped value; scrim tap dismisses only when dismissible; at every sampled animation value, chrome presence × sheet presence == 0 (the handoff invariant); Reduce Motion presents instantly; README snippet.

**Feature test command:** `flutter test test/src/chrome/glass_sheet_route_test.dart test/readme_examples_test.dart`

- [ ] **Step 3: Commit** — `feat(chrome): add showGlassSheet`

---

### Task 13: The example on the package's own widgets (D)

**Files:**
- Modify: `example/lib/src/home.dart`, `example/lib/src/tuner.dart`, `example/lib/src/scenes/kit.dart`
- Delete: `example/lib/src/tab_bar.dart`, and from `example/lib/src/controls.dart` whatever the package now provides
- Test: `example/test/playground_test.dart`

- [ ] **Step 1: Implement.** **First `git status` example/ — if another session's uncommitted work is still there, stop and ask Arham.** Replace: the example tab bar → package `GlassTabBar`; the tuner's `Segmented` → `GlassSegmentedControl`; `TuneSlider` → `GlassSlider` (painted, since the tuner is on the sheet's glass — `GlassHostScope`); the Kit's round and pill toggles → `GlassButton`/`GlassSwitch`; the Kit sliders → `GlassSlider`. Keep Iconsax glyphs as the icons. Add to the Kit a row that takes the scene past eight glass controls (Review Focus 1).

- [ ] **Step 2: Tests:** existing 9 stay green (update finders to the package types); add: the Kit renders more than eight `Glass` widgets and the layer prints no shape-limit warning.

**Feature test command:** `cd example && flutter test`

- [ ] **Step 3: Commit** — `feat(example): build the playground on the package's widgets`

---

### Task 14: Apple presets that look like iOS — **needs Arham**

**Files:**
- Create: `tool/reference_capture/` (a minimal SwiftUI app), `tool/fit_presets.dart`
- Modify: `lib/src/material/apple_presets.dart` (numbers and provenance)
- Test: `test/src/material/apple_presets_test.dart`

- [ ] **Step 1: Capture.** A SwiftUI app on the iOS 27 simulator renders `.glassEffect(.regular)` and `.glassEffect(.clear)` on a 200 × 200 capsule and a 300 × 64 pill over the example's five photographs; screenshot each. **Before starting, ask Arham**, who asked on 2026-09-28 not to run the simulator for visual checks — this is reference capture, not a check, but confirm. If the answer is no, do Step 1b instead.
- [ ] **Step 1b (fallback): Rename honestly.** Keep the numbers; rename the factories' docs from "fitted against iOS" to what they are, and add a README note. No API change.
- [ ] **Step 2: Fit.** Render the same shapes with `glass_forge` on the Impeller lane at the same size; minimise mean colour error per region (rim band, interior) over frost, tint, tint opacity, saturation, highlight and edge refraction with a coarse grid search then a local refine. Write the fitted numbers and the capture provenance into `apple_presets.dart`.
- [ ] **Step 3: Tests:** the fitted materials' interior error against the stored reference crops is below a stated threshold, and the old numbers' error is above it (proves the test can fail).
- [ ] **Step 4: Commit** — `fix(material): refit the Apple presets against iOS 27 captures`

---

### Task 15: Benchmark budgets from a real device — **needs Arham**

**Files:**
- Modify: `benchmark/budgets.json`, `README.md` ("Status and known limits"), `docs/TODO.md`

- [ ] **Step 1:** Ask Arham to connect a physical iPhone. Run `flutter run --profile -t benchmark/run_scene_benchmarks.dart -d <device>` three times; keep the reports.
- [ ] **Step 2:** Set each scene's budget to the worst of the three runs' p90 plus 20% headroom, rounded up to 0.5 ms. Record device, iOS version, date and the raw numbers in the budgets file's provenance.
- [ ] **Step 3:** `flutter test test/src/benchmark/` stays green; README no longer says "seed values".
- [ ] **Step 4:** Rewrite `docs/TODO.md` down to what is genuinely still open, then commit — `chore(benchmark): set budgets from profile runs on <device>`

---

## Cost

Tasks 1–3: renderer, about a day. Tasks 4–12: nine widgets at roughly
two to three hours each with tests. Task 13: half a day. Tasks 14–15 depend on
Arham (a decision and a device). Roughly three to four working days of agent
time end to end, with a progress update after each task.
