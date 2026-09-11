import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/showcase/data/models/place_category.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/cubit/showcase_cubit.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/cubit/showcase_state.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/place_card.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/empty_state.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/entrance_rise.dart';

/// The scrolling photographs. They pass under the header and the tab bar on
/// purpose: that is what gives the glass something to bend.
class ShowcaseFeed extends StatelessWidget {
  const ShowcaseFeed({
    required this.topInset,
    required this.bottomInset,
    super.key,
  });

  final double topInset;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<ShowcaseCubit, ShowcaseState>(
      buildWhen: (previous, current) =>
          previous.category != current.category ||
          previous.query != current.query ||
          previous.savedIds != current.savedIds,
      builder: (context, state) {
        final places = state.visiblePlaces;
        return CustomScrollView(
          // Nothing here clips: the feed fills the screen anyway, and a clip
          // layer above live glass is an arrangement to avoid on device.
          clipBehavior: Clip.none,
          slivers: [
            SliverPadding(padding: EdgeInsetsDirectional.only(top: topInset)),
            if (places.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(bottom: bottomInset),
                  child: Center(
                    child:
                        state.category == PlaceCategory.saved &&
                            !state.isSearching
                        ? EmptyState(
                            icon: AssetPaths.bookmarkSimple,
                            title: l10n.emptySavedTitle,
                            body: l10n.emptySavedBody,
                            actionLabel: l10n.showAllPlaces,
                            onAction: context
                                .read<ShowcaseCubit>()
                                .showEverything,
                          )
                        : EmptyState(
                            icon: AssetPaths.magnifyingGlass,
                            title: l10n.emptySearchTitle,
                            body: l10n.emptySearchBody,
                            actionLabel: l10n.showAllPlaces,
                            onAction: context
                                .read<ShowcaseCubit>()
                                .showEverything,
                          ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.gutter,
                  0,
                  AppSpacing.gutter,
                  bottomInset,
                ),
                sliver: SliverList.separated(
                  itemCount: places.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.s16),
                  itemBuilder: (context, index) {
                    final place = places[index];
                    return EntranceRise(
                      key: ValueKey(place.id),
                      index: index,
                      child: PlaceCard(
                        place: place,
                        isSaved: state.isSaved(place),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
