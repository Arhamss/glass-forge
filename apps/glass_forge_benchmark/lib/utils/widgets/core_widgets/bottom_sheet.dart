import 'package:glass_forge_benchmark/exports.dart';

class CustomBottomSheet extends StatelessWidget {
  const CustomBottomSheet({
    required this.title,
    this.imagePath,
    this.imageWidget,
    this.subtitle,
    this.onTap,
    this.buttonOneText,
    this.buttonTwoText,
    this.buttonOneOnTap,
    this.buttonTwoOnTap,
    this.buttonOneColor,
    this.buttonTwoColor,
    this.buttonOneTextColor,
    this.buttonTwoTextColor,
    this.isLoading = false,
    this.body,
    super.key,
  });

  final String title;
  final String? imagePath;
  final Widget? imageWidget;
  final String? subtitle;
  final VoidCallback? onTap;
  final String? buttonOneText;
  final String? buttonTwoText;
  final VoidCallback? buttonOneOnTap;
  final VoidCallback? buttonTwoOnTap;
  final Color? buttonOneColor;
  final Color? buttonTwoColor;
  final Color? buttonOneTextColor;
  final Color? buttonTwoTextColor;
  final bool isLoading;
  final Widget? body;

  static Future<void> show({
    required BuildContext context,
    required String title,
    String? imagePath,
    Widget? imageWidget,
    String? subtitle,
    String? buttonOneText,
    String? buttonTwoText,
    VoidCallback? buttonOneOnTap,
    VoidCallback? buttonTwoOnTap,
    Color? buttonOneColor,
    Color? buttonTwoColor,
    Color? buttonOneTextColor,
    Color? buttonTwoTextColor,
    double? height,
    VoidCallback? onTap,
    bool isLoading = false,
    Widget? body,
    bool safeAreaBottom = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width,
        minWidth: MediaQuery.of(context).size.width,
      ),
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final keyboardHeight = mediaQuery.viewInsets.bottom;
        final bottomPadding = safeAreaBottom ? mediaQuery.padding.bottom : 0.0;
        final contentHeight = height != null
            ? (mediaQuery.size.height - mediaQuery.viewPadding.top) * height
            : null;
        final totalHeight =
            contentHeight != null ? contentHeight + bottomPadding : null;

        // White background extends to screen bottom; content is inset via SafeArea
        return Padding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: Container(
            height: totalHeight,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              bottom: safeAreaBottom,
              child: SizedBox(
                height: contentHeight,
                child: GestureDetector(
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  child: CustomBottomSheet(
                    imagePath: imagePath,
                    title: title,
                    subtitle: subtitle,
                    onTap: onTap,
                    isLoading: isLoading,
                    imageWidget: imageWidget,
                    buttonOneText: buttonOneText,
                    buttonTwoText: buttonTwoText,
                    buttonOneOnTap: buttonOneOnTap,
                    buttonTwoOnTap: buttonTwoOnTap,
                    buttonOneColor: buttonOneColor,
                    buttonTwoColor: buttonTwoColor,
                    buttonOneTextColor: buttonOneTextColor,
                    buttonTwoTextColor: buttonTwoTextColor,
                    body: body,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      padding: const EdgeInsetsDirectional.all(16),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: body != null ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Container(
                height: 5,
                width: 64,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 16),
              if (imagePath != null) ...[
                SvgPicture.asset(imagePath!, height: 100),
                const SizedBox(height: 24),
              ],
              if (imageWidget != null) ...[
                imageWidget!,
                const SizedBox(height: 20),
              ],
              Text(
                title,
                style: context.h4Medium,
              ),
              if (body != null) ...[
                Expanded(child: body!),
                if (buttonOneText != null || buttonTwoText != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (buttonOneText != null)
                        Expanded(
                          child: CustomButton(
                            padding: const EdgeInsetsDirectional.symmetric(
                              vertical: 12,
                            ),
                            text: buttonOneText!,
                            onPressed: buttonOneOnTap,
                            isLoading: isLoading,
                            borderColor: buttonOneTextColor,
                            textColor: buttonOneTextColor ?? AppColors.textOnPrimary,
                            backgroundColor:
                                buttonOneColor ?? AppColors.primary,
                          ),
                        ),
                      if (buttonOneText != null && buttonTwoText != null)
                        const SizedBox(width: 16),
                      if (buttonTwoText != null)
                        Expanded(
                          child: CustomButton(
                            padding: const EdgeInsetsDirectional.symmetric(
                              vertical: 12,
                            ),
                            text: buttonTwoText!,
                            textColor: buttonTwoTextColor ?? AppColors.textOnPrimary,
                            onPressed: buttonTwoOnTap,
                            isLoading: isLoading,
                            backgroundColor: buttonTwoColor ?? AppColors.error,
                          ),
                        ),
                    ],
                  ),
                ],
              ] else ...[
                const SizedBox(height: 12),
                if (subtitle != null) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      child: Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: context.p2,
                        softWrap: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: CustomButton(
                        padding: const EdgeInsetsDirectional.symmetric(
                          vertical: 12,
                        ),
                        text: buttonOneText ?? '',
                        onPressed: buttonOneOnTap,
                        isLoading: isLoading,
                        borderColor: buttonOneTextColor,
                        textColor: buttonOneTextColor ?? AppColors.textOnPrimary,
                        backgroundColor:
                            buttonOneColor ?? AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomButton(
                        padding: const EdgeInsetsDirectional.symmetric(
                          vertical: 12,
                        ),
                        text: buttonTwoText ?? '',
                        textColor: buttonTwoTextColor ?? AppColors.textOnPrimary,
                        onPressed: buttonTwoOnTap,
                        isLoading: isLoading,
                        backgroundColor: buttonTwoColor ?? AppColors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
    );
  }
}
