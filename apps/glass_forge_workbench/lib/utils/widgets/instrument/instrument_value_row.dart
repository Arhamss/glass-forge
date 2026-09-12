import 'package:glass_forge_workbench/exports.dart';

/// One read-only row inside an `InstrumentPanel`: a label on the start
/// edge, a right-aligned tabular value, and an optional line of evidence
/// under both.
///
/// The counterpart to `InstrumentSlider` for everything the workbench
/// reports rather than controls — a resolved tier, a measured contrast, a
/// gap in pixels.
class InstrumentValueRow extends StatelessWidget {
  /// Creates the row.
  const InstrumentValueRow({
    required this.label,
    required this.value,
    this.note,
    this.isLive = false,
    super.key,
  });

  /// What is being reported, e.g. `'Thermal'`.
  final String label;

  /// The reading, already formatted with its unit.
  final String value;

  /// Why the reading is what it is, in one short line.
  final String? note;

  /// Whether this row is reporting the state currently in force.
  final bool isLive;

  TextStyle _valueStyle(BuildContext context) => context.mono.copyWith(
    color: isLive ? AppColors.accent : AppColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Past about 1.5x text a label and its reading no longer fit one
        // line on a narrow phone, and the label was squeezed to a column of
        // single letters. Past that, the reading goes underneath.
        if (MediaQuery.textScalerOf(context).scale(1) >= 1.5)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.callout.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(value, style: _valueStyle(context)),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.callout.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: _valueStyle(context),
                ),
              ),
            ],
          ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(
            note,
            style: context.caption.copyWith(
              color: AppColors.stageForegroundSubtle,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
