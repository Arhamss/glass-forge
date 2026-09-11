import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/backdrop_rail_segment.dart';

/// The backdrop-picker rail pinned to the bottom edge of a stage.
///
/// A labelled segmented control, not colour-only swatches — colour alone
/// fails for colour-blind viewers picking between backdrops whose colours
/// and values vary widely by design.
class BackdropRail extends StatelessWidget {
  /// Creates the rail.
  const BackdropRail({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// The backdrop currently shown on the stage.
  final GlassBackdrop selected;

  /// Called with the newly picked backdrop.
  final ValueChanged<GlassBackdrop> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.stageRaised.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.stageBorder),
        ),
        // A horizontal SingleChildScrollView is given loose height
        // constraints by the Stack/Align above it and, left alone, claims
        // the whole stage's height for its cross axis. IntrinsicHeight
        // pins it to its content's real height instead, so the rail stays
        // a thin strip rather than a tall band down the specimen.
        child: IntrinsicHeight(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final backdrop in GlassBackdrop.values)
                  BackdropRailSegment(
                    label: backdrop.label,
                    isSelected: backdrop == selected,
                    onTap: () => onChanged(backdrop),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
