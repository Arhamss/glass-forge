import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_context_action.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_context_menu_layout.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_context_menu_panel.dart';

/// What a `GlassContextMenu` pushes: the app dimmed, and the menu grown out
/// of the point that was pressed.
class GlassContextMenuRoute extends PopupRoute<void> {
  GlassContextMenuRoute({
    required this.actions,
    required this.anchor,
    required String barrierLabel,
    bool reduceMotion = false,
  }) : _barrierLabel = barrierLabel,
       _reduceMotion = reduceMotion;

  final List<GlassContextAction> actions;

  /// Where the finger came down, in global coordinates.
  final Offset anchor;

  final String _barrierLabel;
  final bool _reduceMotion;

  static const double width = GlassContextMenuLayout.menuWidth;
  static const double _startScale = 0.9;

  @override
  Color get barrierColor => AppColors.black.withValues(alpha: 0.4);

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => _barrierLabel;

  @override
  Duration get transitionDuration =>
      _reduceMotion ? Duration.zero : AppMotion.select;

  void _select(GlassContextAction action) {
    // A second tap while the menu is on its way out would otherwise pop the
    // screen beneath it.
    if (!isCurrent) return;
    navigator?.pop();
    action.onSelected();
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return CustomSingleChildLayout(
      delegate: GlassContextMenuLayout(
        anchor: anchor,
        padding: MediaQuery.paddingOf(context),
        textDirection: Directionality.of(context),
      ),
      child: GlassContextMenuPanel(actions: actions, onSelected: _select),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Scale only, never a fade: an opacity layer over the menu's backdrop
    // pass breaks it on device. The page fills the screen, so scaling it
    // about the anchor grows the menu out of the finger.
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = AppMotion.selectCurve.transform(animation.value);
        final scale = _startScale + (1 - _startScale) * t;
        return Transform(
          transform: Matrix4.diagonal3Values(scale, scale, 1),
          origin: anchor,
          child: child,
        );
      },
      child: child,
    );
  }
}
