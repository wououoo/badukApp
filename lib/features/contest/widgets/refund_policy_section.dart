import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/payment_provider.dart';
import '../../../data/providers/homepage_provider.dart';

/// 환불 규정 표시 위젯 (대회 상세 / 참가신청 / 환불 규정 페이지에서 재사용).
/// 문구(텍스트)와 계산식은 전부 백엔드(/api/refund/registration-notice)가 DB 데이터로 생성.
/// 이 위젯은 받은 응답을 '그리기만' 한다 → 정책/문구 변경은 백엔드만 수정(앱 리빌드 불필요).
class RefundPolicySection extends ConsumerWidget {
  final int homepageId;
  final bool compact; // true: 축약(대회 상세), false: 전체
  final VoidCallback? onTapDetail;

  const RefundPolicySection({
    super.key,
    required this.homepageId,
    this.compact = false,
    this.onTapDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // baseFee=0 → 일반 정책 표시(금액 미산정). 문구/계산식 모두 백엔드 생성.
    final noticeAsync = ref.watch(
      registrationNoticeProvider((homepageId: homepageId, baseFee: 0)),
    );
    final contestStartDate = ref.watch(homepageDetailProvider(homepageId)).maybeWhen(
          data: (hp) => hp.contestStartDate,
          orElse: () => null,
        );

    return noticeAsync.when(
      data: (n) {
        final rows = (n['policyRows'] as List?) ?? const [];
        if (rows.isEmpty) return const SizedBox.shrink();
        return _buildContent(n, contestStartDate);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildContent(Map<String, dynamic> n, DateTime? contestStartDate) {
    final rows = (n['policyRows'] as List?) ?? const [];
    final noticeLines = (n['noticeLines'] as List?) ?? const [];
    final bannerStyle = n['bannerStyle'] as String?;
    final bannerText = n['bannerText'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.statusSoon.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
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
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(13), topRight: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Icon(Icons.gavel_rounded, size: 18, color: AppColors.statusSoonText),
                const SizedBox(width: 8),
                Text('환불 규정',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.statusSoonText)),
                const Spacer(),
                if (compact && onTapDetail != null)
                  GestureDetector(
                    onTap: onTapDetail,
                    child: Text('자세히 보기',
                        style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),

          // 기간별 배너 (백엔드 생성)
          if (bannerStyle != null && bannerText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _banner(bannerStyle, bannerText),
            ),

          // 정책 타임라인
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...rows.asMap().entries.map((e) {
                  final i = e.key;
                  final p = e.value as Map;
                  final isLast = i == rows.length - 1;
                  final dateRange = _formatDateRange(contestStartDate, _asInt(p['prevDays']), _asInt(p['daysBeforeContest']) ?? 0);
                  return _buildPolicyRow(p, isLast, dateRange);
                }),

                // 안내 문구 (백엔드 생성)
                if (noticeLines.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...noticeLines.map((l) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('$l',
                                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.5)),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(String style, String text) {
    Color bg, border, fg;
    switch (style) {
      case 'success':
        bg = const Color(0xFFECFDF5); border = const Color(0xFFA7F3D0); fg = const Color(0xFF047857);
        break;
      case 'warning':
        bg = const Color(0xFFFFF8E1); border = const Color(0xFFFFE082); fg = const Color(0xFF8B5A00);
        break;
      default:
        bg = const Color(0xFFFEF2F2); border = const Color(0xFFFECACA); fg = const Color(0xFFB91C1C);
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: border)),
      child: Text(text,
          style: TextStyle(
              fontSize: 12.5, color: fg, height: 1.5,
              fontWeight: style == 'success' ? FontWeight.w600 : FontWeight.w400)),
    );
  }

  Widget _buildPolicyRow(Map p, bool isLast, String dateRange) {
    final rate = _asInt(p['rate']) ?? 0;
    final days = _asInt(p['daysBeforeContest']) ?? 0;
    final rateColor = rate >= 100
        ? AppColors.statusOpen
        : rate >= 50
            ? AppColors.statusSoon
            : AppColors.error;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: rateColor.withOpacity(0.12), shape: BoxShape.circle),
            child: Center(
              child: Text('D-$days',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: rateColor)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((p['description'] as String?) ?? '대회 $days일 전까지',
                    style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                if (dateRange.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(dateRange, style: TextStyle(fontSize: 11, color: rateColor, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: rateColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('$rate%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: rateColor)),
          ),
        ],
      ),
    );
  }

  int? _asInt(dynamic v) => v is num ? v.toInt() : null;

  /// 정책 적용 날짜 범위 (표시 전용)
  String _formatDateRange(DateTime? contestDate, int? prevDays, int thisDays) {
    if (contestDate == null) return '';
    final base = DateTime(contestDate.year, contestDate.month, contestDate.day);
    if (prevDays == null) {
      return '~ ${_formatDate(base.subtract(Duration(days: thisDays)))}까지';
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
