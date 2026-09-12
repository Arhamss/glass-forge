import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/controls/glass_slider.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/controls/glass_stepper.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/controls/glass_switch.dart';

import '../../../../helpers/test_app.dart';

Widget _host(Widget child) => testApp(
  Scaffold(
    body: Center(child: SizedBox(width: 300, child: child)),
  ),
);

void main() {
  testWidgets('the switch flips and announces its state', (tester) async {
    final handle = tester.ensureSemantics();
    bool? reported;
    await tester.pumpWidget(
      _host(
        GlassSwitch(
          value: false,
          semanticLabel: 'Wi-Fi',
          onChanged: (value) => reported = value,
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(GlassSwitch)),
      isSemantics(label: 'Wi-Fi', hasToggledState: true, isToggled: false),
    );
    await tester.tap(find.byType(GlassSwitch));
    expect(reported, isTrue);
    handle.dispose();
  });

  testWidgets('a disabled switch ignores taps', (tester) async {
    await tester.pumpWidget(
      _host(
        const GlassSwitch(value: true, semanticLabel: 'Wi-Fi', onChanged: null),
      ),
    );
    await tester.tap(find.byType(GlassSwitch));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the slider follows a tap and steps for a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var value = 0.5;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, rebuild) => GlassSlider(
            value: value,
            semanticLabel: 'Brightness',
            onChanged: (next) => rebuild(() => value = next),
          ),
        ),
      ),
    );

    await tester.tapAt(
      tester.getTopLeft(find.byType(GlassSlider)) + const Offset(20, 22),
    );
    await tester.pump();
    expect(value, lessThan(0.1));

    tester
        .getSemantics(find.byType(GlassSlider))
        .owner!
        .performAction(
          tester.getSemantics(find.byType(GlassSlider)).id,
          SemanticsAction.increase,
        );
    await tester.pump();
    expect(value, greaterThan(0));
    handle.dispose();
  });

  testWidgets('the stepper stops at its bounds', (tester) async {
    final values = <int>[];
    await tester.pumpWidget(
      _host(
        GlassStepper(
          value: 2,
          min: 1,
          max: 2,
          decrementLabel: 'Fewer',
          incrementLabel: 'More',
          onChanged: values.add,
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('More'));
    expect(values, isEmpty);
    await tester.tap(find.bySemanticsLabel('Fewer'));
    expect(values, [1]);
  });
}
