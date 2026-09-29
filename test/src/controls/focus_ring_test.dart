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

    // The focus manager applies a change in a microtask, and the test
    // binding's pump draws no frame unless one was already scheduled. Apply
    // each change first, so one pump is the frame that must show it.
    node.requestFocus();
    FocusManager.instance.applyFocusChangesIfNeeded();
    await tester.pump();
    expect(control, paints..rrect(style: PaintingStyle.stroke));

    node.unfocus();
    FocusManager.instance.applyFocusChangesIfNeeded();
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
    FocusManager.instance.applyFocusChangesIfNeeded();
    await tester.pump();
    expect(
      tester.renderObject(find.byType(GlassButton)),
      isNot(paints..rrect(style: PaintingStyle.stroke)),
    );
  });
}
