import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/homepage.dart';
import '../../../data/models/payment.dart';
import '../../../data/providers/payment_provider.dart';

/// 결제 직전 안내 박스 (웹 PaymentInfoBox.js의 Flutter 포팅)
/// - 참가비 / PG 수수료(부담자) / 합계 분리 표시
/// - 환불 정책 표 + 실제 환불액 미리보기
/// - 4정책 변수(pgFeeBearer / refundFeeBearer / sameDayFree / paymentFeeRefundOnCancel) 기반 동적 안내
/// - 환불 수수료 강조 박스 (분쟁 방지)
class PaymentInfoBox extends ConsumerWidget {
  final HomepageDetail homepage;
  final int baseFee;
  final String? footerHint;

  const PaymentInfoBox({
    super.key,
    required this.homepage,
    required this.baseFee,
    this.footerHint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policiesAsync = ref.watch(refundPoliciesProvider(homepage.homepageId));

    final isUserPaysPaymentFee = homepage.isUserPaysPaymentFee;
    final isUserPaysRefundFee = homepage.isUserPaysRefundFee;
    final sameDayFree = homepage.sameDayFree;
    final paymentFeeRefundOnCancel = homepage.refundPaymentFeeOnCancel;
    final paymentFeeFixed = homepage.paymentFeeFixedOrDefault;
    final refundFeeFixed = homepage.refundFeeFixedOrDefault;
    final refundNoticeOverride = homepage.refundNoticeOverride;

    final pgFeeAmount = homepage.computeUserPaymentPgFee(baseFee);
    final totalAmount = baseFee + pgFeeAmount;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0F7FF), Color(0xFFE8F1FE)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC8DEF9), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 참가비
          _amountRow('참가비 합계', '${_fmt(baseFee)}원', emphasis: false),

          // PG 수수료 (사용자 부담일 때만)
          if (isUserPaysPaymentFee && pgFeeAmount > 0) ...[
            const SizedBox(height: 6),
            _amountRow(
              'PG 수수료 (정액)',
              '+${_fmt(pgFeeAmount)}원',
              emphasis: false,
              subtext: '결제대행사 수수료 · 본 대회는 참가자가 부담합니다',
            ),
          ],

          // 총 결제 금액
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFC8DEF9)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '총 결제 금액',
                style: TextStyle(fontSize: 15, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600),
              ),
              Text(
                '${_fmt(totalAmount)}원',
                style: const TextStyle(fontSize: 22, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
              ),
            ],
          ),

          // 환불 정책 + 시뮬레이션
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFC8DEF9)),
          const SizedBox(height: 12),
          const Text(
            '📋 환불 정책 · 환불 금액 미리보기',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
          ),
          const SizedBox(height: 10),

          // 당일 취소 안내 (토스 2026-05-14 정책: 당일도 환불 수수료 차감)
          if (sameDayFree && totalAmount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '💚 결제 당일 취소',
                    style: TextStyle(fontSize: 13, color: Color(0xFF047857), fontWeight: FontWeight.w600),
                  ),
                  Text(
                    isUserPaysRefundFee && refundFeeFixed > 0
                        ? '${_fmt((totalAmount - refundFeeFixed).clamp(0, 1 << 31))}원 환불 (수수료 ${_fmt(refundFeeFixed)}원 차감)'
                        : '전액 환불 ${_fmt(totalAmount)}원',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF047857), fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),

          // 환불 정책 표
          policiesAsync.when(
            data: (policies) => _buildPolicyTable(
              policies,
              totalAmount: totalAmount,
              sameDayFree: sameDayFree,
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (_, __) => _buildPolicyTable(
              _defaultPolicies(),
              totalAmount: totalAmount,
              sameDayFree: sameDayFree,
            ),
          ),

          // 안내 문구 (운영자 override 우선)
          const SizedBox(height: 12),
          if (refundNoticeOverride != null && refundNoticeOverride.trim().isNotEmpty)
            Text(
              refundNoticeOverride,
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.7),
            )
          else
            _buildDynamicNotice(
              sameDayFree: sameDayFree,
              isUserPaysPaymentFee: isUserPaysPaymentFee,
              paymentFeeRefundOnCancel: paymentFeeRefundOnCancel,
              isUserPaysRefundFee: isUserPaysRefundFee,
              pgFeeAmount: pgFeeAmount,
              refundFeeFixed: refundFeeFixed,
              totalAmount: totalAmount,
            ),

          if (footerHint != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                footerHint!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF555555), height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _amountRow(String label, String value, {bool emphasis = false, String? subtext}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: emphasis ? 15 : 14,
                  color: const Color(0xFF444444),
                  fontWeight: emphasis ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (subtext != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtext,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
                  ),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasis ? 18 : 14,
            color: const Color(0xFF333333),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPolicyTable(List<RefundPolicy> policies, {required int totalAmount, required bool sameDayFree}) {
    // daysBeforeContest 내림차순
    final sorted = List<RefundPolicy>.from(policies)
      ..sort((a, b) => b.daysBeforeContest.compareTo(a.daysBeforeContest));

    final showRefundColumn = totalAmount > 0;
    final timingHeader = sameDayFree ? '다음 날 이후 취소 시점' : '취소 시점';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(timingHeader,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  flex: 1,
                  child: Text('환불율',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ),
                if (showRefundColumn)
                  Expanded(
                    flex: 2,
                    child: Text('실제 환불액',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          // 행 — 각 행에 실제 날짜 범위 함께 표시
          ...sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final isLast = i == sorted.length - 1;
            final refunded = showRefundColumn ? homepage.simulateRefund(totalAmount, p.refundRate) : 0;
            final rateColor = p.refundRate >= 100
                ? const Color(0xFF16A34A)
                : p.refundRate > 0
                    ? const Color(0xFFD97706)
                    : const Color(0xFFDC2626);
            // 이전 정책의 daysBeforeContest (날짜 범위 계산용)
            final prevDays = i == 0 ? null : sorted[i - 1].daysBeforeContest;
            final dateRange = _formatDateRange(homepage.contestStartDate, prevDays, p.daysBeforeContest);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.description ?? '대회 ${p.daysBeforeContest}일 전까지',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF444444)),
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
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${p.refundRate}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 13, color: rateColor, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (showRefundColumn)
                    Expanded(
                      flex: 2,
                      child: Text(
                        refunded > 0 ? '${_fmt(refunded)}원' : '환불 불가',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 13, color: rateColor, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDynamicNotice({
    required bool sameDayFree,
    required bool isUserPaysPaymentFee,
    required bool paymentFeeRefundOnCancel,
    required bool isUserPaysRefundFee,
    required int pgFeeAmount,
    required int refundFeeFixed,
    required int totalAmount,
  }) {
    final notices = <Widget>[];

    if (sameDayFree) {
      if (isUserPaysRefundFee && refundFeeFixed > 0) {
        notices.add(_noticeLine(
          '당일 취소 시 환불율 100%가 적용되며, 환불 수수료 ${_fmt(refundFeeFixed)}원은 차감됩니다.',
          boldStart: '※ ',
          boldKeywords: ['당일 취소', '환불율 100%', '환불 수수료 ${_fmt(refundFeeFixed)}원'],
        ));
      } else {
        notices.add(_noticeLine('당일 취소 시 환불율과 무관하게 전액 환불됩니다.', boldStart: '※ ', boldKeywords: ['당일 취소', '전액 환불']));
      }
    }

    if (isUserPaysPaymentFee && !paymentFeeRefundOnCancel && pgFeeAmount > 0) {
      notices.add(_noticeLine(
        '결제 시 부담하신 결제 PG 수수료 ${_fmt(pgFeeAmount)}원은 환불 시 환급되지 않습니다.',
        boldStart: '※ ',
        boldKeywords: ['결제 PG 수수료 ${_fmt(pgFeeAmount)}원'],
      ));
    }
    if (isUserPaysPaymentFee && paymentFeeRefundOnCancel && pgFeeAmount > 0) {
      notices.add(_noticeLine(
        '결제 시 부담하신 결제 PG 수수료 ${_fmt(pgFeeAmount)}원은 환불 시 함께 환급됩니다.',
        boldStart: '※ ',
      ));
    }

    // 환불 수수료 강조 박스 (분쟁 방지)
    if (isUserPaysRefundFee && refundFeeFixed > 0) {
      notices.add(_buildRefundFeeDetailBox(
        refundFeeFixed: refundFeeFixed,
        sameDayFree: sameDayFree,
        totalAmount: totalAmount,
      ));
    }

    if (!isUserPaysPaymentFee && !isUserPaysRefundFee) {
      notices.add(_noticeLine('결제·환불 PG 수수료는 대회 진행측이 부담합니다.', boldStart: '※ '));
    }

    notices.add(_noticeLine(
      '가상계좌 환불은 환불받을 계좌 정보(은행/계좌번호/예금주)가 필요합니다.',
      boldStart: '※ ',
      boldKeywords: ['계좌 정보(은행/계좌번호/예금주)'],
    ));
    notices.add(_noticeLine('부분환불(학원 단체등록 일부 학생 취소)도 동일 정책이 적용됩니다.', boldStart: '※ '));
    notices.add(_noticeLine(
      '가상계좌 입금 완료 후 결제 확인까지 은행/PG사 시스템에 따라 수 분~수십 분이 소요될 수 있습니다.',
      boldStart: '※ ',
      boldKeywords: ['수 분~수십 분이 소요'],
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: notices.map((w) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: w)).toList(),
    );
  }

  Widget _noticeLine(String text, {String boldStart = '', List<String>? boldKeywords}) {
    final spans = <TextSpan>[];
    if (boldStart.isNotEmpty) spans.add(TextSpan(text: boldStart));

    if (boldKeywords == null || boldKeywords.isEmpty) {
      spans.add(TextSpan(text: text));
    } else {
      var remaining = text;
      while (remaining.isNotEmpty) {
        int? hitIndex;
        String? hitWord;
        for (final kw in boldKeywords) {
          final idx = remaining.indexOf(kw);
          if (idx >= 0 && (hitIndex == null || idx < hitIndex)) {
            hitIndex = idx;
            hitWord = kw;
          }
        }
        if (hitIndex == null || hitWord == null) {
          spans.add(TextSpan(text: remaining));
          break;
        }
        if (hitIndex > 0) {
          spans.add(TextSpan(text: remaining.substring(0, hitIndex)));
        }
        spans.add(TextSpan(
          text: hitWord,
          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
        ));
        remaining = remaining.substring(hitIndex + hitWord.length);
      }
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13.5, color: Color(0xFF374151), height: 1.7),
        children: spans,
      ),
    );
  }

  Widget _buildRefundFeeDetailBox({
    required int refundFeeFixed,
    required bool sameDayFree,
    required int totalAmount,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDBA74), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFFED7AA), width: 1, style: BorderStyle.solid)),
            ),
            child: Text(
              '⚠️ 환불 수수료 ${_fmt(refundFeeFixed)}원 차감 안내',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFC2410C)),
            ),
          ),
          const SizedBox(height: 8),
          _bulletItem(
            '토스페이먼츠(결제대행사)가 가상계좌 환불 처리 시 부과하는 PG 환불 수수료로, 본 대회는 참가자 부담으로 설정되어 있습니다.',
            boldKeywords: const ['가상계좌 환불 처리 시', '참가자 부담'],
          ),
          _bulletItem(
            '환불 시 환불액에서 ${_fmt(refundFeeFixed)}원이 자동 차감되어 입금됩니다. 결제 당일(같은 날) 취소도 동일하게 차감됩니다. (토스 가상계좌 정책)',
            boldKeywords: ['${_fmt(refundFeeFixed)}원이 자동 차감', '결제 당일(같은 날) 취소도 동일하게 차감'],
          ),
          if (sameDayFree)
            _bulletItem(
              '결제 당일(같은 날) 취소 시에는 환불 정책과 무관하게 환불율 100%가 적용되어, 환불 수수료 ${_fmt(refundFeeFixed)}원만 차감된 금액이 입금됩니다.',
              boldKeywords: const ['결제 당일(같은 날) 취소', '환불율 100%'],
            ),
          if (totalAmount > 0)
            _bulletItem(
              '예시: 결제 ${_fmt(totalAmount)}원 · 환불율 100% 적용 시 실제 입금액은 ${_fmt((totalAmount - refundFeeFixed).clamp(0, 1 << 31))}원 (= ${_fmt(totalAmount)}원 − 환불 수수료 ${_fmt(refundFeeFixed)}원)',
              boldKeywords: ['${_fmt((totalAmount - refundFeeFixed).clamp(0, 1 << 31))}원'],
            ),
          _bulletItem(
            '환불율이 100% 미만인 경우, 환불 수수료를 먼저 차감한 금액에 환불율을 곱한 값이 입금됩니다.',
          ),
        ],
      ),
    );
  }

  Widget _bulletItem(String text, {List<String>? boldKeywords}) {
    final spans = <TextSpan>[];
    if (boldKeywords == null || boldKeywords.isEmpty) {
      spans.add(TextSpan(text: text));
    } else {
      var remaining = text;
      while (remaining.isNotEmpty) {
        int? hitIndex;
        String? hitWord;
        for (final kw in boldKeywords) {
          final idx = remaining.indexOf(kw);
          if (idx >= 0 && (hitIndex == null || idx < hitIndex)) {
            hitIndex = idx;
            hitWord = kw;
          }
        }
        if (hitIndex == null || hitWord == null) {
          spans.add(TextSpan(text: remaining));
          break;
        }
        if (hitIndex > 0) spans.add(TextSpan(text: remaining.substring(0, hitIndex)));
        spans.add(TextSpan(
          text: hitWord,
          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFC2410C)),
        ));
        remaining = remaining.substring(hitIndex + hitWord.length);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2, right: 8),
            child: Text('•', style: TextStyle(fontSize: 13, color: Color(0xFFC2410C), fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Color(0xFF4B3A1F), height: 1.7),
                children: spans,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<RefundPolicy> _defaultPolicies() {
    return [
      RefundPolicy(policyId: 0, daysBeforeContest: 7, refundRate: 100, description: '대회 7일 전까지'),
      RefundPolicy(policyId: 0, daysBeforeContest: 3, refundRate: 70, description: '대회 3일~7일 전'),
      RefundPolicy(policyId: 0, daysBeforeContest: 1, refundRate: 50, description: '대회 1일~3일 전'),
      RefundPolicy(policyId: 0, daysBeforeContest: 0, refundRate: 0, description: '대회 당일'),
    ];
  }

  String _fmt(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  /// 정책 적용 날짜 범위 계산 (백엔드 로직과 동일)
  ///  - prevDays == null: 첫 정책(가장 큰 daysBeforeContest) → "~ 6/20(목)까지"
  ///  - prevDays != null: 중간/마지막 정책 → "6/21(금) ~ 6/24(월)"
  ///  - contestDate == null: 빈 문자열 (날짜 표시 안 함)
  String _formatDateRange(DateTime? contestDate, int? prevDays, int thisDays) {
    if (contestDate == null) return '';
    // 시간 부분 제거 (KST 안전)
    final base = DateTime(contestDate.year, contestDate.month, contestDate.day);

    if (prevDays == null) {
      final end = base.subtract(Duration(days: thisDays));
      return '~ ${_formatDate(end)}까지';
    }
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
