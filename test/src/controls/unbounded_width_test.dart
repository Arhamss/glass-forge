import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

Widget _inRow(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Overlay(
    initialEntries: [
      OverlayEntry(
        builder: (context) => GlassLayer(
          tier: GeometryTier.none,
          child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [child]),
          ),
        ),
      ),
    ],
  ),
);

void main() {
  final controls = <String, Widget>{
    'GlassSlider': GlassSlider(value: 0.5, onChanged: (_) {}),
    'GlassSegmentedControl': GlassSegmentedControl<int>(
      segments: const [
        GlassSegment(value: 0, label: Text('A')),
        GlassSegment(value: 1, label: Text('B')),
      ],
      selected: 0,
      onChanged: (_) {},
    ),
    'GlassTextField': const GlassTextField(),
  };
  for (final entry in controls.entries) {
    testWidgets('${entry.key} in an unbounded Row names itself and the fix', (
      tester,
    ) async {
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) => errors.add('${details.exception}');
      try {
        await tester.pumpWidget(_inRow(entry.value));
      } finally {
        FlutterError.onError = previous;
      }
      expect(
        errors.where(
          (e) => e.contains(entry.key) && e.contains('wrap it in Expanded'),
        ),
        isNotEmpty,
      );
    });
  }
}
