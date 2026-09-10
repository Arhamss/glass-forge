import 'package:glass_forge_workbench/exports.dart';

class CustomSwitch extends StatelessWidget {
  const CustomSwitch({
    required this.switchValue,
    required this.onSwitchChanged,
    this.title,
    this.backgroundColor,
    super.key,
  });

  final String? title;
  final bool switchValue;
  final ValueChanged<bool> onSwitchChanged;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: backgroundColor ?? AppColors.surface),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (title != null)
            Text(
              title!,
              style: context.p1Medium.copyWith(color: AppColors.primary),
            ),
          Transform.scale(
            scale: 0.75,
            child: Switch(
              value: switchValue,
              onChanged: onSwitchChanged,
              activeThumbColor: AppColors.textOnPrimary,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.surfaceMuted,
              inactiveThumbColor: AppColors.textTertiary,
              trackOutlineColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : AppColors.border,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
