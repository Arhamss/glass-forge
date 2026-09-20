import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/design/glass_motion_defaults.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/design/glass_tokens.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/motion/glass_motion_controller.dart';
import 'package:glass_forge/src/motion/interactive_glass.dart';

const Size _size = Size(390, 200);

/// Pumps a probe widget under a `MediaQuery` with the given platform
/// brightness, and hands back the context it built in.
Future<BuildContext> _pumpFor(
  WidgetTester tester, {
  required Brightness platformBrightness,
  GlassThemeData? theme,
}) async {
  late BuildContext captured;
  Widget tree = Builder(
    builder: (context) {
      captured = context;
      return const SizedBox.shrink();
    },
  );
  if (theme != null) {
    tree = GlassTheme(data: theme, child: tree);
  }
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(platformBrightness: platformBrightness),
      child: Directionality(textDirection: TextDirection.ltr, child: tree),
    ),
  );
  return captured;
}

void main() {
  testWidgets('no theme still yields a usable system', (tester) async {
    // Tiering, motion and now theming are all opt-in; an app that never adds
    // a GlassTheme must get the fitted Apple system, not an empty one. The
    // check is behavioural rather than an identity comparison: the default
    // has to resolve to a material that actually puts something on screen.
    final context = await _pumpFor(
      tester,
      platformBrightness: Brightness.dark,
    );
    expect(GlassTheme.maybeOf(context), isNull);
    expect(GlassTheme.of(context), GlassTheme.fallback);

    final style = GlassTheme.surfaceOf(
      context,
      GlassSurfaceRole.card,
      size: _size,
    );
    expect(style.material.rendersAnything, isTrue);
    expect(style.material.frost, greaterThan(0));
    expect(style.brightness, Brightness.dark);
  });

  testWidgets('with no pinned brightness, glass follows the platform', (
    tester,
  ) async {
    // The reason `brightness` is nullable: this package does not own the
    // app's appearance and reads the same source Flutter's own themes start
    // from, so the two agree without either being told about the other.
    for (final brightness in Brightness.values) {
      final context = await _pumpFor(
        tester,
        platformBrightness: brightness,
        theme: const GlassThemeData(),
      );
      expect(GlassTheme.brightnessOf(context), brightness);
      expect(
        GlassTheme.materialOf(context),
        GlassMaterial.regular(brightness: brightness),
      );
    }
  });

  testWidgets('a pinned brightness wins over the platform', (tester) async {
    // A MaterialApp in themeMode.dark on a light phone. The theme's answer
    // must not be quietly overridden by the device behind its back.
    final context = await _pumpFor(
      tester,
      platformBrightness: Brightness.light,
      theme: GlassThemeData.dark,
    );
    expect(GlassTheme.brightnessOf(context), Brightness.dark);
    expect(
      GlassTheme.surfaceOf(
        context,
        GlassSurfaceRole.sheet,
        size: _size,
      ).brightness,
      Brightness.dark,
    );
  });

  test('overriding one token changes only what it names', () {
    // The point of the whole layer. A consumer who widens the thick blur
    // step must get exactly that and nothing else — not a reset radius, not
    // a different tint, not a different spring. Comparing the two resolved
    // styles field by field is what makes "only" falsifiable: put the blur
    // factor anywhere but frost and this fails.
    const base = GlassThemeData();
    const widened = GlassThemeData(
      tokens: GlassTokens(blur: GlassBlurScale(thick: 21)),
    );

    final before = base.resolve(
      GlassSurfaceRole.sheet,
      size: _size,
      platformBrightness: Brightness.light,
    );
    final after = widened.resolve(
      GlassSurfaceRole.sheet,
      size: _size,
      platformBrightness: Brightness.light,
    );

    expect(after.material.frost, isNot(before.material.frost));
    expect(
      after.material.copyWith(frost: before.material.frost),
      before.material,
    );
    expect(after.shape, before.shape);
    expect(after.motion, before.motion);
    expect(after.shadows, before.shadows);
    expect(after.labelColor, before.labelColor);
    expect(after.adaptation, before.adaptation);

    // And a role that does not use the step it named is untouched.
    expect(
      widened.resolve(
        GlassSurfaceRole.control,
        size: const Size(120, 44),
        platformBrightness: Brightness.light,
      ),
      base.resolve(
        GlassSurfaceRole.control,
        size: const Size(120, 44),
        platformBrightness: Brightness.light,
      ),
    );
  });

  test('the theme hands out the same springs the motion layer uses', () {
    // The design layer restates the motion layer's defaults, and a restated
    // constant is a constant that drifts. Reading them off the widgets
    // themselves means a change on either side has to be a change on both.
    const defaults = GlassMotionDefaults();
    const widget = InteractiveGlass(child: SizedBox.shrink());
    expect(defaults.follow, widget.followMotion);
    expect(defaults.settle, widget.settleMotion);
    expect(defaults.press, widget.pressMotion);

    final controller = GlassMotionController(vsync: const TestVSync());
    addTearDown(controller.dispose);
    expect(defaults.follow, controller.followMotion);
    expect(defaults.settle, controller.settleMotion);
    expect(defaults.press, controller.pressMotion);
  });

  test('a present spring does not overshoot', () {
    // A sheet that springs past its detent and comes back reads as a
    // mistake. This is the one default with no counterpart in the motion
    // layer, so it is the one worth pinning on its own terms.
    expect(const GlassMotionDefaults().present.bounce, lessThanOrEqualTo(0));
    expect(const GlassMotionDefaults().settle.bounce, greaterThan(0));
  });

  testWidgets('an unchanged theme does not notify', (tester) async {
    // Two equal-but-not-identical theme values must not invalidate every
    // glass surface in the tree: resolving a style walks a bisection and
    // allocates a material, and doing it per rebuild for no reason is how a
    // design system becomes the thing profiling blames.
    const data = GlassThemeData();
    const first = GlassTheme(data: data, child: SizedBox.shrink());
    // copyWith with nothing named rebuilds the value at runtime, so this is
    // a distinct object that compares equal — which is what a rebuilding
    // parent produces and what updateShouldNotify has to see through.
    final rebuilt = data.copyWith();
    final second = GlassTheme(
      data: rebuilt,
      child: const SizedBox.shrink(),
    );
    expect(identical(data, rebuilt), isFalse);
    expect(second.updateShouldNotify(first), isFalse);

    const changed = GlassThemeData(
      tokens: GlassTokens(blur: GlassBlurScale(thick: 21)),
    );
    expect(
      const GlassTheme(
        data: changed,
        child: SizedBox.shrink(),
      ).updateShouldNotify(first),
      isTrue,
    );
  });
}
