import 'package:glass_forge_workbench/exports.dart';

class CustomProgressDashes extends StatelessWidget {
  const CustomProgressDashes({
    required this.totalSteps,
    required this.currentIndex,
    super.key,
    this.height = 3,
    this.gap = 8,
    this.borderRadius = 999,
    this.activeColor = AppColors.primary,
    this.inactiveColor = AppColors.primary,
  }) : assert(totalSteps > 0, 'totalSteps must be > 0');

  final int totalSteps;
  final int currentIndex;
  final double height;
  final double gap;
  final double borderRadius;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final totalGapsWidth = gap * (totalSteps - 1);
        final dashWidth = (availableWidth - totalGapsWidth) / totalSteps;

        return Row(
          children: List.generate(totalSteps * 2 - 1, (i) {
            if (i.isOdd) {
              return SizedBox(width: gap);
            }

            final index = i ~/ 2;
            final isActive = index <= currentIndex;
            return _Dash(
              width: dashWidth.clamp(4, double.infinity),
              height: height,
              color: isActive ? activeColor : inactiveColor,
              radius: borderRadius,
            );
          }),
        );
      },
    );
  }
}

class _Dash extends StatelessWidget {
  const _Dash({
    required this.width,
    required this.height,
    required this.color,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
