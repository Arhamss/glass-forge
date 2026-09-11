import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/showcase/data/models/place.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/cubit/showcase_cubit.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/cubit/showcase_state.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/buttons/glass_button.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/feedback/glass_toast.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/app_svg_icon.dart';

/// A place's details, in a glass sheet over the feed it was opened from.
class PlaceSheet extends StatelessWidget {
  const PlaceSheet({required this.place, super.key});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(place.title, style: context.display),
        const SizedBox(height: AppSpacing.s4),
        Text(
          place.region,
          style: context.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s16),
        Row(
          children: [
            const AppSvgIcon(
              AssetPaths.navigationArrow,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.s4),
            Text(l10n.placeDistance(place.distanceText), style: context.mono),
            const SizedBox(width: AppSpacing.s16),
            const AppSvgIcon(
              AssetPaths.thermometer,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.s4),
            Text(place.temperatureText, style: context.mono),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        Text(place.description, style: context.body),
        const SizedBox(height: AppSpacing.s24),
        BlocBuilder<ShowcaseCubit, ShowcaseState>(
          buildWhen: (previous, current) =>
              previous.isSaved(place) != current.isSaved(place),
          builder: (context, state) {
            final isSaved = state.isSaved(place);
            return isSaved
                ? GlassButton.secondary(
                    label: l10n.unsavePlace,
                    icon: AssetPaths.bookmarkSimpleFill,
                    expand: true,
                    onPressed: () {
                      context.read<ShowcaseCubit>().toggleSaved(place);
                      showGlassToast(
                        context,
                        message: l10n.placeRemovedToast,
                        icon: AssetPaths.bookmarkSimple,
                      );
                    },
                  )
                : GlassButton.primary(
                    label: l10n.savePlace,
                    icon: AssetPaths.bookmarkSimple,
                    expand: true,
                    onPressed: () {
                      context.read<ShowcaseCubit>().toggleSaved(place);
                      showGlassToast(
                        context,
                        message: l10n.placeSavedToast,
                        icon: AssetPaths.bookmarkSimpleFill,
                      );
                    },
                  );
          },
        ),
      ],
    );
  }
}
