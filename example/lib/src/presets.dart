import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';

/// A named material the tuner can jump to.
class Preset {
  const Preset(this.name, this.material);

  final String name;
  final GlassMaterial material;
}

/// Clear glass first; the frosted and the playful further along.
///
/// The first preset is what the app opens on: a flat pane, crisp inside,
/// with a thin refracting lip at the edge and a fine highlight — no dark
/// contour ring, no dome. The package's `GlassMaterial.regular` and
/// `.clear()` are left out: side by side with iOS they do not look like it,
/// and a preset labelled "iOS" has to.
///
/// Frost is a blur sigma and bites hard: at 2 the backdrop is already
/// smeared. Glass that is meant to look clear keeps it below 1.
///
/// The lip is wide and gentle — a 14 px band bending 6 px — on purpose. The
/// edge band's profile is steepest where it meets the flat interior, so a
/// band that bends hard for its width draws a visible inner outline there,
/// and the glass reads as a bezelled slab. Keeping the bend well under half
/// the band's height leaves the rim bending the backdrop with no seam.
final List<Preset> presets = [
  const Preset('Liquid', glassMaterial),
  const Preset('Clear', clearMaterial),
  const Preset(
    'Frosted',
    GlassMaterial(
      thickness: 14,
      edgeRefraction: 6,
      frost: 4,
      tint: Color(0xFFFFFFFF),
      tintOpacity: 0.1,
      saturation: 1.6,
      highlight: 0.8,
    ),
  ),
  Preset('Lens', GlassMaterial.dome()),
  // Dispersion belongs where the glass bends, which on a flat pane is only
  // the rim: an edge band keeps the colour split there. Under a dome the
  // whole interior refracts, and the same split smears across all of it.
  const Preset(
    'Prism',
    GlassMaterial(
      thickness: 14,
      edgeRefraction: 22,
      frost: 0.4,
      chromaticAberration: 0.6,
      tint: Color(0xFFFFFFFF),
      tintOpacity: 0.04,
      saturation: 1.4,
      highlight: 1.5,
    ),
  ),
  const Preset(
    'Candy',
    GlassMaterial(
      thickness: 14,
      edgeRefraction: 8,
      frost: 0.6,
      chromaticAberration: 0.06,
      tint: Color(0xFFFF4F9A),
      tintOpacity: 0.2,
      saturation: 1.8,
    ),
  ),
  const Preset(
    'Smoke',
    GlassMaterial(
      thickness: 14,
      edgeRefraction: 6,
      frost: 3,
      tint: Color(0xFF000000),
      tintOpacity: 0.4,
      saturation: 0.6,
      highlight: 0.6,
    ),
  ),
];

/// The app's default, after Apple's Control Center: a light frost, a
/// neutral tint, and a deep rim that visibly bends what is behind it. The
/// rim is what makes it glass — a thick edge warping the scene through it —
/// and it can be this deep because the edge profile eases into the flat
/// interior with no seam. Frost past about 2 buries it, and then the same
/// surface reads as frosted plastic.
const GlassMaterial glassMaterial = GlassMaterial(
  thickness: 14,
  edgeRefraction: 24,
  frost: 1,
  chromaticAberration: 0.05,
  tint: Color(0xFF2A2A2E),
  tintOpacity: 0.12,
  saturation: 1.5,
  highlight: 2,
  lightDirection: Offset(-0.7071, -0.7071),
);

/// A flat pane, crisp inside, with a thin refracting lip and a fine rim.
const GlassMaterial clearMaterial = GlassMaterial(
  thickness: 14,
  edgeRefraction: 6,
  frost: 0.6,
  chromaticAberration: 0.03,
  tint: Color(0xFFFFFFFF),
  tintOpacity: 0.07,
  saturation: 1.3,
  highlight: 1.5,
);

/// The tab bar's: the default's look, a touch darker for its small labels.
const GlassMaterial chromeMaterial = GlassMaterial(
  thickness: 14,
  edgeRefraction: 20,
  frost: 2,
  chromaticAberration: 0.04,
  tint: Color(0xFF1E1E22),
  tintOpacity: 0.24,
  saturation: 1.5,
  highlight: 2,
  lightDirection: Offset(-0.7071, -0.7071),
);

/// The tab bar's selection: a clear lens that bends the bar and the photo
/// beneath it.
const GlassMaterial selectionMaterial = GlassMaterial(
  thickness: 16,
  edgeRefraction: 22,
  frost: 0.5,
  chromaticAberration: 0.08,
  tint: Color(0xFFFFFFFF),
  tintOpacity: 0.1,
  saturation: 1.3,
  highlight: 2.2,
  lightDirection: Offset(-0.7071, -0.7071),
);

/// The sheet's: frostier and darker again, because it carries a screenful
/// of labels over a busy photograph.
const GlassMaterial sheetMaterial = GlassMaterial(
  thickness: 14,
  edgeRefraction: 20,
  frost: 4,
  tint: Color(0xFF16161A),
  tintOpacity: 0.36,
  saturation: 1.6,
  highlight: 1.8,
  lightDirection: Offset(-0.7071, -0.7071),
);

/// Tints the tuner offers, as swatches.
const List<Color> tints = [
  Color(0xFFFFFFFF),
  Color(0xFF3A3A3A),
  Color(0xFF000000),
  Color(0xFF5AC8FA),
  Color(0xFF7D5CFF),
  Color(0xFFFF4F9A),
  Color(0xFFFFB340),
  Color(0xFF34C759),
];

/// Interpolates every continuous field; the two enums flip at the midpoint.
///
/// `GlassMaterial` has no `lerp` of its own — it is a description of a
/// surface, and most apps never animate between two of them. This one does,
/// so that tapping a preset morphs the glass rather than swapping it.
class GlassMaterialTween extends Tween<GlassMaterial> {
  GlassMaterialTween({super.begin, super.end});

  @override
  GlassMaterial lerp(double t) {
    final a = begin!;
    final b = end!;
    double mix(double x, double y) => lerpDouble(x, y, t)!;
    final pick = t < 0.5;
    return GlassMaterial(
      variant: pick ? a.variant : b.variant,
      profile: pick ? a.profile : b.profile,
      thickness: mix(a.thickness, b.thickness),
      edgeRefraction: mix(a.edgeRefraction, b.edgeRefraction),
      refractionSpread: mix(a.refractionSpread, b.refractionSpread),
      frost: math.max(0, mix(a.frost, b.frost)),
      chromaticAberration: mix(a.chromaticAberration, b.chromaticAberration),
      // A tint at zero opacity has no colour worth keeping, so borrow the
      // other end's. Otherwise fading Clear (white, 0) into Candy (pink)
      // passes through a pale grey-pink instead of just getting pinker.
      tint: Color.lerp(
        a.tintOpacity == 0 ? b.tint : a.tint,
        b.tintOpacity == 0 ? a.tint : b.tint,
        t,
      )!,
      tintOpacity: mix(a.tintOpacity, b.tintOpacity).clamp(0, 1),
      saturation: math.max(0, mix(a.saturation, b.saturation)),
      highlight: math.max(0, mix(a.highlight, b.highlight)),
      lightDirection: Offset.lerp(a.lightDirection, b.lightDirection, t)!,
      contour: math.max(0, mix(a.contour, b.contour)),
    );
  }
}

/// The Dart that builds [material], naming only what differs from the
/// defaults.
String dartFor(GlassMaterial material) {
  const d = GlassMaterial();
  final lines = <String>[];
  void add(String name, Object value) => lines.add('  $name: $value,');
  String n(double v) {
    final fixed = v.toStringAsFixed(2);
    return fixed.contains('.')
        ? fixed
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '')
        : fixed;
  }

  if (material.variant != d.variant) {
    add('variant', 'GlassVariant.${material.variant.name}');
  }
  if (material.profile != d.profile) {
    add('profile', 'GlassProfile.${material.profile.name}');
  }
  void num(String name, double value, double base) {
    if ((value - base).abs() > 0.005) {
      add(name, n(value));
    }
  }

  num('thickness', material.thickness, d.thickness);
  num('edgeRefraction', material.edgeRefraction, d.edgeRefraction);
  num('refractionSpread', material.refractionSpread, d.refractionSpread);
  num('frost', material.frost, d.frost);
  num(
    'chromaticAberration',
    material.chromaticAberration,
    d.chromaticAberration,
  );
  if (material.tintOpacity > 0.005) {
    final hex = material.tint.toARGB32().toRadixString(16).toUpperCase();
    add('tint', 'Color(0x${hex.padLeft(8, '0')})');
  }
  num('tintOpacity', material.tintOpacity, d.tintOpacity);
  num('saturation', material.saturation, d.saturation);
  num('highlight', material.highlight, d.highlight);
  final light = material.lightDirection;
  if ((light - d.lightDirection).distance > 0.01) {
    add('lightDirection', 'Offset(${n(light.dx)}, ${n(light.dy)})');
  }
  num('contour', material.contour, d.contour);

  if (lines.isEmpty) {
    return 'const GlassMaterial()';
  }
  return 'const GlassMaterial(\n${lines.join('\n')}\n)';
}
