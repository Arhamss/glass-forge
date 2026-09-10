import 'package:glass_forge_workbench/exports.dart';

class CustomFilterIconWidget extends StatelessWidget {
  const CustomFilterIconWidget({this.filterCount, this.iconSize = 24.0, super.key});

  final int? filterCount;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        SvgPicture.asset(
          AssetPaths.filterIcon,
          width: iconSize,
          height: iconSize,
        ),
        if (filterCount != null && filterCount! > 0)
          Positioned(
            right: -4,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 3),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                filterCount!.toString().padLeft(2, '0'),
                style: context.overline.secondary.copyWith(fontSize: 8),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
