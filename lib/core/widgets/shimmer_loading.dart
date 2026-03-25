import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';

/// Shimmer.fromColors 래퍼
class ShimmerLoading extends StatelessWidget {
  final Widget child;

  const ShimmerLoading({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: child,
    );
  }
}

/// 회색 블록 (shimmer 내부용)
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// 각 화면별 스켈레톤 빌더
class SkeletonBuilders {
  SkeletonBuilders._();

  /// 2열 그리드 카드 스켈레톤
  static Widget contestGrid({int count = 6}) {
    return ShimmerLoading(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: count,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShimmerBox(width: double.infinity, height: 100, borderRadius: 12),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(width: 120, height: 14),
                    SizedBox(height: 6),
                    ShimmerBox(width: 80, height: 12),
                    SizedBox(height: 6),
                    ShimmerBox(width: 60, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 280x140 가로 스크롤 스켈레톤
  static Widget horizontalContests({int count = 3}) {
    return SizedBox(
      height: 140,
      child: ShimmerLoading(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => const ShimmerBox(
            width: 280,
            height: 140,
            borderRadius: 14,
          ),
        ),
      ),
    );
  }

  /// 52x52 날짜박스 + 텍스트 스켈레톤
  static Widget upcomingContestList({int count = 5}) {
    return ShimmerLoading(
      child: Column(
        children: List.generate(count, (_) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const ShimmerBox(width: 52, height: 52, borderRadius: 12),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 160, height: 14),
                      SizedBox(height: 6),
                      ShimmerBox(width: 100, height: 12),
                      SizedBox(height: 6),
                      ShimmerBox(width: 80, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )),
      ),
    );
  }

  /// 참가신청 목록 스켈레톤
  static Widget registrationList({int count = 3}) {
    return ShimmerLoading(
      child: Column(
        children: List.generate(count, (_) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const ShimmerBox(width: 40, height: 40, borderRadius: 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 140, height: 14),
                      SizedBox(height: 6),
                      ShimmerBox(width: 100, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )),
      ),
    );
  }

  /// 클럽 목록 스켈레톤
  static Widget clubList({int count = 4}) {
    return ShimmerLoading(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: count,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const ShimmerBox(width: 48, height: 48, borderRadius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 120, height: 14),
                      SizedBox(height: 6),
                      ShimmerBox(width: 80, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 알림 목록 스켈레톤
  static Widget notificationList({int count = 5}) {
    return ShimmerLoading(
      child: Column(
        children: List.generate(count, (_) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(width: 8, height: 8, borderRadius: 4),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 160, height: 14),
                      SizedBox(height: 6),
                      ShimmerBox(width: double.infinity, height: 12),
                      SizedBox(height: 6),
                      ShimmerBox(width: 60, height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )),
      ),
    );
  }
}
