import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/house_glass/presentation/cubit/house_glass_cubit.dart';
import 'package:glass_forge_workbench/features/material_studio/presentation/widgets/studio/studio_title.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/helpers/glass_material_code.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/feedback/glass_toast.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/solid_button.dart';

class StudioHeader extends StatelessWidget {
  const StudioHeader({super.key});

  Future<void> _copy(BuildContext context) async {
    final code = GlassMaterialCode.of(
      context.read<HouseGlassCubit>().state.material,
    );
    final message = context.l10n.copiedAsDartToast;
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    showGlassToast(context, message: message, icon: AssetPaths.code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.gutter,
          AppSpacing.s16,
          AppSpacing.gutter,
          AppSpacing.s12,
        ),
        child: MediaQuery.textScalerOf(context).scale(1) >= 1.5
            // Past about 1.5x the title, its line and the button no longer
            // share a row: the title was squeezed to a single letter.
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StudioTitle(),
                  const SizedBox(height: AppSpacing.s12),
                  SolidButton.secondary(
                    label: l10n.copyAsDart,
                    icon: AssetPaths.code,
                    onPressed: () => _copy(context),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(child: StudioTitle()),
                  const SizedBox(width: AppSpacing.s12),
                  SolidButton.secondary(
                    label: l10n.copyAsDart,
                    icon: AssetPaths.code,
                    onPressed: () => _copy(context),
                  ),
                ],
              ),
      ),
    );
  }
}
