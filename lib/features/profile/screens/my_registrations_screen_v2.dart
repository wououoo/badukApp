import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/api_client.dart';
import '../../../data/providers/payment_provider.dart';
// 목록 provider는 원본 화면 것을 그대로 쓴다.
// 복사본에서 다시 정의하면 홈·환불화면의 invalidate가 다른 인스턴스를 건드려
// 입금이 만료돼도 이 화면이 갱신되지 않는다.
import 'my_registrations_screen.dart' show myRegistrationsProvider;
import '../../../data/services/chat_service.dart';
import '../../../data/services/notification_service_stub.dart'
    if (dart.library.io) '../../../data/services/notification_service.dart';


/// 내 참가신청 내역 화면
class MyRegistrationsScreenV2 extends ConsumerStatefulWidget {
  const MyRegistrationsScreenV2({super.key});

  @override
  ConsumerState<MyRegistrationsScreenV2> createState() => _MyRegistrationsScreenV2State();
}

class _MyRegistrationsScreenV2State extends ConsumerState<MyRegistrationsScreenV2> {
  bool _isCancelling = false;

  /// 남은 시간을 1초마다 다시 그리기 위한 시계.
  /// 입금 대기 건이 하나도 없으면 굳이 돌릴 이유가 없어 화면을 다시 그리지 않는다.
  Timer? _ticker;
  bool _needsTick = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_needsTick) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registrations = ref.watch(myRegistrationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('내 참가신청'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myRegistrationsProvider);
        },
        color: AppColors.primary,
        child: registrations.when(
          data: (list) => list.isEmpty ? _buildEmpty() : _buildSectioned(context, list),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: AppColors.textTertiary, size: 48),
                const SizedBox(height: 12),
                Text(
                  '참가신청 내역을 불러올 수 없습니다',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 세 덩어리로 나눈다.
  ///   해야 할 일 : 입금하지 않으면 취소되는 건 — 맨 위, 가장 급한 하나는 반상
  ///   예정       : 결제가 끝났고 아직 안 열린 대회
  ///   지난·취소  : 끝났거나 취소된 것 — 아래로 내린다
  Widget _buildSectioned(BuildContext context, List<Map<String, dynamic>> list) {
    final todo = <Map<String, dynamic>>[];
    final upcoming = <Map<String, dynamic>>[];
    final past = <Map<String, dynamic>>[];

    final today = DateTime.now();
    for (final reg in list) {
      final payment = reg['paymentStatus'] as String? ?? 'UNPAID';
      final status = reg['status'] as String? ?? 'PENDING';
      final cancelled = status == 'CANCELLED' || status == 'REFUNDED';

      if (!cancelled && payment == 'WAITING_FOR_DEPOSIT') {
        todo.add(reg);
        continue;
      }
      final start = _startDateOf(reg);
      // 날짜를 모르면 지난 것으로 밀지 않는다 — 아직 열릴 대회를 숨기는 쪽이 더 나쁘다.
      final notYet = start == null || !start.isBefore(DateTime(today.year, today.month, today.day));
      if (!cancelled && notYet) {
        upcoming.add(reg);
      } else {
        past.add(reg);
      }
    }

    // 급한 순 = 입금 기한이 빨리 끝나는 순
    todo.sort((a, b) {
      final x = _dueOf(a), y = _dueOf(b);
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    });
    upcoming.sort((a, b) {
      final x = _startDateOf(a), y = _startDateOf(b);
      if (x == null || y == null) return 0;
      return x.compareTo(y);
    });

    _needsTick = todo.isNotEmpty;

    final children = <Widget>[];
    if (todo.isNotEmpty) {
      children.add(_sectionTitle('해야 할 일', todo.length));
      for (int i = 0; i < todo.length; i++) {
        // 반상은 화면에 하나뿐이어야 시선이 갈 곳이 정해진다.
        // 두 건 이상이면 가장 급한 것만 검은 면을 입고 나머지는 테두리로 표시한다.
        children.add(i == 0
            ? _buildUrgentCard(context, todo[i])
            : _buildRegistrationCard(context, todo[i], urgent: true));
      }
    }
    if (upcoming.isNotEmpty) {
      children.add(_sectionTitle('예정', upcoming.length));
      for (final reg in upcoming) {
        children.add(_buildRegistrationCard(context, reg));
      }
    }
    if (past.isNotEmpty) {
      children.add(_sectionTitle('지난 · 취소', past.length));
      for (final reg in past) {
        children.add(_buildRegistrationCard(context, reg, faded: true));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: children,
    );
  }

  Widget _sectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // ── 가장 급한 한 건 (반상) ─────────────────────────────
  Widget _buildUrgentCard(BuildContext context, Map<String, dynamic> reg) {
    final va = reg['virtualAccount'] as Map<String, dynamic>?;
    final amount = (va?['amount'] as num?)?.toInt() ??
        ((reg['fee'] as num?)?.toInt() ?? 0) - ((reg['paidAmount'] as num?)?.toInt() ?? 0);
    final due = _dueOf(reg);
    final left = due == null ? null : due.difference(DateTime.now());
    final expired = left != null && left.isNegative;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: AppColors.board,
          child: InkWell(
            onTap: () => _showDetail(context, reg),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _GobanGridPainter())),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 15, color: AppColors.boardAccent),
                          const SizedBox(width: 6),
                          const Text(
                            '입금 대기',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: AppColors.boardAccent,
                            ),
                          ),
                          const Spacer(),
                          if (left != null)
                            Text(
                              expired ? '기한 지남' : _remaining(left),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                                color: AppColors.boardAccent,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Text(
                        reg['contestName'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reg['categoryName'] ?? '',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A97A6)),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${_formatNumber(amount)}원',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.3,
                          height: 1.05,
                          color: Colors.white,
                        ),
                      ),
                      if (va != null) ...[
                        const SizedBox(height: 14),
                        Container(height: 1, color: const Color(0x1AFFFFFF)),
                        const SizedBox(height: 12),
                        _buildDarkAccountRow(va),
                      ],
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

  /// 반상 위 계좌 한 줄. 계좌번호는 눌러서 복사한다.
  Widget _buildDarkAccountRow(Map<String, dynamic> va) {
    final bank = (va['vaBankName'] as String?) ?? '-';
    final number = (va['vaAccountNumber'] as String?) ?? '-';
    final holder = (va['vaCustomerName'] as String?) ?? '';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$bank $number',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (holder.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    // 입금자명이 다르면 자동 대사가 안 돼 확인이 늦어진다. 그래서 같이 적는다.
                    '예금주 $holder',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A97A6)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: number));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('계좌번호를 복사했습니다'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.boardAccent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Text(
              '복사',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 시간·날짜 ──────────────────────────────────────────
  DateTime? _startDateOf(Map<String, dynamic> reg) =>
      DateTime.tryParse((reg['contestStartDate'] ?? '').toString());

  DateTime? _dueOf(Map<String, dynamic> reg) {
    final va = reg['virtualAccount'] as Map<String, dynamic>?;
    if (va == null) return null;
    return DateTime.tryParse((va['vaDueDate'] ?? '').toString());
  }

  /// 남은 시간. 한 시간이 넘으면 분 단위까지만 보여준다 — 초까지 세는 건 임박했을 때만 뜻이 있다.
  String _remaining(Duration d) {
    if (d.inHours >= 1) return '${d.inHours}시간 ${d.inMinutes % 60}분';
    final m = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  String _shortDate(DateTime? d) {
    if (d == null) return '';
    return '${d.month}월 ${d.day}일';
  }

  Widget _buildEmpty() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 130),
        Icon(Icons.how_to_reg_outlined, color: AppColors.textHint, size: 56),
        const SizedBox(height: 18),
        Text(
          '아직 신청한 대회가 없습니다',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '신청하면 입금 기한과 진행 상황을 여기서 봅니다',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 22),
        Center(
          child: SizedBox(
            height: 46,
            child: ElevatedButton(
              // 빈 화면에서 끝내지 않고 다음 걸음을 준다.
              onPressed: () => context.go('/contests'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                '대회 둘러보기',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 목록 카드.
  ///   urgent : 입금 대기인데 반상을 이미 다른 건이 가져간 경우 — 테두리로만 급함을 표시
  ///   faded  : 지나갔거나 취소된 건 — 흐리게 내려 시선을 뺏지 않게
  Widget _buildRegistrationCard(
    BuildContext context,
    Map<String, dynamic> reg, {
    bool urgent = false,
    bool faded = false,
  }) {
    final status = reg['status'] as String? ?? 'PENDING';
    final paymentStatus = reg['paymentStatus'] as String? ?? 'UNPAID';
    final fee = (reg['fee'] as num?)?.toInt() ?? 0;
    final paidAmount = (reg['paidAmount'] as num?)?.toInt() ?? 0;
    final unpaid = fee - paidAmount;
    final options = _groupOptions(_optionsOf(reg));
    final startDate = _shortDate(_startDateOf(reg));

    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgent ? AppColors.primary : AppColors.border,
          width: urgent ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetail(context, reg),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        reg['contestName'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          letterSpacing: -0.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  // 언제 · 어느 부문 — 한 줄로 붙여야 두 줄을 훑지 않는다
                  [startDate, reg['categoryName'] ?? ''].where((e) => e.toString().isNotEmpty).join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
                ),
                if (options.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in options.entries)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '${e.key} ${e.value}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (fee > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      _buildPaymentBadge(paymentStatus),
                      const Spacer(),
                      if (unpaid > 0) ...[
                        Text(
                          '미납',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${_formatNumber(unpaid)}원',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: AppColors.primary,
                          ),
                        ),
                      ] else
                        Text(
                          '${_formatNumber(fee)}원',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                    ],
                  ),
                ],
                // 반상을 다른 건이 가져간 입금 대기 건은 계좌를 여기서 보여준다
                if (urgent && reg['virtualAccount'] != null) ...[
                  const SizedBox(height: 11),
                  _buildVirtualAccountBox(reg['virtualAccount'] as Map<String, dynamic>),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // 지난 건은 지워서 감추는 게 아니라 흐리게 둔다 — 찾을 수는 있어야 한다.
    return faded ? Opacity(opacity: 0.62, child: card) : card;
  }

  Widget _buildVirtualAccountBox(Map<String, dynamic> va) {
    final bankName = (va['vaBankName'] as String?) ?? '-';
    final accountNumber = (va['vaAccountNumber'] as String?) ?? '-';
    final customerName = (va['vaCustomerName'] as String?) ?? '';
    final dueDateStr = va['vaDueDate'] as String?;
    final dueDate = _formatDueDate(dueDateStr);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                '입금 안내',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              const Spacer(),
              if (dueDate.isNotEmpty)
                Text(
                  '$dueDate까지',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('$bankName  ', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Expanded(
                child: SelectableText(
                  accountNumber,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: accountNumber));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('계좌번호가 복사되었습니다'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
                  ),
                  child: Text(
                    '복사',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          if (customerName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '입금자명: $customerName',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.access_time, size: 14, color: Color(0xFFB26A00)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '입금 완료 후 결제 확인까지 은행/PG사 시스템에 따라 수 분~수십 분이 소요될 수 있습니다.\n잠시 후 새로고침해 주세요.',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF8B5A00), height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDueDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '$m/$d $h:$mi';
    } catch (_) {
      return '';
    }
  }

  Future<void> _openChat(BuildContext context, Map<String, dynamic> reg) async {
    try {
      final chatService = ChatService();
      final homepageId = (reg['homepageId'] as num?)?.toInt();
      if (homepageId == null) return;
      final room = await chatService.getOrCreateRoom(homepageId: homepageId);
      if (context.mounted) {
        context.push('/chat/${room['roomId']}', extra: {
          'contestTitle': room['contestTitle'] ?? reg['contestName'],
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('채팅방 생성에 실패했습니다.')),
        );
      }
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case 'APPROVED':
        bg = AppColors.statusOpenBg;
        text = AppColors.statusOpenText;
        label = '승인';
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFF991B1B);
        label = '거절';
        break;
      case 'CANCELLED':
        bg = AppColors.statusClosedBg;
        text = AppColors.statusClosedText;
        label = '취소';
        break;
      default: // PENDING
        bg = AppColors.statusSoonBg;
        text = AppColors.statusSoonText;
        label = '대기';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text),
      ),
    );
  }

  Widget _buildPaymentBadge(String paymentStatus) {
    Color bg;
    Color text;
    String label;

    switch (paymentStatus) {
      case 'COMPLETED':
        bg = AppColors.statusOpenBg;
        text = AppColors.statusOpenText;
        label = '결제완료';
        break;
      case 'WAITING_FOR_DEPOSIT':
        bg = const Color(0xFFFFF3CD);
        text = AppColors.primary;
        label = '입금대기';
        break;
      case 'PENDING':
        bg = AppColors.statusSoonBg;
        text = AppColors.statusSoonText;
        label = '결제대기';
        break;
      case 'REFUNDED':
        bg = AppColors.statusClosedBg;
        text = AppColors.statusClosedText;
        label = '환불완료';
        break;
      case 'PARTIAL_REFUNDED':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFF92400E);
        label = '부분환불';
        break;
      default: // UNPAID
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFF991B1B);
        label = '미결제';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text),
      ),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> reg) {
    final status = reg['status'] as String? ?? 'PENDING';
    final paymentStatus = reg['paymentStatus'] as String? ?? 'UNPAID';
    final fee = (reg['fee'] as num?)?.toInt() ?? 0;
    final paidAmount = (reg['paidAmount'] as num?)?.toInt() ?? 0;
    final unpaid = fee - paidAmount;
    final registeredAt = reg['registeredAt'] as String?;
    final registrationId = reg['registrationId'] as int? ?? 0;

    // 주최측 취소 불가 정책 (부문 override + 대회 전체 합산, 백엔드 cancellationBlocked)
    final cancellationBlocked = reg['cancellationBlocked'] == true;

    // 액션 버튼 표시 조건
    final canEdit = status == 'PENDING' || status == 'APPROVED';
    final canCancel = !cancellationBlocked && (status == 'PENDING' || (status == 'APPROVED' && paymentStatus != 'COMPLETED'));
    final canRefund = !cancellationBlocked && (status == 'APPROVED' && paymentStatus == 'COMPLETED');
    // 유료 항목(숙박 등)을 가진 대회에서, 결제를 마친 신청이면 항목만 더 살 수 있다.
    final canAddon = reg['hasPaidOptions'] == true &&
        status == 'APPROVED' &&
        paymentStatus == 'COMPLETED';
    // 대회장 화면은 참가가 확정됐고 대회가 코앞이거나 진행 중일 때만 뜻이 있다.
    // 한 달 뒤 대회에 체크인 화면을 띄워 봐야 할 일이 없다.
    final start = _startDateOf(reg);
    final showVenueScreen = status == 'APPROVED' &&
        start != null &&
        DateTime.now().isAfter(start.subtract(const Duration(days: 1)));

    final canPay = fee > 0 && unpaid > 0 && (paymentStatus == 'UNPAID' || paymentStatus == 'PENDING')
        && (status == 'PENDING' || status == 'APPROVED');
    final hasRefund = paymentStatus == 'REFUNDED' || paymentStatus == 'PARTIAL_REFUNDED';
    // 부문 변경은 별도 흐름 없이 "취소 후 재신청"으로 처리 (정원 race / 환불 정책 충돌 방지)
    // 안내 문구는 canRefund(결제완료 + 승인)인 케이스에 표시

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // 시트는 화면 맨 아래에 붙는다. SafeArea가 없으면 제스처 바(홈 인디케이터)가
      // 마지막 버튼 위에 겹쳐 눌리지 않는다.
      builder: (bottomSheetContext) => SafeArea(
        // 결제·환불 내역과 액션 버튼까지 붙으면 내용이 화면보다 길어져 아래가 잘렸다.
        // isScrollControlled는 시트를 늘려줄 뿐 넘치는 부분을 처리하지 않으므로 스크롤을 준다.
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            // 머리말 — 무슨 대회의 어느 부문인지, 지금 어떤 상태인지를 한 덩어리로.
            // 가운데 정렬 대회명 하나만 있으면 시트를 연 순간 맥락이 안 잡힌다.
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reg['contestName'] ?? '',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      _buildStatusBadge(status),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          reg['categoryName'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // 내야 할 돈이 있으면 그것만 크게. 없으면 낸 금액을 조용히 적는다.
            if (fee > 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                decoration: BoxDecoration(
                  color: unpaid > 0
                      ? AppColors.primary.withValues(alpha: 0.07)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: unpaid > 0
                        ? AppColors.primary.withValues(alpha: 0.35)
                        : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          unpaid > 0 ? '내야 할 금액' : '결제 금액',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: unpaid > 0
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_formatNumber(unpaid > 0 ? unpaid : paidAmount)}원',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.9,
                            color: unpaid > 0
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 얼마짜리에서 얼마를 냈는지는 아래에 작게 — 확인용이지 주인공이 아니다.
                    Text(
                      '참가비 ${_formatNumber(fee)}원 · 납부 ${_formatNumber(paidAmount)}원 · ${_paymentStatusLabel(paymentStatus)}',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            _detailRow('참가자', reg['participantName'] ?? ''),
            if (registeredAt != null)
              _detailRow('신청일', _formatDate(registeredAt)),

            // 신청한 추가 항목(숙박·식사 등) — 서버가 options로 내려준다. 없는 대회는 이 블록 자체가 안 그려진다.
            if (_optionsOf(reg).isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildOptionsSection(_optionsOf(reg)),
            ],

            // 환불 내역 표시
            if (hasRefund) ...[
              const SizedBox(height: 16),
              _buildRefundHistorySection(registrationId),
            ],

            // 부문 변경 안내 (결제 완료된 신청에만 표시)
            if (canRefund) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // 경고가 아니라 방법 안내다. 색으로 놀라게 하지 않는다.
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: AppColors.textTertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '부문을 바꾸시려면 [취소 신청]으로 환불받으신 후, 원하시는 부문으로 새로 신청해주세요.\n환불 정책에 따라 일부 차감될 수 있습니다.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 취소 불가 정책 안내 (활성 신청인데 주최측이 취소를 막은 경우)
            if (cancellationBlocked && (status == 'PENDING' || status == 'APPROVED')) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.block, size: 18, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '주최측 정책에 따라 현재 참가신청 취소가 불가합니다. 문의처로 연락해주세요.',
                        style: TextStyle(fontSize: 12, color: AppColors.error, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 대회로 가는 길 — 취소·수정보다 위에 둔다.
            // 신청을 확인하러 여는 것보다 "언제 어디로 가나"를 보러 여는 일이 훨씬 잦다.
            const SizedBox(height: 18),
            Row(
              children: [
                if (reg['homepageId'] != null)
                  Expanded(
                    child: _linkButton(
                      icon: Icons.place_outlined,
                      label: '장소 · 안내',
                      onTap: () {
                        Navigator.pop(bottomSheetContext);
                        // 대회 상세에 길찾기(지도앱 연결)와 일정·안내가 모두 있다
                        context.push('/contest/${(reg['homepageId'] as num).toInt()}');
                      },
                    ),
                  ),
                if (reg['homepageId'] != null && showVenueScreen)
                  const SizedBox(width: 9),
                if (showVenueScreen)
                  Expanded(
                    child: _linkButton(
                      icon: Icons.qr_code_scanner,
                      label: '대회장 화면',
                      onTap: () {
                        Navigator.pop(bottomSheetContext);
                        // 참가 정보·체크인·대진표. 접수처에서 보여주는 화면이다.
                        context.push('/qr/contests');
                      },
                    ),
                  ),
              ],
            ),

            // 액션 버튼 영역
            if (canEdit || canCancel || canRefund || canPay) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              // 아직 안 낸 돈이 있으면 그게 지금 할 일이다. 하나만 꽉 채워 앞세운다.
              if (canPay) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                      context.push('/payment', extra: {
                        'registration': null,
                        'participantName': reg['participantName'] ?? '',
                        'categoryName': reg['categoryName'] ?? '',
                        'contestName': reg['contestName'] ?? '',
                        'amount': unpaid,
                        'homepageId': (reg['homepageId'] as num?)?.toInt(),
                        'contestStartDate': null,
                        'registrationId': registrationId,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      '${_formatNumber(unpaid)}원 결제하기',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              // 1행: 수정
              Row(
                children: [
                  if (canEdit)
                    Expanded(
                      child: _actionButton(
                        icon: Icons.edit_outlined,
                        label: '정보 수정',
                        color: AppColors.primary,
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          context.push(
                            '/registration/edit/$registrationId',
                            extra: reg,
                          );
                        },
                      ),
                    ),
                ],
              ),
              // 2행: 취소/환불
              if (canCancel || canRefund) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (canCancel)
                      Expanded(
                        child: _actionButton(
                          icon: Icons.cancel_outlined,
                          label: '신청 취소',
                          color: AppColors.error,
                          onTap: () {
                            Navigator.pop(bottomSheetContext);
                            _confirmCancel(registrationId);
                          },
                        ),
                      ),
                    if (canRefund)
                      Expanded(
                        child: _actionButton(
                          icon: Icons.cancel_outlined,
                          label: '취소 신청',
                          color: const Color(0xFFD97706),
                          onTap: () {
                            Navigator.pop(bottomSheetContext);
                            context.push('/refund/$registrationId');
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ],

            // 항목 추가결제 — 결제를 마친 신청에, 대회가 유료 항목(숙박 등)을 가진 경우에만.
            // 취소 차단(cancellationBlocked)과는 무관하다. 돈을 더 내는 행위라 막을 이유가 없다.
            if (canAddon) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.add_shopping_cart_outlined,
                      label: '항목 추가결제',
                      color: AppColors.primary,
                      onTap: () async {
                        Navigator.pop(bottomSheetContext);
                        final done = await context.push<bool>('/payment/addon', extra: {
                          'registrationId': registrationId,
                          'homepageId': reg['homepageId'],
                          'categoryId': reg['categoryId'],
                          'contestName': reg['contestName'] ?? '',
                        });
                        if (done == true) ref.invalidate(myRegistrationsProvider);
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
          ),
        ),
      ),
    );
  }

  /// 다른 화면으로 보내는 조용한 버튼. 취소·환불 같은 결정 버튼과 무게를 다르게 둔다.
  Widget _linkButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: AppColors.textSecondary),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(int registrationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('참가신청 취소'),
        content: const Text('정말 참가신청을 취소하시겠습니까?\n취소 후에는 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('취소하기'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);

    try {
      final apiClient = ApiClient();
      final response = await apiClient.post(
        '${ApiConstants.myRegistrationUpdate}/$registrationId/cancel',
      );

      if (!mounted) return;

      final success = response.data is Map ? (response.data['success'] ?? false) : false;
      if (success) {
        NotificationService().cancelContestReminders(registrationId);
        ref.invalidate(myRegistrationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('참가신청이 취소되었습니다.')),
        );
      } else {
        final message = response.data is Map ? (response.data['message'] ?? '취소에 실패했습니다.') : '취소에 실패했습니다.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      debugPrint('[Error] 오류가 발생했습니다: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 라벨은 물러나고 값이 앞으로 나와야 훑을 때 값만 읽힌다
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }


  String _paymentStatusLabel(String status) {
    switch (status) {
      case 'COMPLETED': return '결제완료';
      case 'PENDING': return '결제대기';
      case 'REFUNDED': return '환불완료';
      case 'PARTIAL_REFUNDED': return '부분환불';
      default: return '미결제';
    }
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  /// 서버가 내려준 신청 옵션 목록. 옵션을 안 쓰는 대회는 빈 리스트.
  List<Map<String, dynamic>> _optionsOf(Map<String, dynamic> reg) {
    final raw = reg['options'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// 같은 항목(optionKey)끼리 묶어 "숙박 → 1/23 밤, 1/24 밤 ×2" 한 줄로 만든다.
  /// 서버가 답변 행 단위로 주기 때문에, 그대로 나열하면 같은 항목이 여러 줄로 흩어진다.
  Map<String, String> _groupOptions(List<Map<String, dynamic>> options) {
    final values = <String, List<String>>{};
    final labels = <String, String>{};
    final order = <String>[];
    for (final o in options) {
      final key = (o['optionKey'] ?? '').toString();
      if (key.isEmpty) continue;
      if (!order.contains(key)) order.add(key);
      labels[key] = (o['optionLabel'] ?? key).toString();

      final text = (o['textValue'] ?? '').toString().trim();
      var value = text.isNotEmpty
          ? text
          : (o['choiceLabel'] ?? o['choiceValue'] ?? '').toString().trim();
      if (value.isEmpty) continue;

      final qty = (o['quantity'] as num?)?.toInt() ?? 1;
      if (qty > 1) value = '$value ×$qty';
      values.putIfAbsent(key, () => []).add(value);
    }
    final result = <String, String>{};
    for (final key in order) {
      final list = values[key];
      if (list == null || list.isEmpty) continue;
      result[labels[key] ?? key] = list.join(', ');
    }
    return result;
  }

  /// 신청 상세의 '추가 신청 항목' 박스
  Widget _buildOptionsSection(List<Map<String, dynamic>> options) {
    final grouped = _groupOptions(options);
    if (grouped.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rtl, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                '추가 신청 항목',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...grouped.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 76,
                      child: Text(
                        e.key,
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildRefundHistorySection(int registrationId) {
    final refundHistory = ref.watch(refundHistoryProvider(registrationId));

    return refundHistory.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (refunds) {
        if (refunds.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 8),
            Text(
              '환불 내역',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...refunds.map((refund) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _refundStatusBadge(refund.refundStatus),
                      Text(
                        '${_formatNumber(refund.refundAmount)}원',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (refund.refundRate != null)
                    _detailRow('환불율', '${refund.refundRate}%'),
                  if (refund.calculatedDeductionAmount > 0)
                    _detailRow('공제액', '${_formatNumber(refund.calculatedDeductionAmount)}원', valueColor: AppColors.error),
                  if (refund.refundReason != null && refund.refundReason!.isNotEmpty)
                    _detailRow('사유', refund.refundReason!),
                  if (refund.rejectReason != null && refund.rejectReason!.isNotEmpty)
                    _detailRow('거절 사유', refund.rejectReason!, valueColor: AppColors.error),
                  if (refund.requestedAt != null)
                    _detailRow('신청일', _formatDate(refund.requestedAt!)),
                  if (refund.processedAt != null)
                    _detailRow('처리일', _formatDate(refund.processedAt!)),
                ],
              ),
            )),
          ],
        );
      },
    );
  }

  Widget _refundStatusBadge(String status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case 'COMPLETED':
        bg = AppColors.statusOpenBg;
        text = AppColors.statusOpenText;
        label = '환불완료';
        break;
      case 'APPROVED':
        bg = const Color(0xFFDBEAFE);
        text = const Color(0xFF1E40AF);
        label = '승인됨';
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFF991B1B);
        label = '거절됨';
        break;
      case 'FAILED':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFF991B1B);
        label = '실패';
        break;
      default: // REQUESTED
        bg = AppColors.statusSoonBg;
        text = AppColors.statusSoonText;
        label = '처리중';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

/// 반상 격자. 홈의 '지금 할 일' 카드와 같은 간격을 써서 같은 재질로 보이게 한다.
class _GobanGridPainter extends CustomPainter {
  static const double _gap = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.boardGrid
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += _gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += _gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
