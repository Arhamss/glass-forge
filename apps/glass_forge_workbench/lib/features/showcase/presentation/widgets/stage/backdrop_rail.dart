import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/stage/backdrop_rail_segment.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';

/// The backdrop-picker rail pinned to the bottom edge of `SpecimenStage`.
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
    );
  }
}
