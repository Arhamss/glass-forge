import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/glass_inset_surface.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/glass_static_surface.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_zones.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_zones_scope.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';

const _shape = GlassRoundedRectangle(
  radius: BorderRadius.all(Radius.circular(16)),
);

/// A chrome bar pinned at the bottom, and a content card whose top is driven
/// by [cardTop], so a test can slide it under the bar and back out.
Widget _scene(GlassZones zones, ValueNotifier<double> cardTop) {
  return MaterialApp(
    home: GlassZonesScope(
      zones: zones,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 64,
            child: KitGlassLayer(
              priority: GlassPriority.chrome,
              shape: _shape,
              child: SizedBox.expand(),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: cardTop,
            builder: (context, top, child) => Positioned(
              left: 0,
              right: 0,
              top: top,
              height: 80,
              child: child!,
            ),
            child: const KitGlassLayer(
              priority: GlassPriority.content,
              shape: _shape,
              child: Text('caption'),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('content goes static only while it is under chrome', (
    tester,
  ) async {
    final zones = GlassZones();
    final cardTop = ValueNotifier<double>(100);
    addTearDown(zones.dispose);
    addTearDown(cardTop.dispose);

    await tester.pumpWidget(_scene(zones, cardTop));
    await tester.pump();
    expect(find.byType(GlassLayer), findsNWidgets(2));
    expect(find.byType(GlassStaticSurface), findsNothing);

    cardTop.value =
        tester.view.physicalSize.height / tester.view.devicePixelRatio - 100;
    await tester.pump();
    await tester.pump();
    expect(find.byType(GlassLayer), findsOneWidget);
    expect(find.byType(GlassStaticSurface), findsOneWidget);
    expect(find.text('caption'), findsOneWidget);

    cardTop.value = 100;
    await tester.pump();
    await tester.pump();
    expect(find.byType(GlassLayer), findsNWidgets(2));
  });

  testWidgets('forcing static renders every kit layer without a pass', (
    tester,
  ) async {
    final zones = GlassZones()..forceStatic = true;
    final cardTop = ValueNotifier<double>(100);
    addTearDown(zones.dispose);
    addTearDown(cardTop.dispose);

    await tester.pumpWidget(_scene(zones, cardTop));
    await tester.pump();

    expect(find.byType(GlassLayer), findsNothing);
    expect(find.byType(GlassStaticSurface), findsNWidgets(2));
  });

  testWidgets('with no zones in scope, a kit layer is simply live glass', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 40,
            child: KitGlassLayer(
              priority: GlassPriority.chrome,
              shape: _shape,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(GlassLayer), findsOneWidget);
  });

  testWidgets('a kit layer inside another paints an inset, never a pass', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: KitGlassLayer(
              priority: GlassPriority.overlay,
              shape: _shape,
              child: Center(
                child: SizedBox(
                  width: 120,
                  height: 44,
                  child: KitGlassLayer(
                    priority: GlassPriority.content,
                    shape: _shape,
                    child: Text('inner'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(GlassLayer), findsOneWidget);
    expect(find.byType(GlassInsetSurface), findsOneWidget);
    expect(find.text('inner'), findsOneWidget);
  });

  testWidgets('removing an overlapping layer does not rebuild a locked tree', (
    tester,
  ) async {
    final zones = GlassZones();
    final showBar = ValueNotifier<bool>(true);
    addTearDown(zones.dispose);
    addTearDown(showBar.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GlassZonesScope(
          zones: zones,
          child: ValueListenableBuilder<bool>(
            valueListenable: showBar,
            builder: (context, show, _) => Stack(
              children: [
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 200,
                  child: KitGlassLayer(
                    priority: GlassPriority.content,
                    shape: _shape,
                    child: SizedBox.expand(),
                  ),
                ),
                if (show)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 100,
                    height: 64,
                    child: KitGlassLayer(
                      priority: GlassPriority.chrome,
                      shape: _shape,
                      child: SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(GlassStaticSurface), findsOneWidget);

    showBar.value = false;
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pump();
    expect(find.byType(GlassStaticSurface), findsNothing);
  });
}
