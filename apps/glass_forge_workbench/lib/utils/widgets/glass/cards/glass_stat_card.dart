import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';

/// A number-first glass card: a small label, a big figure with its unit,
/// and an optional change.
class GlassStatCard extends StatelessWidget {
  const GlassStatCard({
    required this.label,
    required this.value,
    required this.unit,
    this.delta,
    this.deltaIsPositive = true,
    super.key,
  });

  final String label;
  final String value;
  final String unit;

  /// Already formatted and signed by the caller, e.g. "+12%".
  final String? delta;

  /// Picks the delta's colour. The sign in [delta] carries the meaning too,
  /// so colour is never the only cue.
  final bool deltaIsPositive;

  static const double _valueSize = 28;
  static const double _valueLineHeight = 34;

  static const _shape = GlassSuperellipse(
    radius: BorderRadius.all(Radius.circular(AppRadius.r24)),
  );

  @override
  Widget build(BuildContext context) {
    final delta = this.delta;
    final spokenDelta = delta == null ? '' : ', $delta';
    // One sentence for a screen reader, rather than a stop at each piece.
    return Semantics(
      container: true,
      label: '$label, $value $unit$spokenDelta',
      excludeSemantics: true,
      child: KitGlassLayer(
        priority: GlassPriority.content,
        shape: _shape,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.overline.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              // A figure is never truncated: at large text sizes in a narrow
              // card it shrinks to fit instead.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      style: context.mono.copyWith(
                        fontSize: _valueSize,
                        height: _valueLineHeight / _valueSize,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s4),
                    Text(
                      unit,
                      maxLines: 1,
                      style: context.monoSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (delta != null) ...[
                const SizedBox(height: AppSpacing.s4),
                Text(
                  delta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.monoSmall.copyWith(
                    color: deltaIsPositive
                        ? AppColors.accent
                        : AppColors.danger,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
