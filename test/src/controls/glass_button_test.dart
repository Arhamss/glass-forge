import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/controls/glass_button.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/motion/interactive_glass.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

/// A material that renders nothing, so the composite pass is skipped — see
/// `interactive_glass_test.dart`'s own `_inert` for why this is needed
/// outside Impeller.
const GlassMaterial _inert = GlassMaterial(
  frost: 0,
  edgeRefraction: 0,
  highlight: 0,
);

/// [child] in a layer, either on content or, with [onGlass], nested inside
/// a real `Glass` so `GlassHostScope.isOnGlass` reads true for it.
Widget _harness({
  required Widget child,
  bool onGlass = false,
  Size layerSize = const Size(200, 200),
}) {
  final content = onGlass
      ? Glass(
          shape: const GlassOval(),
          child: Center(child: child),
        )
      : Center(child: child);
  return Directionality(
    textDirection: TextDirection.ltr,
    child: GlassLayer(
      tier: GeometryTier.none,
      material: _inert,
      child: SizedBox(
        width: layerSize.width,
        height: layerSize.height,
        child: content,
      ),
    ),
  );
}

void main() {
  testWidgets('the callback fires on tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(
        child: GlassButton(onPressed: () => taps++, child: const Text('Go')),
      ),
    );

    await tester.tap(find.byType(GlassButton));
    await tester.pump();

    expect(taps, 1);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'a disabled button never fires and never builds a press response',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          child: const GlassButton(onPressed: null, child: Text('Go')),
        ),
      );

      // No `InteractiveGlass` at all: a disabled button has nothing that
      // could scale on press, rather than one that scales and is merely
      // told not to.
      expect(find.byType(InteractiveGlass), findsNothing);

      // Neither a synthetic tap nor a raw pointer down-and-up throws —
      // there is no `onTap` and no `onActivate` registered to call.
      await tester.tap(find.byType(GlassButton));
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(GlassButton)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a text child names the button when no label is given', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(
        child: GlassButton(onPressed: () {}, child: const Text('Go')),
      ),
    );

    expect(
      tester.getSemantics(find.byType(GlassButton)),
      isSemantics(
        label: 'Go',
        isButton: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('semantics report a button, enabled, with the label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(
        child: GlassButton(
          onPressed: () {},
          semanticLabel: 'Continue',
          child: const Text('Continue'),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(GlassButton)),
      isSemantics(
        label: 'Continue',
        isButton: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('semantics report a disabled button', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(
        child: const GlassButton(
          onPressed: null,
          semanticLabel: 'Continue',
          child: Text('Continue'),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(GlassButton)),
      isSemantics(label: 'Continue', isButton: true, isEnabled: false),
    );
    handle.dispose();
  });

  testWidgets('a toggled button reports its state, on and off', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    for (final on in [true, false]) {
      await tester.pumpWidget(
        _harness(
          child: GlassButton(
            onPressed: () {},
            toggled: on,
            child: const Text('Mute'),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(GlassButton)),
        isSemantics(
          isButton: true,
          hasToggledState: true,
          isToggled: on,
        ),
      );
    }

    await tester.pumpWidget(
      _harness(
        child: GlassButton.icon(
          onPressed: () {},
          semanticLabel: 'Favourite',
          toggled: true,
          icon: const SizedBox(width: 20, height: 20),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(GlassButton)),
      isSemantics(
        label: 'Favourite',
        hasToggledState: true,
        isToggled: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('a button with no toggled value reports no toggle state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(
        child: GlassButton(onPressed: () {}, child: const Text('Go')),
      ),
    );
    // A tristate: `none` — no toggle state at all — is what null must
    // produce, where `false` would announce a button that is off.
    final toggled = tester
        .getSemantics(find.byType(GlassButton))
        .flagsCollection
        .isToggled;
    expect(toggled.toBoolOrNull(), isNull);
    handle.dispose();
  });

  testWidgets('Enter and Space activate a focused button', (tester) async {
    var taps = 0;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      _harness(
        child: GlassButton(
          onPressed: () => taps++,
          focusNode: focusNode,
          child: const Text('Go'),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 2);

    await tester.pumpAndSettle();
  });

  testWidgets(
    "a 24 px icon button's hit area is 44x44 while its glass stays smaller",
    (tester) async {
      await tester.pumpWidget(
        _harness(
          child: GlassButton.icon(
            onPressed: () {},
            semanticLabel: 'Add',
            icon: const SizedBox(width: 24, height: 24),
          ),
        ),
      );

      final frameSize = tester.getSize(find.byType(GlassButton));
      expect(frameSize.width, greaterThanOrEqualTo(44));
      expect(frameSize.height, greaterThanOrEqualTo(44));

      final glassSize = tester.getSize(
        find.descendant(
          of: find.byType(GlassButton),
          matching: find.byType(Glass),
        ),
      );
      expect(glassSize.width, lessThan(44));
      expect(glassSize.height, lessThan(44));
    },
  );

  testWidgets('exactly one Glass on content', (tester) async {
    await tester.pumpWidget(
      _harness(
        child: GlassButton(onPressed: () {}, child: const Text('Go')),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(GlassButton),
        matching: find.byType(Glass),
      ),
      findsOneWidget,
    );
  });

  testWidgets('zero Glass under GlassHostScope', (tester) async {
    await tester.pumpWidget(
      _harness(
        onGlass: true,
        child: GlassButton(onPressed: () {}, child: const Text('Go')),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(GlassButton),
        matching: find.byType(Glass),
      ),
      findsNothing,
    );
  });

  testWidgets('Reduce Motion makes the painted press instant', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);

    await tester.pumpWidget(
      _harness(
        onGlass: true,
        child: GlassButton(onPressed: () {}, child: const Text('Go')),
      ),
    );

    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.duration, Duration.zero);
  });

  testWidgets('glow: false keeps a press off the shared glow channel', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        layerSize: const Size(64, 64),
        child: GlassButton(
          onPressed: () {},
          glow: false,
          child: const Text('Go'),
        ),
      ),
    );
    final layer = tester.renderObject<RenderGlassLayer>(
      find.byType(GlassLayer),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(GlassButton)),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(layer.glow.strength, 0, reason: 'glow: false still glowed');

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a press still lights the shared channel by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        layerSize: const Size(64, 64),
        child: GlassButton(onPressed: () {}, child: const Text('Go')),
      ),
    );
    final layer = tester.renderObject<RenderGlassLayer>(
      find.byType(GlassLayer),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(GlassButton)),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(layer.glow.strength, greaterThan(0), reason: 'never glowed');

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
