import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/cubit/showcase_cubit.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/cubit/showcase_state.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/cards/glass_stat_card.dart';

/// What the user has saved, at a glance.
class ShowcaseTripsSheet extends StatelessWidget {
  const ShowcaseTripsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<ShowcaseCubit, ShowcaseState>(
      buildWhen: (previous, current) => previous.savedIds != current.savedIds,
      builder: (context, state) {
        final nearest = state.nearestSaved;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.yourTrips, style: context.title),
            const SizedBox(height: AppSpacing.s16),
            Row(
              children: [
                Expanded(
                  child: GlassStatCard(
                    label: l10n.statSaved,
                    value: '${state.savedIds.length}',
                    unit: l10n.statSavedUnit,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: GlassStatCard(
                    label: l10n.statNearest,
                    value: nearest?.distanceText ?? '—',
                    unit: l10n.statNearestUnit,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s20),
            if (state.savedPlaces.isEmpty)
              Text(
                l10n.tripsEmpty,
                style: context.body.copyWith(color: AppColors.textSecondary),
              )
            else
              for (final place in state.savedPlaces)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: AppSpacing.s12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(place.title, style: context.bodyMedium),
                      ),
                      Text(
                        l10n.placeDistance(place.distanceText),
                        style: context.monoSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }
}
