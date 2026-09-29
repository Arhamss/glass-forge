import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/design/glass_motion_defaults.dart';
import 'package:glass_forge/src/design/glass_surface.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/design/glass_tint.dart';
import 'package:glass_forge/src/design/glass_tokens.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';
import 'package:glass_forge/src/widgets/glass_presence.dart';

const Color _white = Color(0xFFFFFFFF);
const Color _black = Color(0xFF000000);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness platformBrightness = Brightness.light,
}) {
  return tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(platformBrightness: platformBrightness),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: GlassLayer(child: Center(child: child)),
      ),
    ),
  );
}

Color? _labelColorAt(WidgetTester tester, Finder finder) {
  return DefaultTextStyle.of(tester.element(finder)).style.color;
}

/// How opaque [finder] is actually drawn: every [FadeTransition] above it,
/// multiplied together.
double _drawnOpacity(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  for (final widget in tester.widgetList(
    find.ancestor(of: finder, matching: find.byType(FadeTransition)),
  )) {
    opacity *= (widget as FadeTransition).opacity.value;
  }
  return opacity;
}

void main() {
  group('presence', () {
    testWidgets(
      "a surface's content fades with the presence around it, so it never "
      'floats on glass that has gone',
      (tester) async {
        final presence = AnimationController(vsync: tester, value: 0.25);
        addTearDown(presence.dispose);
        await _pump(
          tester,
          SizedBox(
            width: 320,
            height: 120,
            child: GlassPresence(
              presence: presence,
              child: const GlassSurface.card(child: Text('content')),
            ),
          ),
        );
        expect(_drawnOpacity(tester, find.text('content')), 0.25);

        presence.value = 0;
        await tester.pump();
        expect(_drawnOpacity(tester, find.text('content')), 0);
      },
    );

    testWidgets('with no presence around it the content is fully drawn', (
      tester,
    ) async {
      await _pump(
        tester,
        const SizedBox(
          width: 320,
          height: 120,
          child: GlassSurface.card(child: Text('content')),
        ),
      );
      expect(_drawnOpacity(tester, find.text('content')), 1);
    });
  });

  testWidgets('a surface renders its child with no theme in the tree', (
    tester,
  ) async {
    await _pump(
      tester,
      const SizedBox(
        width: 320,
        height: 120,
        child: GlassSurface.card(child: Text('content')),
      ),
    );
    expect(find.text('content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a small control flips its labels where a large sheet does not', (
    tester,
  ) async {
    // The same rule as `glass_surfaces_test.dart`, one layer up: what the
    // size gate decides has to survive being wired through a widget's
    // constraints and come out as the colour text is actually drawn in.
    // Both surfaces sit over the same dark backdrop in the same light
    // platform scheme.
    await _pump(
      tester,
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 160,
            height: 44,
            child: GlassSurface.control(
              backdrop: _black,
              child: Text('control'),
            ),
          ),
          SizedBox(
            width: 360,
            height: 400,
            child: GlassSurface.sheet(
              backdrop: _black,
              child: Text('sheet'),
            ),
          ),
        ],
      ),
    );

    expect(_labelColorAt(tester, find.text('control')), _white);
    expect(_labelColorAt(tester, find.text('sheet')), _black);
  });

  testWidgets('an unbounded surface is treated as large, not as tiny', (
    tester,
  ) async {
    // `constraints.biggest` is infinite on an unbounded axis. Reading that
    // as a small size would make a surface that can grow without limit flip
    // its scheme, which is the one direction the gate must never go.
    await _pump(
      tester,
      const Align(
        alignment: Alignment.topLeft,
        child: GlassSurface.control(
          backdrop: _black,
          child: Text('loose'),
        ),
      ),
    );
    expect(_labelColorAt(tester, find.text('loose')), _black);
  });

  testWidgets('a themed override reaches the rendered material', (
    tester,
  ) async {
    // The theme is only worth having if a value set at the top of the tree
    // arrives at the render object at the bottom of it.
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: GlassTheme(
            data: GlassThemeData(
              surfaces: GlassSurfaces(
                card: GlassSurfaceSpec(
                  blur: GlassBlurStep.ultra,
                  tint: GlassTintStep.opaque,
                  radius: GlassRadiusStep.capsule,
                  depth: GlassDepthStep.flush,
                  adaptation: GlassAdaptation.none,
                  motion: GlassMotionRole.present,
                  minimumContrast: 3,
                ),
              ),
            ),
            child: GlassLayer(
              child: Center(
                child: SizedBox(
                  width: 200,
                  height: 60,
                  child: GlassSurface.card(child: Text('themed')),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final glass = tester.widget<Glass>(find.byType(Glass));
    expect(glass.material!.tintOpacity, GlassTintRamp.appleLight.opaque);
    expect(
      glass.material!.frost,
      const GlassBlurScale().factorOf(GlassBlurStep.ultra) *
          GlassMaterial.regular(brightness: Brightness.light).frost,
    );
    expect(
      (glass.shape as GlassSuperellipse).radius.topLeft.x,
      double.infinity,
    );
  });

  testWidgets("a passed material replaces the role's on the Glass", (
    tester,
  ) async {
    const material = GlassMaterial(frost: 2, tintOpacity: 0.3);
    await _pump(
      tester,
      const SizedBox(
        width: 300,
        height: 62,
        child: GlassSurface.navigationBar(
          material: material,
          child: SizedBox.shrink(),
        ),
      ),
    );
    expect(tester.widget<Glass>(find.byType(Glass)).material, material);
  });

  testWidgets("no material passed keeps the role's", (tester) async {
    // The expected value comes from the theme, not from the surface under
    // test, so a surface that dropped the role's material would not match.
    late GlassSurfaceStyle role;
    await _pump(
      tester,
      SizedBox(
        width: 300,
        height: 62,
        child: Builder(
          builder: (context) {
            role = GlassTheme.surfaceOf(
              context,
              GlassSurfaceRole.navigationBar,
              size: const Size(300, 62),
            );
            return const GlassSurface.navigationBar(
              child: SizedBox.shrink(),
            );
          },
        ),
      ),
    );
    final glass = tester.widget<Glass>(find.byType(Glass));
    expect(glass.material, role.material);
    expect(glass.material, isNot(const GlassMaterial()));
  });

  testWidgets('a flush role skips the shadow pass entirely', (tester) async {
    // An empty shadow list is meant to cost nothing, not to paint a
    // transparent shadow. The absence of the painter is the observable form
    // of that.
    await _pump(
      tester,
      const SizedBox(
        width: 300,
        height: 300,
        child: GlassSurface.scrim(child: SizedBox.shrink()),
      ),
    );
    expect(find.byType(CustomPaint), findsNothing);

    await _pump(
      tester,
      const SizedBox(
        width: 300,
        height: 120,
        child: GlassSurface.card(child: SizedBox.shrink()),
      ),
    );
    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets('every constructor takes a material that replaces the role '
      'material', (tester) async {
    const custom = GlassMaterial(tint: Color(0xFFFF2200), tintOpacity: 0.3);
    final surfaces = <Widget>[
      const GlassSurface(
        role: GlassSurfaceRole.card,
        material: custom,
        child: Text('0'),
      ),
      const GlassSurface.navigationBar(material: custom, child: Text('1')),
      const GlassSurface.sheet(material: custom, child: Text('2')),
      const GlassSurface.card(material: custom, child: Text('3')),
      const GlassSurface.control(material: custom, child: Text('4')),
      const GlassSurface.scrim(material: custom, child: Text('5')),
    ];
    for (var i = 0; i < surfaces.length; i++) {
      await _pump(
        tester,
        SizedBox(width: 200, height: 60, child: surfaces[i]),
      );
      final glass = find.ancestor(
        of: find.text('$i'),
        matching: find.byType(Glass),
      );
      expect(tester.widget<Glass>(glass).material, custom, reason: '$i');
    }
  });
}
