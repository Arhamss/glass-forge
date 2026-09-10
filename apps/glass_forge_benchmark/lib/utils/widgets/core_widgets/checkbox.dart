import 'package:glass_forge_benchmark/exports.dart';

class CustomCheckbox extends StatelessWidget {
  const CustomCheckbox({
    required this.value,
    required this.onChanged,
    super.key,
    this.borderColor,
    this.checkColor,
    this.size = 20,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final Color? borderColor;
  final Color? checkColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: value ? AppColors.surface : Colors.transparent,
          border: Border.all(
            color: borderColor ?? AppColors.primary,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: value
            ? Padding(
                padding: const EdgeInsets.all(3),
                child: SvgPicture.asset(
                  AssetPaths.tickIcon,
                  colorFilter: const ColorFilter.mode(
                    AppColors.primary,
                    BlendMode.srcIn,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
