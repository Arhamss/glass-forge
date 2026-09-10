import 'package:glass_forge_benchmark/exports.dart';

class CustomRetryWidget extends StatelessWidget {
  const CustomRetryWidget({
    required this.onRetry,
    required this.message,
    super.key,
  });

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message ?? 'Something went wrong. Please try again.',
            style: context.p2.copyWith(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          CustomButton.tertiary(
            text: 'Retry',
            onPressed: onRetry,
            isExpanded: false,
          ),
        ],
      ),
    );
  }
}
