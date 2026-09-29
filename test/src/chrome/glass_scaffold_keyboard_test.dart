import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

const ValueKey<String> _bottomBarKey = ValueKey('bottomBar');

/// A 400 x 800 screen with a 60 px bottom bar and a field at the bottom of
/// a list that is only just taller than the screen.
Widget _screen() => MaterialApp(
  home: GlassScaffold(
    bottomBar: const SizedBox(key: _bottomBarKey, height: 60),
    body: ListView(
      children: const [
        SizedBox(height: 700),
        GlassTextField(placeholder: 'Search'),
        SizedBox(height: 40),
      ],
    ),
  ),
);

void main() {
  testWidgets(
    'a focused field in the body scrolls clear of the keyboard and of the '
    'bottom bar riding it',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_screen());
      await tester.pump();

      await tester.tap(find.byType(GlassTextField));
      await tester.pump();

      // The real keyboard: an inset on the view itself, not a viewport the
      // test shrank by hand.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      final barTop = tester.getTopLeft(find.byKey(_bottomBarKey)).dy;
      expect(barTop, 440, reason: 'the bar rides the 300 px keyboard');
      final fieldBottom = tester
          .getBottomLeft(
            find.byType(GlassTextField),
          )
          .dy;
      expect(
        fieldBottom,
        lessThanOrEqualTo(barTop),
        reason: 'the field must end above the bar, which sits on the keyboard',
      );
    },
  );

  testWidgets(
    "the body's MediaQuery counts the keyboard once: in the bottom padding, "
    'not again in viewInsets',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);

      MediaQueryData? body;
      await tester.pumpWidget(
        MaterialApp(
          home: GlassScaffold(
            bottomBar: const SizedBox(height: 60),
            body: Builder(
              builder: (context) {
                body = MediaQuery.of(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(body!.padding.bottom, 360);
      expect(body!.viewInsets.bottom, 0);
    },
  );

  testWidgets('with no bottom bar the body keeps the keyboard in viewInsets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);

    MediaQueryData? body;
    await tester.pumpWidget(
      MaterialApp(
        home: GlassScaffold(
          body: Builder(
            builder: (context) {
              body = MediaQuery.of(context);
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(body!.viewInsets.bottom, 300);
  });
}
