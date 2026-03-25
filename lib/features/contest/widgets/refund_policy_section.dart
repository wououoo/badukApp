import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/payment.dart';
import '../../../data/providers/payment_provider.dart';

/// 환불 규정 표시 위젯 (3곳에서 재사용)
/// - 대회 상세 화면 (정보 탭)
/// - 참가신청 화면 (동의 체크박스 위)
/// - 환불 규정 전용 페이지
class RefundPolicySection extends ConsumerWidget {
  final int homepageId;
  final bool compact; // true: 축약 버전 (대회 상세), false: 전체 버전
  final VoidCallback? onTapDetail; // "자세히 보기" 클릭 시

  const RefundPolicySection({
    super.key,
    required this.homepageId,
    this.compact = false,
    this.onTapDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policiesAsync = ref.watch(refundPoliciesProvider(homepageId));

    return policiesAsync.when(
      data: (policies) {
        if (policies.isEmpty) return const SizedBox.shrink();
        return _buildContent(context, policies);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildContent(BuildContext context, List<RefundPolicy> policies) {
    // daysBeforeContest 내림차순 정렬 (먼 날짜부터)
    final sorted = List<RefundPolicy>.from(policies)
      ..sort((a, b) => b.daysBeforeContest.compareTo(a.daysBeforeContest));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.statusSoon.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.statusSoonBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13),
                topRight: Radius.circular(13),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.gavel_rounded,
                  size: 18,
                  color: AppColors.statusSoonText,
                ),
                const SizedBox(width: 8),
                Text(
                  '환불 규정',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.statusSoonText,
                  ),
                ),
                const Spacer(),
                if (compact && onTapDetail != null)
                  GestureDetector(
                    onTap: onTapDetail,
                    child: Text(
                      '자세히 보기',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 정책 목록
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 정책 테이블
                ...sorted.asMap().entries.map((entry) {
                  final i = entry.key;
                  final policy = entry.value;
                  final isLast = i == sorted.length - 1;
                  return _buildPolicyRow(policy, isLast);
                }),

                // 대회 당일 환불 불가 안내
                const SizedBox(height: 8),
                _buildNonRefundableRow(),

                // compact 모드가 아닐 때 추가 안내
                if (!compact) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '환불은 대회 시작일 기준으로 계산됩니다. '
                            '환불 신청 후 처리까지 영업일 기준 3~5일이 소요될 수 있습니다.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyRow(RefundPolicy policy, bool isLast) {
    final rateColor = policy.refundRate >= 100
        ? AppColors.statusOpen
        : policy.refundRate >= 50
            ? AppColors.statusSoon
            : AppColors.error;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          // 타임라인 아이콘
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rateColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'D-${policy.daysBeforeContest}',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: rateColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 설명
          Expanded(
            child: Text(
              policy.description ??
                  '대회 ${policy.daysBeforeContest}일 전까지',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // 환불율
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: rateColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${policy.refundRate}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: rateColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNonRefundableRow() {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.error,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '대회 당일 이후',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '환불 불가',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
        ),
      ],
    );
  }
}
