import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/controls/glass_text_field.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_host_scope.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

/// A material that renders nothing, so the composite pass is skipped — the
/// same reason `glass_button_test.dart` needs it outside Impeller.
const GlassMaterial _inert = GlassMaterial(
  frost: 0,
  edgeRefraction: 0,
  highlight: 0,
);

/// [child] in a layer, either on content or, with [onGlass], nested inside a
/// real `Glass` so `GlassHostScope.isOnGlass` reads true for it.
///
/// Wrapped in an `Overlay`: any tap on an `EditableText` with non-null
/// `selectionControls` — even the empty ones this field passes — builds a
/// `SelectionOverlay`, which asserts on an `Overlay` ancestor. A real app
/// always has one, through its `Navigator`; a bare `WidgetsApp`-less harness
/// has to add it back by hand.
///
/// [supportsSystemContextMenu] threads a `MediaQuery` reporting
/// `supportsShowingSystemContextMenu` — the other half, alongside
/// `debugDefaultTargetPlatformOverride`, of what
/// `SystemContextMenu.isSupported` checks.
Widget _harness({
  required Widget child,
  bool onGlass = false,
  bool supportsSystemContextMenu = false,
}) {
  final content = onGlass
      ? Glass(
          shape: const GlassOval(),
          child: Center(child: child),
        )
      : Center(child: child);
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(
        supportsShowingSystemContextMenu: supportsSystemContextMenu,
      ),
      child: Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (context) => GlassLayer(
              tier: GeometryTier.none,
              material: _inert,
              child: SizedBox(width: 240, height: 200, child: content),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The field's own background — a `Glass` on content, a `DecoratedBox`
/// under `GlassHostScope` — found the same way in every test that reads
/// its material or colour.
Finder _glass() => find.descendant(
  of: find.byType(GlassTextField),
  matching: find.byType(Glass),
);

void main() {
  testWidgets('typing reaches onChanged', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final values = <String>[];
    await tester.pumpWidget(
      _harness(
        child: GlassTextField(
          controller: controller,
          onChanged: values.add,
        ),
      ),
    );

    await tester.enterText(find.byType(EditableText), 'liquid glass');
    await tester.pump();

    expect(values, ['liquid glass']);
    expect(controller.text, 'liquid glass');
  });

  testWidgets('the IME submit action reaches onSubmitted', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      _harness(
        child: GlassTextField(onSubmitted: (value) => submitted = value),
      ),
    );

    await tester.enterText(find.byType(EditableText), 'go');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(submitted, 'go');
  });

  testWidgets('focus brightens the material and blur restores it', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(child: const GlassTextField()));

    final before = tester.widget<Glass>(_glass()).material!;

    await tester.tap(find.byType(GlassTextField));
    await tester.pumpAndSettle();

    final focused = tester.widget<Glass>(_glass()).material!;
    expect(
      focused.highlight,
      greaterThan(before.highlight),
      reason: 'focus should read as the glass lighting up',
    );

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final blurred = tester.widget<Glass>(_glass()).material!;
    expect(blurred.highlight, closeTo(before.highlight, 1e-9));
    expect(blurred.tintOpacity, closeTo(before.tintOpacity, 1e-9));
  });

  testWidgets('Reduce Motion makes the focus change instant', (tester) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);

    await tester.pumpWidget(_harness(child: const GlassTextField()));
    final before = tester.widget<Glass>(_glass()).material!;

    await tester.tap(find.byType(GlassTextField));
    // Exactly one frame: an instant settle needs no further pumps.
    await tester.pump();

    final focused = tester.widget<Glass>(_glass()).material!;
    expect(focused.highlight, greaterThan(before.highlight));
  });

  testWidgets('the EditableText is not a descendant of Glass', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(child: const GlassTextField(placeholder: 'Search')),
    );

    expect(
      find.descendant(of: _glass(), matching: find.byType(EditableText)),
      findsNothing,
      reason: 'the caret and selection must never be refracted',
    );
    expect(find.byType(EditableText), findsOneWidget);
  });

  testWidgets('zero Glass under GlassHostScope; the field still paints', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(onGlass: true, child: const GlassTextField()),
    );

    expect(_glass(), findsNothing);
    expect(
      find.descendant(
        of: find.byType(GlassTextField),
        matching: find.byType(DecoratedBox),
      ),
      findsOneWidget,
    );
    // The leading/trailing layer still knows it is on glass.
    expect(
      GlassHostScope.isOnGlass(
        tester.element(find.byType(EditableText)),
      ),
      isTrue,
    );
  });

  testWidgets('semantics expose a text field with the placeholder as label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(child: const GlassTextField(placeholder: 'Search')),
    );

    expect(
      tester.getSemantics(find.byType(EditableText)),
      isSemantics(label: 'Search', isTextField: true),
    );
    handle.dispose();
  });

  testWidgets(
    'shows the system context menu where the device supports it',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          supportsSystemContextMenu: true,
          child: const GlassTextField(),
        ),
      );

      expect(find.byType(SystemContextMenu), findsNothing);

      // A tap first: `showToolbar` only opens an already-existing selection
      // overlay, and that overlay isn't created until the first selection
      // change — the same order Flutter's own `system_context_menu_test.dart`
      // uses.
      await tester.tap(find.byType(GlassTextField));
      await tester.pump();

      final state = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      expect(state.showToolbar(), isTrue);
      await tester.pump();

      expect(find.byType(SystemContextMenu), findsOneWidget);
    },
    // Not `addTearDown` + a manual `debugDefaultTargetPlatformOverride`
    // assignment: the test framework's own end-of-test invariant check runs
    // before `addTearDown` callbacks do, and fails if that override is
    // still non-null at that point. `variant` resets it through the
    // framework's own `setUp`/`tearDown` hooks instead, which run in time.
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'shows nothing where the device does not support the system menu',
    (tester) async {
      // Neither `supportsSystemContextMenu` nor the target platform is
      // overridden here — both already default to a combination
      // `SystemContextMenu.isSupported` reads as unsupported, which is
      // exactly the case this test means to cover.
      await tester.pumpWidget(_harness(child: const GlassTextField()));

      await tester.tap(find.byType(GlassTextField));
      await tester.pump();

      final state = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      // No assertion, and no menu: `_resolveContextMenuBuilder` returned
      // null rather than an `EditableTextContextMenuBuilder` that would
      // have built (and asserted inside) `SystemContextMenu.editableText`
      // on an unsupported device.
      expect(state.showToolbar(), isTrue);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SystemContextMenu), findsNothing);
    },
  );

  testWidgets(
    'a custom contextMenuBuilder overrides the default',
    (tester) async {
      var built = 0;
      await tester.pumpWidget(
        _harness(
          supportsSystemContextMenu: true,
          child: GlassTextField(
            contextMenuBuilder: (context, editableTextState) {
              built++;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.tap(find.byType(GlassTextField));
      await tester.pump();

      final state = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      expect(state.showToolbar(), isTrue);
      await tester.pump();

      expect(built, 1);
      expect(find.byType(SystemContextMenu), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'a focused field inside a scroll view ends up clear of the keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) => MediaQuery.fromView(
                  view: tester.view,
                  child: Builder(
                    builder: (context) {
                      final bottomInset = MediaQuery.viewInsetsOf(
                        context,
                      ).bottom;
                      return GlassLayer(
                        tier: GeometryTier.none,
                        material: _inert,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: bottomInset),
                          child: const SingleChildScrollView(
                            child: Column(
                              children: [
                                SizedBox(height: 700),
                                GlassTextField(placeholder: 'Search'),
                                SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.byType(GlassTextField));
      await tester.pump();

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      await tester.pumpAndSettle();

      final fieldBottom = tester
          .getBottomLeft(
            find.byType(GlassTextField),
          )
          .dy;
      expect(800 - fieldBottom, greaterThanOrEqualTo(299));
    },
  );
}
