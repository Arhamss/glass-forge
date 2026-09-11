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

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: context.callout.copyWith(
                  color: AppColors.stageForegroundMuted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              textAlign: TextAlign.end,
              style: context.mono.copyWith(
                color: isLive
                    ? AppColors.stageAccent
                    : AppColors.stageForeground,
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
