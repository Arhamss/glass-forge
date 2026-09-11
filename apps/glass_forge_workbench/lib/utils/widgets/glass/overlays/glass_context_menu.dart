import 'dart:async';

import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/helpers/haptic_helper.dart';
import 'package:glass_forge_workbench/utils/helpers/reduce_motion.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_context_action.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_context_menu_route.dart';

/// Opens a glass menu of [actions] where [child] is long-pressed, over the
/// whole app.
class GlassContextMenu extends StatelessWidget {
  const GlassContextMenu({
    required this.actions,
    required this.child,
    super.key,
  });

  final List<GlassContextAction> actions;
  final Widget child;

  void _open(BuildContext context, Offset anchor) {
    AppHaptics.toggle();
    unawaited(
      Navigator.of(context, rootNavigator: true).push(
        GlassContextMenuRoute(
          actions: actions,
          anchor: anchor,
          barrierLabel: MaterialLocalizations.of(
            context,
          ).modalBarrierDismissLabel,
          reduceMotion: context.reduceMotion,
        ),
      ),
    );
  }

  // A screen reader's long press has no finger position, so the menu grows
  // out of the middle of the child instead.
  void _openFromCentre(BuildContext context) {
    final box = context.findRenderObject();
    final anchor = box is RenderBox && box.hasSize
        ? box.localToGlobal(box.size.center(Offset.zero))
        : Offset.zero;
    _open(context, anchor);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      onLongPress: () => _openFromCentre(context),
      child: GestureDetector(
        excludeFromSemantics: true,
        onLongPressStart: (details) => _open(context, details.globalPosition),
        child: child,
      ),
    );
  }
}
