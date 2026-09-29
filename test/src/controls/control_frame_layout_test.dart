import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/controls/control_frame.dart';
import 'package:glass_forge/src/controls/glass_button.dart';
import 'package:glass_forge/src/controls/glass_switch.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

// How a control sizes itself in loose space. The frame grows the hit area
// to 44 x 44 around the control's own visual; it must never grow it past
// that into whatever space the parent happens to offer. A `Center` with no
// size factors did exactly that: a button in a start-aligned column spanned
// the whole row, and a switch in `Align(topLeft)` sat in the middle of the
// screen with the whole screen as its hit area.

/// A material that renders nothing, so the composite pass is skipped
/// outside Impeller -- see `glass_button_test.dart`.
const GlassMaterial _inert = GlassMaterial(
  frost: 0,
  edgeRefraction: 0,
  highlight: 0,
);

Widget _screen(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: GlassLayer(
    tier: GeometryTier.none,
    material: _inert,
    child: child,
  ),
);

/// The size of the visual the frame found by [frame] wraps.
Size _visualSize(WidgetTester tester, Finder frame) {
  final center = find
      .descendant(of: frame, matching: find.byType(Center))
      .first;
  return tester.renderObject<RenderPositionedBox>(center).child!.size;
}

Size _atLeast44(Size size) => Size(
  size.width < GlassControlFrame.minimumExtent
      ? GlassControlFrame.minimumExtent
      : size.width,
  size.height < GlassControlFrame.minimumExtent
      ? GlassControlFrame.minimumExtent
      : size.height,
);

void main() {
  testWidgets('a button in a start-aligned column keeps its own width', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        ListView(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassButton(onPressed: () {}, child: const Text('Go')),
              ],
            ),
          ],
        ),
      ),
    );

    final frame = find.byType(GlassControlFrame);
    final rect = tester.getRect(frame);
    expect(rect.left, 0);
    expect(rect.size, _atLeast44(_visualSize(tester, frame)));
    expect(rect.width, lessThan(200));
  });

  testWidgets(
    'a switch in Align(topLeft) sits at the top-left with a hit area of '
    'max(size, 44 x 44)',
    (tester) async {
      var toggles = 0;
      await tester.pumpWidget(
        _screen(
          Align(
            alignment: Alignment.topLeft,
            child: GlassSwitch(value: false, onChanged: (_) => toggles++),
          ),
        ),
      );

      final frame = find.byType(GlassControlFrame);
      final rect = tester.getRect(frame);
      expect(rect.topLeft, Offset.zero);
      // 64 x 28 track: 64 wide, grown to 44 tall.
      expect(rect.size, const Size(64, 44));

      // Well outside the hit area: nothing happens.
      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      expect(toggles, 0);

      await tester.tapAt(rect.center);
      await tester.pump();
      expect(toggles, 1);
    },
  );
}
