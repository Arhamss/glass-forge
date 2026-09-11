import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/showcase/data/place_catalog.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_mini_player.dart';

class MiniPlayerDemo extends StatefulWidget {
  const MiniPlayerDemo({super.key});

  @override
  State<MiniPlayerDemo> createState() => _MiniPlayerDemoState();
}

class _MiniPlayerDemoState extends State<MiniPlayerDemo> {
  final ValueNotifier<bool> _playing = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _playing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<bool>(
      valueListenable: _playing,
      builder: (context, playing, _) => GlassMiniPlayer(
        artwork: AssetPaths.photoAlbumNightDrive,
        title: PlaceCatalog.nowPlayingTitle,
        subtitle: PlaceCatalog.nowPlayingArtist,
        isPlaying: playing,
        onPlayPause: () => _playing.value = !playing,
        playLabel: l10n.play,
        pauseLabel: l10n.pause,
      ),
    );
  }
}
