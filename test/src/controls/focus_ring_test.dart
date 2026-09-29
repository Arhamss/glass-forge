import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

Widget _onLayer(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: GlassLayer(
    tier: GeometryTier.none,
    child: Center(child: child),
  ),
);

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  testWidgets('a keyboard-focused control draws a focus ring; unfocused, '
      'none', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      _onLayer(
        GlassSwitch(value: false, focusNode: node, onChanged: (_) {}),
      ),
    );
    final control = tester.renderObject(find.byType(GlassSwitch));
    expect(
      control,
      isNot(paints..rrect(style: PaintingStyle.stroke)),
    );

    node.requestFocus();
    await tester.pump();
    expect(control, paints..rrect(style: PaintingStyle.stroke));

    node.unfocus();
    await tester.pump();
    await tester.pump();
    expect(
      control,
      isNot(paints..rrect(style: PaintingStyle.stroke)),
    );
  });

  testWidgets('a touch-focused control draws no ring', (tester) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      _onLayer(
        GlassButton(
          onPressed: () {},
          focusNode: node,
          child: const Text('Go'),
        ),
      ),
    );
    node.requestFocus();
    await tester.pump();
    expect(
      tester.renderObject(find.byType(GlassButton)),
      isNot(paints..rrect(style: PaintingStyle.stroke)),
    );
  });
}
