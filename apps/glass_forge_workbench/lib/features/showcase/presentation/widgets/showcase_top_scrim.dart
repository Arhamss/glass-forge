import 'package:glass_forge_workbench/exports.dart';

/// Darkens the top of the feed behind the header, so the title and the
/// status bar read over any photograph without a solid bar.
class ShowcaseTopScrim extends StatelessWidget {
  const ShowcaseTopScrim({
    required this.height,
    required this.solidUntil,
    super.key,
  });

  final double height;

  /// Down to here the ground is fully opaque: the status bar and the title
  /// sit on it, and nothing scrolling beneath may show through their words.
  final double solidUntil;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.ground,
                AppColors.ground,
                AppColors.ground.withValues(alpha: 0.72),
                AppColors.ground.withValues(alpha: 0),
              ],
              stops: [0, solidUntil / height, (solidUntil / height + 1) / 2, 1],
            ),
          ),
        ),
      ),
    );
  }
}
