import 'package:cached_network_image/cached_network_image.dart';
import 'package:glass_forge_benchmark/exports.dart';
import 'package:shimmer/shimmer.dart';

class CustomCachedImageWidget extends StatelessWidget {
  const CustomCachedImageWidget({
    required this.imageUrl,
    this.placeHolder = AppConstants.productPlaceHolder,
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.compactPlaceholder = false,
    this.placeholderAspectRatio,
    this.errorFallback,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final String placeHolder;
  final BorderRadiusGeometry? borderRadius;
  final BoxFit fit;

  /// When true, placeholder/shimmer is centered and constrained (e.g. for full-screen
  /// viewers) so the background stays visible instead of shimmer filling the screen.
  final bool compactPlaceholder;

  /// When set, placeholder height = width / value (e.g. 4/3 gives shorter placeholder).
  /// Only used when [compactPlaceholder] is false and [width] is non-null.
  final double? placeholderAspectRatio;

  /// Custom widget to show on load error instead of the default placeholder.
  final Widget? errorFallback;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();
    if (trimmedUrl.isEmpty) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(0),
        child: Container(
          width: width,
          height: height,
          color: AppColors.surfaceAlt,
          child: Image.asset(
            placeHolder,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: width,
                height: height,
                color: AppColors.surfaceAlt,
                child: Center(
                  child: SvgPicture.asset(
                    AssetPaths.imageIcon,
                    width: (width != null && height != null)
                        ? (width! < height! ? width! * 0.5 : height! * 0.5)
                        : 24,
                    colorFilter: const ColorFilter.mode(
                      AppColors.textTertiary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(0),
      child: CachedNetworkImage(
        imageUrl: trimmedUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: AppColors.surfaceAlt,
          highlightColor: AppColors.surface,
          child: compactPlaceholder
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth > 0
                        ? constraints.maxWidth * 0.9
                        : 280.0;
                    final h = w * (4 / 3);
                    return Center(
                      child: Container(
                        width: w,
                        height: h,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius:
                              borderRadius ?? BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                )
              : placeholderAspectRatio != null
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final h = w / placeholderAspectRatio!;
                        return SizedBox(
                          width: w,
                          height: h,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius:
                                  borderRadius ?? BorderRadius.zero,
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      width: width,
                      height: height,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: borderRadius ?? BorderRadius.zero,
                      ),
                    ),
        ),
        errorWidget: (context, url, error) => errorFallback ?? Image.asset(
          placeHolder,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: width,
              height: height,
              color: AppColors.surfaceAlt,
              child: Center(
                child: SvgPicture.asset(
                  AssetPaths.imageIcon,
                  width: (width != null && height != null)
                      ? (width! < height! ? width! * 0.5 : height! * 0.5)
                      : 24,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textTertiary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
