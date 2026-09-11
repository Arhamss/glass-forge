import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/features/motion/presentation/cubit/motion_state.dart';
import 'package:glass_forge_workbench/features/motion/presentation/widgets/motion_stage.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/stage_caption.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('the stage caption clears the status bar', (tester) async {
    // The stage runs edge to edge under the status bar so the glass can sit
    // beneath it. Anything pinned to its top therefore has to inset itself,
    // and this one did not: the caption printed straight through the clock.
    const statusBar = 59.0;

    await tester.pumpWidget(
      testApp(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: statusBar)),
          child: MotionStage(
            state: const MotionState(),
            onBackdropChanged: (_) {},
          ),
        ),
      ),
    );

    final top = tester.getTopLeft(find.byType(StageCaption)).dy;
    expect(
      top,
      greaterThanOrEqualTo(statusBar),
      reason: 'caption overlapped the status bar at $top',
    );
  });
}
