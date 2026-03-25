import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 배너 아이템 데이터 모델
class BannerItem {
  final String? imageUrl;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final String? routePath;

  const BannerItem({
    this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    this.routePath,
  });
}

/// 배너 캐러셀 위젯 (자동 스크롤, 페이지 인디케이터)
class BannerCarousel extends StatefulWidget {
  final List<BannerItem> items;
  final double height;
  final Duration autoScrollDuration;
  final ValueChanged<String?>? onTap;

  const BannerCarousel({
    super.key,
    required this.items,
    this.height = 160,
    this.autoScrollDuration = const Duration(seconds: 5),
    this.onTap,
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    if (widget.items.length <= 1) return;
    _timer = Timer.periodic(widget.autoScrollDuration, (_) {
      if (!mounted) return;
      final nextPage = (_currentPage + 1) % widget.items.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            height: widget.height,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return _buildBannerPage(item);
              },
            ),
          ),
          if (widget.items.length > 1) ...[
            const SizedBox(height: 10),
            _buildPageIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildBannerPage(BannerItem item) {
    final hasImage = item.imageUrl != null;

    return GestureDetector(
      onTap: () => widget.onTap?.call(item.routePath),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: item.backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // 포스터 이미지
              if (hasImage)
                Positioned.fill(
                  child: Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              // 하단 그래디언트 오버레이 (텍스트 가독성)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: hasImage ? 80 : 0,
                child: hasImage
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              // 텍스트
              Positioned(
                left: 20,
                bottom: 16,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.items.length, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
