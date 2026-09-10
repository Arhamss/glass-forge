import 'package:glass_forge_benchmark/exports.dart';

class CustomTile extends StatelessWidget {
  const CustomTile({
    required this.label,
    super.key,
    this.showIcon = false,
    this.onTap,
    this.iconPath,
  });

  final String label;
  final bool showIcon;
  final VoidCallback? onTap;
  final String? iconPath;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(44),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: context.p2.copyWith(
                  color: AppColors.textOnPrimary,
                ),
              ),
            ),
            if (showIcon && iconPath != null)
              if (iconPath!.contains('svg'))
                SvgPicture.asset(iconPath!)
              else
                Image.asset(iconPath!),
          ],
        ),
      ),
    );
  }
}
