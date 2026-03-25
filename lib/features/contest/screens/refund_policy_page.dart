import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/payment.dart';
import '../../../data/providers/payment_provider.dart';

/// 환불 규정 전용 페이지
class RefundPolicyPage extends ConsumerWidget {
  final int homepageId;
  final String contestName;

  const RefundPolicyPage({
    super.key,
    required this.homepageId,
    required this.contestName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policiesAsync = ref.watch(refundPoliciesProvider(homepageId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('환불 규정'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: policiesAsync.when(
        data: (policies) => _buildBody(context, policies),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '환불 규정을 불러올 수 없습니다.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<RefundPolicy> policies) {
    final sorted = List<RefundPolicy>.from(policies)
      ..sort((a, b) => b.daysBeforeContest.compareTo(a.daysBeforeContest));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 대회명
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        contestName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (policies.isEmpty) ...[
            // 환불 규정 없음
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 48,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '등록된 환불 규정이 없습니다.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '대회 주최측에 문의해 주세요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // 환불 규정 테이블
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 테이블 헤더
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.statusSoonBg,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            '환불 기준',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.statusSoonText,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            '환불율',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.statusSoonText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 정책 행
                  ...sorted.asMap().entries.map((entry) {
                    final i = entry.key;
                    final policy = entry.value;
                    final isEven = i % 2 == 0;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      color: isEven ? null : AppColors.surfaceVariant.withOpacity(0.5),
                      child: Row(
                        children: [
                          // D-day 뱃지
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _getRateColor(policy.refundRate).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                'D-${policy.daysBeforeContest}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _getRateColor(policy.refundRate),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // 설명
                          Expanded(
                            flex: 3,
                            child: Text(
                              policy.description ??
                                  '대회 시작 ${policy.daysBeforeContest}일 전까지 취소 시',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                          // 환불율
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getRateColor(policy.refundRate).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${policy.refundRate}%',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _getRateColor(policy.refundRate),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // 대회 당일 이후
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.03),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.block_rounded,
                              size: 20,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 3,
                          child: Text(
                            '대회 당일 이후 또는 노쇼(No-show)',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '불가',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 안내사항
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.border,
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '안내사항',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildGuideItem('환불 기준일은 대회 시작일 기준입니다.'),
                  _buildGuideItem('환불 신청 후 처리까지 영업일 기준 3~5일이 소요될 수 있습니다.'),
                  _buildGuideItem('부분 환불 시 참가비에서 해당 비율만큼 환불됩니다.'),
                  _buildGuideItem('문의사항은 대회 주최측에 연락해 주세요.'),
                ],
              ),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildGuideItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRateColor(int rate) {
    if (rate >= 100) return AppColors.statusOpen;
    if (rate >= 50) return AppColors.statusSoon;
    return AppColors.error;
  }
}
