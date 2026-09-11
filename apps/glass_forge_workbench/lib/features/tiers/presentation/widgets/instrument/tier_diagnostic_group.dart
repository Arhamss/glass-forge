import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_panel.dart';

/// The line `ResolvedTier.describe()` prints to the console, shown here so
/// what you read in a log and what you read on screen are the same string.
class TierDiagnosticGroup extends StatelessWidget {
  /// Creates the group.
  const TierDiagnosticGroup({required this.description, super.key});

  /// The output of `ResolvedTier.describe()`.
  final String description;

  @override
  Widget build(BuildContext context) {
    return InstrumentPanel(
      title: 'describe()',
      cells: [
        Text(
          description,
          style: context.caption.copyWith(
            color: AppColors.stageForegroundMuted,
            height: 1.6,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
