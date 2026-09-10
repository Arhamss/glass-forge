import 'package:glass_forge_benchmark/exports.dart';

/// Universal round, fixed-size back button for app bars.
/// White circle with black arrow so it stands out from the background.
class CustomBackButton extends StatelessWidget {
  const CustomBackButton({
    super.key,
    this.onPressed,
    this.semanticLabel = 'Back',
  });

  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return CustomCircleButton(
      icon: SvgPicture.asset(
        AssetPaths.arrowLeftIcon,
        colorFilter: const ColorFilter.mode(
          AppColors.primary,
          BlendMode.srcIn,
        ),
      ),
      onPressed: onPressed ?? () => context.pop(),
      backgroundColor: AppColors.surface,
      semanticLabel: semanticLabel,
    );
  }
}

/// Universal round, fixed-size circle button for app bar leading/actions.
/// Same size ([40]) everywhere for consistency.
class CustomCircleButton extends StatelessWidget {
  const CustomCircleButton({
    required this.icon,
    required this.onPressed,
    super.key,
    this.backgroundColor,
    this.foregroundColor,
    this.semanticLabel,
  });

  final Widget icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    const double size = 40;
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        onPressed: onPressed,
        icon: icon,
        tooltip: semanticLabel,
        style: IconButton.styleFrom(
          minimumSize: const Size(size, size),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const CircleBorder(),
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
        ),
      ),
    );
  }
}

/// Standard padding for app bar leading (wraps [CustomBackButton] / [CustomCircleButton]).
const EdgeInsetsDirectional _appBarLeadingPadding = EdgeInsetsDirectional.only(
  start: 16,
  bottom: 8,
  top: 8,
);

/// This AppBar follows the consistent pattern used across all screens:
/// - Dark system overlay style
/// - Transparent material
/// - Standardized round, fixed-size leading button (white circle, black arrow)
/// - Consistent title styling
PreferredSizeWidget customAppBar({
  required BuildContext context,
  required String title,
  VoidCallback? onBackPressed,
  List<Widget>? actions,
  bool showBackButton = true,
  double? toolbarHeight,
  Widget? leading,
  Widget? titleWidget,
}) {
  return AppBar(
    systemOverlayStyle: SystemUiOverlayStyle.dark,
    forceMaterialTransparency: true,
    toolbarHeight: toolbarHeight,
    centerTitle: true,
    leadingWidth: showBackButton ? 16 + 40 : 0,
    leading: showBackButton
        ? (leading ??
            Padding(
              padding: _appBarLeadingPadding,
              child: CustomBackButton(onPressed: onBackPressed),
            ))
        : const SizedBox.shrink(),
    title: titleWidget ??
        Text(
          title,
          style: context.h4Medium.copyWith(fontSize: 16),
        ),
    actions: actions,
  );
}
