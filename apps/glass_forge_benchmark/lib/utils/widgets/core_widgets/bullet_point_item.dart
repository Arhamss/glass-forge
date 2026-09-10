import 'package:glass_forge_benchmark/exports.dart';

class CustomBulletPointItem extends StatelessWidget {
  const CustomBulletPointItem({
    required this.text,
    super.key,
    this.textStyle,
    this.bulletCharacter = '•',
    this.bulletSize = 16.0,
    this.bulletColor,
    this.spacing = 8.0,
    this.padding = const EdgeInsetsDirectional.only(bottom: 8),
  });

  final String text;
  final TextStyle? textStyle;
  final String bulletCharacter;
  final double bulletSize;
  final Color? bulletColor;
  final double spacing;
  final EdgeInsetsDirectional padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bulletCharacter,
            style: context.p1.copyWith(
              fontSize: bulletSize,
              color: bulletColor ?? AppColors.primary,
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: Text(
              text,
              style:
                  textStyle ??
                  context.p2.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
