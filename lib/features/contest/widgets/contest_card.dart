import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/contest.dart';
import '../../../data/providers/user_provider.dart';
import 'contest_status_badge.dart';

/// 대회 카드 위젯 (런너블 스타일 2열 그리드용)
class ContestCard extends ConsumerWidget {
  final Contest contest;
  final VoidCallback? onTap;

  const ContestCard({
    super.key,
    required this.contest,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds = ref.watch(favoriteIdsProvider);
    final isFavorite = favoriteIds.contains(contest.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상태 뱃지 + 즐겨찾기 버튼
              Row(
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
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: isFavorite ? AppColors.error : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 대회명
              Text(
                contest.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              // 상세 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 주최
                    if (contest.organizer != null && contest.organizer!.isNotEmpty)
                      _buildInfoRow(Icons.business_outlined, contest.organizer!),
                    // 참가비
                    if (contest.participationFee != null && contest.participationFee!.isNotEmpty)
                      _buildInfoRow(Icons.payments_outlined, contest.participationFee!),
                    // 접수기간
                    if (contest.registrationPeriod != null && contest.registrationPeriod!.isNotEmpty)
                      _buildInfoRow(Icons.event_available_outlined, contest.registrationPeriod!),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 하단 정보
              Row(
                children: [
                  // 장소
                  Expanded(
                    child: _buildInfoChip(
                      Icons.location_on_outlined,
                      contest.region.isNotEmpty ? contest.region : '장소 미정',
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 날짜
                  _buildInfoChip(
                    Icons.calendar_today_outlined,
                    _formatShortDate(contest.startDate),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatShortDate(DateTime? date) {
    if (date == null) return '미정';
    return '${date.month}/${date.day}';
  }

}
