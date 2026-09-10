import 'package:glass_forge_benchmark/exports.dart';

class CustomStarRatingWidget extends StatelessWidget {
  const CustomStarRatingWidget({
    required this.rating,
    this.maxRating = 5,
    this.starSize = 16.0,
    this.spacing = 4.0,
    this.showEmptyStars = true,
    super.key,
  });

  /// The user's rating (0 to maxRating)
  final int rating;

  /// Maximum rating value (default: 5)
  final int maxRating;

  /// Size of each star icon
  final double starSize;

  /// Spacing between stars
  final double spacing;

  /// Whether to show empty stars for unfilled ratings
  final bool showEmptyStars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRating, (index) {
        final isFilled = index < rating;
        
        return Padding(
          padding: EdgeInsetsDirectional.only(
            end: index < maxRating - 1 ? spacing : 0,
          ),
          child: SvgPicture.asset(
            isFilled 
              ? AssetPaths.starFilledIcon 
              : AssetPaths.starUnfilledIcon,
            width: starSize,
            height: starSize,
          ),
        );
      }),
    );
  }
}
