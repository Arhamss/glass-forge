import 'package:glass_forge_benchmark/exports.dart';

class CustomSocialAuthButton extends StatelessWidget {
  const CustomSocialAuthButton({
    required this.text,
    required this.iconPath,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String text;
  final String iconPath;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return CustomButton.tertiary(
      text: text,
      onPressed: isLoading ? null : onPressed,
      isLoading: isLoading,
      prefixIcon: SvgPicture.asset(
        iconPath,
        width: 20,
        height: 20,
      ),
      iconSpacing: 12,
    );
  }
}
