import 'package:glass_forge_workbench/exports.dart';

/// Fades content into the ground under a bar that floats over it, the way
/// iOS softens a scroll edge, so text scrolling beneath the glass never sits
/// directly under its labels.
///
/// Paint only: a gradient over the content, never a filter or a clip.
class ScrollEdgeFade extends StatelessWidget {
  const ScrollEdgeFade.top({required this.extent, super.key})
    : _begin = Alignment.topCenter,
      _end = Alignment.bottomCenter;

  const ScrollEdgeFade.bottom({required this.extent, super.key})
    : _begin = Alignment.bottomCenter,
      _end = Alignment.topCenter;

  final double extent;
  final Alignment _begin;
  final Alignment _end;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: extent,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: _begin,
              end: _end,
              colors: [
                AppColors.ground.withValues(alpha: 0.96),
                AppColors.ground.withValues(alpha: 0.8),
                AppColors.ground.withValues(alpha: 0),
              ],
              stops: const [0, 0.5, 1],
            ),
          ),
        ),
      ),
    );
  }
}
