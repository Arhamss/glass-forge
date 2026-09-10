import 'package:glass_forge_workbench/exports.dart';

class CustomIconButton extends StatelessWidget {
  const CustomIconButton({
    this.icon,
    this.onPressed,
    this.backgroundColor = AppColors.surface,
    this.iconColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(100)),
    this.borderColor = AppColors.textTertiary,
    this.splashColor = Colors.black12,
    this.outsidePadding = EdgeInsetsDirectional.zero,
    this.iconPadding,
    this.borderWidth = 1,
    this.isLoading = false,
    this.shrinkTargetSize = true,
    this.semanticLabel,
    super.key,
  });

  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color? iconColor;
  final BorderRadiusGeometry borderRadius;
  final Color borderColor;
  final Color splashColor;
  final Widget? icon;
  final double? iconPadding;
  final EdgeInsetsDirectional outsidePadding;
  final bool isLoading;
  final double borderWidth;
  final bool shrinkTargetSize;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget iconButtonWidget = IconButton(
      onPressed: isLoading == true ? null : onPressed,
      tooltip: semanticLabel,
      icon: isLoading
          ? const CustomLoadingWidget(size: 18)
          : icon ?? SvgPicture.asset(AssetPaths.arrowLeftIcon),
      color: iconColor,
      style: IconButton.styleFrom(
        tapTargetSize: shrinkTargetSize
            ? MaterialTapTargetSize.shrinkWrap
            : MaterialTapTargetSize.padded,
        padding: EdgeInsetsDirectional.all(iconPadding ?? 8),
        minimumSize: Size.zero,
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: borderColor, width: borderWidth),
        ),
      ),
    );

    return Padding(padding: outsidePadding, child: iconButtonWidget);
  }
}
