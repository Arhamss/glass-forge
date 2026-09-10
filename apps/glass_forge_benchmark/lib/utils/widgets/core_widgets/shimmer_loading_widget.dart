import 'package:flutter/material.dart';
import 'package:glass_forge_benchmark/constants/app_colors.dart';
import 'package:shimmer/shimmer.dart';

class CustomShimmerWidget extends StatelessWidget {
  const CustomShimmerWidget({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 0.0,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Shimmer.fromColors(
        baseColor: AppColors.surfaceAlt,
        highlightColor: AppColors.surface,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}
