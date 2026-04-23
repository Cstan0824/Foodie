import 'package:flutter/cupertino.dart';
import 'package:shimmer/shimmer.dart';
import 'package:taste_spot/core/theme/app_theme.dart';

class Skeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const Skeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      // Lower contrast for a "ghost" effect that doesn't flicker on fast loads
      baseColor: AppColors.surface,
      highlightColor: AppColors.surface.withAlpha(100),
      period: const Duration(milliseconds: 2000), // Slower, smoother pulse
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({
    super.key,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surface.withAlpha(100),
      period: const Duration(milliseconds: 2000),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
