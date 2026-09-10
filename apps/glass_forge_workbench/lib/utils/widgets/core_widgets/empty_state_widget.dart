import 'package:glass_forge_workbench/exports.dart';

class CustomEmptyStateWidget extends StatelessWidget {
  const CustomEmptyStateWidget({
    required this.title,
    this.subtitle,
    this.iconPath,
    this.iconBgColor,
    this.buttonText,
    this.onButtonPressed,
    this.secondaryButtonText,
    this.onSecondaryButtonPressed,
    this.showSecondaryButton = false,
    this.iconColor,
    this.iconWidget,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? iconPath;
  final Color? iconBgColor;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryButtonPressed;
  final bool showSecondaryButton;
  final Color? iconColor;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (iconWidget != null && iconPath == null) ...[
            iconWidget!,
          ] else if (iconPath != null && iconWidget == null) ...[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color:
                    iconBgColor ??
                    AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: SvgPicture.asset(
                  iconPath!,
                  width: 40,
                  height: 40,
                  colorFilter: iconColor != null
                      ? ColorFilter.mode(iconColor!, BlendMode.srcIn)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            title,
            style: context.h3.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: context.p2.copyWith(color: AppColors.primary),
              textAlign: TextAlign.center,
            ),
          ],
          if (buttonText != null || showSecondaryButton) ...[
            const SizedBox(height: 32),
            if (showSecondaryButton && secondaryButtonText != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: CustomButton(
                      text: buttonText ?? '',
                      onPressed: onButtonPressed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: secondaryButtonText!,
                      onPressed: onSecondaryButtonPressed,
                    ),
                  ),
                ],
              ),
            ] else if (buttonText != null) ...[
              CustomButton(text: buttonText!, onPressed: onButtonPressed),
            ],
          ],
        ],
      ),
    );
  }
}
