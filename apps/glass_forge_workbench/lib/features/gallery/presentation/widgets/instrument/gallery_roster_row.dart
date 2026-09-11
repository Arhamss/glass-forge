import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/extensions/glass_adaptation_extensions.dart';
import 'package:glass_forge_workbench/utils/extensions/glass_surface_role_extensions.dart';

/// One role in the gallery's roster: its name, the verdict the size gate
/// reached for it, and the two schemes it resolves to.
class GalleryRosterRow extends StatelessWidget {
  /// Creates the row.
  const GalleryRosterRow({
    required this.role,
    required this.adaptation,
    required this.lightScheme,
    required this.darkScheme,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  /// The role this row reports on.
  final GlassSurfaceRole role;

  /// How much adaptation it gets at the current size.
  final GlassAdaptation adaptation;

  /// The scheme it resolves to in a light app.
  final Brightness lightScheme;

  /// The scheme it resolves to in a dark app.
  final Brightness darkScheme;

  /// Whether this role is the one on the stage.
  final bool isSelected;

  /// Called when the row is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected
        ? AppColors.stageForeground
        : AppColors.stageForegroundMuted;
    // The selected row's fill lifts the ground it sits on, which takes the
    // subtle grey under 4.5:1. Measured, not eyeballed — see
    // test/constants/stage_contrast_test.dart.
    final secondary = isSelected
        ? AppColors.stageForegroundMuted
        : AppColors.stageForegroundSubtle;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${role.label}, ${adaptation.verb}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.stageForeground.withValues(alpha: 0.12)
                : AppColors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      role.label,
                      style: context.callout.copyWith(color: foreground),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    adaptation.verb,
                    style: context.callout.copyWith(color: foreground),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${lightScheme.name} in a light app, '
                '${darkScheme.name} in a dark one',
                style: context.caption.copyWith(color: secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
