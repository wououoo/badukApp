import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/contest.dart';
import '../../../data/providers/user_provider.dart';
import 'contest_status_badge.dart';

/// 포스터 모드 대회 카드 (배경 이미지 + 오버레이 텍스트)
class ContestPosterCard extends ConsumerWidget {
  final Contest contest;
  final VoidCallback? onTap;

  const ContestPosterCard({
    super.key,
    required this.contest,
    this.onTap,
  });

  /// posterUrl을 절대 URL로 변환
  String _getFullPosterUrl(String posterUrl) {
    if (posterUrl.startsWith('http')) return posterUrl;
    // baseUrl에서 /api 제거하여 서버 루트 URL 생성
    final serverRoot = ApiConstants.baseUrl.replaceAll('/api', '');
    return '$serverRoot$posterUrl';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds = ref.watch(favoriteIdsProvider);
    final isFavorite = favoriteIds.contains(contest.id);
    final hasPoster = contest.posterUrl != null && contest.posterUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 배경 (포스터 이미지 or 그라데이션)
            if (hasPoster)
              Image.network(
                _getFullPosterUrl(contest.posterUrl!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildGradientBackground(),
              )
            else
              _buildGradientBackground(),

            // 하단 오버레이
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.75),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 대회명
                    Text(
                      contest.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // 장소 + 날짜
                    Row(
                      children: [
                        if (contest.region.isNotEmpty) ...[
                          const Icon(Icons.location_on, size: 11, color: Colors.white70),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              contest.region,
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Icon(Icons.calendar_today, size: 11, color: Colors.white70),
                        const SizedBox(width: 2),
                        Text(
                          _formatShortDate(contest.startDate),
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 상단 뱃지 + 즐겨찾기
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ContestStatusBadge.fromString(
                    contest.status,
                    contestDate: contest.startDate,
                    contestEndDate: contest.endDate,
                  ),
                  GestureDetector(
                    onTap: () {
                      ref.read(favoriteIdsProvider.notifier).toggle(contest.id);
                      ref.invalidate(favoritesProvider);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: isFavorite ? AppColors.error : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 포스터가 없을 때 대회 유형별 그라데이션 배경
  Widget _buildGradientBackground() {
    // 상태에 따라 색상 변경
    final colors = _getGradientColors();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
          child: Text(
            contest.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.3),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  List<Color> _getGradientColors() {
    final status = contest.status?.toLowerCase() ?? '';
    if (status.contains('진행') || status == 'live') {
      return [const Color(0xFF1B5E20), const Color(0xFF2E7D32)];
    } else if (status.contains('종료') || status == 'closed') {
      return [const Color(0xFF37474F), const Color(0xFF546E7A)];
    }
    return [const Color(0xFF283593), const Color(0xFF3949AB)];
  }

  String _formatShortDate(DateTime? date) {
    if (date == null) return '미정';
    return '${date.month}/${date.day}';
  }
}
