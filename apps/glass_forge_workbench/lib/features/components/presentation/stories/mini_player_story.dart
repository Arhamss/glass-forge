import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/widgets/demos/mini_player_demo.dart';

ComponentStory miniPlayerStory() => ComponentStory(
  knobs: const [],
  builder: (context, values) => const Padding(
    padding: EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.gutter),
    child: MiniPlayerDemo(),
  ),
  code: (values) => '''
GlassMiniPlayer(
  artwork: 'assets/images/album.jpg',
  title: 'Night Drive',
  subtitle: 'Coastline FM',
  isPlaying: isPlaying,
  onPlayPause: togglePlaying,
  playLabel: 'Play',
  pauseLabel: 'Pause',
)''',
);
