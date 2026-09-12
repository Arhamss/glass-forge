import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/backdrop_rail_segment.dart';

/// The backdrop picker pinned to the bottom edge of a stage.
///
/// Five equal segments rather than a scrolling row: the fifth backdrop is
/// the pure-black rim test, and a row that scrolled put it off the end of
/// every phone, where nobody found it. Labels are short for the same reason,
/// and text scaling is capped so they stay on one line.
class BackdropRail extends StatelessWidget {
  const BackdropRail({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final GlassBackdrop selected;
  final ValueChanged<GlassBackdrop> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.gutter,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppRadius.rPill),
          border: Border.all(color: AppColors.hairlineStrong),
        ),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(3),
            child: Row(
              children: [
                for (final backdrop in GlassBackdrop.values)
                  Expanded(
                    child: BackdropRailSegment(
                      label: backdrop.label,
                      isSelected: backdrop == selected,
                      onTap: () => onChanged(backdrop),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
