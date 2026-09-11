import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/showcase/data/models/place_category.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/cubit/showcase_cubit.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/cubit/showcase_state.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/showcase_alerts_sheet.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/showcase_trips_sheet.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_circle_button.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_segmented_control.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_top_bar.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_bottom_sheet.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_search_bar.dart';

/// The glass chrome floating over the top of the feed: title bar, search,
/// and the filter.
class ShowcaseHeader extends StatelessWidget {
  const ShowcaseHeader({super.key});

  static const double _searchGap = AppSpacing.s8;
  static const double _filterGap = AppSpacing.s12;
  static const double _bottomGap = AppSpacing.s12;

  /// The header's full height, including the status bar it sits under.
  static double heightOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top +
      GlassTopBar.height +
      _searchGap +
      GlassSearchBar.height +
      _filterGap +
      GlassSegmentedControl.height +
      _bottomGap;

  void _openTrips(BuildContext context) {
    final cubit = context.read<ShowcaseCubit>();
    showGlassSheet<void>(
      context,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const ShowcaseTripsSheet()),
    );
  }

  void _openAlerts(BuildContext context) {
    context.read<ShowcaseCubit>().markAlertsRead();
    showGlassSheet<void>(context, builder: (_) => const ShowcaseAlertsSheet());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ShowcaseCubit>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BlocBuilder<ShowcaseCubit, ShowcaseState>(
          buildWhen: (previous, current) =>
              previous.hasUnreadAlerts != current.hasUnreadAlerts,
          builder: (context, state) => GlassTopBar(
            title: l10n.showcaseTitle,
            leading: GlassCircleButton(
              icon: AssetPaths.user,
              semanticLabel: l10n.yourTrips,
              onPressed: () => _openTrips(context),
            ),
            trailing: GlassCircleButton(
              icon: AssetPaths.bell,
              semanticLabel: l10n.notifications,
              badge: state.hasUnreadAlerts,
              onPressed: () => _openAlerts(context),
            ),
          ),
        ),
        const SizedBox(height: _searchGap),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.gutter,
          ),
          child: BlocBuilder<ShowcaseCubit, ShowcaseState>(
            buildWhen: (previous, current) => previous.query != current.query,
            builder: (context, state) => GlassSearchBar(
              hint: l10n.showcaseSearchHint,
              clearLabel: l10n.clearSearch,
              value: state.query,
              onChanged: cubit.setQuery,
            ),
          ),
        ),
        const SizedBox(height: _filterGap),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.gutter,
          ),
          child: BlocBuilder<ShowcaseCubit, ShowcaseState>(
            buildWhen: (previous, current) =>
                previous.category != current.category,
            builder: (context, state) => GlassSegmentedControl<PlaceCategory>(
              values: PlaceCategory.values,
              labelOf: (category) => category.label,
              selected: state.category,
              onChanged: cubit.setCategory,
            ),
          ),
        ),
        const SizedBox(height: _bottomGap),
      ],
    );
  }
}
