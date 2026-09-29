import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/controls/control_frame.dart';

Widget _onLayer(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: GlassLayer(
    tier: GeometryTier.none,
    child: Center(
      child: SizedBox(width: 300, child: Center(child: child)),
    ),
  ),
);

/// The presence the control's one `Glass` renders at: an `Opacity` never
/// reaches glass, so this is the only thing that can dim it.
double? _glassPresence(WidgetTester tester) =>
    GlassPresenceScope.maybeOf(tester.element(find.byType(Glass)))?.value;

void main() {
  final disabled = <String, Widget>{
    'button': const GlassButton(onPressed: null, child: Text('Go')),
    'switch': const GlassSwitch(value: true, onChanged: null),
    'slider': const GlassSlider(value: 0.5, onChanged: null),
    'segmented control': const GlassSegmentedControl<int>(
      segments: [
        GlassSegment(value: 0, label: Text('A')),
        GlassSegment(value: 1, label: Text('B')),
      ],
      selected: 0,
      onChanged: null,
    ),
    'text field': const GlassTextField(enabled: false),
  };

  for (final entry in disabled.entries) {
    testWidgets('a disabled ${entry.key} dims its glass, not only its paint', (
      tester,
    ) async {
      await tester.pumpWidget(_onLayer(entry.value));
      expect(_glassPresence(tester), GlassControlFrame.disabledOpacity);
    });
  }

  testWidgets('an enabled control leaves its glass at full presence', (
    tester,
  ) async {
    await tester.pumpWidget(
      _onLayer(GlassSwitch(value: true, onChanged: (_) {})),
    );
    expect(_glassPresence(tester), isNull);
  });

  testWidgets('under an enclosing presence the two multiply', (tester) async {
    final outer = AnimationController(vsync: tester, value: 0.5);
    addTearDown(outer.dispose);
    await tester.pumpWidget(
      _onLayer(
        GlassPresence(
          presence: outer,
          child: const GlassSwitch(value: true, onChanged: null),
        ),
      ),
    );
    expect(_glassPresence(tester), closeTo(0.5 * 0.4, 1e-9));
  });

  testWidgets('disabled controls under one presence share one presence '
      'object, so they share one backdrop pass', (tester) async {
    await tester.pumpWidget(
      _onLayer(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassSwitch(value: true, onChanged: null),
            GlassSwitch(value: false, onChanged: null),
          ],
        ),
      ),
    );
    final glasses = find.byType(Glass);
    expect(
      GlassPresenceScope.maybeOf(tester.element(glasses.first)),
      isNotNull,
    );
    expect(
      GlassPresenceScope.maybeOf(tester.element(glasses.first)),
      same(GlassPresenceScope.maybeOf(tester.element(glasses.last))),
    );
  });

  testWidgets("toggling a button's onPressed keeps its InteractiveGlass", (
    tester,
  ) async {
    final enabled = ValueNotifier<bool>(true);
    addTearDown(enabled.dispose);
    await tester.pumpWidget(
      _onLayer(
        ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (context, on, _) => GlassButton(
            onPressed: on ? () {} : null,
            child: const Text('Go'),
          ),
        ),
      ),
    );
    final before = tester.state(find.byType(InteractiveGlass));
    enabled.value = false;
    await tester.pump();
    expect(find.byType(InteractiveGlass), findsOneWidget);
    expect(tester.state(find.byType(InteractiveGlass)), same(before));
  });
}
