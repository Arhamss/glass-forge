import 'package:glass_forge_benchmark/exports.dart';

class CustomButton extends StatelessWidget {
  const CustomButton({
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    super.key,
    this.backgroundColor = AppColors.primary,
    this.textColor = AppColors.textOnPrimary,
    this.disabledTextColor,
    this.disabledBackgroundColor,
    this.borderRadius = 100,
    EdgeInsetsGeometry? padding,
    this.fontWeight = FontWeight.w600,
    this.splashColor = Colors.black12,
    this.fontSize = 16,
    this.prefixIcon,
    this.suffixIcon,
    EdgeInsetsGeometry? outsidePadding,
    this.isExpanded = true,
    this.iconSpacing,
    this.disabled = false,
    this.borderColor,
    this.borderWidth = 1.0,
    this.textStyle,
    this.hasShadow = false,
    this.alignPrefixStart = false,
    this.centerContent = false,
  })  : padding = padding ??
            const EdgeInsetsDirectional.symmetric(vertical: 18, horizontal: 24),
        outsidePadding = outsidePadding ?? EdgeInsetsDirectional.zero;

  /// Default brand action — main CTA on a screen.
  const CustomButton.primary({
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    super.key,
    this.prefixIcon,
    this.suffixIcon,
    EdgeInsetsGeometry? outsidePadding,
    this.isExpanded = true,
    this.iconSpacing,
    this.disabled = false,
    this.hasShadow = false,
    this.alignPrefixStart = false,
    this.centerContent = false,
    this.padding = const EdgeInsetsDirectional.symmetric(
      vertical: 18,
      horizontal: 24,
    ),
  })  : backgroundColor = AppColors.primary,
        textColor = AppColors.textOnPrimary,
        disabledTextColor = AppColors.overlayTextMuted,
        disabledBackgroundColor = AppColors.textTertiary,
        borderRadius = 100,
        fontWeight = FontWeight.w600,
        splashColor = Colors.black12,
        fontSize = 16,
        borderColor = null,
        borderWidth = 1.0,
        textStyle = null,
        outsidePadding = outsidePadding ?? EdgeInsetsDirectional.zero;

  /// Alternate filled action when primary doesn't fit the surface.
  const CustomButton.secondary({
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    super.key,
    this.prefixIcon,
    this.suffixIcon,
    EdgeInsetsGeometry? outsidePadding,
    this.isExpanded = true,
    this.iconSpacing,
    this.disabled = false,
    this.hasShadow = false,
    this.alignPrefixStart = false,
    this.centerContent = false,
    this.padding = const EdgeInsetsDirectional.symmetric(
      vertical: 18,
      horizontal: 24,
    ),
  })  : backgroundColor = AppColors.primaryMuted,
        textColor = AppColors.textOnPrimary,
        disabledTextColor = AppColors.overlayTextMuted,
        disabledBackgroundColor = AppColors.textTertiary,
        borderRadius = 100,
        fontWeight = FontWeight.w600,
        splashColor = Colors.black12,
        fontSize = 16,
        borderColor = null,
        borderWidth = 1.0,
        textStyle = null,
        outsidePadding = outsidePadding ?? EdgeInsetsDirectional.zero;

  /// Outlined action — secondary emphasis, often paired with a primary.
  const CustomButton.tertiary({
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    super.key,
    this.prefixIcon,
    this.suffixIcon,
    this.outsidePadding = EdgeInsetsDirectional.zero,
    this.isExpanded = true,
    this.iconSpacing,
    this.disabled = false,
    this.hasShadow = false,
    this.alignPrefixStart = false,
    this.centerContent = false,
    this.padding = const EdgeInsetsDirectional.symmetric(
      vertical: 18,
      horizontal: 24,
    ),
    this.borderWidth = 1.0,
    this.textStyle,
    this.splashColor = Colors.black12,
  })  : backgroundColor = AppColors.surface,
        textColor = AppColors.primary,
        disabledTextColor = AppColors.textTertiary,
        disabledBackgroundColor = AppColors.surfaceAlt,
        borderRadius = 100,
        fontWeight = FontWeight.w600,
        fontSize = 16,
        borderColor = AppColors.primary;

  /// Destructive actions — delete, leave, cancel subscription.
  const CustomButton.danger({
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    super.key,
    this.prefixIcon,
    this.suffixIcon,
    EdgeInsetsGeometry? outsidePadding,
    this.isExpanded = true,
    this.iconSpacing,
    this.disabled = false,
    this.hasShadow = false,
    this.alignPrefixStart = false,
    this.centerContent = false,
    this.padding = const EdgeInsetsDirectional.symmetric(
      vertical: 18,
      horizontal: 24,
    ),
  })  : backgroundColor = AppColors.error,
        textColor = AppColors.textOnPrimary,
        disabledTextColor = AppColors.overlayTextMuted,
        disabledBackgroundColor = AppColors.textTertiary,
        borderRadius = 100,
        fontWeight = FontWeight.w600,
        splashColor = Colors.black12,
        fontSize = 16,
        borderColor = null,
        borderWidth = 1.0,
        textStyle = null,
        outsidePadding = outsidePadding ?? EdgeInsetsDirectional.zero;

  /// Inline links and low-emphasis actions ("Forgot password?", "Skip").
  const CustomButton.text({
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    super.key,
    this.prefixIcon,
    this.suffixIcon,
    this.outsidePadding = const EdgeInsetsDirectional.all(4),
    this.isExpanded = true,
    this.iconSpacing,
    this.disabled = false,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w700,
  })  : backgroundColor = Colors.transparent,
        textColor = AppColors.primary,
        disabledTextColor = AppColors.textTertiary,
        disabledBackgroundColor = Colors.transparent,
        borderRadius = 100,
        padding = const EdgeInsetsDirectional.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        splashColor = Colors.transparent,
        borderColor = null,
        borderWidth = 0.0,
        textStyle = null,
        hasShadow = false,
        alignPrefixStart = false,
        centerContent = false;

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color backgroundColor;
  final Color textColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final FontWeight fontWeight;
  final Color splashColor;
  final double fontSize;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final EdgeInsetsGeometry? outsidePadding;
  final bool isExpanded;
  final double? iconSpacing;
  final bool disabled;
  final Color? disabledTextColor;
  final Color? disabledBackgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final TextStyle? textStyle;
  final bool hasShadow;
  final bool alignPrefixStart;
  final bool centerContent;

  @override
  Widget build(BuildContext context) {
    final effectiveDisabledBackgroundColor =
        disabledBackgroundColor ?? backgroundColor.withValues(alpha: 0.4);
    final effectiveDisabledTextColor =
        disabledTextColor ?? textColor.withValues(alpha: 0.4);

    final buttonContent = TextButton(
      onPressed: (isLoading || disabled) ? null : onPressed,
      style: TextButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size.zero,
        padding: EdgeInsetsDirectional.zero,
        backgroundColor: disabled
            ? effectiveDisabledBackgroundColor
            : backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: borderColor != null
              ? BorderSide(
                  color: disabled
                      ? borderColor!.withValues(alpha: 0.5)
                      : borderColor!,
                  width: borderWidth,
                )
              : BorderSide.none,
        ),
        splashFactory: InkRipple.splashFactory,
        overlayColor: splashColor,
      ),
      child: Padding(
        padding: padding,
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CustomLoadingWidget(color: textColor),
              )
            : Row(
                mainAxisAlignment: centerContent
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (prefixIcon != null) ...[
                    prefixIcon!,
                    if (!alignPrefixStart) SizedBox(width: iconSpacing ?? 8),
                  ],
                  if (centerContent)
                    Flexible(
                      child: Text(
                        text,
                        style: textStyle ??
                            context.h2.copyWith(
                              color: disabled
                                  ? effectiveDisabledTextColor
                                  : textColor,
                              fontWeight: fontWeight,
                              fontSize: fontSize,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    Expanded(
                      child: Text(
                        text,
                        style: textStyle ??
                            context.h2.copyWith(
                              color: disabled
                                  ? effectiveDisabledTextColor
                                  : textColor,
                              fontWeight: fontWeight,
                              fontSize: fontSize,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (suffixIcon != null) ...[
                    SizedBox(width: iconSpacing ?? 8),
                    suffixIcon!,
                  ],
                ],
              ),
      ),
    );

    final Widget buttonWidget = Padding(
      padding: outsidePadding ?? EdgeInsetsDirectional.zero,
      child: isExpanded
          ? Row(children: [Expanded(child: buttonContent)])
          : buttonContent,
    );

    if (hasShadow) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 4),
              blurRadius: 15,
              color: AppColors.primary.withValues(alpha: 0.05),
            ),
          ],
        ),
        child: buttonWidget,
      );
    }

    return buttonWidget;
  }
}
