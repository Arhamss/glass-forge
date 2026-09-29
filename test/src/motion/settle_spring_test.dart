import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/motion/settle_spring.dart';

/// Owns one controller in whatever domain a test asks for, and records
/// every Reduce Motion change it hears.
class _Host extends StatefulWidget {
  const _Host({super.key});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host>
    with SingleTickerProviderStateMixin, ReduceMotionSnap {
  late final AnimationController controller = AnimationController(
    vsync: this,
  );
  final List<bool> heard = [];

  @override
  void didChangeReduceMotion({required bool reduceMotion}) {
    heard.add(reduceMotion);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  final key = GlobalKey<_HostState>();

  testWidgets(
    'a 0-to-1 fraction settles within half a pixel of a 200 px travel',
    (tester) async {
      await tester.pumpWidget(_Host(key: key));
      final state = key.currentState!;
      state.controller.settleTo(state.context, 1, pixelsPerUnit: 200);
      await tester.pumpAndSettle();
      // The expected value is the target itself, not anything the spring
      // computed: half a pixel of a 200 px travel is 0.0025.
      expect(state.controller.value, closeTo(1, 0.5 / 200));
    },
  );

  testWidgets('Reduce Motion jumps straight to the target', (tester) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    await tester.pumpWidget(_Host(key: key));
    final state = key.currentState!;
    state.controller.settleTo(state.context, 0.7, pixelsPerUnit: 100);
    expect(state.controller.value, 0.7);
    expect(state.controller.isAnimating, isFalse);
  });

  testWidgets('no travel at all jumps rather than springing', (tester) async {
    await tester.pumpWidget(_Host(key: key));
    final state = key.currentState!;
    state.controller.settleTo(state.context, 0.4, pixelsPerUnit: 0);
    expect(state.controller.value, 0.4);
  });

  testWidgets('ReduceMotionSnap hears Reduce Motion turn on and off, and '
      'stops listening once disposed', (tester) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_Host(key: key));
    final heard = key.currentState!.heard;

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    await tester.pump();
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    await tester.pump();
    expect(heard, [true, false]);

    await tester.pumpWidget(const SizedBox.shrink());
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    await tester.pump();
    expect(heard, [true, false]);
  });
}
