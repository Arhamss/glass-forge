import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

/// A layer material nothing in the control role resolves to, so a control
/// that inherits the layer's material instead of resolving its own is
/// caught.
const GlassMaterial _layerMaterial = GlassMaterial(
  tint: Color(0xFFFF2200),
  tintOpacity: 0.6,
  frost: 0,
  edgeRefraction: 0,
  highlight: 0,
);

Widget _onLayer(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: GlassLayer(
    tier: GeometryTier.none,
    material: _layerMaterial,
    child: Center(child: SizedBox(width: 240, child: Center(child: child))),
  ),
);

/// The control role's material, as a control at [glass]'s size resolves
/// it — the same material its label colour was chosen against.
GlassMaterial _controlMaterial(WidgetTester tester, Finder glass) =>
    GlassTheme.surfaceOf(
      tester.element(glass),
      GlassSurfaceRole.control,
      size: tester.getSize(glass),
    ).material;

void main() {
  testWidgets("a button's glass is the control role's material, not the "
      "layer's", (tester) async {
    await tester.pumpWidget(
      _onLayer(GlassButton(onPressed: () {}, child: const Text('Go'))),
    );
    final glass = find.byType(Glass);
    expect(tester.widget<Glass>(glass).material, isNotNull);
    expect(
      tester.widget<Glass>(glass).material,
      _controlMaterial(tester, glass),
    );
  });

  testWidgets('a disabled button keeps the same material', (tester) async {
    await tester.pumpWidget(
      _onLayer(const GlassButton(onPressed: null, child: Text('Go'))),
    );
    final glass = find.byType(Glass);
    expect(
      tester.widget<Glass>(glass).material,
      _controlMaterial(tester, glass),
    );
  });

  testWidgets("a slider's thumb is the control role's material", (
    tester,
  ) async {
    await tester.pumpWidget(
      _onLayer(GlassSlider(value: 0.5, onChanged: (_) {})),
    );
    final glass = find.byType(Glass);
    expect(
      tester.widget<Glass>(glass).material,
      _controlMaterial(tester, glass),
    );
  });

  testWidgets("a segmented control's pill is the control role's material", (
    tester,
  ) async {
    await tester.pumpWidget(
      _onLayer(
        GlassSegmentedControl<int>(
          segments: const [
            GlassSegment(value: 0, label: Text('A')),
            GlassSegment(value: 1, label: Text('B')),
          ],
          selected: 0,
          onChanged: (_) {},
        ),
      ),
    );
    final glass = find.byType(Glass);
    expect(
      tester.widget<Glass>(glass).material,
      _controlMaterial(tester, glass),
    );
  });
}
