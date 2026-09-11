import 'package:glass_forge_workbench/exports.dart';

/// One rung of the tier ladder: what it is, what it costs a material, and
/// whether it is reachable on this device right now.
class TierLadderRung extends StatelessWidget {
  /// Creates the rung.
  const TierLadderRung({
    required this.label,
    required this.effect,
    required this.status,
    required this.isSelected,
    required this.isInForce,
    required this.onTap,
    super.key,
  });

  /// The rung's name.
  final String label;

  /// What it does to a material.
  final String effect;

  /// Its standing right now — pinned, in force, or where it would be
  /// held. Empty when there is nothing to say.
  final String status;

  /// Whether this rung is the one pinned.
  final bool isSelected;

  /// Whether this rung is the one actually rendering.
  final bool isInForce;

  /// Called when the rung is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected || isInForce
        ? AppColors.stageForeground
        : AppColors.stageForegroundMuted;
    // A selected rung's fill lifts the ground it sits on, which takes the
    // subtle grey under 4.5:1. Measured, not eyeballed — see
    // test/constants/stage_contrast_test.dart.
    final secondary = isSelected
        ? AppColors.stageForegroundMuted
        : AppColors.stageForegroundSubtle;
    return Semantics(
      button: true,
      selected: isSelected,
      label: status.isEmpty ? label : '$label, $status',
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
                      label,
                      style: context.p2Medium.copyWith(color: foreground),
                    ),
                  ),
                  if (status.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Text(
                      status,
                      style: context.p2Medium.copyWith(
                        color: isInForce
                            ? AppColors.stageAccent
                            : secondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                effect,
                style: context.caption.copyWith(
                  color: secondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
