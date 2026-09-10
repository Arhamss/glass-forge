import 'package:flutter/gestures.dart';
import 'package:glass_forge_workbench/exports.dart';

class CustomRichText extends StatelessWidget {
  const CustomRichText({
    required this.textBefore,
    required this.richText,
    required this.textAfter,
    super.key,
    this.normalTextStyle,
    this.richTextStyle,
    this.richTextColor,
    this.onRichTextTap,
    this.textAlign = TextAlign.center,
    this.noSpace = false,
    this.richTextDecoration,
  });

  final TextStyle? normalTextStyle;
  final TextStyle? richTextStyle;
  final bool noSpace;
  final String textBefore;
  final String textAfter;
  final String richText;
  final Color? richTextColor;
  final VoidCallback? onRichTextTap;
  final TextAlign textAlign;
  final TextDecoration? richTextDecoration;

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        text: textBefore,
        style: normalTextStyle ??
            context.overline.copyWith(
              color: AppColors.textSecondary,
            ),
        children: [
          TextSpan(
            text: noSpace ? richText : ' $richText ',
            style: richTextStyle ??
                context.p2Bold.copyWith(
                  fontSize: 10,
                  color: richTextColor ?? AppColors.primary,
                  fontWeight: FontWeight.bold,
                  decoration: richTextDecoration,
                ),
            recognizer: TapGestureRecognizer()..onTap = onRichTextTap,
          ),
          TextSpan(
            text: textAfter,
            style: normalTextStyle ??
                context.overline.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
