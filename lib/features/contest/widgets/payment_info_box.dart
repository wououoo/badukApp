import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/homepage.dart';
import '../../../data/providers/payment_provider.dart';

/// 결제 직전 안내 박스.
/// 문구(텍스트)와 계산식(금액)은 전부 백엔드(/api/refund/registration-notice)가 DB 데이터로 생성한다.
/// 이 위젯은 받은 응답을 '그리기만' 한다 → 정책/문구/기간 로직 변경은 백엔드만 수정(앱 리빌드 불필요).
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
    final noticeAsync = ref.watch(
      registrationNoticeProvider((homepageId: homepage.homepageId, baseFee: baseFee)),
    );
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
      child: noticeAsync.when(
        data: (n) => _content(n),
        loading: () => _content(const <String, dynamic>{}),
        error: (_, __) => _content(const <String, dynamic>{}),
      ),
    );
  }

  Widget _content(Map<String, dynamic> n) {
    final totalAmount = _asInt(n['totalAmount']) ?? baseFee;
    final pgFeeAmount = _asInt(n['pgFeeAmount']) ?? 0;
    final rows = (n['policyRows'] as List?) ?? const [];
    final noticeLines = (n['noticeLines'] as List?) ?? const [];
    final bannerStyle = n['bannerStyle'] as String?;
    final bannerText = n['bannerText'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _amountRow('참가비 합계', '${_fmt(baseFee)}원'),
        if (pgFeeAmount > 0) ...[
          const SizedBox(height: 6),
          _amountRow('PG 수수료', '+${_fmt(pgFeeAmount)}원',
              subtext: '결제대행사 수수료 · 본 대회는 참가자가 부담합니다'),
        ],
        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0xFFC8DEF9)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('총 결제 금액',
                style: TextStyle(fontSize: 15, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600)),
            Text('${_fmt(totalAmount)}원',
                style: const TextStyle(fontSize: 22, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFC8DEF9)),
        const SizedBox(height: 12),
        const Text('📋 환불 정책 · 환불 금액 미리보기',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A))),
        const SizedBox(height: 10),
        if (bannerStyle != null && bannerText != null) _banner(bannerStyle, bannerText),
        _policyTable(rows, totalAmount: totalAmount),
        if (noticeLines.isNotEmpty) const SizedBox(height: 4),
        ...noticeLines.map((l) => _noticeLine('$l')),
        if (footerHint != null) ...[
          const SizedBox(height: 10),
          Text(footerHint!, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
      ],
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: border)),
      child: Text(text,
          style: TextStyle(
              fontSize: 12.5, color: fg, height: 1.5,
              fontWeight: style == 'success' ? FontWeight.w600 : FontWeight.w400)),
    );
  }

  Widget _policyTable(List rows, {required int totalAmount}) {
    final showRefund = totalAmount > 0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(7), topRight: Radius.circular(7)),
            ),
            child: Row(
              children: [
                const Expanded(flex: 3, child: Text('취소 시점',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600))),
                const Expanded(flex: 1, child: Text('환불율', textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600))),
                if (showRefund)
                  const Expanded(flex: 2, child: Text('실제 환불액', textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          ...rows.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value as Map;
            final isLast = i == rows.length - 1;
            final rate = _asInt(p['rate']) ?? 0;
            final refund = _asInt(p['refund']);
            final rateColor = rate >= 100
                ? const Color(0xFF16A34A)
                : rate > 0
                    ? const Color(0xFFD97706)
                    : const Color(0xFFDC2626);
            final dateRange = _formatDateRange(
                homepage.contestStartDate, _asInt(p['prevDays']), _asInt(p['daysBeforeContest']));
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((p['description'] as String?) ?? '대회 ${_asInt(p['daysBeforeContest']) ?? 0}일 전까지',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF444444))),
                        if (dateRange.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(dateRange, style: TextStyle(fontSize: 11, color: rateColor, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text('$rate%', textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 13, color: rateColor, fontWeight: FontWeight.w700)),
                  ),
                  if (showRefund)
                    Expanded(
                      flex: 2,
                      child: Text(refund != null && refund > 0 ? '${_fmt(refund)}원' : '환불 불가',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 13, color: rateColor, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _noticeLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text('※ $text', style: const TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.6)),
    );
  }

  Widget _amountRow(String label, String value, {String? subtext}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF374151))),
              if (subtext != null) ...[
                const SizedBox(height: 2),
                Text(subtext, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ],
          ),
        ),
        Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600)),
      ],
    );
  }

  int? _asInt(dynamic v) => v is num ? v.toInt() : null;

  String _fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  /// 정책 적용 날짜 범위 (표시 전용)
  String _formatDateRange(DateTime? contestDate, int? prevDays, int? thisDays) {
    if (contestDate == null || thisDays == null) return '';
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    String fmt(DateTime d) => '${d.month}/${d.day}(${weekdays[d.weekday % 7]})';
    DateTime sub(int days) => contestDate.subtract(Duration(days: days));
    if (prevDays == null) return '~ ${fmt(sub(thisDays))}까지';
    final start = sub(prevDays - 1);
    final end = sub(thisDays);
    if (start == end) return fmt(start);
    return '${fmt(start)} ~ ${fmt(end)}';
  }
}
