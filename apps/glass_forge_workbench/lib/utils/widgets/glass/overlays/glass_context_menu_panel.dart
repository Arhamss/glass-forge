import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/house_glass.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_context_action.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_context_menu_row.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';

class GlassContextMenuPanel extends StatelessWidget {
  const GlassContextMenuPanel({
    required this.actions,
    required this.onSelected,
    super.key,
  });

  final List<GlassContextAction> actions;
  final ValueChanged<GlassContextAction> onSelected;

  static const double _radius = 20;

  static const _shape = GlassSuperellipse(
    radius: BorderRadius.all(Radius.circular(_radius)),
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // Painted before the glass, so the glass bends it too and the menu
      // reads as lifted off the dimmed app.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: const [
          BoxShadow(
            color: AppColors.glassShadow,
            blurRadius: 28,
            offset: Offset(0, 10),
            spreadRadius: -6,
          ),
        ],
      ),
      child: KitGlassLayer(
        material: HouseGlass.overlayOf(context),
        priority: GlassPriority.overlay,
        shape: _shape,
        child: ColoredBox(
          color: AppColors.glassMessageScrim,
          // A popup route sits outside every Material, so the app's fallback
          // text style would otherwise show through.
          child: DefaultTextStyle(
            style: context.body,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0)
                      const ColoredBox(
                        color: AppColors.hairline,
                        child: SizedBox(height: 1),
                      ),
                    GlassContextMenuRow(
                      action: actions[i],
                      onTap: () => onSelected(actions[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
