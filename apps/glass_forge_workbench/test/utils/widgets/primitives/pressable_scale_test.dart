import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/constants/app_motion.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/pressable_scale.dart';

import '../../../helpers/test_app.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => testApp(
  MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Center(child: child),
  ),
);

double _scale(WidgetTester tester) =>
    tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

void main() {
  testWidgets('scales down while pressed and fires once on release', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        PressableScale(
          onTap: () => taps++,
          child: const SizedBox.square(dimension: 80),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await tester.pump(AppMotion.press);
    expect(_scale(tester), lessThan(1));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(_scale(tester), 1);
  });

  testWidgets('stays still under Reduce Motion', (tester) async {
    await tester.pumpWidget(
      _host(
        PressableScale(
          onTap: () {},
          child: const SizedBox.square(dimension: 80),
        ),
        reduceMotion: true,
      ),
    );

    await tester.startGesture(tester.getCenter(find.byType(PressableScale)));
    await tester.pump(AppMotion.press);
    expect(_scale(tester), 1);
  });

  testWidgets('reads as disabled with no handler', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const PressableScale(
          onTap: null,
          semanticLabel: 'Save',
          child: SizedBox.square(dimension: 80),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(PressableScale)),
      matchesSemantics(label: 'Save', isButton: true, hasEnabledState: true),
    );
    handle.dispose();
  });
}
