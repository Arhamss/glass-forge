import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/house_glass/presentation/cubit/house_glass_cubit.dart';
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.materialTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.display,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.materialSubtitle,
                    style: context.calloutRegular.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
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
