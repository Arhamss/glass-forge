import 'package:glass_forge_workbench/exports.dart';

/// The one line of text a stage is allowed to carry.
///
/// Stages are otherwise chrome-free, so anything that has to be said over
/// one — what the renderer is doing, what the numbers under the specimen
/// mean — is said here: small, tabular, and pinned out of the specimen's
/// way by whoever places it.
class StageCaption extends StatelessWidget {
  /// Creates the caption.
  const StageCaption({required this.text, this.isLive = false, super.key});

  /// The line to show. Kept to a handful of words.
  final String text;

  /// Whether this reports something currently running.
  ///
  /// The one place the accent green is allowed: active state, never
  /// decoration.
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.stageGround.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.stageBorder),
      ),
      child: Text(
        text,
        style: context.caption.copyWith(
          color: isLive
              ? AppColors.stageAccent
              : AppColors.stageForegroundMuted,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
