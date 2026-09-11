import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/constants/asset_paths.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/buttons/glass_button.dart';

import '../../../../helpers/test_app.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget button, {
  double textScale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    testApp(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Center(
            child: Padding(padding: const EdgeInsets.all(16), child: button),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a primary button reports a tap', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      GlassButton.primary(label: 'Save', onPressed: () => taps++),
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('a secondary button reports a tap', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      GlassButton.secondary(
        label: 'Share',
        icon: AssetPaths.shareNetwork,
        onPressed: () => taps++,
      ),
    );

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('without a callback it reads as disabled', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const GlassButton.primary(label: 'Save', onPressed: null),
    );

    expect(
      tester.getSemantics(find.byType(GlassButton)),
      isSemantics(
        label: 'Save',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );

    await tester.tap(find.text('Save'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('while loading it spins, keeps its width, and ignores taps', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      GlassButton.primary(label: 'Get directions', onPressed: () => taps++),
    );
    final idleWidth = tester.getSize(find.byType(GlassButton)).width;

    await _pump(
      tester,
      GlassButton.primary(
        label: 'Get directions',
        onPressed: () => taps++,
        isLoading: true,
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.getSize(find.byType(GlassButton)).width, idleWidth);

    await tester.tap(find.byType(GlassButton));
    await tester.pump(const Duration(milliseconds: 300));
    expect(taps, 0);
  });

  testWidgets('fits a 320 pt screen at twice the text size', (tester) async {
    for (final expand in [false, true]) {
      await _pump(
        tester,
        GlassButton.primary(
          label: 'Get directions to the harbour',
          icon: AssetPaths.shareNetwork,
          expand: expand,
          onPressed: () {},
        ),
        textScale: 2,
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);

      await _pump(
        tester,
        GlassButton.secondary(
          label: 'Remove from your saved places',
          icon: AssetPaths.bookmarkSimple,
          expand: expand,
          onPressed: () {},
        ),
        textScale: 2,
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
