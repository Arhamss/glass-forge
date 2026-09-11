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

void main() {
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

  testWidgets('a small control flips its labels where a large sheet does not',
      (tester) async {
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
}
