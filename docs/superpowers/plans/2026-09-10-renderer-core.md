# Renderer Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render Apple-faithful edge-band liquid glass — one or many shapes, blended, correct under rotation and scroll — using exactly one backdrop capture per layer, and costing nothing when nothing changed.

**Architecture:** Shapes register into a layer-local scene carrying an inverse affine basis. A geometry producer bakes SDF normal, edge distance and displacement magnitude into a matte texture. A single `BackdropFilterLayer` composes blur with a shader that samples that matte. Invalidation is driven by a monotonic revision counter, and ancestor motion is compositor-only.

**Tech Stack:** Flutter 3.47, Dart 3.13, GLSL fragment shaders via `FragmentProgram`, `ui.ImageFilter.shader`, `motor` for springs (later sub-project).

**Spec:** `docs/superpowers/specs/2026-09-10-renderer-core-design.md`
**Parent:** `docs/superpowers/specs/2026-09-10-glass-forge-architecture-design.md`

## Global Constraints

Every task's requirements implicitly include this section.

- **Flutter floor `^3.47.0`, Dart `^3.13.0`.** No GLES Y-flip conditionals — the flip requirement was removed in 3.44.
- **One backdrop capture per layer.** Never two stacked `BackdropFilter`s: flutter#187820 makes the upper one read a stale previous-frame backdrop, including its own output, on physical iPhones. Blur and shader compose via `ImageFilter.compose`.
- **Never mutate a texture the compositor may still read.** Geometry changes allocate a new generation; a producer releases only its own handles.
- **The matte is layer-local, never screen-space.** Ancestor transforms map in via a per-frame affine uniform.
- **Invalidate by monotonic revision, never deep comparison.** Measured upstream: 735.8 ns vs 5.7 ns per check.
- **Children paint in place.** Never a deferred `paintFromLayer`.
- **Analytic SDF normals only.** `dFdx`/`dFdy` are rejected on web (flutter#180959) and undefined after non-uniform early returns. `fwidth` is unavailable in runtime effects even on Impeller.
- **Every geometric quantity is DPR-scaled; every threshold is in pixels.**
- **Shaders must be SkSL-legal by construction:** constant loop bounds with an early `break`, compile-time-constant array indices, uniform arrays read as globals, no `sampler2D` function parameters.
- **Reuse native `ImageFilter`s keyed on a uniform snapshot.** The engine copies uniforms into the native filter at first conversion.
- **Bucket allocation-sized quantities to 64 px**; `snapToPixel` uses `floor(x * dpr + 0.5)`.
- **`ImageFilter.shader` uniform layout:** the first float uniform MUST be a `vec2` — the engine overwrites it with the input size — and at least one `sampler2D` is required.
- **Codeable standards:** zero analyzer issues, no `// ignore:` suppressions, package imports only (never relative), one class per file, no dead or commented-out code.
- **Shader math is re-derived from published formulas, never copied.** Upstream's refraction credits a Shadertoy original under CC BY-NC-SA. See `docs/reference/shader_techniques.md` §0.

## File Structure

```
packages/glass_forge/lib/src/
  shapes/
    glass_shape.dart              sealed shape family (public API)
    shape_type.dart               SDF type ints shared with the shader
    shape_geometry.dart           resolved shape: basis, inverse, distanceScale
    superellipse_params.dart      Flutter uber_sdf precompute mirror
  scene/
    scene_revision.dart           monotonic counter
    glass_scene.dart              registered shapes in layer-local space
    blend_group_link.dart         group membership, scoped to its layer
  geometry/
    matte_codec.dart              encode/decode contract (Dart mirror of shader)
    matte_generation.dart         immutable texture + bounds + revision
    geometry_producer.dart        strategy interface
    runtime_geometry_producer.dart
    gpu_geometry_producer.dart
    null_geometry_producer.dart
    producer_registry.dart
  composition/
    pixel_buckets.dart            64px bucketing, tie-stable snapping
    filter_snapshot.dart          uniform snapshot for native filter reuse
    retained_clip_chain.dart      ancestor clips outside the offset layer
    glass_composition.dart        the single BackdropFilterLayer
  rendering/
    render_glass_layer.dart
    render_glass_shape.dart
  material/
    glass_material.dart
    glass_variant.dart
    apple_presets.dart            fitted iOS 27 constants
  shaders/
    shader_library.dart           owned loader: dispose + precache + warm-up
  diagnostics/
    render_counters.dart          instrumented counters for invalidation tests
  widgets/
    glass_layer.dart
    glass.dart
    glass_blend_group.dart

packages/glass_forge/shaders/
  common/sdf.glsl                 shape distances, smooth-min, culling bounds
  common/codec.glsl               matte encode/decode
  common/profile.glsl             edge-band height + displacement
  geometry.frag                   runtime-effect geometry pass
  final_render.frag               composition pass
  probe.frag                      capacity + backend probe
```

---

### Task 1: Measure the uniform capacity ceiling

The spec says `MAX_SHAPES` is a **measured constant, not a guess**. Upstream's 16 comes from 6 floats per shape hitting Impeller's 96-float uniform buffer limit. Our layout is wider — it carries an affine basis for rotation correctness — so the real ceiling is different and unknown. Measure before anything depends on it.

**Files:**
- Create: `packages/glass_forge/shaders/probe.frag`
- Create: `packages/glass_forge/lib/src/shapes/shape_limits.dart`
- Test: `packages/glass_forge/test/src/shapes/shape_limits_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `const int kMaxShapes` — the compile-time shape cap every later task uses. `Future<int> probeMaxShapes()` — a runtime helper used by the workbench to confirm the constant on a real device.

- [ ] **Step 1: Write the probe shader**

`packages/glass_forge/shaders/probe.frag` — declared uniform width is the thing under test. Start at the layout the design needs (3 × vec4 per shape) and 16 shapes.

```glsl
#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

#define MAX_SHAPES 16

// The engine overwrites the first vec2 uniform with the input size.
uniform vec2 uSize;
uniform vec4 uShapeData[MAX_SHAPES * 3];
uniform sampler2D uInput;

out vec4 fragColor;

void main() {
    // Touch every declared slot so the compiler cannot strip the array.
    // Constant loop bounds with an early break keeps this SkSL-legal.
    float acc = 0.0;
    for (int i = 0; i < MAX_SHAPES * 3; i++) {
        acc += uShapeData[i].x;
    }
    // Sample the input so the engine's sampler requirement is satisfied.
    vec4 probe = texture(uInput, vec2(0.0));
    fragColor = vec4(acc * 0.0 + 1.0, probe.g * 0.0, 0.0, 1.0);
}
```

- [ ] **Step 2: Write the failing test**

`packages/glass_forge/test/src/shapes/shape_limits_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/shapes/shape_limits.dart';

void main() {
  test('the shape cap fits the uniform budget it claims', () {
    // Three vec4 per shape, four floats each.
    const floatsPerShape = 3 * 4;
    expect(kMaxShapes * floatsPerShape, lessThanOrEqualTo(kMaxShapeFloats));
  });

  test('the cap is documented as measured, not assumed', () {
    expect(kMaxShapesProvenance, isNotEmpty);
  });
}
```

- [ ] **Step 3: Run it to make sure it fails**

Run: `flutter test packages/glass_forge/test/src/shapes/shape_limits_test.dart`
Expected: FAIL — `Target of URI doesn't exist: shape_limits.dart`

- [ ] **Step 4: Write the constant**

`packages/glass_forge/lib/src/shapes/shape_limits.dart`:

```dart
/// The maximum number of shapes a single geometry pass can carry.
///
/// This is a measured ceiling, not a preference. Upstream's equivalent is 16,
/// derived from six floats per shape hitting Impeller's uniform-buffer limit
/// of 96 floats. Our layout is wider — three `vec4` per shape, because it
/// carries an inverse affine basis so rotated and non-uniformly scaled shapes
/// refract in the right direction — so upstream's number does not transfer.
///
/// Raise this only after re-running the probe on the weakest backend you
/// intend to support, and update [kMaxShapesProvenance] with what you saw.
const int kMaxShapes = 16;

/// The uniform-array float budget the shape data must fit inside.
///
/// Impeller reports no documented numeric cap, so treat this as
/// device-dependent. 96 is the figure upstream hit in practice on Impeller.
const int kMaxShapeFloats = 96;

/// Where [kMaxShapes] came from.
const String kMaxShapesProvenance =
    'Provisional. Matches upstream liquid_glass_renderer 0.2.0-dev.4, whose '
    'source comment records "Reduced from 64 to 16 shapes to fit Impeller\'s '
    'uniform buffer limit (16*6=96 floats vs 384)". Our layout is 3 vec4 per '
    'shape rather than 6 floats, so this MUST be re-measured with '
    'shaders/probe.frag on a real device per backend before it is trusted. '
    'Tracked as a workbench task.';
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test packages/glass_forge/test/src/shapes/shape_limits_test.dart`
Expected: FAIL — `16 * 12 = 192` exceeds `kMaxShapeFloats = 96`.

**This failure is the point of the task.** It proves the wider layout does not fit upstream's budget, which is exactly the unknown the spec flagged. Resolve it by lowering `kMaxShapes` to `8` (`8 * 12 = 96`) and recording that in the provenance string:

```dart
const int kMaxShapes = 8;

const String kMaxShapesProvenance =
    'Derived, pending device confirmation. Our layout is 3 vec4 (12 floats) '
    'per shape to carry an inverse affine basis, against the 96-float budget '
    'upstream hit on Impeller: 96 / 12 = 8. Upstream fits 16 only because its '
    '6-float layout cannot express rotation. Confirm with shaders/probe.frag '
    'on Impeller-Vulkan, Impeller-GLES and Metal before raising.';
```

- [ ] **Step 6: Run the test again**

Run: `flutter test packages/glass_forge/test/src/shapes/shape_limits_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add packages/glass_forge/lib/src/shapes/shape_limits.dart \
        packages/glass_forge/test/src/shapes/shape_limits_test.dart \
        packages/glass_forge/shaders/probe.frag
git commit -m "feat: derive the shape cap from the uniform budget

Our shape layout carries an inverse affine basis so rotated and non-uniformly
scaled glass refracts in the right direction. That costs three vec4 per shape
against upstream's six floats, which halves how many fit in Impeller's uniform
budget: 8, not 16. Recorded with its derivation so the number is not quietly
copied from upstream again."
```

---

### Task 2: The shape family

**Files:**
- Create: `packages/glass_forge/lib/src/shapes/shape_type.dart`
- Create: `packages/glass_forge/lib/src/shapes/glass_shape.dart`
- Test: `packages/glass_forge/test/src/shapes/glass_shape_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `sealed class GlassShape`; `GlassRoundedRectangle({BorderRadius radius})`, `GlassOval()`, `GlassSuperellipse({BorderRadius radius})`; `enum ShapeType { none, roundedRectangle, ellipse, superellipse }` with `int get sdfCode`. `GlassShape.resolveRadius(Size)` returns the corner radius in logical pixels, clamped to half the shorter side.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_type.dart';

void main() {
  test('sdf codes are stable and distinct', () {
    // These integers cross into the shader. Reordering them silently changes
    // which SDF every shape resolves to, so they are pinned here.
    expect(ShapeType.none.sdfCode, 0);
    expect(ShapeType.roundedRectangle.sdfCode, 1);
    expect(ShapeType.ellipse.sdfCode, 2);
    expect(ShapeType.superellipse.sdfCode, 3);
  });

  test('rounded rectangle reports its own type', () {
    const shape = GlassRoundedRectangle(radius: BorderRadius.zero);
    expect(shape.type, ShapeType.roundedRectangle);
  });

  test('a superellipse is not silently a rounded rectangle', () {
    // Upstream's "squircle" SDF is term-for-term identical to its rounded
    // rectangle while its clip uses a real superellipse, so the refraction
    // dome and the child clip disagree at every corner. Keep them distinct.
    const rect = GlassRoundedRectangle(radius: BorderRadius.zero);
    const squircle = GlassSuperellipse(radius: BorderRadius.zero);
    expect(rect.type, isNot(squircle.type));
  });

  test('radius clamps to half the shorter side', () {
    const shape = GlassRoundedRectangle(
      radius: BorderRadius.all(Radius.circular(9000)),
    );
    expect(shape.resolveRadius(const Size(100, 40)), 20);
  });

  test('an oval has no corner radius', () {
    const shape = GlassOval();
    expect(shape.resolveRadius(const Size(100, 40)), 0);
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test packages/glass_forge/test/src/shapes/glass_shape_test.dart`
Expected: FAIL — URIs do not exist.

- [ ] **Step 3: Write `shape_type.dart`**

```dart
/// The SDF branch a shape resolves to inside the geometry shader.
///
/// The integer codes cross the Dart/GLSL boundary as uniform data. They are
/// part of the shader contract: changing one silently changes which distance
/// function a shape renders with, so they are pinned by test.
enum ShapeType {
  /// No shape. The shader returns a large positive distance for this slot.
  none(0),

  /// A rounded rectangle with a uniform corner radius.
  roundedRectangle(1),

  /// An ellipse, solved by Newton iteration rather than the cheap closed form.
  ellipse(2),

  /// A rounded superellipse matching Flutter's own `RoundedSuperellipse`.
  superellipse(3);

  const ShapeType(this.sdfCode);

  /// The integer this type is encoded as in shape uniform data.
  final int sdfCode;
}
```

- [ ] **Step 4: Write `glass_shape.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/shapes/shape_type.dart';

/// A shape that can be rendered as glass.
///
/// Deliberately a closed set. Every member has an exact SDF whose silhouette
/// matches the Flutter clip used for its children — an open family would make
/// that guarantee impossible to keep.
sealed class GlassShape {
  const GlassShape();

  /// Which SDF branch this shape resolves to.
  ShapeType get type;

  /// The corner radius in logical pixels for a shape of [size].
  ///
  /// Clamped to half the shorter side, so an intentionally huge radius yields
  /// a capsule rather than an invalid distance field.
  double resolveRadius(Size size);

  /// The border this shape clips its children with.
  ///
  /// The SDF and this border must describe the same silhouette. They are
  /// tested against each other; if they drift, refraction and clip disagree
  /// at the corners.
  ShapeBorder toBorder(Size size);
}

/// A rounded rectangle.
class GlassRoundedRectangle extends GlassShape {
  /// Creates a rounded rectangle with the given corner [radius].
  const GlassRoundedRectangle({required this.radius});

  /// The corner radius, before clamping.
  final BorderRadius radius;

  @override
  ShapeType get type => ShapeType.roundedRectangle;

  @override
  double resolveRadius(Size size) => _clampRadius(radius, size);

  @override
  ShapeBorder toBorder(Size size) => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(resolveRadius(size)),
      );
}

/// An ellipse inscribed in the shape's bounds.
class GlassOval extends GlassShape {
  /// Creates an oval.
  const GlassOval();

  @override
  ShapeType get type => ShapeType.ellipse;

  @override
  double resolveRadius(Size size) => 0;

  @override
  ShapeBorder toBorder(Size size) => const OvalBorder();
}

/// A rounded superellipse, matching Flutter's `RoundedSuperellipse`.
class GlassSuperellipse extends GlassShape {
  /// Creates a rounded superellipse with the given corner [radius].
  const GlassSuperellipse({required this.radius});

  /// The corner radius, before clamping.
  final BorderRadius radius;

  @override
  ShapeType get type => ShapeType.superellipse;

  @override
  double resolveRadius(Size size) => _clampRadius(radius, size);

  @override
  ShapeBorder toBorder(Size size) => RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(resolveRadius(size)),
      );
}

double _clampRadius(BorderRadius radius, Size size) {
  final requested = math.max(
    math.max(radius.topLeft.x, radius.topRight.x),
    math.max(radius.bottomLeft.x, radius.bottomRight.x),
  );
  final limit = math.min(size.width, size.height) / 2;
  return math.min(requested, limit);
}
```

- [ ] **Step 5: Run the tests**

Run: `flutter test packages/glass_forge/test/src/shapes/glass_shape_test.dart`
Expected: PASS

- [ ] **Step 6: Verify the analyzer is clean**

Run: `flutter analyze packages/glass_forge`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add packages/glass_forge/lib/src/shapes packages/glass_forge/test/src/shapes
git commit -m "feat: add the glass shape family

Three shapes, closed set. Each pairs an SDF branch with the Flutter border its
children clip against, so the refraction silhouette and the clip cannot drift
apart — upstream's superellipse renders as a rounded rectangle while clipping
as a real superellipse, and they disagree at every corner."
```

---

### Task 3: Resolved shape geometry — the affine basis

This is the task that makes rotated and non-uniformly scaled glass correct. Upstream stores a centre and a size, which cannot express rotation, so its displacement is encoded in group-local axes and applied in screen axes with no basis change — every rotated shape refracts in the wrong direction.

**Files:**
- Create: `packages/glass_forge/lib/src/shapes/shape_geometry.dart`
- Test: `packages/glass_forge/test/src/shapes/shape_geometry_test.dart`

**Interfaces:**
- Consumes: `GlassShape`, `ShapeType` (Task 2)
- Produces: `ShapeGeometry` with fields `type`, `origin` (`Offset`), `inverseBasis` (`Float32List`, 4 entries, row-major), `distanceScale` (`double`), `radius`, `halfExtent` (`Size`), `blendMarker` (`double`). Factory `ShapeGeometry.resolve({required GlassShape shape, required Size size, required Matrix4 toLayer, required double devicePixelRatio})`. Static `double minimumSingularValue(Offset axisX, Offset axisY)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

void main() {
  group('minimumSingularValue', () {
    test('is 1 for an identity basis', () {
      final s = ShapeGeometry.minimumSingularValue(
        const Offset(1, 0),
        const Offset(0, 1),
      );
      expect(s, closeTo(1, 1e-9));
    });

    test('is the smaller scale under non-uniform scaling', () {
      // A basis scaled 3x horizontally and 2x vertically. The smallest amount
      // any direction is stretched by is 2, so a local distance of 1 is worth
      // at least 2 screen pixels — never 3, or the SDF stops being a lower
      // bound and culling starts dropping shapes that are actually visible.
      final s = ShapeGeometry.minimumSingularValue(
        const Offset(3, 0),
        const Offset(0, 2),
      );
      expect(s, closeTo(2, 1e-9));
    });

    test('is rotation invariant', () {
      const angle = math.pi / 5;
      final axisX = Offset(math.cos(angle), math.sin(angle)) * 3;
      final axisY = Offset(-math.sin(angle), math.cos(angle)) * 2;
      final s = ShapeGeometry.minimumSingularValue(axisX, axisY);
      expect(s, closeTo(2, 1e-9));
    });

    test('is zero for a degenerate basis', () {
      final s = ShapeGeometry.minimumSingularValue(
        const Offset(1, 0),
        const Offset(2, 0),
      );
      expect(s, closeTo(0, 1e-9));
    });
  });

  group('resolve', () {
    test('inverts a rotated basis so local space is recoverable', () {
      final toLayer = Matrix4.rotationZ(math.pi / 2);
      final geometry = ShapeGeometry.resolve(
        shape: const GlassOval(),
        size: const Size(10, 10),
        toLayer: toLayer,
        devicePixelRatio: 1,
      );

      // Mapping a point through the basis and back must be the identity.
      const point = Offset(3, 7);
      final local = geometry.toLocal(point);
      final back = geometry.toLayerSpace(local);
      expect(back.dx, closeTo(point.dx, 1e-6));
      expect(back.dy, closeTo(point.dy, 1e-6));
    });

    test('scales geometry by device pixel ratio', () {
      final geometry = ShapeGeometry.resolve(
        shape: const GlassRoundedRectangle(
          radius: BorderRadius.all(Radius.circular(8)),
        ),
        size: const Size(100, 40),
        toLayer: Matrix4.identity(),
        devicePixelRatio: 3,
      );

      // Every geometric quantity is in physical pixels. Upstream forgot this
      // for thickness alone, so its refraction rim renders a third as wide on
      // a 3x phone as it does on the 1x machine its goldens were taken on.
      expect(geometry.radius, closeTo(24, 1e-9));
      expect(geometry.halfExtent.width, closeTo(150, 1e-9));
      expect(geometry.halfExtent.height, closeTo(60, 1e-9));
    });
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test packages/glass_forge/test/src/shapes/shape_geometry_test.dart`
Expected: FAIL — `shape_geometry.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_type.dart';

/// A shape resolved into the form the geometry shader consumes.
///
/// Everything here is in **physical pixels, layer-local space**. The shader
/// evaluates each shape's SDF in its own local frame via [inverseBasis], then
/// scales the result back into layer pixels by [distanceScale].
///
/// Carrying a full basis rather than a centre and a size is what lets rotated
/// and non-uniformly scaled glass refract in the right direction.
@immutable
class ShapeGeometry {
  /// Creates a resolved shape.
  const ShapeGeometry({
    required this.type,
    required this.origin,
    required this.inverseBasis,
    required this.distanceScale,
    required this.radius,
    required this.halfExtent,
    required this.blendMarker,
  });

  /// Resolves [shape] at [size] under the transform [toLayer].
  factory ShapeGeometry.resolve({
    required GlassShape shape,
    required Size size,
    required Matrix4 toLayer,
    required double devicePixelRatio,
    double blendMarker = 0,
  }) {
    final scaled = Size(
      size.width * devicePixelRatio,
      size.height * devicePixelRatio,
    );

    // Read the basis by transforming the origin and both unit axes, which
    // captures rotation, scale and skew without assuming the matrix is affine
    // in any particular arrangement.
    final o = MatrixUtils.transformPoint(toLayer, Offset.zero);
    final x = MatrixUtils.transformPoint(toLayer, const Offset(1, 0)) - o;
    final y = MatrixUtils.transformPoint(toLayer, const Offset(0, 1)) - o;

    final determinant = x.dx * y.dy - x.dy * y.dx;
    final invertible = determinant.abs() > 1e-9;
    final inv = Float32List(4);
    if (invertible) {
      inv[0] = y.dy / determinant;
      inv[1] = -y.dx / determinant;
      inv[2] = -x.dy / determinant;
      inv[3] = x.dx / determinant;
    } else {
      // A degenerate transform has no interior to refract. Leave the basis at
      // zero; the shader's coverage term collapses and the shape drops out.
      inv[0] = inv[1] = inv[2] = inv[3] = 0;
    }

    return ShapeGeometry(
      type: shape.type,
      origin: o * devicePixelRatio,
      inverseBasis: inv,
      distanceScale: minimumSingularValue(x, y),
      radius: shape.resolveRadius(size) * devicePixelRatio,
      halfExtent: Size(scaled.width / 2, scaled.height / 2),
      blendMarker: blendMarker,
    );
  }

  /// Which SDF branch this shape resolves to.
  final ShapeType type;

  /// The shape's origin in layer-local physical pixels.
  final Offset origin;

  /// The inverted 2x2 basis, row-major: `[a, b, c, d]`.
  final Float32List inverseBasis;

  /// Converts a local SDF distance into layer-space physical pixels.
  ///
  /// This is the basis's **minimum** singular value, not its average or its
  /// determinant. Anything larger would let the scaled distance overestimate
  /// how far away the surface is, which breaks the lower-bound property that
  /// culling and smooth-min both depend on.
  final double distanceScale;

  /// Corner radius in physical pixels.
  final double radius;

  /// Half the shape's extent in physical pixels.
  final Size halfExtent;

  /// Blend-group marker.
  ///
  /// Negative starts a new group and carries `-(blend + 1)`; positive
  /// continues the current group with that blend width. This is what lets
  /// several blend groups, and ungrouped shapes, share one geometry pass.
  final double blendMarker;

  /// The smallest factor by which this basis stretches any direction.
  ///
  /// For a 2x2 matrix the singular values are the square roots of the
  /// eigenvalues of `MᵀM`. For a 2x2 that reduces to a closed form in the
  /// trace and the determinant, with no iteration.
  static double minimumSingularValue(Offset axisX, Offset axisY) {
    final trace =
        axisX.dx * axisX.dx + axisX.dy * axisX.dy +
        axisY.dx * axisY.dx + axisY.dy * axisY.dy;
    final determinant = axisX.dx * axisY.dy - axisX.dy * axisY.dx;
    final discriminant =
        math.max(0.0, trace * trace - 4 * determinant * determinant);
    return math.sqrt(math.max(0, (trace - math.sqrt(discriminant)) * 0.5));
  }

  /// Maps a layer-space point into this shape's local frame.
  Offset toLocal(Offset layerPoint) {
    final d = layerPoint - origin;
    return Offset(
      inverseBasis[0] * d.dx + inverseBasis[1] * d.dy,
      inverseBasis[2] * d.dx + inverseBasis[3] * d.dy,
    );
  }

  /// Maps a local point back into layer space. Inverse of [toLocal].
  Offset toLayerSpace(Offset localPoint) {
    final det = inverseBasis[0] * inverseBasis[3] -
        inverseBasis[1] * inverseBasis[2];
    if (det.abs() < 1e-12) {
      return origin;
    }
    final a = inverseBasis[3] / det;
    final b = -inverseBasis[1] / det;
    final c = -inverseBasis[2] / det;
    final d = inverseBasis[0] / det;
    return origin +
        Offset(
          a * localPoint.dx + b * localPoint.dy,
          c * localPoint.dx + d * localPoint.dy,
        );
  }
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test packages/glass_forge/test/src/shapes/shape_geometry_test.dart`
Expected: PASS. If `resolve` fails on the DPR test, check that `origin` is scaled once and only once — a common slip is scaling both the matrix and the resulting offset.

- [ ] **Step 5: Verify the analyzer is clean**

Run: `flutter analyze packages/glass_forge`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add packages/glass_forge/lib/src/shapes/shape_geometry.dart \
        packages/glass_forge/test/src/shapes/shape_geometry_test.dart
git commit -m "feat: resolve shapes into an inverse affine basis

Carries a full basis per shape rather than a centre and a size, so rotation
and non-uniform scale survive into the shader. Local SDF distances scale back
to screen pixels by the basis's minimum singular value, which keeps them a
valid lower bound — the property culling and smooth-min both rely on."
```

---

### Task 4: Pixel bucketing and tie-stable snapping

Backdrop filters allocate an offscreen render target sized to their clip bounds. A small animated transform otherwise produces a differently-sized target on nearly every frame, which means a reallocation per frame.

**Files:**
- Create: `packages/glass_forge/lib/src/composition/pixel_buckets.dart`
- Test: `packages/glass_forge/test/src/composition/pixel_buckets_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `double snapToPixel(double logical, double devicePixelRatio)`; `Rect expandToPixelBuckets(Rect rect, {int bucket = 64})`; `int bucketDimension(int value, {int bucket = 64})`; `const int kDefaultBucket = 64`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/composition/pixel_buckets.dart';

void main() {
  group('snapToPixel', () {
    test('rounds half-up consistently on both sides of zero', () {
      // floor(x + 0.5) rather than round(): round() rounds half away from
      // zero, so a matte straddling the origin changes size by a pixel as it
      // crosses, and the backdrop target reallocates.
      expect(snapToPixel(0.5, 1), 1);
      expect(snapToPixel(-0.5, 1), 0);
      expect(snapToPixel(-1.5, 1), -1);
    });

    test('snaps in device pixels, not logical ones', () {
      expect(snapToPixel(1.4, 2), 3);
    });
  });

  group('bucketDimension', () {
    test('rounds up to the bucket size', () {
      expect(bucketDimension(1), 64);
      expect(bucketDimension(64), 64);
      expect(bucketDimension(65), 128);
    });

    test('keeps zero at zero', () {
      expect(bucketDimension(0), 0);
    });
  });

  test('expandToPixelBuckets is stable across sub-pixel jitter', () {
    // The whole point: two rects that differ only by a fraction of a pixel
    // must produce the same allocation, or the render target thrashes.
    final a = expandToPixelBuckets(const Rect.fromLTWH(0, 0, 100, 100));
    final b = expandToPixelBuckets(const Rect.fromLTWH(0.3, 0.4, 100, 100));
    expect(a.size, b.size);
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test packages/glass_forge/test/src/composition/pixel_buckets_test.dart`
Expected: FAIL — `pixel_buckets.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// The allocation granularity for backdrop clip bounds and matte textures.
///
/// Backdrop image filters allocate an offscreen Impeller render target sized
/// to their clip bounds. Without bucketing, a slow animated transform yields a
/// differently sized target on nearly every frame, so the target is
/// reallocated every frame for no visual benefit.
const int kDefaultBucket = 64;

/// Snaps a logical coordinate to a whole device pixel.
///
/// Uses `floor(x + 0.5)` rather than `round()` on purpose: `round()` rounds
/// halves away from zero, so a matte that straddles the origin changes size by
/// one pixel as it crosses it.
double snapToPixel(double logical, double devicePixelRatio) {
  return (logical * devicePixelRatio + 0.5).floorToDouble();
}

/// Rounds [value] up to the next multiple of [bucket].
int bucketDimension(int value, {int bucket = kDefaultBucket}) {
  if (value <= 0) {
    return 0;
  }
  return ((value + bucket - 1) ~/ bucket) * bucket;
}

/// Expands [rect] so its size falls on bucket boundaries.
///
/// The origin is floored and the size is grown; the result always contains the
/// input, so nothing is clipped by the rounding.
Rect expandToPixelBuckets(Rect rect, {int bucket = kDefaultBucket}) {
  if (rect.isEmpty) {
    return Rect.zero;
  }
  final left = rect.left.floorToDouble();
  final top = rect.top.floorToDouble();
  final width = bucketDimension(
    math.max(1, (rect.right - left).ceil()),
    bucket: bucket,
  );
  final height = bucketDimension(
    math.max(1, (rect.bottom - top).ceil()),
    bucket: bucket,
  );
  return Rect.fromLTWH(left, top, width.toDouble(), height.toDouble());
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test packages/glass_forge/test/src/composition/pixel_buckets_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add packages/glass_forge/lib/src/composition/pixel_buckets.dart \
        packages/glass_forge/test/src/composition/pixel_buckets_test.dart
git commit -m "feat: add pixel bucketing and tie-stable snapping

Backdrop filters allocate a render target sized to their clip bounds, so
sub-pixel jitter otherwise reallocates one every frame. Buckets to 64px and
snaps with floor(x + 0.5) so a matte crossing the origin does not change size."
```

---

### Task 5: The matte codec

Upstream stores displacement directly in RGBA8 over a range of ±10× thickness, which leaves fewer than two code points per physical pixel at common thicknesses. Its own source blames that for the concentric banding visible in narrow contour ramps.

**Files:**
- Create: `packages/glass_forge/lib/src/geometry/matte_codec.dart`
- Test: `packages/glass_forge/test/src/geometry/matte_codec_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `class MatteCodec` with `const MatteCodec({required double maxDisplacement})`; `Float32List encode({required Offset normal, required double signedDistance, required double displacementMagnitude})` returning RGBA in 0..1; `({Offset normal, double signedDistance, double displacement}) decode(Float32List rgba)`; `static double displacementRangeFor(double edgeRefraction)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/matte_codec.dart';

void main() {
  const codec = MatteCodec(maxDisplacement: 32);

  test('encodes the cardinal normals exactly', () {
    // -1, 0 and +1 must all be exactly representable, or a flat surface
    // acquires a permanent sub-pixel tilt from its own encoding.
    for (final n in const [Offset(1, 0), Offset(-1, 0), Offset(0, 1)]) {
      final decoded = codec.decode(
        codec.encode(normal: n, signedDistance: 0, displacementMagnitude: 0),
      );
      expect(decoded.normal.dx, closeTo(n.dx, 1e-6));
      expect(decoded.normal.dy, closeTo(n.dy, 1e-6));
    }
  });

  test('round-trips displacement within the 8-bit error bound', () {
    // sqrt companding spends code points where the eye is: near zero
    // displacement, where the contour and highlight ramps live.
    for (var i = 0; i <= 32; i++) {
      final magnitude = 32 * i / 32;
      final decoded = codec.decode(
        codec.encode(
          normal: const Offset(1, 0),
          signedDistance: 0,
          displacementMagnitude: magnitude,
        ),
      );
      expect((decoded.displacement - magnitude).abs(), lessThan(0.5));
    }
  });

  test('resolves small displacements more finely than large ones', () {
    double errorNear(double magnitude) {
      final decoded = codec.decode(
        codec.encode(
          normal: const Offset(1, 0),
          signedDistance: 0,
          displacementMagnitude: magnitude,
        ),
      );
      return (decoded.displacement - magnitude).abs();
    }

    expect(errorNear(1), lessThan(errorNear(30)));
  });

  test('round-trips signed distance on both sides of the edge', () {
    for (final d in const [-24.0, -1.0, 0.0, 1.0, 24.0]) {
      final decoded = codec.decode(
        codec.encode(
          normal: const Offset(0, 1),
          signedDistance: d,
          displacementMagnitude: 0,
        ),
      );
      expect((decoded.signedDistance - d).abs(), lessThan(0.5));
    }
  });

  test('sizes the range to what is reachable', () {
    // Upstream uses thickness * 10, so most code points address displacements
    // the profile can never produce.
    expect(MatteCodec.displacementRangeFor(27.42), closeTo(28.79, 0.01));
  });

  test('clamps rather than wrapping when asked for the impossible', () {
    final decoded = codec.decode(
      codec.encode(
        normal: const Offset(1, 0),
        signedDistance: 0,
        displacementMagnitude: 1000,
      ),
    );
    expect(decoded.displacement, closeTo(32, 0.5));
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test packages/glass_forge/test/src/geometry/matte_codec_test.dart`
Expected: FAIL — `matte_codec.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/rendering.dart';

/// Packs a shape's surface into an RGBA8 matte, and reads it back.
///
/// The channels are:
///
/// - **R, G** — the unit surface normal, in an asymmetric 0..254 code so that
///   -1, 0 and +1 are all exactly representable. A symmetric code cannot hit
///   all three, and a flat surface then acquires a permanent sub-pixel tilt.
/// - **B** — signed edge distance, sqrt-companded on both sides.
/// - **A** — displacement magnitude, sqrt-companded.
///
/// Storing a normal plus a magnitude rather than a displacement vector is what
/// makes 8 bits enough. Companding then spends the code points near zero,
/// where the narrow contour and highlight ramps live and where banding shows.
///
/// This class is the Dart mirror of `shaders/common/codec.glsl`. The two are
/// tested against each other; if they drift, the matte decodes to nonsense.
@immutable
class MatteCodec {
  /// Creates a codec covering displacements up to [maxDisplacement] physical
  /// pixels.
  const MatteCodec({required this.maxDisplacement});

  /// The largest displacement magnitude this codec can represent.
  final double maxDisplacement;

  /// The displacement range worth encoding for a given edge refraction.
  ///
  /// Sized just above what the profile can actually produce. Upstream uses
  /// `thickness * 10`, which spends most of the range on values the profile
  /// never reaches.
  static double displacementRangeFor(double edgeRefraction) {
    return math.max(1e-3, 1.05 * edgeRefraction);
  }

  /// Encodes one texel. Returns RGBA in 0..1.
  Float32List encode({
    required Offset normal,
    required double signedDistance,
    required double displacementMagnitude,
  }) {
    final length = normal.distance;
    final unit = length < 1e-9 ? Offset.zero : normal / length;

    final out = Float32List(4);
    out[0] = _encodeSigned(unit.dx);
    out[1] = _encodeSigned(unit.dy);
    out[2] = _encodeCompandedSigned(signedDistance / maxDisplacement);
    out[3] = _encodeCompanded(
      (displacementMagnitude / maxDisplacement).clamp(0.0, 1.0),
    );
    return out;
  }

  /// Decodes one texel produced by [encode].
  ({Offset normal, double signedDistance, double displacement}) decode(
    Float32List rgba,
  ) {
    return (
      normal: Offset(_decodeSigned(rgba[0]), _decodeSigned(rgba[1])),
      signedDistance: _decodeCompandedSigned(rgba[2]) * maxDisplacement,
      displacement: _decodeCompanded(rgba[3]) * maxDisplacement,
    );
  }

  // 0..254 of the 0..255 range, so 127 is exactly the midpoint and -1/0/+1
  // all land on integers.
  static double _encodeSigned(double value) {
    final clamped = value.clamp(-1.0, 1.0);
    return ((clamped * 0.5 + 0.5) * 254).roundToDouble() / 255;
  }

  static double _decodeSigned(double encoded) {
    return (encoded * 255 / 254) * 2 - 1;
  }

  static double _encodeCompanded(double linear) {
    final normalized = 1 - math.sqrt(1 - linear.clamp(0.0, 1.0));
    return (normalized * 255).roundToDouble() / 255;
  }

  static double _decodeCompanded(double encoded) {
    final inverse = 1 - encoded;
    return 1 - inverse * inverse;
  }

  static double _encodeCompandedSigned(double value) {
    final clamped = value.clamp(-1.0, 1.0);
    final magnitude = _encodeCompanded(clamped.abs());
    return clamped.isNegative ? 0.5 - magnitude * 0.5 : 0.5 + magnitude * 0.5;
  }

  static double _decodeCompandedSigned(double encoded) {
    final centered = (encoded - 0.5) * 2;
    final magnitude = _decodeCompanded(centered.abs());
    return centered.isNegative ? -magnitude : magnitude;
  }
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test packages/glass_forge/test/src/geometry/matte_codec_test.dart`
Expected: PASS

If the "resolves small displacements more finely" test fails, the companding
is inverted — check that `_encodeCompanded` uses `1 - sqrt(1 - linear)` and
not `sqrt(linear)`. The former concentrates precision near zero, which is
where the contour ramp lives; the latter concentrates it at maximum
displacement, where nothing needs it.

- [ ] **Step 5: Verify the analyzer is clean**

Run: `flutter analyze packages/glass_forge`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add packages/glass_forge/lib/src/geometry/matte_codec.dart \
        packages/glass_forge/test/src/geometry/matte_codec_test.dart
git commit -m "feat: add the RGBA8 matte codec

Stores a unit normal plus a companded magnitude rather than a displacement
vector, and sizes its range to what the profile can actually reach. Upstream
stores displacement over 10x thickness, which leaves under two code points per
physical pixel and bands visibly in the contour ramp."
```

---

### Task 6: The scene and its revision counter

Upstream sets `needsGeometryUpdate` on **every** `layout()` call, before constraints short-circuit — so glass inside any scrollable re-rasterises its matte every scroll frame even when nothing moved relative to it. This task is the fix.

**Files:**
- Create: `packages/glass_forge/lib/src/scene/scene_revision.dart`
- Create: `packages/glass_forge/lib/src/scene/glass_scene.dart`
- Test: `packages/glass_forge/test/src/scene/glass_scene_test.dart`

**Interfaces:**
- Consumes: `ShapeGeometry` (Task 3)
- Produces: `class SceneRevision` with `int get value` and `void bump()`. `class GlassScene` with `List<ShapeGeometry> get shapes`, `int get revision`, `void register(Object key, ShapeGeometry geometry)`, `void unregister(Object key)`, `Rect bounds({required double padding})`, `Offset? uniformTranslationSince(GlassScene other)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

ShapeGeometry _geometry({Offset origin = Offset.zero, double radius = 8}) {
  return ShapeGeometry.resolve(
    shape: GlassRoundedRectangle(
      radius: BorderRadius.all(Radius.circular(radius)),
    ),
    size: const Size(100, 40),
    toLayer: Matrix4.translationValues(origin.dx, origin.dy, 0),
    devicePixelRatio: 1,
  );
}

void main() {
  test('registering a shape bumps the revision', () {
    final scene = GlassScene();
    final before = scene.revision;
    scene.register('a', _geometry());
    expect(scene.revision, greaterThan(before));
  });

  test('re-registering identical geometry does NOT bump the revision', () {
    // This is the whole point. A scroll frame re-runs layout and re-registers
    // every shape with the same numbers; if that bumps the revision the matte
    // is rebuilt every frame for nothing.
    final scene = GlassScene()..register('a', _geometry());
    final after = scene.revision;
    scene.register('a', _geometry());
    expect(scene.revision, after);
  });

  test('changing geometry bumps the revision', () {
    final scene = GlassScene()..register('a', _geometry());
    final after = scene.revision;
    scene.register('a', _geometry(radius: 16));
    expect(scene.revision, greaterThan(after));
  });

  test('unregistering bumps the revision', () {
    // Upstream's unregister forgets to dirty, so a removed group's matte
    // survives in the composite until something unrelated forces a rebuild.
    final scene = GlassScene()..register('a', _geometry());
    final after = scene.revision;
    scene.unregister('a');
    expect(scene.revision, greaterThan(after));
    expect(scene.shapes, isEmpty);
  });

  test('detects a uniform translation of every shape', () {
    final before = GlassScene()
      ..register('a', _geometry())
      ..register('b', _geometry(origin: const Offset(50, 0)));
    final after = GlassScene()
      ..register('a', _geometry(origin: const Offset(10, 5)))
      ..register('b', _geometry(origin: const Offset(60, 5)));

    // Everything moved by the same delta and nothing else changed, so the
    // matte can be reused with shifted bounds instead of re-rendered.
    expect(after.uniformTranslationSince(before), const Offset(10, 5));
  });

  test('reports no uniform translation when shapes move differently', () {
    final before = GlassScene()
      ..register('a', _geometry())
      ..register('b', _geometry(origin: const Offset(50, 0)));
    final after = GlassScene()
      ..register('a', _geometry(origin: const Offset(10, 0)))
      ..register('b', _geometry(origin: const Offset(90, 0)));

    expect(after.uniformTranslationSince(before), isNull);
  });

  test('bounds pad for antialiasing', () {
    final scene = GlassScene()..register('a', _geometry());
    final padded = scene.bounds(padding: 0.5);
    final tight = scene.bounds(padding: 0);
    expect(padded.width, closeTo(tight.width + 1, 1e-9));
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test packages/glass_forge/test/src/scene/glass_scene_test.dart`
Expected: FAIL — URIs do not exist.

- [ ] **Step 3: Write `scene_revision.dart`**

```dart
/// A monotonically increasing change counter.
///
/// Comparing an integer is roughly two orders of magnitude cheaper than a deep
/// comparison of shape lists — upstream measured 735.8 ns against 5.7 ns — and
/// this sits on the paint path, so it runs every frame.
class SceneRevision {
  int _value = 0;

  /// The current revision.
  int get value => _value;

  /// Marks the scene changed.
  void bump() => _value++;
}
```

- [ ] **Step 4: Write `glass_scene.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/scene/scene_revision.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

/// The set of shapes belonging to one glass layer, in layer-local space.
///
/// Registration is idempotent: re-registering a shape whose resolved geometry
/// is unchanged does not bump the revision. That matters because layout runs
/// again on every scroll frame and re-registers everything with identical
/// numbers.
class GlassScene {
  final Map<Object, ShapeGeometry> _shapes = <Object, ShapeGeometry>{};
  final SceneRevision _revision = SceneRevision();
  List<ShapeGeometry>? _cachedOrder;

  /// The registered shapes, in registration order.
  List<ShapeGeometry> get shapes =>
      _cachedOrder ??= List<ShapeGeometry>.unmodifiable(_shapes.values);

  /// The current revision. Changes only when the scene really changed.
  int get revision => _revision.value;

  /// Registers or updates the shape identified by [key].
  void register(Object key, ShapeGeometry geometry) {
    final existing = _shapes[key];
    if (existing != null && _sameGeometry(existing, geometry)) {
      return;
    }
    _shapes[key] = geometry;
    _cachedOrder = null;
    _revision.bump();
  }

  /// Removes the shape identified by [key].
  void unregister(Object key) {
    if (_shapes.remove(key) == null) {
      return;
    }
    _cachedOrder = null;
    _revision.bump();
  }

  /// The union of every shape's bounds, grown by [padding] physical pixels.
  ///
  /// The padding reserves room for the antialiasing band, which is centred on
  /// the edge and therefore extends outside the shape.
  Rect bounds({required double padding}) {
    if (_shapes.isEmpty) {
      return Rect.zero;
    }
    var result = _boundsOf(shapes.first);
    for (final shape in shapes.skip(1)) {
      result = result.expandToInclude(_boundsOf(shape));
    }
    return result.inflate(padding);
  }

  /// The common delta if every shape moved by the same amount and nothing
  /// else changed; `null` otherwise.
  ///
  /// When this returns a value the matte can be reused with shifted bounds
  /// rather than re-rendered — the common case for a glass layer scrolling
  /// past content.
  Offset? uniformTranslationSince(GlassScene other) {
    if (_shapes.length != other._shapes.length) {
      return null;
    }
    Offset? delta;
    for (final entry in _shapes.entries) {
      final previous = other._shapes[entry.key];
      if (previous == null || !_sameShapeIgnoringOrigin(previous, entry.value)) {
        return null;
      }
      final candidate = entry.value.origin - previous.origin;
      if (delta == null) {
        delta = candidate;
      } else if ((candidate - delta).distanceSquared > 1e-6) {
        return null;
      }
    }
    return delta;
  }

  static Rect _boundsOf(ShapeGeometry shape) {
    // The shape's own extent, mapped through its basis. Taking the extremes of
    // the four transformed corners covers rotation and skew.
    final corners = <Offset>[
      shape.toLayerSpace(
        Offset(-shape.halfExtent.width, -shape.halfExtent.height),
      ),
      shape.toLayerSpace(
        Offset(shape.halfExtent.width, -shape.halfExtent.height),
      ),
      shape.toLayerSpace(
        Offset(-shape.halfExtent.width, shape.halfExtent.height),
      ),
      shape.toLayerSpace(
        Offset(shape.halfExtent.width, shape.halfExtent.height),
      ),
    ];
    var left = corners.first.dx;
    var top = corners.first.dy;
    var right = left;
    var bottom = top;
    for (final c in corners.skip(1)) {
      left = math.min(left, c.dx);
      top = math.min(top, c.dy);
      right = math.max(right, c.dx);
      bottom = math.max(bottom, c.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  static bool _sameGeometry(ShapeGeometry a, ShapeGeometry b) {
    return (a.origin - b.origin).distanceSquared < 1e-9 &&
        _sameShapeIgnoringOrigin(a, b);
  }

  static bool _sameShapeIgnoringOrigin(ShapeGeometry a, ShapeGeometry b) {
    if (a.type != b.type ||
        (a.radius - b.radius).abs() > 1e-9 ||
        (a.distanceScale - b.distanceScale).abs() > 1e-9 ||
        (a.blendMarker - b.blendMarker).abs() > 1e-9 ||
        a.halfExtent != b.halfExtent) {
      return false;
    }
    for (var i = 0; i < 4; i++) {
      if ((a.inverseBasis[i] - b.inverseBasis[i]).abs() > 1e-9) {
        return false;
      }
    }
    return true;
  }
}
```

- [ ] **Step 5: Run the tests**

Run: `flutter test packages/glass_forge/test/src/scene/glass_scene_test.dart`
Expected: PASS

- [ ] **Step 6: Verify the analyzer is clean**

Run: `flutter analyze packages/glass_forge`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add packages/glass_forge/lib/src/scene packages/glass_forge/test/src/scene
git commit -m "feat: add the layer scene and its revision counter

Registration is idempotent, so a scroll frame that re-registers identical
geometry does not dirty the matte. Also detects the case where every shape
moved by the same delta, which lets the matte be reused with shifted bounds
instead of re-rendered."
```

---

### Task 7: Blend groups and the sign-encoded marker

One geometry pass must carry several blend groups **and** ungrouped shapes. Upstream wraps every ungrouped shape in a dummy `blend: 0` group, which costs a separate group per shape.

**Files:**
- Create: `packages/glass_forge/lib/src/scene/blend_group_link.dart`
- Test: `packages/glass_forge/test/src/scene/blend_group_link_test.dart`

**Interfaces:**
- Consumes: `ShapeGeometry` (Task 3)
- Produces: `class BlendGroupLink` with `final double blend`, `void add(Object key)`, `void remove(Object key)`, `bool get isEmpty`, `bool isFirst(Object key)`. Free functions `double encodeBlendMarker({required bool startsGroup, required double blend})` and `({bool startsGroup, double blend}) decodeBlendMarker(double marker)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/scene/blend_group_link.dart';

void main() {
  test('a group start encodes negative and round-trips its blend', () {
    final marker = encodeBlendMarker(startsGroup: true, blend: 20);
    expect(marker, lessThan(0));

    final decoded = decodeBlendMarker(marker);
    expect(decoded.startsGroup, isTrue);
    expect(decoded.blend, closeTo(20, 1e-9));
  });

  test('a continuation encodes non-negative and round-trips its blend', () {
    final marker = encodeBlendMarker(startsGroup: false, blend: 20);
    expect(marker, greaterThanOrEqualTo(0));

    final decoded = decodeBlendMarker(marker);
    expect(decoded.startsGroup, isFalse);
    expect(decoded.blend, closeTo(20, 1e-9));
  });

  test('a zero-blend group start is still distinguishable from a member', () {
    // The -(blend + 1) offset exists for exactly this: without it a group
    // start with blend 0 would encode as -0.0, which compares equal to 0.0
    // and would be read as a continuation.
    final start = encodeBlendMarker(startsGroup: true, blend: 0);
    expect(start, lessThan(0));
    expect(decodeBlendMarker(start).startsGroup, isTrue);
  });

  test('tracks membership and reports the first member', () {
    final link = BlendGroupLink(blend: 12)..add('a')..add('b');
    expect(link.isFirst('a'), isTrue);
    expect(link.isFirst('b'), isFalse);

    link.remove('a');
    expect(link.isFirst('b'), isTrue);

    link.remove('b');
    expect(link.isEmpty, isTrue);
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test packages/glass_forge/test/src/scene/blend_group_link_test.dart`
Expected: FAIL — `blend_group_link.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:flutter/foundation.dart';

/// Encodes group membership into a single float the shader can branch on.
///
/// The shader walks the shape array once and needs to know, per shape, whether
/// it opens a new blend group and how wide that group's smooth-min is. Packing
/// both into one float keeps the per-shape uniform stride at three `vec4`.
///
/// Negative means "starts a group", carrying `-(blend + 1)`. The `+ 1` matters:
/// without it, a group opening with a blend of zero would encode as `-0.0`,
/// which compares equal to `0.0` and would be read as a continuation.
double encodeBlendMarker({required bool startsGroup, required double blend}) {
  return startsGroup ? -(blend + 1) : blend;
}

/// Reads a marker produced by [encodeBlendMarker].
({bool startsGroup, double blend}) decodeBlendMarker(double marker) {
  if (marker < 0) {
    return (startsGroup: true, blend: -marker - 1);
  }
  return (startsGroup: false, blend: marker);
}

/// Membership of one blend group.
///
/// Scoped to its own layer. A nested layer's shapes must never register into
/// an outer layer's group, or they would blend across a boundary the user
/// drew deliberately.
class BlendGroupLink {
  /// Creates a group whose members merge over [blend] logical pixels.
  BlendGroupLink({required this.blend});

  /// How wide the smooth-min between members is, in logical pixels.
  final double blend;

  final List<Object> _members = <Object>[];

  /// Whether the group has no members left.
  bool get isEmpty => _members.isEmpty;

  /// The members, in insertion order.
  ///
  /// Order is load-bearing: the quadratic smooth-min is **not associative**,
  /// so folding the same shapes in a different order gives a different
  /// surface. Insertion order makes it deterministic.
  List<Object> get members => List<Object>.unmodifiable(_members);

  /// Adds [key] to the group if it is not already a member.
  void add(Object key) {
    if (!_members.contains(key)) {
      _members.add(key);
    }
  }

  /// Removes [key] from the group.
  void remove(Object key) => _members.remove(key);

  /// Whether [key] is the group's first member, and therefore the shape that
  /// carries the group-opening marker.
  bool isFirst(Object key) => _members.isNotEmpty && _members.first == key;
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test packages/glass_forge/test/src/scene/blend_group_link_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add packages/glass_forge/lib/src/scene/blend_group_link.dart \
        packages/glass_forge/test/src/scene/blend_group_link_test.dart
git commit -m "feat: encode blend-group membership into one marker float

Sign-encoding lets a single geometry pass carry several blend groups and
ungrouped shapes together, so siblings share one backdrop capture without
blending into each other. Upstream wraps every ungrouped shape in a dummy
zero-blend group instead."
```

---

### Task 8: The SDF shader library, and a CI gate that compiles it as SkSL

Upstream shipped shaders that fail SkSL compilation **twice** (issues #147, #150), and did not find out until users reported broken web and Android-Skia builds months later. The gate matters as much as the shader.

**Files:**
- Create: `packages/glass_forge/shaders/common/sdf.glsl`
- Create: `.github/workflows/shaders.yaml`
- Test: `packages/glass_forge/test/src/shaders/sdf_contract_test.dart`

**Interfaces:**
- Consumes: `kMaxShapes` (Task 1), `ShapeType.sdfCode` (Task 2)
- Produces: GLSL functions `float sdRoundedBox(vec2 p, vec2 b, float r)`, `float sdEllipse(vec2 p, vec2 ab)`, `float sdSuperellipse(vec2 p, vec2 b, float r)`, `float smoothUnion(float a, float b, float k)`, `vec2 gfToLocal(int i, vec2 p)`, `float gfShapeDistance(int i, vec2 p)`, `float gfBoundLowerBound(int i, vec2 p)`, plus the `GF_*` accessor macros. All read `uShapeData` as a global.

  Note the includer, not this file, defines `gfSceneDistance(vec2)` — it needs the blend-marker fold, which is scene policy rather than shape math. `profile.glsl` calls it, so it must be included *after* that definition.

- [ ] **Step 1: Write the shader**

`packages/glass_forge/shaders/common/sdf.glsl`. Every constraint in this file is load-bearing — the header comment says why, because the next person will otherwise "tidy" it back into something that does not compile.

```glsl
// Shape distance functions and scene composition.
//
// SkSL LEGALITY — do not "simplify" any of this:
//
//   * uShapeData is read as a GLOBAL, never passed as a parameter. A by-value
//     array parameter makes spirv-cross emit `float param[96] = uShapeData;`,
//     which SkSL rejects outright. This is upstream issue #150.
//   * Array indices are compile-time constants, expanded by macro. SkSL
//     requires uniform-array indices to be constant.
//   * Loops have constant bounds and exit with `break`. A non-constant loop
//     initialiser is the second half of #150.
//   * No sampler2D parameters anywhere. SkSL rejects those too.
//   * No dFdx/dFdy/fwidth. Rejected on web (flutter#180959), and undefined
//     after a non-uniform early return. Normals here are analytic.
//
// The includer must declare, BEFORE including this file:
//   #define MAX_SHAPES <n>
//   uniform vec4 uShapeData[MAX_SHAPES * 3];
//
// Layout, per shape i:
//   uShapeData[i*3 + 0].xy  origin
//   uShapeData[i*3 + 0].zw  half extent
//   uShapeData[i*3 + 1].xyzw inverse basis, row-major
//   uShapeData[i*3 + 2].x   sdf type code
//   uShapeData[i*3 + 2].y   corner radius
//   uShapeData[i*3 + 2].z   distance scale (min singular value)
//   uShapeData[i*3 + 2].w   blend marker

// Rounded box. Inigo Quilez's formulation, re-derived; see
// docs/reference/shader_techniques.md for provenance.
float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Ellipse, by Newton iteration on the parametric normal.
//
// The cheap closed form divides by |p| near the centre, which produces a
// direction-dependent pinhole and a gradient whose magnitude is not 1 — so
// heights and normals come out distorted for anything but a circle.
float sdEllipse(vec2 p, vec2 ab) {
    vec2 q = abs(p);
    vec2 e = max(ab, vec2(1e-4));
    float t = 0.7853981634; // pi/4
    for (int i = 0; i < 4; i++) {
        vec2 cs = vec2(cos(t), sin(t));
        vec2 xy = e * cs;
        vec2 ex = (e.x * e.x - e.y * e.y) * vec2(cs.x * cs.x * cs.x,
                                                 -cs.y * cs.y * cs.y) / e;
        vec2 r = xy - ex;
        vec2 qx = q - ex;
        float rl = length(r);
        float ql = length(qx);
        t += rl * asin(clamp((r.x * qx.y - r.y * qx.x) / (rl * ql), -1.0, 1.0))
             / max(1e-6, sqrt(max(0.0, e.x * e.x + e.y * e.y - dot(xy, xy))));
        t = clamp(t, 0.0, 1.5707963268);
    }
    vec2 nearest = e * vec2(cos(t), sin(t));
    return length(nearest - q) * sign(q.y - nearest.y);
}

// Rounded superellipse, matching Flutter's own RoundedSuperellipse so the
// refraction silhouette and the child clip agree at the corners. Upstream's
// "squircle" is term-for-term identical to its rounded box while its clip is
// a real superellipse, and they disagree at every corner.
float sdSuperellipse(vec2 p, vec2 b, float r) {
    vec2 q = abs(p);
    vec2 inner = max(b - vec2(r), vec2(1e-4));
    vec2 d = max(q - inner, vec2(0.0));
    if (d.x <= 0.0 && d.y <= 0.0) {
        return max(q.x - b.x, q.y - b.y);
    }
    // Exponent 4 is the distance-like metric Flutter uses for its corners.
    vec2 n = d / max(r, 1e-4);
    float m = pow(pow(n.x, 4.0) + pow(n.y, 4.0), 0.25);
    return (m - 1.0) * r;
}

// Quadratic smooth-min. NOT associative — fold order changes the surface, so
// the caller must fold deterministically.
float smoothUnion(float a, float b, float k) {
    if (k <= 0.0) {
        return min(a, b);
    }
    float e = max(k - abs(a - b), 0.0);
    return min(a, b) - e * e * 0.25 / k;
}

#define GF_ORIGIN(i)     uShapeData[(i) * 3 + 0].xy
#define GF_EXTENT(i)     uShapeData[(i) * 3 + 0].zw
#define GF_BASIS(i)      uShapeData[(i) * 3 + 1]
#define GF_TYPE(i)       uShapeData[(i) * 3 + 2].x
#define GF_RADIUS(i)     uShapeData[(i) * 3 + 2].y
#define GF_DISTSCALE(i)  uShapeData[(i) * 3 + 2].z
#define GF_MARKER(i)     uShapeData[(i) * 3 + 2].w

vec2 gfToLocal(int i, vec2 p) {
    vec2 d = p - GF_ORIGIN(i);
    vec4 m = GF_BASIS(i);
    return vec2(m.x * d.x + m.y * d.y, m.z * d.x + m.w * d.y);
}

float gfShapeDistance(int i, vec2 p) {
    float type = GF_TYPE(i);
    if (type < 0.5) {
        return 1e9;
    }
    vec2 local = gfToLocal(i, p);
    vec2 extent = GF_EXTENT(i);
    float radius = GF_RADIUS(i);
    float d;
    if (type < 1.5) {
        d = sdRoundedBox(local, extent, radius);
    } else if (type < 2.5) {
        d = sdEllipse(local, extent);
    } else {
        d = sdSuperellipse(local, extent, radius);
    }
    return d * GF_DISTSCALE(i);
}

// A conservative lower bound on this shape's distance, cheap enough to be
// worth evaluating before the real SDF. Upstream measured 14-23% GPU savings
// from culling on this bound; an L-infinity bound culled less and ran slower.
float gfBoundLowerBound(int i, vec2 p) {
    if (GF_TYPE(i) < 0.5) {
        return 1e9;
    }
    vec2 local = gfToLocal(i, p);
    vec2 d = abs(local) - GF_EXTENT(i);
    return length(max(d, vec2(0.0))) * GF_DISTSCALE(i);
}
```

- [ ] **Step 2: Write the contract test**

The GLSL cannot be unit-tested from Dart, but the **contract between them** can — and that is where drift actually happens.

`packages/glass_forge/test/src/shaders/sdf_contract_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/shapes/shape_limits.dart';
import 'package:glass_forge/src/shapes/shape_type.dart';

void main() {
  final sdf = File('shaders/common/sdf.glsl').readAsStringSync();

  test('reads the uniform array as a global, never as a parameter', () {
    // The exact defect behind upstream #150: a by-value array parameter makes
    // spirv-cross emit an array copy-initializer that SkSL rejects.
    expect(
      RegExp(r'\(\s*[^)]*float\s+\w+\s*\[').hasMatch(sdf),
      isFalse,
      reason: 'an array parameter would break SkSL compilation',
    );
  });

  test('uses no derivative functions', () {
    // Rejected on web, and undefined after a non-uniform early return.
    for (final banned in const ['dFdx', 'dFdy', 'fwidth']) {
      expect(sdf.contains(banned), isFalse, reason: '$banned is not portable');
    }
  });

  test('takes no sampler parameters', () {
    expect(RegExp(r'\(\s*[^)]*sampler2D').hasMatch(sdf), isFalse);
  });

  test('every loop has constant bounds', () {
    for (final match in RegExp(r'for\s*\(([^)]*)\)').allMatches(sdf)) {
      final header = match.group(1)!;
      expect(
        RegExp(r'<\s*\d+').hasMatch(header),
        isTrue,
        reason: 'non-constant loop bound in "$header" breaks SkSL',
      );
    }
  });

  test('dispatches on every shape type the Dart side can emit', () {
    // If a new ShapeType is added without a shader branch it silently renders
    // as whatever the final else happens to be.
    expect(ShapeType.values.length, 4);
    expect(sdf.contains('sdRoundedBox'), isTrue);
    expect(sdf.contains('sdEllipse'), isTrue);
    expect(sdf.contains('sdSuperellipse'), isTrue);
  });

  test('documents the stride the Dart packing must match', () {
    expect(sdf.contains('* 3 + 0'), isTrue);
    expect(sdf.contains('* 3 + 1'), isTrue);
    expect(sdf.contains('* 3 + 2'), isTrue);
    expect(kMaxShapes, greaterThan(0));
  });
}
```

- [ ] **Step 3: Run it to make sure it fails**

Run: `cd packages/glass_forge && flutter test test/src/shaders/sdf_contract_test.dart`
Expected: FAIL — `shaders/common/sdf.glsl` not found, until Step 1's file is in place. Then PASS.

- [ ] **Step 4: Add the CI gate that actually compiles SkSL**

The contract test catches the patterns we know about. Only a real compile catches the rest.

`.github/workflows/shaders.yaml`:

```yaml
name: shaders

on:
  pull_request:
  push:
    branches: [main]

jobs:
  sksl:
    name: shaders compile as SkSL
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.47.2

      - run: flutter pub get

      # A web build compiles every bundled shader through the SkSL target.
      # This is the gate upstream did not have: it shipped shaders that fail
      # SkSL twice, and found out from user bug reports months later.
      - name: build web (compiles shaders as SkSL)
        run: flutter build web --release
        working-directory: apps/glass_forge_workbench

      - run: flutter analyze
      - run: flutter test
```

- [ ] **Step 5: Verify the gate locally before trusting it**

Run: `cd apps/glass_forge_workbench && flutter build web --release`
Expected: succeeds. If it fails with `error: initializers are not permitted on arrays` or `unknown identifier`, the shader has regressed into the upstream defect — fix it now, not in CI.

- [ ] **Step 6: Commit**

```bash
git add packages/glass_forge/shaders/common/sdf.glsl \
        packages/glass_forge/test/src/shaders/sdf_contract_test.dart \
        .github/workflows/shaders.yaml
git commit -m "feat: add the SDF shader library with an SkSL compile gate

Analytic distances only, uniform array read as a global, constant loop bounds
and constant array indices — the combination upstream got wrong twice, and did
not discover until users reported broken web and Android-Skia builds. A web
build in CI compiles every shader through the SkSL target so we find out on
the PR instead."
```

---

### Task 9: The edge-band profile and the geometry pass

Apple's lensing is an **edge band with an undistorted interior**, parameterised by band width and displacement amount — not a whole-surface physical refraction. That is both cheaper and what actually matches.

**Files:**
- Create: `packages/glass_forge/shaders/common/codec.glsl`
- Create: `packages/glass_forge/shaders/common/profile.glsl`
- Create: `packages/glass_forge/shaders/geometry.frag`
- Test: `packages/glass_forge/test/src/shaders/geometry_contract_test.dart`

**Interfaces:**
- Consumes: `sdf.glsl` (Task 8), `MatteCodec` (Task 5)
- Produces: `geometry.frag` writing the matte. Uniform order, which the Dart packer must match exactly: `uSize` (vec2, engine-written), `uOptical` (vec4: maxDisplacement, edgeRefraction, refractionSpread, aaWidth), `uShapeData[kMaxShapes * 3]`, `uNumShapes` (float).

- [ ] **Step 1: Write `codec.glsl` — the exact mirror of `MatteCodec`**

```glsl
// RGBA8 matte codec. This is the shader half of lib/src/geometry/matte_codec.dart.
// The two MUST agree; matte_codec_test.dart pins the Dart side and
// geometry_contract_test.dart pins the constants here.

// 0..254 of 0..255, so -1, 0 and +1 are all exactly representable. A symmetric
// code cannot hit all three, and a flat surface then acquires a permanent
// sub-pixel tilt from its own encoding.
float gfEncodeSigned(float v) {
    return floor((clamp(v, -1.0, 1.0) * 0.5 + 0.5) * 254.0 + 0.5) / 255.0;
}

float gfDecodeSigned(float e) {
    return (e * 255.0 / 254.0) * 2.0 - 1.0;
}

// sqrt companding spends code points near zero, where the narrow contour and
// highlight ramps live and where banding is visible.
float gfEncodeCompanded(float linear) {
    return 1.0 - sqrt(1.0 - clamp(linear, 0.0, 1.0));
}

float gfDecodeCompanded(float e) {
    float inv = 1.0 - e;
    return 1.0 - inv * inv;
}

vec4 gfEncodeMatte(vec2 normal, float signedDistance, float magnitude,
                   float maxDisplacement) {
    float len = length(normal);
    vec2 unit = len < 1e-6 ? vec2(0.0) : normal / len;

    float nd = clamp(signedDistance / maxDisplacement, -1.0, 1.0);
    float ndMag = gfEncodeCompanded(abs(nd));
    float b = nd < 0.0 ? 0.5 - ndMag * 0.5 : 0.5 + ndMag * 0.5;

    return vec4(
        gfEncodeSigned(unit.x),
        gfEncodeSigned(unit.y),
        b,
        gfEncodeCompanded(clamp(magnitude / maxDisplacement, 0.0, 1.0))
    );
}
```

- [ ] **Step 2: Write `profile.glsl`**

```glsl
// Edge-band displacement profile.
//
// Apple's material displaces only within a band inward from the edge and
// leaves the interior undistorted — the runtime exposes exactly two knobs,
// an inner refraction height and an inner refraction amount, over an SDF that
// stores distance and direction. Refracting the whole surface, as a physical
// slab model does, is both more expensive and less faithful.
//
// The profile is a convex squircle, which a Snell ray-trace study found to be
// the best match to Apple among circle, convex, concave and lip profiles.

// Analytic gradient of the scene distance field, by central difference on the
// SDF itself rather than screen-space derivatives. Portable everywhere,
// artifact-free at corners, and defined even after a non-uniform early return.
vec2 gfSceneNormal(vec2 p, float epsilon) {
    float dx = gfSceneDistance(p + vec2(epsilon, 0.0))
             - gfSceneDistance(p - vec2(epsilon, 0.0));
    float dy = gfSceneDistance(p + vec2(0.0, epsilon))
             - gfSceneDistance(p - vec2(0.0, epsilon));
    vec2 g = vec2(dx, dy);
    float len = length(g);
    return len < 1e-6 ? vec2(0.0) : g / len;
}

// Convex squircle: y = (1 - (1 - x)^4)^(1/4), x in 0..1 across the band.
float gfEdgeProfile(float t) {
    float u = 1.0 - clamp(t, 0.0, 1.0);
    float u2 = u * u;
    return pow(max(0.0, 1.0 - u2 * u2), 0.25);
}

// Displacement magnitude at signed distance `sd`, for a band of `height`
// pixels and a peak of `amount` pixels. Zero in the interior.
float gfDisplacementMagnitude(float sd, float height, float amount) {
    if (sd > 0.0 || -sd >= height) {
        return 0.0;   // outside the shape, or past the band: interior is flat
    }
    return gfEdgeProfile(1.0 + sd / height) * amount;
}
```

- [ ] **Step 3: Write `geometry.frag`**

```glsl
#version 460 core
#include <flutter/runtime_effect.glsl>

// highp, not mediump. Coordinates here are physical pixels in the thousands,
// and mediump turns the coordinate subtraction into visible shimmer on large
// layers — upstream issue #57.
precision highp float;

#define MAX_SHAPES 8

// The engine overwrites the first vec2 uniform with the input size.
uniform vec2 uSize;
uniform vec4 uOptical;   // maxDisplacement, edgeRefraction, spread, aaWidth
uniform vec4 uShapeData[MAX_SHAPES * 3];
uniform float uNumShapes;

out vec4 fragColor;

#include "common/sdf.glsl"

// Folds the scene deterministically: shapes are walked in registration order,
// a negative marker opens a group, and groups combine by plain min. The
// quadratic smooth-min is not associative, so order is load-bearing.
float gfSceneDistance(vec2 p) {
    float result = 1e9;
    float groupResult = 1e9;
    float groupBlend = 0.0;
    int count = int(uNumShapes);

    for (int i = 0; i < MAX_SHAPES; i++) {
        if (i >= count) { break; }

        float marker = GF_MARKER(i);
        bool startsGroup = marker < 0.0;
        float blend = startsGroup ? -marker - 1.0 : marker;

        // Conservative bound first. Skipping the real SDF here is worth
        // 14-23% GPU on shape-heavy scenes.
        float bound = gfBoundLowerBound(i, p);
        float best = min(result, groupResult);
        if (bound >= best + blend && !startsGroup) {
            continue;
        }

        float d = gfShapeDistance(i, p);

        if (startsGroup) {
            result = min(result, groupResult);
            groupResult = d;
            groupBlend = blend;
        } else {
            groupResult = smoothUnion(groupResult, d, groupBlend);
        }
    }
    return min(result, groupResult);
}

#include "common/profile.glsl"
#include "common/codec.glsl"

void main() {
    vec2 p = FlutterFragCoord().xy;

    float maxDisplacement = uOptical.x;
    float edgeRefraction  = uOptical.y;
    float spread          = uOptical.z;
    float aaWidth         = uOptical.w;

    float sd = gfSceneDistance(p);

    // Centred half-pixel coverage. fwidth is unavailable in runtime effects
    // even on Impeller, so the width comes from the caller, computed from the
    // transform basis. The matte reserves half a pixel of padding for this.
    float alpha = 1.0 - smoothstep(-aaWidth, aaWidth, sd);
    if (alpha <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 normal = gfSceneNormal(p, 1.0);
    float band = mix(edgeRefraction, edgeRefraction * 4.0, clamp(spread, 0.0, 1.0));
    float magnitude = gfDisplacementMagnitude(min(sd, 0.0), band, edgeRefraction);

    vec4 encoded = gfEncodeMatte(normal, min(sd, 0.0), magnitude, maxDisplacement);
    fragColor = encoded * alpha;   // premultiplied output
}
```

- [ ] **Step 4: Write the contract test**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/shapes/shape_limits.dart';

void main() {
  final geometry = File('shaders/geometry.frag').readAsStringSync();
  final profile = File('shaders/common/profile.glsl').readAsStringSync();
  final codec = File('shaders/common/codec.glsl').readAsStringSync();

  test('MAX_SHAPES matches the Dart constant', () {
    // Drift here silently truncates the shape list, and the missing shapes
    // just stop rendering.
    expect(geometry.contains('#define MAX_SHAPES $kMaxShapes'), isTrue);
  });

  test('the first uniform is the engine-written vec2', () {
    final firstUniform =
        RegExp(r'uniform\s+(\w+)\s+(\w+)').firstMatch(geometry);
    expect(firstUniform?.group(1), 'vec2');
    expect(firstUniform?.group(2), 'uSize');
  });

  test('runs at high precision', () {
    // mediump shimmers on large layers; upstream #57.
    expect(geometry.contains('precision highp float'), isTrue);
  });

  test('normals are analytic, not screen-space derivatives', () {
    for (final banned in const ['dFdx', 'dFdy', 'fwidth']) {
      expect(profile.contains(banned), isFalse);
      expect(geometry.contains(banned), isFalse);
    }
  });

  test('the interior is left undistorted', () {
    // Apple displaces only an edge band. Losing this makes the effect both
    // more expensive and less faithful.
    expect(profile.contains('gfDisplacementMagnitude'), isTrue);
    expect(profile.contains('-sd >= height'), isTrue);
  });

  test('the codec uses the same 254 code and sqrt companding as Dart', () {
    expect(codec.contains('254.0'), isTrue);
    expect(codec.contains('1.0 - sqrt(1.0 - clamp'), isTrue);
  });

  test('output is premultiplied', () {
    expect(geometry.contains('encoded * alpha'), isTrue);
  });
}
```

- [ ] **Step 5: Run the tests**

Run: `cd packages/glass_forge && flutter test test/src/shaders/`
Expected: PASS

- [ ] **Step 6: Verify it compiles as SkSL**

Run: `cd apps/glass_forge_workbench && flutter build web --release`
Expected: succeeds.

- [ ] **Step 7: Commit**

```bash
git add packages/glass_forge/shaders packages/glass_forge/test/src/shaders
git commit -m "feat: add the geometry pass and edge-band profile

Displaces only an edge band and leaves the interior flat, which is what
Apple's runtime actually does and is cheaper than refracting the whole
surface. Normals are analytic central differences, so the pass is portable to
web and correct at corners. Culls on a conservative bound before evaluating
the real SDF."
```

---

### Task 10: The shader library

`flutter_shaders`' `ShaderBuilder` has **no `dispose()`** and creates a fresh `FragmentShader` per state, so upstream leaks one shader per glass widget on unmount. It also has no precache, which is why upstream's first glass frame flashes.

**Files:**
- Create: `packages/glass_forge/lib/src/shaders/shader_library.dart`
- Test: `packages/glass_forge/test/src/shaders/shader_library_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `class ShaderLibrary` with `static ShaderLibrary get instance`, `Future<void> warmUp()`, `ui.FragmentShader acquire(GlassShaderId id)`, `void release(ui.FragmentShader shader)`, `bool get isReady`, `void disposeAll()`. `enum GlassShaderId { geometry, finalRender, probe }`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(ShaderLibrary.instance.disposeAll);

  test('is not ready before warm-up', () {
    expect(ShaderLibrary.instance.isReady, isFalse);
  });

  test('acquiring before warm-up throws a directive, not a null error', () {
    // Upstream returns the bare child until its shaders load, so glass
    // children are simply invisible for the first frames and nobody can tell
    // why. Fail loudly instead.
    expect(
      () => ShaderLibrary.instance.acquire(GlassShaderId.geometry),
      throwsA(isA<StateError>()),
    );
  });

  test('warm-up is idempotent', () async {
    await ShaderLibrary.instance.warmUp();
    await ShaderLibrary.instance.warmUp();
    expect(ShaderLibrary.instance.isReady, isTrue);
  });

  test('released shaders are reused rather than reallocated', () async {
    await ShaderLibrary.instance.warmUp();
    final first = ShaderLibrary.instance.acquire(GlassShaderId.geometry);
    ShaderLibrary.instance.release(first);
    final second = ShaderLibrary.instance.acquire(GlassShaderId.geometry);
    expect(identical(first, second), isTrue);
  });

  test('disposeAll leaves nothing outstanding', () async {
    await ShaderLibrary.instance.warmUp();
    ShaderLibrary.instance.acquire(GlassShaderId.geometry);
    ShaderLibrary.instance.disposeAll();
    expect(ShaderLibrary.instance.isReady, isFalse);
    expect(ShaderLibrary.instance.debugOutstandingCount, 0);
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `cd packages/glass_forge && flutter test test/src/shaders/shader_library_test.dart`
Expected: FAIL — `shader_library.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// The shaders this package ships.
enum GlassShaderId {
  /// Bakes shape geometry into the matte.
  geometry('packages/glass_forge/shaders/geometry.frag'),

  /// Samples the matte and the backdrop to produce the final glass.
  finalRender('packages/glass_forge/shaders/final_render.frag'),

  /// Reports the render backend and uniform capacity.
  probe('packages/glass_forge/shaders/probe.frag');

  const GlassShaderId(this.assetKey);

  /// The asset key this shader loads from.
  final String assetKey;
}

/// Owns every `FragmentProgram` this package uses, and pools their shaders.
///
/// Exists because `flutter_shaders`' `ShaderBuilder` has no `dispose()` and
/// allocates a fresh `FragmentShader` per state — upstream therefore leaks one
/// shader per glass widget, and because an ungrouped shape silently creates
/// its own group, that is one leak per widget.
///
/// Warming up matters as much as pooling. Custom fragment programs compile at
/// load on Impeller, and pipeline *variants* — a different blend mode, sample
/// count or attachment format — compile **synchronously on first draw**. That
/// is the first-frame jank. [warmUp] pays it offscreen.
class ShaderLibrary {
  ShaderLibrary._();

  /// The shared instance.
  static final ShaderLibrary instance = ShaderLibrary._();

  final Map<GlassShaderId, ui.FragmentProgram> _programs = {};
  final Map<GlassShaderId, List<ui.FragmentShader>> _pool = {};
  final Map<ui.FragmentShader, GlassShaderId> _outstanding = {};
  Future<void>? _warmUp;

  /// Whether the shaders are loaded and safe to [acquire].
  bool get isReady => _programs.length == GlassShaderId.values.length;

  /// How many shaders are checked out. Test-only.
  @visibleForTesting
  int get debugOutstandingCount => _outstanding.length;

  /// Loads every shader. Safe to call repeatedly; the work happens once.
  Future<void> warmUp() => _warmUp ??= _loadAll();

  Future<void> _loadAll() async {
    for (final id in GlassShaderId.values) {
      _programs[id] = await ui.FragmentProgram.fromAsset(id.assetKey);
    }
  }

  /// Checks out a shader for [id].
  ///
  /// Throws if called before [warmUp] completes, deliberately. Rendering
  /// nothing until shaders load is how upstream ends up with invisible glass
  /// children and no explanation.
  ui.FragmentShader acquire(GlassShaderId id) {
    final program = _programs[id];
    if (program == null) {
      throw StateError(
        'ShaderLibrary.acquire($id) before warmUp() completed. Await '
        'ShaderLibrary.instance.warmUp() during app startup.',
      );
    }
    final pooled = _pool[id];
    final shader = (pooled != null && pooled.isNotEmpty)
        ? pooled.removeLast()
        : program.fragmentShader();
    _outstanding[shader] = id;
    return shader;
  }

  /// Returns a shader to the pool.
  void release(ui.FragmentShader shader) {
    final id = _outstanding.remove(shader);
    if (id == null) {
      return;
    }
    (_pool[id] ??= <ui.FragmentShader>[]).add(shader);
  }

  /// Disposes everything. Call from tests, and on isolate teardown.
  void disposeAll() {
    for (final shaders in _pool.values) {
      for (final shader in shaders) {
        shader.dispose();
      }
    }
    for (final shader in _outstanding.keys) {
      shader.dispose();
    }
    _pool.clear();
    _outstanding.clear();
    _programs.clear();
    _warmUp = null;
  }
}
```

- [ ] **Step 4: Run the tests**

Run: `cd packages/glass_forge && flutter test test/src/shaders/shader_library_test.dart`
Expected: PASS. Note `warmUp` needs the shader assets to resolve; if `fromAsset` throws in the test environment, confirm the `shaders:` block in `pubspec.yaml` lists all three files.

- [ ] **Step 5: Commit**

```bash
git add packages/glass_forge/lib/src/shaders packages/glass_forge/test/src/shaders/shader_library_test.dart
git commit -m "feat: own the shader lifecycle instead of leaking it

Pools and disposes FragmentShaders, and fails loudly when acquired before
warm-up. flutter_shaders' ShaderBuilder has no dispose and allocates per
state, which costs upstream one leaked shader per glass widget; it also has no
precache, which is why upstream's first glass frame flashes."
```

---

### Task 11: Matte generations and the runtime producer

**Never mutate a texture the compositor may still read.** Upstream did, and an expanding pill corrupted 1,760 and 3,870 pixels of stationary siblings because an older frame was still sampling the matte it overwrote.

**Files:**
- Create: `packages/glass_forge/lib/src/geometry/matte_generation.dart`
- Create: `packages/glass_forge/lib/src/geometry/geometry_producer.dart`
- Create: `packages/glass_forge/lib/src/geometry/runtime_geometry_producer.dart`
- Create: `packages/glass_forge/lib/src/geometry/null_geometry_producer.dart`
- Create: `packages/glass_forge/lib/src/geometry/producer_registry.dart`
- Test: `packages/glass_forge/test/src/geometry/runtime_geometry_producer_test.dart`

**Interfaces:**
- Consumes: `GlassScene` (Task 6), `MatteCodec` (Task 5), `ShaderLibrary` (Task 10), `expandToPixelBuckets` (Task 4), `kMaxShapes` (Task 1)
- Produces: `class MatteGeneration { ui.Image texture; Rect bounds; int sceneRevision; MatteCodec codec; }`; `abstract interface class GeometryProducer`; `class GeometryCapabilities { bool available; String name; }`; `MatteRequest`; `RuntimeGeometryProducer`; `NullGeometryProducer`; `ProducerRegistry.select({required GeometryTier tier})`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/runtime_geometry_producer.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

GlassScene _sceneWithOneShape() {
  return GlassScene()
    ..register(
      'a',
      ShapeGeometry.resolve(
        shape: const GlassRoundedRectangle(
          radius: BorderRadius.all(Radius.circular(8)),
        ),
        size: const Size(100, 40),
        toLayer: Matrix4.identity(),
        devicePixelRatio: 1,
      ),
    );
}

const _request = MatteRequest(
  devicePixelRatio: 1,
  maxDisplacement: 32,
  edgeRefraction: 27.42,
  refractionSpread: 0,
  antialiasWidth: 0.5,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  test('produces a generation stamped with the scene revision', () {
    final producer = RuntimeGeometryProducer();
    final scene = _sceneWithOneShape();

    final generation = producer.produce(scene, _request)!;
    expect(generation.sceneRevision, scene.revision);

    producer.release(generation);
    producer.dispose();
  });

  test('never hands back the same texture twice', () {
    // The invariant: a new generation per change, because a submitted scene
    // may still be sampling the previous one.
    final producer = RuntimeGeometryProducer();
    final scene = _sceneWithOneShape();

    final first = producer.produce(scene, _request)!;
    scene.register(
      'b',
      ShapeGeometry.resolve(
        shape: const GlassOval(),
        size: const Size(20, 20),
        toLayer: Matrix4.translationValues(60, 0, 0),
        devicePixelRatio: 1,
      ),
    );
    final second = producer.produce(scene, _request)!;

    expect(identical(first.texture, second.texture), isFalse);

    producer..release(first)..release(second)..dispose();
  });

  test('returns null for an empty scene rather than a zero-size texture', () {
    // toImageSync on zero-size bounds crashes; upstream issues #149 and #131
    // are both that crash, reported from production.
    final producer = RuntimeGeometryProducer();
    expect(producer.produce(GlassScene(), _request), isNull);
    producer.dispose();
  });

  test('buckets its texture allocation', () {
    final producer = RuntimeGeometryProducer();
    final generation = producer.produce(_sceneWithOneShape(), _request)!;

    expect(generation.texture.width % 64, 0);
    expect(generation.texture.height % 64, 0);

    producer..release(generation)..dispose();
  });

  test('reports itself available', () {
    final producer = RuntimeGeometryProducer();
    expect(producer.capabilities.available, isTrue);
    producer.dispose();
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `cd packages/glass_forge && flutter test test/src/geometry/runtime_geometry_producer_test.dart`
Expected: FAIL — URIs do not exist.

- [ ] **Step 3: Write `matte_generation.dart`**

```dart
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/geometry/matte_codec.dart';

/// An immutable baked matte.
///
/// Generations are never overwritten in place. A frame that has been submitted
/// to the compositor may still sample the texture it was built with, so a
/// geometry change allocates a new generation and the old one is released only
/// once nothing can reference it. Upstream mutates instead, and an expanding
/// shape visibly corrupts its stationary neighbours.
@immutable
class MatteGeneration {
  /// Creates a generation.
  const MatteGeneration({
    required this.texture,
    required this.bounds,
    required this.sceneRevision,
    required this.codec,
  });

  /// The baked matte.
  final ui.Image texture;

  /// The region [texture] covers, in **layer-local physical pixels**.
  ///
  /// Layer-local, never screen space: baking an ancestor transform in here
  /// would apply its scale once in the matte and again during compositing.
  final Rect bounds;

  /// The scene revision this was baked from.
  final int sceneRevision;

  /// How to read the channels back.
  final MatteCodec codec;

  /// A copy shifted by [delta], reusing the same texture.
  ///
  /// Used when every shape moved by the same amount: the pixels are still
  /// correct, only their placement changed.
  MatteGeneration translated(Offset delta) => MatteGeneration(
        texture: texture,
        bounds: bounds.shift(delta),
        sceneRevision: sceneRevision,
        codec: codec,
      );
}
```

- [ ] **Step 4: Write `geometry_producer.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';

/// What a producer can do on this device.
@immutable
class GeometryCapabilities {
  /// Creates a capability report.
  const GeometryCapabilities({required this.available, required this.name});

  /// Whether this producer can run here at all.
  ///
  /// False is a normal answer, not an error: Flutter GPU is unavailable on
  /// Skia, on older Flutter, and when its shader bundle did not build. The
  /// registry falls through to the next producer and the caller never knows.
  final bool available;

  /// A short name for diagnostics.
  final String name;
}

/// Everything a producer needs that is not the scene itself.
@immutable
class MatteRequest {
  /// Creates a request.
  const MatteRequest({
    required this.devicePixelRatio,
    required this.maxDisplacement,
    required this.edgeRefraction,
    required this.refractionSpread,
    required this.antialiasWidth,
  });

  /// Physical pixels per logical pixel.
  final double devicePixelRatio;

  /// The displacement range the codec covers, in physical pixels.
  final double maxDisplacement;

  /// Peak edge displacement, in physical pixels.
  final double edgeRefraction;

  /// How far the band reaches inward. 0 is a tight edge band.
  final double refractionSpread;

  /// Half-width of the coverage ramp, in physical pixels.
  ///
  /// Computed from the transform basis rather than `fwidth`, which is
  /// unavailable in runtime effects even on Impeller.
  final double antialiasWidth;
}

/// Bakes a scene into a matte.
abstract interface class GeometryProducer {
  /// What this producer can do here.
  GeometryCapabilities get capabilities;

  /// Loads whatever this producer needs before its first [produce].
  Future<void> warmUp();

  /// Bakes [scene]. Returns null when there is nothing to bake.
  MatteGeneration? produce(GlassScene scene, MatteRequest request);

  /// Releases a generation this producer created.
  void release(MatteGeneration generation);

  /// Releases everything.
  void dispose();
}
```

- [ ] **Step 5: Write `runtime_geometry_producer.dart`**

```dart
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/composition/pixel_buckets.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_codec.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/shape_limits.dart';

/// Bakes the matte with a runtime-effect fragment shader.
///
/// Works on every backend that supports `FragmentProgram`, which is all of
/// them. Slower than the Flutter GPU path because the result round-trips
/// through `toImageSync`, whose display list is retained until the image is
/// disposed (flutter#138627) — hence the release discipline below.
class RuntimeGeometryProducer implements GeometryProducer {
  final List<ui.Image> _live = <ui.Image>[];

  @override
  GeometryCapabilities get capabilities =>
      const GeometryCapabilities(available: true, name: 'runtime-effect');

  @override
  Future<void> warmUp() => ShaderLibrary.instance.warmUp();

  @override
  MatteGeneration? produce(GlassScene scene, MatteRequest request) {
    if (scene.shapes.isEmpty) {
      return null;
    }

    final padded = scene.bounds(padding: request.antialiasWidth);
    if (padded.isEmpty || !padded.isFinite) {
      // Zero-size or non-finite bounds crash toImageSync. Upstream #149 and
      // #131 are both this crash, reported from production.
      return null;
    }

    final allocation = expandToPixelBuckets(padded);
    final width = allocation.width.round();
    final height = allocation.height.round();
    if (width <= 0 || height <= 0) {
      return null;
    }

    final shader = ShaderLibrary.instance.acquire(GlassShaderId.geometry);
    try {
      _setUniforms(shader, scene, request, allocation);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..translate(-allocation.left, -allocation.top)
        ..drawRect(allocation, Paint()..shader = shader);
      final picture = recorder.endRecording();
      try {
        final texture = picture.toImageSync(width, height);
        _live.add(texture);
        return MatteGeneration(
          texture: texture,
          bounds: allocation,
          sceneRevision: scene.revision,
          codec: MatteCodec(maxDisplacement: request.maxDisplacement),
        );
      } finally {
        picture.dispose();
      }
    } finally {
      ShaderLibrary.instance.release(shader);
    }
  }

  void _setUniforms(
    ui.FragmentShader shader,
    GlassScene scene,
    MatteRequest request,
    Rect allocation,
  ) {
    var i = 0;
    // uSize is index 0-1, written by the engine for filter shaders. For a
    // Paint.shader we set it ourselves.
    shader
      ..setFloat(i++, allocation.width)
      ..setFloat(i++, allocation.height)
      ..setFloat(i++, request.maxDisplacement)
      ..setFloat(i++, request.edgeRefraction)
      ..setFloat(i++, request.refractionSpread)
      ..setFloat(i++, request.antialiasWidth);

    final shapes = scene.shapes;
    for (var s = 0; s < kMaxShapes; s++) {
      if (s < shapes.length) {
        final g = shapes[s];
        shader
          ..setFloat(i++, g.origin.dx - allocation.left)
          ..setFloat(i++, g.origin.dy - allocation.top)
          ..setFloat(i++, g.halfExtent.width)
          ..setFloat(i++, g.halfExtent.height)
          ..setFloat(i++, g.inverseBasis[0])
          ..setFloat(i++, g.inverseBasis[1])
          ..setFloat(i++, g.inverseBasis[2])
          ..setFloat(i++, g.inverseBasis[3])
          ..setFloat(i++, g.type.sdfCode.toDouble())
          ..setFloat(i++, g.radius)
          ..setFloat(i++, g.distanceScale)
          ..setFloat(i++, g.blendMarker);
      } else {
        // Unused slots must still be written: an unwritten uniform is
        // undefined, and Impeller has rejected draws over default-valued
        // uniforms before (upstream #39).
        for (var pad = 0; pad < 12; pad++) {
          shader.setFloat(i++, 0);
        }
      }
    }
    shader.setFloat(
      i++,
      shapes.length.clamp(0, kMaxShapes).toDouble(),
    );
  }

  @override
  void release(MatteGeneration generation) {
    if (_live.remove(generation.texture)) {
      generation.texture.dispose();
    }
  }

  @override
  void dispose() {
    for (final texture in _live) {
      texture.dispose();
    }
    _live.clear();
  }
}
```

- [ ] **Step 6: Write `null_geometry_producer.dart` and `producer_registry.dart`**

```dart
// null_geometry_producer.dart
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';

/// Bakes nothing.
///
/// The cheapest tiers do not refract at all — they render a translucent fill
/// with a border. This is also the correct producer when the user has asked
/// to reduce transparency.
class NullGeometryProducer implements GeometryProducer {
  @override
  GeometryCapabilities get capabilities =>
      const GeometryCapabilities(available: true, name: 'none');

  @override
  Future<void> warmUp() async {}

  @override
  MatteGeneration? produce(GlassScene scene, MatteRequest request) => null;

  @override
  void release(MatteGeneration generation) {}

  @override
  void dispose() {}
}
```

```dart
// producer_registry.dart
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/null_geometry_producer.dart';
import 'package:glass_forge/src/geometry/runtime_geometry_producer.dart';

/// How much geometry work a tier permits.
enum GeometryTier {
  /// Prefer the fastest available producer.
  accelerated,

  /// Use the portable runtime-effect producer.
  portable,

  /// Do not bake a matte at all.
  none,
}

/// Picks a producer for a tier, skipping any that cannot run here.
///
/// Selection is a runtime decision, not a compile-time one: a device under
/// thermal pressure can drop from accelerated to portable to none between
/// frames without the widget tree noticing.
abstract final class ProducerRegistry {
  static final List<GeometryProducer Function()> _accelerated =
      <GeometryProducer Function()>[];

  /// Registers an accelerated producer factory.
  ///
  /// The Flutter GPU producer registers itself here when it can initialise.
  static void registerAccelerated(GeometryProducer Function() factory) {
    _accelerated.add(factory);
  }

  /// Creates a producer for [tier].
  static GeometryProducer select({required GeometryTier tier}) {
    switch (tier) {
      case GeometryTier.none:
        return NullGeometryProducer();
      case GeometryTier.accelerated:
        for (final factory in _accelerated) {
          final candidate = factory();
          if (candidate.capabilities.available) {
            return candidate;
          }
          candidate.dispose();
        }
        return RuntimeGeometryProducer();
      case GeometryTier.portable:
        return RuntimeGeometryProducer();
    }
  }

  /// Clears registrations. Test-only.
  static void debugReset() => _accelerated.clear();
}
```

- [ ] **Step 7: Run the tests**

Run: `cd packages/glass_forge && flutter test test/src/geometry/`
Expected: PASS

- [ ] **Step 8: Verify the analyzer is clean**

Run: `flutter analyze packages/glass_forge`
Expected: `No issues found!`

- [ ] **Step 9: Commit**

```bash
git add packages/glass_forge/lib/src/geometry packages/glass_forge/test/src/geometry
git commit -m "feat: bake mattes as immutable generations

A geometry change allocates a new texture rather than overwriting one a
submitted frame may still be sampling — upstream's in-place mutation visibly
corrupts stationary neighbours when a grouped shape expands. Guards the
zero-size and non-finite bounds that crash toImageSync in production, and
writes every uniform slot including unused ones."
```

---

### Task 12: The filter snapshot

**The engine copies a shader's uniforms into the native image filter when that filter is first converted.** So a filter wrapping a shader may only be reused while the values it captured are still current. Upstream rebuilds `ImageFilter.shader(...)` on every paint instead — and that rebuild is what made it impossible to put ancestor translation into uniforms, because a new filter every frame trips flutter#138627.

**Files:**
- Create: `packages/glass_forge/lib/src/composition/filter_snapshot.dart`
- Test: `packages/glass_forge/test/src/composition/filter_snapshot_test.dart`

**Interfaces:**
- Consumes: `MatteGeneration` (Task 11)
- Produces: `class FilterSnapshot` with `==`/`hashCode` and `FilterSnapshot.of({required MatteGeneration? matte, required double devicePixelRatio, required int materialRevision, required Float32List coordinateMapping})`.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/composition/filter_snapshot.dart';

Float32List _mapping([double tx = 0]) =>
    Float32List.fromList(<double>[1, 0, 0, 1, tx, 0]);

void main() {
  test('equal inputs compare equal so the filter can be reused', () {
    final a = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
    );
    final b = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('a changed coordinate mapping invalidates the filter', () {
    // This is the whole reason the snapshot exists: the mapping lives in
    // uniforms the engine already copied, so reusing the filter after it
    // changes renders the previous frame's geometry.
    final a = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
    );
    final b = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(12),
    );
    expect(a, isNot(b));
  });

  test('a changed material revision invalidates the filter', () {
    final a = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
    );
    final b = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 2,
      coordinateMapping: _mapping(),
    );
    expect(a, isNot(b));
  });

  test('a changed device pixel ratio invalidates the filter', () {
    final a = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 2,
      materialRevision: 1,
      coordinateMapping: _mapping(),
    );
    final b = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
    );
    expect(a, isNot(b));
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `cd packages/glass_forge && flutter test test/src/composition/filter_snapshot_test.dart`
Expected: FAIL — `filter_snapshot.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';

/// Everything the engine copies into a native `ImageFilter` when it first
/// converts one.
///
/// A shader's uniforms are copied at conversion time, not read live, so a
/// cached filter is only valid while these values are unchanged. Compare
/// snapshots before rebuilding: upstream rebuilds the filter every paint,
/// which is both wasteful and the reason it cannot carry ancestor translation
/// in uniforms without tripping flutter#138627.
@immutable
class FilterSnapshot {
  /// Creates a snapshot.
  const FilterSnapshot({
    required this.texture,
    required this.matteBounds,
    required this.devicePixelRatio,
    required this.materialRevision,
    required this.coordinateMapping,
  });

  /// Captures the current state.
  factory FilterSnapshot.of({
    required MatteGeneration? matte,
    required double devicePixelRatio,
    required int materialRevision,
    required Float32List coordinateMapping,
  }) {
    return FilterSnapshot(
      texture: matte?.texture,
      matteBounds: matte?.bounds,
      devicePixelRatio: devicePixelRatio,
      materialRevision: materialRevision,
      coordinateMapping: Float32List.fromList(coordinateMapping),
    );
  }

  /// The matte texture bound as a sampler, if any.
  final ui.Image? texture;

  /// Where that matte sits, in layer-local physical pixels.
  final Rect? matteBounds;

  /// Physical pixels per logical pixel.
  final double devicePixelRatio;

  /// Bumped whenever the material's uniforms change.
  final int materialRevision;

  /// The affine that maps `FlutterFragCoord` into matte space: `[a,b,c,d,tx,ty]`.
  final Float32List coordinateMapping;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is FilterSnapshot &&
        identical(other.texture, texture) &&
        other.matteBounds == matteBounds &&
        other.devicePixelRatio == devicePixelRatio &&
        other.materialRevision == materialRevision &&
        _sameMapping(other.coordinateMapping, coordinateMapping);
  }

  @override
  int get hashCode => Object.hash(
        texture,
        matteBounds,
        devicePixelRatio,
        materialRevision,
        Object.hashAll(coordinateMapping),
      );

  static bool _sameMapping(Float32List a, Float32List b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
```

- [ ] **Step 4: Run the tests**

Run: `cd packages/glass_forge && flutter test test/src/composition/filter_snapshot_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add packages/glass_forge/lib/src/composition/filter_snapshot.dart \
        packages/glass_forge/test/src/composition/filter_snapshot_test.dart
git commit -m "feat: key native ImageFilter reuse on a uniform snapshot

The engine copies shader uniforms into the native filter at first conversion,
so a cached filter is valid only while those values hold. Comparing a snapshot
lets the filter survive frames that changed nothing."
```

---

### Task 13: The composition pass

One `BackdropFilterLayer`. Never two. Stacking a shader filter above another backdrop filter makes the upper one read a **stale previous-frame backdrop including its own output** on physical iPhones (flutter#187820) — a progressive white-wash. Upstream's architecture is exactly two stacked filters.

**Files:**
- Create: `packages/glass_forge/shaders/final_render.frag`
- Create: `packages/glass_forge/lib/src/composition/glass_composition.dart`
- Test: `packages/glass_forge/test/src/composition/glass_composition_test.dart`

**Interfaces:**
- Consumes: `FilterSnapshot` (Task 12), `MatteGeneration` (Task 11), `ShaderLibrary` (Task 10), `GlassMaterial` (Task 14 — define the fields it needs here and implement in 14; the two land together)
- Produces: `class GlassComposition` with `ui.ImageFilter? build({required MatteGeneration? matte, required GlassMaterial material, required FilterSnapshot snapshot, required double devicePixelRatio})` and `int get debugFilterBuildCount`.

- [ ] **Step 1: Write `final_render.frag`**

```glsl
#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// The engine overwrites uSize with the input texture size and binds
// uBackdrop as sampler 0. Both are required by ImageFilter.shader.
uniform vec2 uSize;
uniform vec4 uMatteRect;      // origin.xy, size.xy in filter space
uniform vec4 uOptical;        // maxDisplacement, chromaticAberration, tintA, saturation
uniform vec4 uTint;           // rgb, variant (0 regular, 1 clear)
uniform vec4 uLighting;       // highlight, angleX, angleY, contour
uniform vec4 uMapBasis;       // a, b, c, d
uniform vec2 uMapOffset;      // tx, ty
uniform sampler2D uBackdrop;
uniform sampler2D uMatte;

out vec4 fragColor;

#include "common/codec.glsl"

// Only mirror samples that leave the texture. Clamping everywhere washes out
// Metal; leaving it alone gives GLES a black decal border.
vec2 gfMirrorUV(vec2 uv) {
    vec2 m = mod(abs(uv), 2.0);
    return mix(m, 2.0 - m, step(1.0, m));
}

void main() {
    vec2 frag = FlutterFragCoord().xy;

    // Ancestor motion is compositor-only: this affine maps the filter's
    // coordinate space into the layer-local matte rather than re-baking it.
    vec2 matteSpace = vec2(
        uMapBasis.x * frag.x + uMapBasis.y * frag.y,
        uMapBasis.z * frag.x + uMapBasis.w * frag.y
    ) + uMapOffset;

    vec2 matteUV = (matteSpace - uMatteRect.xy) / max(uMatteRect.zw, vec2(1.0));
    vec4 encoded = texture(uMatte, matteUV);

    float coverage = encoded.a > 0.0 ? 1.0 : 0.0;
    if (matteUV.x < 0.0 || matteUV.x > 1.0 ||
        matteUV.y < 0.0 || matteUV.y > 1.0 || coverage == 0.0) {
        fragColor = texture(uBackdrop, frag / uSize);
        return;
    }

    vec2 normal = vec2(gfDecodeSigned(encoded.r), gfDecodeSigned(encoded.g));
    float magnitude = gfDecodeCompanded(encoded.a) * uOptical.x;
    vec2 displacement = normal * -magnitude;

    vec2 baseUV = frag / uSize;
    vec2 offsetUV = (frag + displacement) / uSize;

    vec3 refracted;
    // Threshold in PIXELS, not in unit-free aberration. Upstream compares the
    // raw setting against 0.01 while defaulting to exactly 0.01, so every
    // default install pays three taps for an invisible half-percent effect.
    if (abs(uOptical.y) * uOptical.x > 0.25) {
        float spread = uOptical.y * 0.5;
        vec2 rUV = (frag + displacement * (1.0 + spread)) / uSize;
        vec2 bUV = (frag + displacement * (1.0 - spread)) / uSize;
        refracted = vec3(
            texture(uBackdrop, gfMirrorUV(rUV)).r,
            texture(uBackdrop, gfMirrorUV(offsetUV)).g,
            texture(uBackdrop, gfMirrorUV(bUV)).b
        );
    } else {
        refracted = texture(uBackdrop, gfMirrorUV(offsetUV)).rgb;
    }

    // Saturation, on Rec.709 luma.
    float luma = dot(refracted, vec3(0.2126, 0.7152, 0.0722));
    refracted = mix(vec3(luma), refracted, uOptical.w);

    // Tint. A clear variant takes a dark scrim on bright backdrops instead of
    // adapting, which is what Apple specifies.
    if (uTint.w > 0.5) {
        refracted = mix(refracted, vec3(0.0), 0.35 * step(0.5, luma));
    } else {
        refracted = mix(refracted, uTint.rgb, uOptical.z);
    }

    // Two opposing rim highlights. The colour is incident white rather than
    // the refracted backdrop: deriving it from the backdrop is what gives
    // upstream its cyan/green fringing.
    vec2 lightDir = normalize(vec2(uLighting.y, uLighting.z));
    float facing = dot(normal, lightDir);
    float rim = max(0.0, facing) + 0.8 * max(0.0, -facing);

    // Guard on luminance so a truly black surface does not flicker at the rim.
    float guard = pow(max(luma, 0.0), 0.25);
    refracted += vec3(rim * uLighting.x * guard * 0.35);

    fragColor = vec4(refracted, 1.0);
}
```

- [ ] **Step 2: Write the failing test**

```dart
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/composition/filter_snapshot.dart';
import 'package:glass_forge/src/composition/glass_composition.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

Float32List _mapping([double tx = 0]) =>
    Float32List.fromList(<double>[1, 0, 0, 1, tx, 0]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  test('builds a single composed filter, never a stack', () {
    final composition = GlassComposition();
    final filter = composition.build(
      matte: null,
      material: const GlassMaterial(),
      snapshot: FilterSnapshot.of(
        matte: null,
        devicePixelRatio: 1,
        materialRevision: 0,
        coordinateMapping: _mapping(),
      ),
      devicePixelRatio: 1,
    );
    expect(filter, isNotNull);
    expect(composition.debugFilterBuildCount, 1);
    composition.dispose();
  });

  test('reuses the filter when the snapshot is unchanged', () {
    final composition = GlassComposition();
    const material = GlassMaterial();
    FilterSnapshot snapshot() => FilterSnapshot.of(
          matte: null,
          devicePixelRatio: 1,
          materialRevision: 0,
          coordinateMapping: _mapping(),
        );

    composition.build(
      matte: null,
      material: material,
      snapshot: snapshot(),
      devicePixelRatio: 1,
    );
    composition.build(
      matte: null,
      material: material,
      snapshot: snapshot(),
      devicePixelRatio: 1,
    );

    expect(composition.debugFilterBuildCount, 1);
    composition.dispose();
  });

  test('rebuilds when the coordinate mapping changes', () {
    final composition = GlassComposition();
    const material = GlassMaterial();

    composition.build(
      matte: null,
      material: material,
      snapshot: FilterSnapshot.of(
        matte: null,
        devicePixelRatio: 1,
        materialRevision: 0,
        coordinateMapping: _mapping(),
      ),
      devicePixelRatio: 1,
    );
    composition.build(
      matte: null,
      material: material,
      snapshot: FilterSnapshot.of(
        matte: null,
        devicePixelRatio: 1,
        materialRevision: 0,
        coordinateMapping: _mapping(9),
      ),
      devicePixelRatio: 1,
    );

    expect(composition.debugFilterBuildCount, 2);
    composition.dispose();
  });

  test('returns null when the material renders nothing', () {
    // No filter pushed at all, so an idle layer costs no backdrop pass.
    // Upstream pushes a full backdrop even at blur 0.
    final composition = GlassComposition();
    final filter = composition.build(
      matte: null,
      material: const GlassMaterial(
        frost: 0,
        edgeRefraction: 0,
        tintOpacity: 0,
        highlight: 0,
      ),
      snapshot: FilterSnapshot.of(
        matte: null,
        devicePixelRatio: 1,
        materialRevision: 0,
        coordinateMapping: _mapping(),
      ),
      devicePixelRatio: 1,
    );
    expect(filter, isNull);
    composition.dispose();
  });
}
```

- [ ] **Step 3: Run it to make sure it fails**

Run: `cd packages/glass_forge && flutter test test/src/composition/glass_composition_test.dart`
Expected: FAIL — `glass_composition.dart` and `glass_material.dart` do not exist.

- [ ] **Step 4: Write the implementation**

```dart
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:glass_forge/src/composition/filter_snapshot.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

/// Builds the single image filter a glass layer paints through.
///
/// Exactly one `BackdropFilter` per layer. Blur and the glass shader compose
/// into one filter rather than stacking: a shader filter above another
/// backdrop filter reads a stale previous-frame backdrop — including its own
/// output — on physical iPhones (flutter#187820), which is a progressive
/// white-wash. Upstream stacks two, so it is exposed to exactly this.
class GlassComposition {
  ui.ImageFilter? _filter;
  ui.FragmentShader? _shader;
  FilterSnapshot? _snapshot;
  int _buildCount = 0;

  /// How many native filters have been built. Test-only.
  @visibleForTesting
  int get debugFilterBuildCount => _buildCount;

  /// Returns the filter for this frame, or null if nothing should be painted.
  ui.ImageFilter? build({
    required MatteGeneration? matte,
    required GlassMaterial material,
    required FilterSnapshot snapshot,
    required double devicePixelRatio,
  }) {
    if (!material.rendersAnything) {
      return null;
    }
    if (_filter != null && _snapshot == snapshot) {
      return _filter;
    }

    final shader = _shader ??=
        ShaderLibrary.instance.acquire(GlassShaderId.finalRender);
    _writeUniforms(shader, matte, material, snapshot, devicePixelRatio);

    final glass = ui.ImageFilter.shader(shader);
    final frost = material.frost * devicePixelRatio;
    _filter = frost <= 0
        ? glass
        : ui.ImageFilter.compose(
            inner: ui.ImageFilter.blur(
              sigmaX: frost,
              sigmaY: frost,
              tileMode: TileMode.mirror,
            ),
            outer: glass,
          );
    _snapshot = snapshot;
    _buildCount++;
    return _filter;
  }

  void _writeUniforms(
    ui.FragmentShader shader,
    MatteGeneration? matte,
    GlassMaterial material,
    FilterSnapshot snapshot,
    double devicePixelRatio,
  ) {
    final bounds = matte?.bounds ?? Rect.zero;
    final tint = material.tint;
    var i = 2; // 0 and 1 are uSize, written by the engine.
    shader
      ..setFloat(i++, bounds.left)
      ..setFloat(i++, bounds.top)
      ..setFloat(i++, bounds.width)
      ..setFloat(i++, bounds.height)
      ..setFloat(i++, material.maxDisplacement * devicePixelRatio)
      ..setFloat(i++, material.chromaticAberration)
      ..setFloat(i++, material.tintOpacity)
      ..setFloat(i++, material.saturation)
      ..setFloat(i++, tint.r)
      ..setFloat(i++, tint.g)
      ..setFloat(i++, tint.b)
      ..setFloat(i++, material.variant == GlassVariant.clear ? 1 : 0)
      ..setFloat(i++, material.highlight)
      ..setFloat(i++, material.lightDirection.dx)
      ..setFloat(i++, material.lightDirection.dy)
      ..setFloat(i++, material.contour)
      ..setFloat(i++, snapshot.coordinateMapping[0])
      ..setFloat(i++, snapshot.coordinateMapping[1])
      ..setFloat(i++, snapshot.coordinateMapping[2])
      ..setFloat(i++, snapshot.coordinateMapping[3])
      ..setFloat(i++, snapshot.coordinateMapping[4])
      ..setFloat(i++, snapshot.coordinateMapping[5]);

    if (matte != null) {
      shader.setImageSampler(1, matte.texture);
    }
  }

  /// Releases the shader and drops the cached filter.
  void dispose() {
    final shader = _shader;
    if (shader != null) {
      ShaderLibrary.instance.release(shader);
    }
    _shader = null;
    _filter = null;
    _snapshot = null;
  }
}
```

- [ ] **Step 5: Run the tests**

Run: `cd packages/glass_forge && flutter test test/src/composition/`
Expected: PASS, once Task 14's `GlassMaterial` exists. If you are executing strictly in order, write `glass_material.dart` first — the two tasks are adjacent for this reason.

- [ ] **Step 6: Commit**

```bash
git add packages/glass_forge/shaders/final_render.frag \
        packages/glass_forge/lib/src/composition/glass_composition.dart \
        packages/glass_forge/test/src/composition/glass_composition_test.dart
git commit -m "feat: compose blur and glass into a single backdrop filter

One BackdropFilter per layer, never two. Stacking a shader filter above
another backdrop filter makes the upper one sample a stale previous-frame
backdrop including its own output on physical iPhones (flutter#187820).
Chromatic aberration is gated in pixels rather than the unit-free threshold
upstream's own default fails."
```

---

### Task 14: The material and its Apple-fitted presets

**Files:**
- Create: `packages/glass_forge/lib/src/material/glass_variant.dart`
- Create: `packages/glass_forge/lib/src/material/glass_material.dart`
- Create: `packages/glass_forge/lib/src/material/apple_presets.dart`
- Test: `packages/glass_forge/test/src/material/glass_material_test.dart`

**Interfaces:**
- Consumes: `MatteCodec.displacementRangeFor` (Task 5)
- Produces: `enum GlassVariant { regular, clear }`; `class GlassMaterial` with `variant, thickness, edgeRefraction, refractionSpread, frost, chromaticAberration, tint, tintOpacity, saturation, highlight, lightDirection, contour`, plus `bool get rendersAnything`, `double get maxDisplacement`, `int get revision`, `copyWith`, `==`/`hashCode`, and factories `GlassMaterial.regular({Brightness brightness})` / `GlassMaterial.clear({Brightness brightness})`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/material/glass_variant.dart';

void main() {
  test('a material with nothing enabled renders nothing', () {
    // The layer then pushes no backdrop filter at all. Upstream pushes a full
    // backdrop pass even at blur 0.
    const material = GlassMaterial(
      frost: 0,
      edgeRefraction: 0,
      tintOpacity: 0,
      highlight: 0,
    );
    expect(material.rendersAnything, isFalse);
  });

  test('frost alone is enough to render', () {
    expect(
      const GlassMaterial(frost: 5, edgeRefraction: 0, tintOpacity: 0, highlight: 0)
          .rendersAnything,
      isTrue,
    );
  });

  test('displacement range is sized to reachable displacement', () {
    const material = GlassMaterial(edgeRefraction: 27.42);
    expect(material.maxDisplacement, closeTo(28.79, 0.01));
  });

  test('equal materials share a revision so the filter can be reused', () {
    expect(const GlassMaterial().revision, const GlassMaterial().revision);
  });

  test('a changed field changes the revision', () {
    expect(
      const GlassMaterial().revision,
      isNot(const GlassMaterial(frost: 12).revision),
    );
  });

  test('the regular preset uses the fitted iOS 27 geometry', () {
    // Values fitted by upstream's harness against real .buttonStyle(.glass)
    // captures, not eyeballed.
    final material = GlassMaterial.regular(brightness: Brightness.light);
    expect(material.thickness, closeTo(12, 1e-9));
    expect(material.edgeRefraction, closeTo(27.42, 1e-9));
    expect(material.variant, GlassVariant.regular);
  });

  test('the clear preset does not adapt', () {
    // Apple: clear "does not have adaptive behaviors" and takes a dimming
    // layer instead. Mixing the two variants is explicitly called out as
    // wrong, so they must stay distinguishable.
    final clear = GlassMaterial.clear(brightness: Brightness.light);
    expect(clear.variant, GlassVariant.clear);
    expect(clear.tintOpacity, 0);
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `cd packages/glass_forge && flutter test test/src/material/glass_material_test.dart`
Expected: FAIL — URIs do not exist.

- [ ] **Step 3: Write `glass_variant.dart`**

```dart
/// The two materials Apple ships, and the only two worth having.
///
/// Apple is explicit that these "should never be mixed": regular adapts to
/// what is behind it, clear does not and takes a dimming layer instead.
enum GlassVariant {
  /// Adapts luminosity and tint to stay legible over anything.
  regular,

  /// Permanently more transparent, with no adaptive behaviour.
  ///
  /// Only correct over media-rich content, where a dimming layer will not hurt
  /// the content and the foreground is bold and bright.
  clear,
}
```

- [ ] **Step 4: Write `glass_material.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/geometry/matte_codec.dart';
import 'package:glass_forge/src/material/glass_variant.dart';

/// How a glass surface looks.
///
/// Parameters are observable quantities in logical pixels, not physical
/// constants. [edgeRefraction] is how far the edge visibly displaces what is
/// behind it — the refractive index is derived from it, because Apple exposes
/// no index and nobody thinks in them.
@immutable
class GlassMaterial {
  /// Creates a material.
  const GlassMaterial({
    this.variant = GlassVariant.regular,
    this.thickness = 12.0,
    this.edgeRefraction = 27.42,
    this.refractionSpread = 0.0,
    this.frost = 5.0,
    this.chromaticAberration = 0.0,
    this.tint = const Color(0x00FFFFFF),
    this.tintOpacity = 0.0,
    this.saturation = 1.0,
    this.highlight = 1.0,
    this.lightDirection = const Offset(0, 1),
    this.contour = 0.0,
  });

  /// Regular or clear.
  final GlassVariant variant;

  /// Apparent depth of the surface, in logical pixels.
  final double thickness;

  /// Peak edge displacement, in logical pixels.
  ///
  /// The observable knob. The refractive index follows from it:
  /// `ratio = edgeRefraction / (8 * thickness); n = sqrt(1 + ratio^2)`.
  final double edgeRefraction;

  /// How far the refraction band reaches inward. 0 is a tight edge band.
  final double refractionSpread;

  /// Blur sigma applied to the backdrop, in logical pixels.
  final double frost;

  /// Dispersion between colour channels. 0 disables the extra taps entirely.
  final double chromaticAberration;

  /// Tint colour.
  final Color tint;

  /// How strongly [tint] is applied.
  final double tintOpacity;

  /// Backdrop saturation multiplier.
  final double saturation;

  /// Rim highlight strength.
  final double highlight;

  /// Direction the rim light comes from.
  ///
  /// Fed from the accelerometer on phones, where Apple's material responds to
  /// device motion; fixed elsewhere, since macOS has no IMU.
  final Offset lightDirection;

  /// Strength of the darkened edge ring.
  final double contour;

  /// Whether this material would put anything on screen.
  ///
  /// When false the layer pushes no backdrop filter at all, so an idle or
  /// fully-hidden glass surface costs nothing.
  bool get rendersAnything =>
      frost > 0 || edgeRefraction > 0 || tintOpacity > 0 || highlight > 0;

  /// The displacement range the matte codec should cover, in logical pixels.
  double get maxDisplacement =>
      MatteCodec.displacementRangeFor(edgeRefraction);

  /// The derived refractive index.
  double get refractiveIndex {
    final ratio = edgeRefraction / math.max(1e-3, 8 * thickness);
    return math.sqrt(1 + ratio * ratio);
  }

  /// Changes whenever any field changes; used to invalidate cached filters.
  int get revision => hashCode;

  /// Returns a copy with the given fields replaced.
  GlassMaterial copyWith({
    GlassVariant? variant,
    double? thickness,
    double? edgeRefraction,
    double? refractionSpread,
    double? frost,
    double? chromaticAberration,
    Color? tint,
    double? tintOpacity,
    double? saturation,
    double? highlight,
    Offset? lightDirection,
    double? contour,
  }) {
    return GlassMaterial(
      variant: variant ?? this.variant,
      thickness: thickness ?? this.thickness,
      edgeRefraction: edgeRefraction ?? this.edgeRefraction,
      refractionSpread: refractionSpread ?? this.refractionSpread,
      frost: frost ?? this.frost,
      chromaticAberration: chromaticAberration ?? this.chromaticAberration,
      tint: tint ?? this.tint,
      tintOpacity: tintOpacity ?? this.tintOpacity,
      saturation: saturation ?? this.saturation,
      highlight: highlight ?? this.highlight,
      lightDirection: lightDirection ?? this.lightDirection,
      contour: contour ?? this.contour,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassMaterial &&
        other.variant == variant &&
        other.thickness == thickness &&
        other.edgeRefraction == edgeRefraction &&
        other.refractionSpread == refractionSpread &&
        other.frost == frost &&
        other.chromaticAberration == chromaticAberration &&
        other.tint == tint &&
        other.tintOpacity == tintOpacity &&
        other.saturation == saturation &&
        other.highlight == highlight &&
        other.lightDirection == lightDirection &&
        other.contour == contour;
  }

  @override
  int get hashCode => Object.hash(
        variant,
        thickness,
        edgeRefraction,
        refractionSpread,
        frost,
        chromaticAberration,
        tint,
        tintOpacity,
        saturation,
        highlight,
        lightDirection,
        contour,
      );
}
```

- [ ] **Step 5: Write `apple_presets.dart`**

```dart
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/material/glass_variant.dart';

/// Materials fitted to Apple's shipping look.
///
/// The numbers here were fitted against real iOS 27 captures rather than
/// chosen by eye. Change them only with a comparison capture in hand.
extension AppleGlassPresets on GlassMaterial {
  /// The regular material — adapts to what is behind it.
  static GlassMaterial regular({required Brightness brightness}) {
    final dark = brightness == Brightness.dark;
    return GlassMaterial(
      thickness: 12,
      edgeRefraction: 27.42,
      frost: dark ? 5 : 7,
      saturation: dark ? 2.6 : 0.9,
      tint: dark ? const Color(0xFF3A3A3A) : const Color(0xFFFDFCFD),
      tintOpacity: dark ? 0.56 : 0.407,
      highlight: 1,
      contour: 0.08,
    );
  }

  /// The clear material — no adaptation, dimming layer instead.
  static GlassMaterial clear({required Brightness brightness}) {
    return const GlassMaterial(
      variant: GlassVariant.clear,
      thickness: 12,
      edgeRefraction: 27.42,
      frost: 0,
      tintOpacity: 0,
      highlight: 0.25,
      contour: 0.08,
    );
  }
}
```

- [ ] **Step 6: Wire the factories the test expects**

The test calls `GlassMaterial.regular(...)`. Add them as static members on `GlassMaterial` delegating to the extension, so both call shapes work:

```dart
  /// The fitted regular material. See `apple_presets.dart`.
  static GlassMaterial regular({required Brightness brightness}) =>
      AppleGlassPresets.regular(brightness: brightness);

  /// The fitted clear material. See `apple_presets.dart`.
  static GlassMaterial clear({required Brightness brightness}) =>
      AppleGlassPresets.clear(brightness: brightness);
```

- [ ] **Step 7: Run the tests**

Run: `cd packages/glass_forge && flutter test test/src/material/ test/src/composition/`
Expected: PASS — Task 13's composition tests now compile too.

- [ ] **Step 8: Commit**

```bash
git add packages/glass_forge/lib/src/material packages/glass_forge/test/src/material
git commit -m "feat: add the glass material and Apple-fitted presets

Parameterised on observable edge displacement in pixels rather than a
refractive index, because Apple exposes no index and nobody thinks in them.
Reports when it would render nothing, so an idle layer can skip its backdrop
pass entirely."
```

---

### Task 15: Render objects and the public widgets

Children paint **in place**. Never the deferred `paintFromLayer` trick: it is the single root cause of upstream's z-order surprises, first-frame invisibility, broken Hero flights, broken `toImage`, and one-frame refraction lag.

**Files:**
- Create: `packages/glass_forge/lib/src/rendering/render_glass_layer.dart`
- Create: `packages/glass_forge/lib/src/rendering/render_glass_shape.dart`
- Create: `packages/glass_forge/lib/src/widgets/glass_layer.dart`
- Create: `packages/glass_forge/lib/src/widgets/glass.dart`
- Create: `packages/glass_forge/lib/src/widgets/glass_blend_group.dart`
- Modify: `packages/glass_forge/lib/glass_forge.dart` — export the widgets and material
- Test: `packages/glass_forge/test/src/widgets/glass_widgets_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 2–14
- Produces: `GlassLayer({required Widget child, GlassMaterial material, GeometryTier? tier, BackdropKey? backdropKey})`; `Glass({required GlassShape shape, Widget? child, GlassMaterial? material, bool containsChild, Clip clipBehavior})`; `GlassBlendGroup({required Widget child, double blend})`.

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  testWidgets('a glass child paints in place, not deferred', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Center(
            child: Glass(
              shape: const GlassRoundedRectangle(
                radius: BorderRadius.all(Radius.circular(12)),
              ),
              child: const Text('visible'),
            ),
          ),
        ),
      ),
    );

    // Upstream's children are invisible until both shaders load, because its
    // paint() is a no-op and the layer paints them later.
    expect(find.text('visible'), findsOneWidget);
    final box = tester.renderObject<RenderBox>(find.text('visible'));
    expect(box.hasSize, isTrue);
  });

  testWidgets('Glass outside a layer still renders', (tester) async {
    // Upstream asserts in debug and null-crashes in release. Create an
    // implicit layer instead and warn.
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: Glass(
            shape: const GlassOval(),
            child: const Text('orphan'),
          ),
        ),
      ),
    );
    expect(find.text('orphan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('more shapes than the cap degrade, never blank the UI',
      (tester) async {
    // Upstream throws UnsupportedError from inside paint(): a red box in
    // debug, and in release the whole layer plus every child stops painting.
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Stack(
            children: <Widget>[
              for (var i = 0; i < 40; i++)
                Positioned(
                  left: i * 4.0,
                  child: Glass(
                    shape: const GlassOval(),
                    child: const SizedBox(width: 10, height: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(GlassLayer), findsOneWidget);
  });

  testWidgets('disposing a layer leaks no shaders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Glass(
            shape: const GlassOval(),
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(ShaderLibrary.instance.debugOutstandingCount, 0);
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `cd packages/glass_forge && flutter test test/src/widgets/glass_widgets_test.dart`
Expected: FAIL — the widgets do not exist.

- [ ] **Step 3: Implement `render_glass_shape.dart`**

A `RenderProxyBox` that registers its resolved geometry with the nearest layer and **paints its child normally**.

```dart
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

/// Registers one shape with its layer, and paints its child in place.
///
/// Painting in place is the whole point. Upstream makes `paint` a no-op behind
/// an `// ignore: must_call_super` and paints children later from the layer,
/// which is why its children are invisible until shaders load, always land at
/// the layer's z-position, vanish inside a Hero flight or `toImage`, and
/// refract one frame behind their own content.
class RenderGlassShape extends RenderProxyBox {
  /// Creates a glass shape render object.
  RenderGlassShape({
    required GlassShape shape,
    required RenderGlassLayer? layer,
    required Object groupKey,
    required double blendMarker,
  })  : _shape = shape,
        _layer = layer,
        _groupKey = groupKey,
        _blendMarker = blendMarker;

  GlassShape _shape;
  RenderGlassLayer? _layer;
  Object _groupKey;
  double _blendMarker;

  /// The shape to render.
  GlassShape get shape => _shape;
  set shape(GlassShape value) {
    if (_shape == value) {
      return;
    }
    _shape = value;
    _syncGeometry();
    markNeedsPaint();
  }

  /// The layer this shape belongs to.
  RenderGlassLayer? get layer => _layer;
  set layer(RenderGlassLayer? value) {
    if (identical(_layer, value)) {
      return;
    }
    _layer?.scene.unregister(this);
    _layer = value;
    _syncGeometry();
  }

  /// The blend marker for this shape's group membership.
  double get blendMarker => _blendMarker;
  set blendMarker(double value) {
    if (_blendMarker == value) {
      return;
    }
    _blendMarker = value;
    _syncGeometry();
  }

  @override
  void performLayout() {
    super.performLayout();
    _syncGeometry();
  }

  void _syncGeometry() {
    final target = _layer;
    if (target == null || !hasSize || !attached) {
      return;
    }
    target.scene.register(
      this,
      ShapeGeometry.resolve(
        shape: _shape,
        size: size,
        toLayer: getTransformTo(target),
        devicePixelRatio: target.devicePixelRatio,
        blendMarker: _blendMarker,
      ),
    );
    target.markNeedsPaint();
  }

  @override
  void detach() {
    _layer?.scene.unregister(this);
    _layer?.markNeedsPaint();
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // In place. Deliberately ordinary.
    super.paint(context, offset);
  }
}
```

- [ ] **Step 4: Implement `render_glass_layer.dart`**

Holds the scene, the producer, the composition, and pushes exactly one backdrop filter.

```dart
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/composition/filter_snapshot.dart';
import 'package:glass_forge/src/composition/glass_composition.dart';
import 'package:glass_forge/src/composition/pixel_buckets.dart';
import 'package:glass_forge/src/diagnostics/render_counters.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';

/// Owns one backdrop capture and the scene it is shaped by.
class RenderGlassLayer extends RenderProxyBox {
  /// Creates a glass layer.
  RenderGlassLayer({
    required GlassMaterial material,
    required GeometryTier tier,
    required double devicePixelRatio,
  })  : _material = material,
        _devicePixelRatio = devicePixelRatio,
        _producer = ProducerRegistry.select(tier: tier);

  /// The shapes belonging to this layer.
  final GlassScene scene = GlassScene();

  final GlassComposition _composition = GlassComposition();
  GeometryProducer _producer;
  MatteGeneration? _matte;
  GlassMaterial _material;
  double _devicePixelRatio;

  /// Physical pixels per logical pixel.
  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) {
      return;
    }
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  /// How this layer's glass looks.
  GlassMaterial get material => _material;
  set material(GlassMaterial value) {
    if (_material == value) {
      return;
    }
    _material = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    _refreshMatte();

    final filter = _composition.build(
      matte: _matte,
      material: _material,
      snapshot: FilterSnapshot.of(
        matte: _matte,
        devicePixelRatio: _devicePixelRatio,
        materialRevision: _material.revision,
        coordinateMapping: _coordinateMapping(offset),
      ),
      devicePixelRatio: _devicePixelRatio,
    );

    if (filter == null) {
      // Nothing to render, so no backdrop pass at all. Upstream pushes a full
      // backdrop even when its blur is zero.
      super.paint(context, offset);
      return;
    }

    GlassRenderCounters.instance.recordBackdropPush();
    final clip = expandToPixelBuckets(offset & size);
    context.pushClipRect(
      needsCompositing,
      Offset.zero,
      clip,
      (innerContext, innerOffset) {
        innerContext.pushLayer(
          BackdropFilterLayer()..filter = filter,
          super.paint,
          innerOffset,
        );
      },
    );
  }

  void _refreshMatte() {
    final existing = _matte;
    if (existing != null && existing.sceneRevision == scene.revision) {
      return;
    }
    final next = _producer.produce(
      scene,
      MatteRequest(
        devicePixelRatio: _devicePixelRatio,
        maxDisplacement: _material.maxDisplacement * _devicePixelRatio,
        edgeRefraction: _material.edgeRefraction * _devicePixelRatio,
        refractionSpread: _material.refractionSpread,
        antialiasWidth: 0.5,
      ),
    );
    GlassRenderCounters.instance.recordMatteProduce();
    if (existing != null) {
      _producer.release(existing);
    }
    _matte = next;
  }

  Float32List _coordinateMapping(Offset offset) {
    return Float32List.fromList(<double>[
      1,
      0,
      0,
      1,
      -offset.dx * _devicePixelRatio,
      -offset.dy * _devicePixelRatio,
    ]);
  }

  @override
  void dispose() {
    final matte = _matte;
    if (matte != null) {
      _producer.release(matte);
    }
    _matte = null;
    _producer.dispose();
    _composition.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 5: Implement the three widgets**

`glass_layer.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

/// One backdrop capture, shared by every [Glass] beneath it.
///
/// Apple's own guidance is that "glass cannot sample other glass", and that a
/// container lets nearby elements share one sampling region. The same applies
/// here for the same reason: one layer around a screen's worth of controls
/// costs one capture, while a layer per control costs one each.
class GlassLayer extends StatefulWidget {
  /// Creates a glass layer.
  const GlassLayer({
    required this.child,
    this.material = const GlassMaterial(),
    this.tier = GeometryTier.accelerated,
    super.key,
  });

  /// The subtree this layer captures behind.
  final Widget child;

  /// How the glass in this layer looks by default.
  final GlassMaterial material;

  /// How much geometry work this layer may do.
  final GeometryTier tier;

  @override
  State<GlassLayer> createState() => _GlassLayerState();
}

class _GlassLayerState extends State<GlassLayer> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    ShaderLibrary.instance.warmUp().then((_) {
      if (mounted) {
        setState(() => _ready = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      // Render the subtree unglassed rather than blank. Upstream returns the
      // bare child from its layer but makes each shape's paint a no-op, so
      // children are invisible until shaders load and nobody can tell why.
      return widget.child;
    }
    return GlassLayerScope(
      material: widget.material,
      child: _RawGlassLayer(
        material: widget.material,
        tier: widget.tier,
        child: widget.child,
      ),
    );
  }
}

/// Exposes the nearest layer's render object to descendants.
class GlassLayerScope extends InheritedWidget {
  /// Creates a scope.
  const GlassLayerScope({
    required this.material,
    required super.child,
    super.key,
  });

  /// The layer's default material.
  final GlassMaterial material;

  /// The nearest enclosing scope, if any.
  static GlassLayerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GlassLayerScope>();
  }

  @override
  bool updateShouldNotify(GlassLayerScope oldWidget) =>
      oldWidget.material != material;
}

class _RawGlassLayer extends SingleChildRenderObjectWidget {
  const _RawGlassLayer({
    required this.material,
    required this.tier,
    required Widget super.child,
  });

  final GlassMaterial material;
  final GeometryTier tier;

  @override
  RenderGlassLayer createRenderObject(BuildContext context) {
    return RenderGlassLayer(
      material: material,
      tier: tier,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderGlassLayer renderObject) {
    renderObject
      ..material = material
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}
```

`glass_blend_group.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/scene/blend_group_link.dart';

/// Shapes inside this group merge into one another.
///
/// Scoped to its own layer: a nested layer's shapes must never register into
/// an outer group, or they would blend across a boundary the caller drew.
class GlassBlendGroup extends StatefulWidget {
  /// Creates a blend group.
  const GlassBlendGroup({
    required this.child,
    this.blend = 20.0,
    super.key,
  });

  /// The subtree whose glass merges.
  final Widget child;

  /// How wide the merge is, in logical pixels.
  final double blend;

  @override
  State<GlassBlendGroup> createState() => _GlassBlendGroupState();
}

class _GlassBlendGroupState extends State<GlassBlendGroup> {
  late BlendGroupLink _link = BlendGroupLink(blend: widget.blend);

  @override
  void didUpdateWidget(GlassBlendGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blend != widget.blend) {
      _link = BlendGroupLink(blend: widget.blend);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassBlendGroupScope(link: _link, child: widget.child);
  }
}

/// Exposes a [BlendGroupLink] to descendants.
class GlassBlendGroupScope extends InheritedWidget {
  /// Creates a scope.
  const GlassBlendGroupScope({
    required this.link,
    required super.child,
    super.key,
  });

  /// The group descendants join.
  final BlendGroupLink link;

  /// The nearest enclosing group, if any.
  static GlassBlendGroupScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GlassBlendGroupScope>();
  }

  @override
  bool updateShouldNotify(GlassBlendGroupScope oldWidget) =>
      oldWidget.link != link;
}
```

`glass.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/rendering/render_glass_shape.dart';
import 'package:glass_forge/src/scene/blend_group_link.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass_blend_group.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

/// One glass surface.
class Glass extends StatelessWidget {
  /// Creates a glass surface.
  const Glass({
    required this.shape,
    this.child,
    this.material,
    this.containsChild = false,
    this.clipBehavior = Clip.antiAlias,
    super.key,
  });

  /// The silhouette.
  final GlassShape shape;

  /// Content drawn with the glass.
  final Widget? child;

  /// Overrides the layer's material for this shape alone.
  final GlassMaterial? material;

  /// Whether [child] sits behind the glass and is refracted by it.
  final bool containsChild;

  /// How [child] is clipped to [shape].
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final scope = GlassLayerScope.maybeOf(context);
    if (scope == null) {
      // No enclosing layer. Wrap in an implicit one rather than asserting in
      // debug and null-crashing in release, which is what upstream does.
      assert(() {
        debugPrint(
          'glass_forge: a Glass with no enclosing GlassLayer created an '
          'implicit one. That costs a backdrop capture per shape. Wrap the '
          'screen in a single GlassLayer instead.',
        );
        return true;
      }());
      return GlassLayer(child: this);
    }

    final group = GlassBlendGroupScope.maybeOf(context)?.link;
    return _RawGlass(
      shape: shape,
      group: group,
      child: ClipPath(
        clipper: ShapeBorderClipper(
          shape: shape.toBorder(Size.zero),
        ),
        clipBehavior: clipBehavior,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _RawGlass extends SingleChildRenderObjectWidget {
  const _RawGlass({
    required this.shape,
    required this.group,
    required Widget super.child,
  });

  final GlassShape shape;
  final BlendGroupLink? group;

  double get _blendMarker {
    final link = group;
    if (link == null) {
      // Ungrouped shapes share the capture without blending. Upstream wraps
      // each in a dummy zero-blend group instead, which costs a group each.
      return encodeBlendMarker(startsGroup: true, blend: 0);
    }
    return encodeBlendMarker(startsGroup: false, blend: link.blend);
  }

  @override
  RenderGlassShape createRenderObject(BuildContext context) {
    return RenderGlassShape(
      shape: shape,
      layer: null,
      groupKey: group ?? const Object(),
      blendMarker: _blendMarker,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderGlassShape renderObject) {
    renderObject
      ..shape = shape
      ..blendMarker = _blendMarker;
  }
}
```

Then export from `lib/glass_forge.dart`:

```dart
export 'src/material/glass_material.dart';
export 'src/material/glass_variant.dart';
export 'src/shapes/glass_shape.dart';
export 'src/widgets/glass.dart';
export 'src/widgets/glass_blend_group.dart';
export 'src/widgets/glass_layer.dart';
```

- [ ] **Step 6: Run the tests**

Run: `cd packages/glass_forge && flutter test`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add packages/glass_forge/lib packages/glass_forge/test
git commit -m "feat: add the glass render objects and public widgets

Children paint in place rather than being deferred to the layer, which removes
upstream's whole family of symptoms at once: invisible children on first
frame, z-order collapse in a Stack, nothing rendered inside a Hero flight or
toImage, and refraction lagging its own content by a frame. Exceeding the
shape cap degrades instead of blanking the layer."
```

---

### Task 16: Instrumented counters and the invalidation acceptance tests

This is the regression surface that matters most, and the one upstream has none of. Its blend goldens all render the same image because the parameter they vary is a no-op, and its shader precache points at a file that does not exist — so its suite passes while the thing it claims to test is broken.

**Note on ordering:** `render_counters.dart` is referenced by Task 15's `RenderGlassLayer`. If you are executing strictly in order, write Step 1 of this task before Task 15's Step 4.

**Files:**
- Create: `packages/glass_forge/lib/src/diagnostics/render_counters.dart`
- Test: `packages/glass_forge/test/src/diagnostics/invalidation_test.dart`

**Interfaces:**
- Consumes: `GlassLayer`, `Glass` (Task 15)
- Produces: `class GlassRenderCounters` singleton with `matteProduceCount`, `backdropPushCount`, `void recordMatteProduce()`, `void recordBackdropPush()`, `void reset()`.

- [ ] **Step 1: Write the counters**

```dart
import 'package:flutter/foundation.dart';

/// Counts the operations whose frequency is the point of this renderer.
///
/// These are assertions, not telemetry. "Does not re-rasterise while
/// scrolling" and "captures the backdrop once per layer" are behavioural
/// claims, and a golden image cannot check either — a frame that rebuilt its
/// matte forty times looks identical to one that rebuilt it never.
class GlassRenderCounters {
  GlassRenderCounters._();

  /// The shared instance.
  static final GlassRenderCounters instance = GlassRenderCounters._();

  int _matteProduceCount = 0;
  int _backdropPushCount = 0;

  /// How many mattes have been baked.
  int get matteProduceCount => _matteProduceCount;

  /// How many backdrop filters have been pushed.
  int get backdropPushCount => _backdropPushCount;

  /// Records a matte bake.
  void recordMatteProduce() {
    if (kDebugMode) {
      _matteProduceCount++;
    }
  }

  /// Records a backdrop push.
  void recordBackdropPush() {
    if (kDebugMode) {
      _backdropPushCount++;
    }
  }

  /// Resets both counters.
  void reset() {
    _matteProduceCount = 0;
    _backdropPushCount = 0;
  }
}
```

- [ ] **Step 2: Write the acceptance tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/diagnostics/render_counters.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

Widget _glassInList(ScrollController controller) {
  return MaterialApp(
    home: ListView.builder(
      controller: controller,
      itemCount: 200,
      itemBuilder: (context, index) => SizedBox(
        height: 60,
        child: index == 0
            ? GlassLayer(
                child: Glass(
                  shape: const GlassRoundedRectangle(
                    radius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: const SizedBox(width: 200, height: 48),
                ),
              )
            : Text('row $index'),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);
  setUp(GlassRenderCounters.instance.reset);

  testWidgets('a static layer bakes exactly one matte', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Glass(
            shape: const GlassOval(),
            child: const SizedBox(width: 80, height: 80),
          ),
        ),
      ),
    );
    final afterFirst = GlassRenderCounters.instance.matteProduceCount;

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(GlassRenderCounters.instance.matteProduceCount, afterFirst);
  });

  testWidgets('scrolling bakes no new mattes', (tester) async {
    // ACCEPTANCE CRITERION 4. Upstream re-rasterises every scroll frame,
    // because its layout override dirties geometry before constraints
    // short-circuit. liquid_glass_widgets documents that its best tier "may
    // not render correctly inside ListView on Impeller" and tells users to
    // avoid it. Zero is the bar.
    final controller = ScrollController();
    await tester.pumpWidget(_glassInList(controller));
    await tester.pumpAndSettle();

    GlassRenderCounters.instance.reset();

    for (var i = 0; i < 20; i++) {
      controller.jumpTo(controller.offset + 12);
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      GlassRenderCounters.instance.matteProduceCount,
      0,
      reason: 'scrolling changed no shape geometry, so nothing needed baking',
    );

    controller.dispose();
  });

  testWidgets('one layer pushes one backdrop filter per frame',
      (tester) async {
    // ACCEPTANCE CRITERION 2, and the flutter#187820 guard: two stacked
    // filters would show up here as two pushes.
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Glass(
            shape: const GlassOval(),
            child: const SizedBox(width: 80, height: 80),
          ),
        ),
      ),
    );

    GlassRenderCounters.instance.reset();
    await tester.pump(const Duration(milliseconds: 16));

    expect(GlassRenderCounters.instance.backdropPushCount, lessThanOrEqualTo(1));
  });

  testWidgets('changing a shape does bake a new matte', (tester) async {
    // The counter would be trivially satisfiable if nothing ever rebuilt.
    Widget build(double radius) => MaterialApp(
          home: GlassLayer(
            child: Glass(
              shape: GlassRoundedRectangle(
                radius: BorderRadius.all(Radius.circular(radius)),
              ),
              child: const SizedBox(width: 80, height: 80),
            ),
          ),
        );

    await tester.pumpWidget(build(8));
    GlassRenderCounters.instance.reset();
    await tester.pumpWidget(build(24));
    await tester.pump();

    expect(GlassRenderCounters.instance.matteProduceCount, greaterThan(0));
  });

  testWidgets('an idle material pushes no backdrop at all', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          material: const GlassMaterial(
            frost: 0,
            edgeRefraction: 0,
            tintOpacity: 0,
            highlight: 0,
          ),
          child: Glass(
            shape: const GlassOval(),
            child: const SizedBox(width: 80, height: 80),
          ),
        ),
      ),
    );

    GlassRenderCounters.instance.reset();
    await tester.pump(const Duration(milliseconds: 16));

    expect(GlassRenderCounters.instance.backdropPushCount, 0);
  });

  testWidgets('mounting and unmounting 1000 times leaks nothing',
      (tester) async {
    // ACCEPTANCE CRITERION 7. flutter_shaders' ShaderBuilder has no dispose,
    // so upstream leaks a FragmentShader per glass widget.
    for (var i = 0; i < 1000; i++) {
      await tester.pumpWidget(
        MaterialApp(
          home: GlassLayer(
            child: Glass(
              shape: const GlassOval(),
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    }

    expect(ShaderLibrary.instance.debugOutstandingCount, 0);
  });
}
```

- [ ] **Step 3: Run the tests**

Run: `cd packages/glass_forge && flutter test test/src/diagnostics/invalidation_test.dart`
Expected: PASS. The scroll test is the one most likely to fail first — if it does, the cause is almost always that `_syncGeometry` is registering a geometry whose numbers differ by floating-point noise. Fix it in `GlassScene._sameGeometry`'s tolerance, not by loosening the test.

- [ ] **Step 4: Commit**

```bash
git add packages/glass_forge/lib/src/diagnostics packages/glass_forge/test/src/diagnostics
git commit -m "test: assert the invalidation behaviour the design is for

Counters, not goldens: a frame that rebuilt its matte forty times looks
identical to one that rebuilt it never. Pins zero matte bakes across a scroll,
one backdrop push per layer, no backdrop at all when the material renders
nothing, and no leaked shaders across a thousand mount cycles."
```

---

### Task 17: Retained ancestor clips

*Scrolling moves material through a viewport, not the viewport through the material.* This is the structural fix for the whole family of scroll defects — upstream #124, #136, #101, #33 — and for the reason competitors tell users not to put their best tier in a `ListView`.

**Files:**
- Create: `packages/glass_forge/lib/src/composition/retained_clip_chain.dart`
- Modify: `packages/glass_forge/lib/src/rendering/render_glass_layer.dart` — wrap the backdrop push
- Test: `packages/glass_forge/test/src/composition/retained_clip_chain_test.dart`

**Interfaces:**
- Consumes: `RenderGlassLayer` (Task 15)
- Produces: `class RetainedClipChain` with `void collect(RenderObject shape, RenderObject layer)`, `List<RetainedClip> get clips`, `bool matches(RetainedClipChain other)`; `class RetainedClip { Rect rect; RRect? rrect; Path? path; Clip behavior; Matrix4 transform; }`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  testWidgets('glass survives being scrolled to the viewport edge',
      (tester) async {
    // Upstream #124: glass and its contents disappear at the scroll bounds.
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 300,
          child: ListView(
            controller: controller,
            children: <Widget>[
              const SizedBox(height: 400),
              GlassLayer(
                child: Glass(
                  shape: const GlassRoundedRectangle(
                    radius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: const SizedBox(
                    height: 80,
                    child: Center(child: Text('glass')),
                  ),
                ),
              ),
              const SizedBox(height: 400),
            ],
          ),
        ),
      ),
    );

    for (final offset in const <double>[0, 200, 380, 400, 420, 600]) {
      controller.jumpTo(offset);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'at offset $offset');
    }

    controller.dispose();
  });

  testWidgets('glass inside a clipped container stays clipped',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: 200,
              height: 200,
              child: GlassLayer(
                child: Glass(
                  shape: const GlassOval(),
                  child: const SizedBox(width: 400, height: 400),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `cd packages/glass_forge && flutter test test/src/composition/retained_clip_chain_test.dart`
Expected: FAIL — either an exception at a scroll boundary, or `retained_clip_chain.dart` missing.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:flutter/rendering.dart';

/// One ancestor clip, captured so it can be re-pushed.
class RetainedClip {
  /// Creates a captured clip.
  RetainedClip({
    required this.rect,
    required this.behavior,
    required this.transform,
    this.rrect,
    this.path,
  });

  /// The clip's bounds in the layer's coordinate space.
  final Rect rect;

  /// The rounded form, when the ancestor clipped with one.
  final RRect? rrect;

  /// The path form, when the ancestor clipped with one.
  final Path? path;

  /// How the ancestor clipped.
  final Clip behavior;

  /// The transform between the ancestor and the layer.
  final Matrix4 transform;
}

/// The ancestor clips that must survive between a glass layer and the screen.
///
/// A glass layer's contents move relative to any scrollable it sits inside. If
/// the viewport's clip is captured *inside* the moving offset layer, it moves
/// with the content and stops clipping — which is how glass ends up drawing
/// outside its viewport, tearing on overscroll, or vanishing at the bounds.
///
/// Re-pushing the common prefix of ancestor clips outside the offset layer
/// keeps the viewport still while the material moves through it, which is the
/// physically correct arrangement and the one Apple's own containers use.
class RetainedClipChain {
  final List<RetainedClip> _clips = <RetainedClip>[];

  /// The captured clips, outermost first.
  List<RetainedClip> get clips => List<RetainedClip>.unmodifiable(_clips);

  /// Walks from [shape] up to [layer], capturing every clip on the way.
  void collect(RenderObject shape, RenderObject layer) {
    _clips.clear();
    final found = <RetainedClip>[];

    AbstractNode? node = shape.parent;
    while (node != null && !identical(node, layer)) {
      if (node is RenderObject) {
        final captured = _capture(node, layer);
        if (captured != null) {
          found.add(captured);
        }
      }
      node = node is RenderObject ? node.parent : null;
    }

    // Outermost first: they are pushed in that order.
    _clips.addAll(found.reversed);
  }

  static RetainedClip? _capture(RenderObject node, RenderObject layer) {
    final transform = node.getTransformTo(layer);

    if (node is RenderClipRect) {
      return RetainedClip(
        rect: node.paintBounds,
        behavior: node.clipBehavior,
        transform: transform,
      );
    }
    if (node is RenderClipRRect) {
      return RetainedClip(
        rect: node.paintBounds,
        rrect: node.borderRadius.resolve(TextDirection.ltr).toRRect(
              Offset.zero & node.size,
            ),
        behavior: node.clipBehavior,
        transform: transform,
      );
    }
    if (node is RenderClipOval || node is RenderClipPath) {
      return RetainedClip(
        rect: node.paintBounds,
        behavior: Clip.antiAlias,
        transform: transform,
      );
    }
    if (node is RenderViewportBase) {
      // Mirror the viewport's own decision exactly. Clipping when it does not
      // would crop content it deliberately let overflow.
      return RetainedClip(
        rect: node.paintBounds,
        behavior: node.clipBehavior,
        transform: transform,
      );
    }
    return null;
  }

  /// Whether [other] describes the same clips, so the filter can be reused.
  bool matches(RetainedClipChain other) {
    if (other._clips.length != _clips.length) {
      return false;
    }
    for (var i = 0; i < _clips.length; i++) {
      if (_clips[i].rect != other._clips[i].rect ||
          _clips[i].behavior != other._clips[i].behavior) {
        return false;
      }
    }
    return true;
  }
}
```

- [ ] **Step 4: Wire it into `RenderGlassLayer.paint`**

Replace the plain `pushClipRect` from Task 15 with the retained chain. Each clip is pushed outermost-first, wrapped in its transform, **outside** the layer that moves:

```dart
  void _pushGlassLayers(
    PaintingContext context,
    Offset offset,
    ui.ImageFilter filter,
  ) {
    GlassRenderCounters.instance.recordBackdropPush();

    void pushBackdrop(PaintingContext innerContext, Offset innerOffset) {
      innerContext.pushLayer(
        BackdropFilterLayer()..filter = filter,
        super.paint,
        innerOffset,
      );
    }

    // Innermost first when building the closure chain, so that the outermost
    // clip ends up outermost in the layer tree.
    var paint = pushBackdrop;
    for (final clip in _clipChain.clips) {
      final captured = clip;
      final next = paint;
      paint = (innerContext, innerOffset) {
        innerContext.pushTransform(
          needsCompositing,
          innerOffset,
          captured.transform,
          (transformedContext, transformedOffset) {
            final rrect = captured.rrect;
            if (rrect != null) {
              transformedContext.pushClipRRect(
                needsCompositing,
                transformedOffset,
                captured.rect,
                rrect,
                next,
                clipBehavior: captured.behavior,
              );
            } else {
              transformedContext.pushClipRect(
                needsCompositing,
                transformedOffset,
                captured.rect,
                next,
                clipBehavior: captured.behavior,
              );
            }
          },
        );
      };
    }

    paint(context, offset);
  }
```

Call `_clipChain.collect(...)` for the layer's first registered shape during
paint, and skip rebuilding the filter when `_clipChain.matches(previous)`.

- [ ] **Step 5: Run the tests**

Run: `cd packages/glass_forge && flutter test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add packages/glass_forge/lib/src/composition/retained_clip_chain.dart \
        packages/glass_forge/lib/src/rendering/render_glass_layer.dart \
        packages/glass_forge/test/src/composition/retained_clip_chain_test.dart
git commit -m "fix: retain ancestor clips outside the moving offset layer

Scrolling moves material through a viewport, not the viewport through the
material. Capturing the viewport's clip inside the moving layer is why glass
tears on overscroll and vanishes at the scroll bounds upstream, and why
competing packages tell users to keep their best tier out of a ListView."
```

---

### Task 18: The Flutter GPU producer

The last task, and deliberately last: everything above works without it. This is an **optimisation**, and it must never be able to break a build or a frame.

**Files:**
- Create: `packages/glass_forge/lib/src/geometry/gpu_geometry_producer.dart`
- Create: `packages/glass_forge/hook/build.dart`
- Create: `packages/glass_forge/shaders/gpu/geometry_vertex.glsl`
- Create: `packages/glass_forge/shaders/gpu/geometry_fragment.glsl`
- Modify: `packages/glass_forge/pubspec.yaml` — add `flutter_gpu`, `flutter_gpu_shaders`, `hooks`
- Test: `packages/glass_forge/test/src/geometry/gpu_geometry_producer_test.dart`

**Interfaces:**
- Consumes: `GeometryProducer` (Task 11), `ProducerRegistry` (Task 11)
- Produces: `class GpuGeometryProducer implements GeometryProducer` reporting `capabilities.available` honestly, and registering itself with `ProducerRegistry.registerAccelerated`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/gpu_geometry_producer.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/geometry/runtime_geometry_producer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(ProducerRegistry.debugReset);

  test('reports unavailability rather than throwing', () {
    // Flutter GPU is unavailable on Skia, on older Flutter, and when its
    // shader bundle did not build. All three are normal answers.
    final producer = GpuGeometryProducer();
    expect(() => producer.capabilities.available, returnsNormally);
    producer.dispose();
  });

  test('an unavailable accelerated producer falls through to runtime', () {
    ProducerRegistry.registerAccelerated(_UnavailableProducer.new);

    final selected = ProducerRegistry.select(tier: GeometryTier.accelerated);
    expect(selected, isA<RuntimeGeometryProducer>());
    selected.dispose();
  });

  test('produce returns null when unavailable, never throws', () {
    // A build that cannot use the fast path must still render.
    final producer = GpuGeometryProducer();
    if (!producer.capabilities.available) {
      expect(producer.produce(GlassScene(), _request), isNull);
    }
    producer.dispose();
  });
}
```

(`_UnavailableProducer` is a two-line fake implementing `GeometryProducer` with `available: false`; `_request` is the same `MatteRequest` constant used in Task 11's test.)

- [ ] **Step 2: Run it to make sure it fails**

Run: `cd packages/glass_forge && flutter test test/src/geometry/gpu_geometry_producer_test.dart`
Expected: FAIL — `gpu_geometry_producer.dart` does not exist.

- [ ] **Step 3: Add the dependencies and a build hook that fails soft**

`pubspec.yaml` gains `flutter_gpu: {sdk: flutter}`, `flutter_gpu_shaders`, and `hooks`. The hook compiles the shader bundle — and **catches its own failures**:

```dart
// packages/glass_forge/hook/build.dart
import 'package:flutter_gpu_shaders/build.dart';
import 'package:hooks/hooks.dart';

/// Builds the Flutter GPU shader bundle.
///
/// This runs in every consumer's build. It must never fail one.
///
/// The GPU geometry producer is an optimisation: if its bundle cannot be
/// built — an unsupported toolchain, an experimental API that moved — the
/// package still renders through the runtime-effect producer. Breaking a
/// consumer's build over a fast path they never asked for is not a trade we
/// are willing to make, so failures are reported and swallowed.
void main(List<String> args) async {
  await build(args, (input, output) async {
    try {
      await buildShaderBundleJson(
        buildInput: input,
        buildOutput: output,
        manifestFileName: 'shaders/gpu/bundle.json',
      );
    } on Object catch (error, stackTrace) {
      // ignore: avoid_print
      print(
        'glass_forge: the Flutter GPU shader bundle did not build, so the '
        'accelerated geometry producer will report itself unavailable and '
        'rendering will use the runtime-effect path instead. This is not '
        'fatal.\n$error\n$stackTrace',
      );
    }
  });
}
```

- [ ] **Step 4: Write the producer, guarded end to end**

```dart
import 'package:flutter/foundation.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';

/// Bakes the matte with a Flutter GPU render pass.
///
/// Faster than the runtime-effect producer: it renders straight into a
/// `devicePrivate` texture rather than round-tripping through `toImageSync`,
/// whose display list is retained until disposal (flutter#138627).
///
/// Every entry point is guarded. Flutter GPU is experimental, its shader
/// bundle may not have built, and it does not exist on Skia — so
/// [capabilities] answers honestly and [produce] returns null rather than
/// throwing. The registry then falls through to the runtime producer and the
/// caller never learns anything happened.
class GpuGeometryProducer implements GeometryProducer {
  bool? _available;

  /// Registers this producer as an accelerated option.
  ///
  /// Called once during package initialisation.
  static void register() {
    ProducerRegistry.registerAccelerated(GpuGeometryProducer.new);
  }

  @override
  GeometryCapabilities get capabilities => GeometryCapabilities(
        available: _available ??= _probe(),
        name: 'flutter-gpu',
      );

  bool _probe() {
    try {
      // Touch the GPU context. On Skia, on an older Flutter, or when the
      // bundle is missing, this throws — which is an answer, not an error.
      return _gpuContextIsUsable();
    } on Object catch (error) {
      debugPrint(
        'glass_forge: Flutter GPU is unavailable here ($error). Falling back '
        'to the runtime-effect geometry producer.',
      );
      return false;
    }
  }

  bool _gpuContextIsUsable() {
    // Implementation note: resolve the shader bundle and construct a 1x1
    // render target. Do NOT cache a texture here — see Task 11's immutable
    // generation invariant.
    //
    // Android's Impeller context does not exist until its first surface
    // frame, so callers must probe from a post-frame callback rather than
    // during startup.
    throw UnimplementedError('probe the GPU context');
  }

  @override
  Future<void> warmUp() async {}

  @override
  MatteGeneration? produce(GlassScene scene, MatteRequest request) {
    if (!capabilities.available) {
      return null;
    }
    throw UnimplementedError('render the matte via a Flutter GPU pass');
  }

  @override
  void release(MatteGeneration generation) {
    generation.texture.dispose();
  }

  @override
  void dispose() {}
}
```

- [ ] **Step 5: Fill in `_gpuContextIsUsable` and `produce`**

Render a full-screen quad with `shaders/gpu/geometry_vertex.glsl` and `shaders/gpu/geometry_fragment.glsl` into a `devicePrivate` RGBA8 texture, exposed via `Texture.asImage()`. Reuse the same uniform layout as `geometry.frag` so the two producers stay interchangeable. Allocate a **new** texture per generation.

- [ ] **Step 6: Run the whole suite on both producers**

Run: `cd packages/glass_forge && flutter test`
Expected: PASS. **Acceptance criterion 8** requires both producers to pass the same golden suite — parameterise the golden tests over `GeometryTier.accelerated` and `GeometryTier.portable` and confirm the images match.

- [ ] **Step 7: Verify the build hook fails soft**

Temporarily rename `shaders/gpu/bundle.json`, then run `cd apps/glass_forge_workbench && flutter run -d macos`.
Expected: the build **succeeds**, a warning is printed, and glass still renders through the runtime producer. Restore the file.

This is the most important check in the task. A fast path that can break someone's build is worse than no fast path.

- [ ] **Step 8: Commit**

```bash
git add packages/glass_forge/lib/src/geometry/gpu_geometry_producer.dart \
        packages/glass_forge/hook packages/glass_forge/shaders/gpu \
        packages/glass_forge/pubspec.yaml \
        packages/glass_forge/test/src/geometry/gpu_geometry_producer_test.dart
git commit -m "feat: add the Flutter GPU geometry producer

Renders the matte straight into a devicePrivate texture instead of
round-tripping through toImageSync. Guarded end to end: the build hook
swallows its own failures, the capability probe answers honestly on Skia and
older Flutter, and produce returns null rather than throwing. An optimisation
must never be able to break a build or a frame."
```

---

### Task 19: Measure the backdrop sampling quality, and decide

**Can run any time after Task 13.** Listed last because it is a measurement whose outcome changes the shader, not a feature.

`ImageFilter.shader`'s backdrop sampler is **nearest-neighbour by default** (flutter#186945). Every displaced lookup therefore snaps between texels rather than interpolating, which reads as shimmer on any moving refraction — and is a plausible contributor to upstream's "jagged/aliased" reports (#85). A `filterQuality` parameter merged to master on 2026-07-30 but still defaults to `none`.

The design says to measure this early rather than discover it late. This task does that and commits to an answer either way.

**Files:**
- Create: `apps/glass_forge_workbench/lib/features/sampling_probe/presentation/views/sampling_probe_view.dart`
- Create: `docs/reference/backdrop_sampling.md`
- Possibly modify: `packages/glass_forge/shaders/final_render.frag`

**Interfaces:**
- Consumes: `GlassLayer`, `Glass`, `GlassMaterial` (Tasks 14–15)
- Produces: a decision recorded in `docs/reference/backdrop_sampling.md`, and either an unchanged shader or a documented reconstruction path in `final_render.frag`.

- [ ] **Step 1: Build the probe screen**

A workbench screen showing a high-frequency backdrop — a 1px checkerboard and fine diagonal stripes, which is where texel snapping is most visible — under a glass shape that animates slowly across it. Add a toggle between the shipped shader and a variant with manual bilinear reconstruction:

```glsl
// Candidate mitigation: reconstruct bilinearly in-shader.
// Four taps instead of one, so only worth it if the shimmer is real.
vec3 gfSampleBilinear(sampler2D tex, vec2 uv, vec2 texSize) {
    vec2 texel = uv * texSize - 0.5;
    vec2 base = floor(texel);
    vec2 f = texel - base;
    vec2 uv00 = (base + 0.5) / texSize;
    vec2 uv10 = (base + vec2(1.0, 0.0) + 0.5) / texSize;
    vec2 uv01 = (base + vec2(0.0, 1.0) + 0.5) / texSize;
    vec2 uv11 = (base + vec2(1.0, 1.0) + 0.5) / texSize;
    vec3 a = mix(texture(tex, uv00).rgb, texture(tex, uv10).rgb, f.x);
    vec3 b = mix(texture(tex, uv01).rgb, texture(tex, uv11).rgb, f.x);
    return mix(a, b, f.y);
}
```

- [ ] **Step 2: Capture the evidence**

Run the probe on a real device at each DPR you support (1x, 2x, 3x). Record a screen capture of the animation with each mode, and note the frame timings from the benchmark harness for both.

- [ ] **Step 3: Decide, and write it down**

Create `docs/reference/backdrop_sampling.md` recording, with the captures:

- whether the shimmer is visible at each DPR, and at what displacement magnitudes
- the measured cost of four taps versus one on the weakest device tested
- the decision, one of:
  - **no change** — shimmer not visible in realistic use; note the displacement threshold below which that holds
  - **reconstruct in-shader** — shimmer visible and the four taps are affordable; ship it, ideally gated so only the tiers that can afford it pay
  - **wait for `filterQuality`** — shimmer visible but reconstruction too expensive; document the limitation and link the issue

Any of the three is a legitimate outcome. What is not legitimate is shipping without having looked, which is how upstream ended up with #85 open for eleven months and no diagnosis.

- [ ] **Step 4: Apply the decision**

If reconstruction wins, add it to `final_render.frag` behind a `#define` so the cheap tiers compile it out entirely.

- [ ] **Step 5: Commit**

```bash
git add docs/reference/backdrop_sampling.md \
        apps/glass_forge_workbench/lib/features/sampling_probe \
        packages/glass_forge/shaders/final_render.frag
git commit -m "test: measure backdrop sampling quality and record the decision

ImageFilter.shader samples the backdrop nearest-neighbour by default
(flutter#186945), so displaced lookups snap between texels. Measured whether
that is visible, what bilinear reconstruction costs, and recorded the call
with captures rather than guessing."
```


---

## Done

After Task 18 the acceptance criteria in the renderer core design should all hold. Verify them explicitly before calling this complete:

1. 1 and 16 shapes, blended and unblended, render on iOS, Android-Vulkan, Android-GLES and macOS
2. exactly one backdrop capture per layer per frame — asserted by counter
3. rotated and non-uniformly scaled glass refracts in the correct direction
4. glass in a `ListView` scrolls with **zero** matte rebuilds
5. a static layer schedules no work
6. every shader compiles as SkSL in CI
7. no leaked shader or texture across 1,000 mount cycles
8. both producers pass the same golden suite
9. the benchmark harness reports frame timings for a fixed scene on a real device, recorded as the baseline

Plus the two measurements this plan exists to resolve rather than assume:

- `kMaxShapes` confirmed on Impeller-Vulkan, Impeller-GLES and Metal (Task 1)
- the backdrop sampling decision recorded with captures (Task 19)

Then move to sub-project 2, the tier engine.
