import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/showcase/data/place_catalog.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/cubit/showcase_cubit.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/cubit/showcase_state.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_mini_player.dart';

class ShowcasePlayerDock extends StatelessWidget {
  const ShowcasePlayerDock({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<ShowcaseCubit, ShowcaseState>(
      buildWhen: (previous, current) => previous.isPlaying != current.isPlaying,
      builder: (context, state) => GlassMiniPlayer(
        artwork: AssetPaths.photoAlbumNightDrive,
        title: PlaceCatalog.nowPlayingTitle,
        subtitle: PlaceCatalog.nowPlayingArtist,
        isPlaying: state.isPlaying,
        onPlayPause: context.read<ShowcaseCubit>().togglePlaying,
        playLabel: l10n.play,
        pauseLabel: l10n.pause,
      ),
    );
  }
}
