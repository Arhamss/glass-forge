import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_circle_button.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';

/// A glass capsule for whatever is playing: artwork, two lines, and a
/// play/pause button drawn as an inset on the capsule.
class GlassMiniPlayer extends StatelessWidget {
  const GlassMiniPlayer({
    required this.artwork,
    required this.title,
    required this.subtitle,
    required this.isPlaying,
    required this.onPlayPause,
    required this.playLabel,
    required this.pauseLabel,
    super.key,
  });

  static const double height = 64;
  static const double _artwork = 44;

  /// An asset path.
  final String artwork;
  final String title;
  final String subtitle;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final String playLabel;
  final String pauseLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: KitGlassLayer(
        priority: GlassPriority.chrome,
        shape: const GlassSuperellipse(
          radius: BorderRadius.all(Radius.circular(height / 2)),
        ),
        child: ColoredBox(
          color: AppColors.glassChromeScrim,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 6, 0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.r12),
                    child: Image.asset(
                      artwork,
                      width: _artwork,
                      height: _artwork,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.callout,
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GlassCircleButton(
                    icon: isPlaying
                        ? AssetPaths.pauseFill
                        : AssetPaths.playFill,
                    semanticLabel: isPlaying ? pauseLabel : playLabel,
                    onPressed: onPlayPause,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
