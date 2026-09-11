import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/showcase/data/models/place.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/cubit/showcase_cubit.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/place_sheet.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/cards/glass_media_card.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/feedback/glass_toast.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_circle_button.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_bottom_sheet.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_context_action.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_context_menu.dart';

/// One place in the feed: tap for details, bookmark to save, long-press for
/// more.
class PlaceCard extends StatelessWidget {
  const PlaceCard({required this.place, required this.isSaved, super.key});

  final Place place;
  final bool isSaved;

  void _toggleSaved(BuildContext context) {
    final l10n = context.l10n;
    context.read<ShowcaseCubit>().toggleSaved(place);
    showGlassToast(
      context,
      message: isSaved ? l10n.placeRemovedToast : l10n.placeSavedToast,
      icon: isSaved ? AssetPaths.bookmarkSimple : AssetPaths.bookmarkSimpleFill,
    );
  }

  Future<void> _copyName(BuildContext context) async {
    final message = context.l10n.nameCopiedToast;
    await Clipboard.setData(ClipboardData(text: place.title));
    if (!context.mounted) return;
    showGlassToast(context, message: message, icon: AssetPaths.check);
  }

  void _openDetails(BuildContext context) {
    final cubit = context.read<ShowcaseCubit>();
    showGlassSheet<void>(
      context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: PlaceSheet(place: place),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GlassContextMenu(
      actions: [
        GlassContextAction(
          label: isSaved ? l10n.unsavePlace : l10n.savePlace,
          icon: isSaved
              ? AssetPaths.bookmarkSimpleFill
              : AssetPaths.bookmarkSimple,
          onSelected: () => _toggleSaved(context),
        ),
        GlassContextAction(
          label: l10n.copyName,
          icon: AssetPaths.copy,
          onSelected: () => _copyName(context),
        ),
      ],
      child: GlassMediaCard(
        image: place.photo,
        title: place.title,
        subtitle: l10n.placeSubtitle(place.region, place.distanceText),
        chip: place.temperatureText,
        onTap: () => _openDetails(context),
        trailing: GlassCircleButton(
          icon: isSaved
              ? AssetPaths.bookmarkSimpleFill
              : AssetPaths.bookmarkSimple,
          iconColor: isSaved ? AppColors.accent : AppColors.textPrimary,
          semanticLabel: isSaved
              ? l10n.unbookmarkPlace(place.title)
              : l10n.bookmarkPlace(place.title),
          onPressed: () => _toggleSaved(context),
        ),
      ),
    );
  }
}
