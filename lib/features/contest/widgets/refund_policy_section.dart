import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/payment.dart';
import '../../../data/providers/payment_provider.dart';
import '../../../data/providers/homepage_provider.dart';

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
    // 환불 수수료 안내용으로 homepage detail도 watch (캐시되어 추가 호출 없음)
    final homepageAsync = ref.watch(homepageDetailProvider(homepageId));

    return policiesAsync.when(
      data: (policies) {
        if (policies.isEmpty) return const SizedBox.shrink();
        // homepage 정보가 로드되었으면 환불 수수료 + 대회 시작일 추출, 아니면 기본값
        final isUserPaysRefundFee = homepageAsync.maybeWhen(
          data: (hp) => hp.isUserPaysRefundFee,
          orElse: () => true,
        );
        final refundFeeFixed = homepageAsync.maybeWhen(
          data: (hp) => hp.refundFeeFixedOrDefault,
          orElse: () => 400,
        );
        final contestStartDate = homepageAsync.maybeWhen(
          data: (hp) => hp.contestStartDate,
          orElse: () => null,
        );
        return _buildContent(context, policies, isUserPaysRefundFee, refundFeeFixed, contestStartDate);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildContent(BuildContext context, List<RefundPolicy> policies, bool isUserPaysRefundFee, int refundFeeFixed, DateTime? contestStartDate) {
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
                // 정책 테이블 — 각 행에 실제 날짜 범위 함께 표시
                ...sorted.asMap().entries.map((entry) {
                  final i = entry.key;
                  final policy = entry.value;
                  final isLast = i == sorted.length - 1;
                  // 이전 정책의 daysBeforeContest (날짜 범위 계산용)
                  final prevDays = i == 0 ? null : sorted[i - 1].daysBeforeContest;
                  final dateRange = _formatDateRange(contestStartDate, prevDays, policy.daysBeforeContest);
                  return _buildPolicyRow(policy, isLast, dateRange);
                }),

                // 환불 수수료 안내 (사용자 부담 + 정액 > 0일 때)
                if (isUserPaysRefundFee && refundFeeFixed > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                              children: [
                                const TextSpan(text: '환불 시 토스 가상계좌 환불 수수료 '),
                                TextSpan(
                                  text: '${refundFeeFixed}원',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const TextSpan(text: '이 추가 차감됩니다. 결제 당일 취소도 동일.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

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

  Widget _buildPolicyRow(RefundPolicy policy, bool isLast, String dateRange) {
    final rateColor = policy.refundRate >= 100
        ? AppColors.statusOpen
        : policy.refundRate >= 50
            ? AppColors.statusSoon
            : AppColors.error;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타임라인 아이콘
          Container(
            margin: const EdgeInsets.only(top: 2),
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
          // 설명 + 날짜 범위
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  policy.description ??
                      '대회 ${policy.daysBeforeContest}일 전까지',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (dateRange.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    dateRange,
                    style: TextStyle(
                      fontSize: 11,
                      color: rateColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 환불율
          Container(
            margin: const EdgeInsets.only(top: 2),
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

  /// 정책 적용 날짜 범위 계산
  /// - prevDays == null: 첫 정책(가장 큰 daysBeforeContest) → "~ 6/20(목)까지"
  /// - prevDays != null: 중간/마지막 정책 → "6/21(금) ~ 6/24(월)"
  /// - contestDate == null: 빈 문자열 반환 (날짜 표시 안 함)
  String _formatDateRange(DateTime? contestDate, int? prevDays, int thisDays) {
    if (contestDate == null) return '';
    // 시간 부분 제거 (백엔드와 동일하게 날짜만 비교)
    final base = DateTime(contestDate.year, contestDate.month, contestDate.day);

    if (prevDays == null) {
      // 가장 위 정책 — "~ (contestDate - thisDays)까지"
      final end = base.subtract(Duration(days: thisDays));
      return '~ ${_formatDate(end)}까지';
    }
    // 중간/마지막 정책 — start ~ end
    final start = base.subtract(Duration(days: prevDays - 1));
    final end = base.subtract(Duration(days: thisDays));
    if (start.isAtSameMomentAs(end)) return _formatDate(start);
    return '${_formatDate(start)} ~ ${_formatDate(end)}';
  }

  String _formatDate(DateTime d) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.month}/${d.day}(${weekdays[d.weekday - 1]})';
  }

}
