import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmering placeholder box.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({this.width, this.height, this.radius = 14, super.key});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Shimmer.fromColors(
      baseColor: tokens.shimmerBase,
      highlightColor: tokens.shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: tokens.shimmerBase,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Vertical list of skeleton rows (store/orders lists).
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({this.itemCount = 5, this.itemHeight = 88, super.key});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => AppSkeleton(height: itemHeight, radius: 20),
    );
  }
}

/// 2-column product grid skeleton.
class AppSkeletonGrid extends StatelessWidget {
  const AppSkeletonGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final int columns = width >= 1000 ? 4 : (width >= 600 ? 3 : 2);
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.62,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: AppSkeleton(radius: 20)),
          SizedBox(height: 8),
          AppSkeleton(height: 14),
          SizedBox(height: 4),
          AppSkeleton(height: 12, width: 80),
        ],
      ),
    );
  }
}
