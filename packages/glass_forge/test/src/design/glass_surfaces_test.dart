import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/design/glass_legibility.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_tint.dart';
import 'package:glass_forge/src/design/glass_tokens.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/material/glass_variant.dart';

const Color _white = Color(0xFFFFFFFF);
const Color _black = Color(0xFF000000);

Color _worstBackdropFor(Brightness brightness) =>
    brightness == Brightness.dark ? _white : _black;

GlassSurfaceStyle _resolve(
  GlassSurfaceSpec spec, {
  required Size size,
  required Brightness brightness,
  Color? backdrop,
}) {
  return spec.resolve(
    size: size,
    platformBrightness: brightness,
    backdrop: backdrop,
  );
}

void main() {
  group('size gates the flip, exactly as Apple states it', () {
    test('a small surface flips, and the same surface large does not', () {
      // The headline rule: "small elements like navbars and tabbars… flip
      // from light to dark based on the background. Larger elements like
      // menus and sidebars adapt based on context, but they don't flip."
      // Same spec, same backdrop, same platform scheme — only the size
      // differs.
      final small = _resolve(
        GlassSurfaceSpec.control,
        size: const Size(120, 44),
        brightness: Brightness.light,
        backdrop: _black,
      );
      final large = _resolve(
        GlassSurfaceSpec.control,
        size: const Size(400, 400),
        brightness: Brightness.light,
        backdrop: _black,
      );

      expect(small.adaptation, GlassAdaptation.flip);
      expect(small.brightness, Brightness.dark);
      expect(small.labelColor, _white);

      expect(large.adaptation, GlassAdaptation.adapt);
      expect(large.brightness, Brightness.light);
      expect(large.labelColor, _black);
    });

    test('the gate is thinness, not area', () {
      // A navigation bar is enormous by area and still flips; a square that
      // covers less of the screen than it does, does not. The two sizes are
      // chosen to disagree with an area rule on purpose: the bar's 88,000
      // square pixels are more than the square's 62,500, so anything gated
      // on area gets both of these backwards.
      const bar = Size(2000, 44);
      const square = Size(250, 250);
      expect(bar.width * bar.height, greaterThan(square.width * square.height));

      expect(
        GlassSurfaceSpec.navigationBar.adaptationFor(bar, maxShortSide: 96),
        GlassAdaptation.flip,
      );
      expect(
        GlassSurfaceSpec.navigationBar.adaptationFor(square, maxShortSide: 96),
        GlassAdaptation.adapt,
      );
    });

    test('the gate demotes and never promotes', () {
      // A sheet that happened to be small must not start inverting itself.
      // Apple names menus and sidebars as things that adapt without
      // flipping, and a phone-width sidebar is still a sidebar.
      expect(
        GlassSurfaceSpec.sheet.adaptationFor(
          const Size(10, 10),
          maxShortSide: 96,
        ),
        GlassAdaptation.adapt,
      );
      expect(
        GlassSurfaceSpec.scrim.adaptationFor(
          const Size(10, 10),
          maxShortSide: 96,
        ),
        GlassAdaptation.none,
      );
    });

    test('the threshold is a token, so a consumer can move it', () {
      const tall = Size(400, 120);
      expect(
        GlassSurfaceSpec.navigationBar.adaptationFor(tall, maxShortSide: 96),
        GlassAdaptation.adapt,
      );
      expect(
        GlassSurfaceSpec.navigationBar.adaptationFor(tall, maxShortSide: 130),
        GlassAdaptation.flip,
      );
    });
  });

  group('every role keeps the contrast it promises', () {
    for (final role in GlassSurfaceRole.values) {
      for (final brightness in Brightness.values) {
        test('${role.name} in ${brightness.name}', () {
          // Resolved with no backdrop, which is the case with no adaptation
          // to fall back on, then measured against the worst backdrop that
          // scheme can face. This is the promise the tint ramp exists to
          // keep, checked per role rather than per step, so a role assigned
          // a tint step too weak for its own minimumContrast fails here.
          final spec = const GlassSurfaces().of(role);
          final style = _resolve(
            spec,
            size: const Size(390, 200),
            brightness: brightness,
          );
          final contrast = GlassLegibility.labelContrast(
            tint: style.material.tint,
            opacity: style.material.tintOpacity,
            backdrop: _worstBackdropFor(brightness),
            label: style.labelColor,
          );
          expect(
            contrast,
            greaterThanOrEqualTo(spec.minimumContrast),
            reason: '${role.name} promises ${spec.minimumContrast}:1 and '
                'delivers ${contrast.toStringAsFixed(2)}:1',
          );
        });
      }
    }
  });

  group('adaptation raises tint, and only when it has to', () {
    // The default roles already carry a tint step derived against the worst
    // case, so the raise is a no-op for them by construction. It earns its
    // keep for a consumer who asks for a thinner tint than their own
    // contrast target can support — which is exactly the mistake a design
    // system should absorb rather than render.
    final thin = GlassSurfaceSpec.card.copyWith(tint: GlassTintStep.legible);

    test('over a backdrop that needs it, the tint thickens', () {
      final style = _resolve(
        thin,
        size: const Size(390, 200),
        brightness: Brightness.dark,
        backdrop: _white,
      );
      expect(
        style.material.tintOpacity,
        greaterThan(GlassTintRamp.appleDark.legible),
      );
      expect(style.labelContrast, isNotNull);
      expect(style.labelContrast, greaterThanOrEqualTo(thin.minimumContrast));
    });

    test('over a backdrop that does not, nothing moves', () {
      final style = _resolve(
        thin,
        size: const Size(390, 200),
        brightness: Brightness.dark,
        backdrop: _black,
      );
      expect(style.material.tintOpacity, GlassTintRamp.appleDark.legible);
    });

    test('a non-adapting role stays put where an adapting one moves', () {
      // Same tint step, same target, same backdrop — the only difference is
      // the adaptation mode, so this is what makes `none` a real value
      // rather than a synonym for `adapt`.
      final fixed = GlassSurfaceSpec.scrim.copyWith(
        tint: GlassTintStep.legible,
      );
      final adapting = _resolve(
        thin,
        size: const Size(390, 200),
        brightness: Brightness.dark,
        backdrop: _white,
      );
      final unmoving = _resolve(
        fixed,
        size: const Size(390, 200),
        brightness: Brightness.dark,
        backdrop: _white,
      );
      expect(
        unmoving.material.tintOpacity,
        lessThan(adapting.material.tintOpacity),
      );
      expect(unmoving.labelContrast, lessThan(fixed.minimumContrast));
    });
  });

  test('the clear variant ignores the backdrop entirely', () {
    // Apple: clear "does not have adaptive behaviors". Not a weaker
    // adaptation — none, over anything.
    final spec = GlassSurfaceSpec.card.copyWith(variant: GlassVariant.clear);
    final overBlack = _resolve(
      spec,
      size: const Size(44, 44),
      brightness: Brightness.light,
      backdrop: _black,
    );
    final overWhite = _resolve(
      spec,
      size: const Size(44, 44),
      brightness: Brightness.light,
      backdrop: _white,
    );
    expect(overBlack.adaptation, GlassAdaptation.none);
    expect(overBlack.material, overWhite.material);
    expect(overBlack.material, GlassMaterial.clear());
  });

  test('a blur step is a ratio, so the fitted light/dark frost survives', () {
    // The tempting simplification is to store absolute sigmas. That would
    // silently throw away the fitted difference between the light and dark
    // frost (7 and 5) for every step but `regular`, which is why the ratio
    // has to be the thing that is constant across schemes and the sigma the
    // thing that is not.
    final spec = GlassSurfaceSpec.card.copyWith(blur: GlassBlurStep.thick);
    double frostFor(Brightness brightness, GlassBlurStep step) => _resolve(
      spec.copyWith(blur: step),
      size: const Size(390, 200),
      brightness: brightness,
    ).material.frost;

    final lightRegular = frostFor(Brightness.light, GlassBlurStep.regular);
    final darkRegular = frostFor(Brightness.dark, GlassBlurStep.regular);
    expect(lightRegular, isNot(darkRegular));

    expect(
      frostFor(Brightness.light, GlassBlurStep.thick) / lightRegular,
      closeTo(frostFor(Brightness.dark, GlassBlurStep.thick) / darkRegular,
          1e-9),
    );
  });

  test('blur grows with how much backdrop a role covers', () {
    // Apple's "scale blur… with element size", read as area covered: a
    // control hides a word, a bar hides a line, a sheet hides a screenful, a
    // scrim hides everything. A role assigned the wrong rung fails here.
    const tokens = GlassTokens();
    double sigmaFor(GlassSurfaceRole role) =>
        tokens.blur.sigmaOf(const GlassSurfaces().of(role).blur);

    expect(
      sigmaFor(GlassSurfaceRole.control),
      lessThan(sigmaFor(GlassSurfaceRole.navigationBar)),
    );
    expect(
      sigmaFor(GlassSurfaceRole.navigationBar),
      lessThan(sigmaFor(GlassSurfaceRole.sheet)),
    );
    expect(
      sigmaFor(GlassSurfaceRole.sheet),
      lessThan(sigmaFor(GlassSurfaceRole.scrim)),
    );
  });

  test('chrome floats above content, and a scrim floats above nothing', () {
    const tokens = GlassTokens();
    double liftFor(GlassSurfaceRole role) =>
        tokens.depth.liftOf(const GlassSurfaces().of(role).depth);

    expect(liftFor(GlassSurfaceRole.scrim), 0);
    expect(
      liftFor(GlassSurfaceRole.card),
      lessThan(liftFor(GlassSurfaceRole.navigationBar)),
    );
    expect(
      liftFor(GlassSurfaceRole.navigationBar),
      lessThan(liftFor(GlassSurfaceRole.sheet)),
    );
  });

  test('labelContrast is null when there was nothing to measure', () {
    final style = _resolve(
      GlassSurfaceSpec.card,
      size: const Size(390, 200),
      brightness: Brightness.dark,
    );
    expect(style.labelContrast, isNull);
  });

  test('naming one field of one role leaves the other four alone', () {
    final surfaces = GlassSurfaces(
      card: GlassSurfaceSpec.card.copyWith(blur: GlassBlurStep.ultra),
    );
    expect(surfaces.card.blur, GlassBlurStep.ultra);
    expect(surfaces.card.tint, GlassSurfaceSpec.card.tint);
    expect(surfaces.card.depth, GlassSurfaceSpec.card.depth);
    expect(surfaces.navigationBar, GlassSurfaceSpec.navigationBar);
    expect(surfaces.sheet, GlassSurfaceSpec.sheet);
    expect(surfaces.control, GlassSurfaceSpec.control);
    expect(surfaces.scrim, GlassSurfaceSpec.scrim);
  });
}
