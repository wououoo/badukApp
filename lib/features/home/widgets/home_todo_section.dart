import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../profile/screens/my_registrations_screen.dart' show myRegistrationsProvider;

/// 홈 최상단 "지금 할 일".
///
/// 화면을 열었을 때 던지는 질문을 하나로 줄인다 — 지금 뭘 해야 하지.
/// 급한 것 하나만 검은 반상 카드로 세우고 나머지는 한 줄로 내린다.
/// 할 일이 없으면 아무것도 그리지 않는다(평소 홈은 조용한 화면이다).
class HomeTodoSection extends ConsumerWidget {
  /// 화면 확인용 스위치. 실제 입금 대기 건이 없을 때 샘플 한 건으로 렌더한다.
  ///
  /// 샘플의 키 이름은 백엔드 `/api/mobile/users/me/registrations` 응답과 **동일하게** 맞춰져 있어
  /// (paymentStatus·virtualAccount.vaDueDate·vaBankName·vaAccountNumber·amount…),
  /// 실제 데이터가 들어오면 이 스위치를 꺼도 같은 화면이 그려진다.
  /// 배포 전에는 반드시 false여야 한다.
  final bool previewSample;

  const HomeTodoSection({super.key, this.previewSample = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (previewSample) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PaymentDueCard(reg: _sampleDue()),
            const SizedBox(height: 10),
            _UpcomingRow(reg: _sampleUpcoming()),
          ],
        ),
      );
    }

    final async = ref.watch(myRegistrationsProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (regs) {
        final due = _findPaymentDue(regs);
        final upcoming = _findUpcoming(regs);
        if (due == null && upcoming == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (due != null) _PaymentDueCard(reg: due),
              if (due != null && upcoming != null) const SizedBox(height: 10),
              if (upcoming != null) _UpcomingRow(reg: upcoming),
            ],
          ),
        );
      },
    );
  }

  /// 렌더 확인용 샘플 — 백엔드 응답과 키·형태가 같다.
  static Map<String, dynamic> _sampleDue() => {
        'paymentStatus': 'WAITING_FOR_DEPOSIT',
        'contestName': '제25회 태백산 배달 바둑대회',
        'categoryName': '일반부',
        'fee': 20000,
        'virtualAccount': {
          'amount': 20000,
          'vaBankName': '신한',
          'vaAccountNumber': '3020-1234-5678',
          'vaDueDate':
              DateTime.now().add(const Duration(seconds: 20)).toIso8601String() // 확인용: 20초 뒤 만료,
        },
      };

  static Map<String, dynamic> _sampleUpcoming() => {
        'status': 'APPROVED',
        'contestName': '2026 전국유소년바둑대회',
        'categoryName': '초등부 저학년',
        'contestStartDate':
            DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      };

  /// 입금 기한이 남아 있는 신청 (가상계좌 발급 후 미입금)
  static Map<String, dynamic>? _findPaymentDue(List<Map<String, dynamic>> regs) {
    for (final r in regs) {
      if (r['paymentStatus'] != 'WAITING_FOR_DEPOSIT') continue;
      final va = r['virtualAccount'];
      if (va is! Map) continue;
      // 기한이 지난 건도 남긴다. 서버가 취소로 바꾸는 데 최대 3분 걸리는데,
      // 그 사이 카드가 그냥 사라지면 사용자는 무슨 일이 있었는지 알 수 없다.
      final due = DateTime.tryParse((va['vaDueDate'] ?? '').toString());
      if (due == null) continue;
      return r;
    }
    return null;
  }

  /// 사흘 안에 열리는 확정된 대회
  static Map<String, dynamic>? _findUpcoming(List<Map<String, dynamic>> regs) {
    final now = DateTime.now();
    Map<String, dynamic>? best;
    DateTime? bestAt;
    for (final r in regs) {
      if (r['status'] != 'APPROVED') continue;
      final at = DateTime.tryParse((r['contestStartDate'] ?? '').toString());
      if (at == null) continue;
      final days = at.difference(now).inDays;
      if (at.isBefore(now) || days > 3) continue;
      if (bestAt == null || at.isBefore(bestAt)) {
        best = r;
        bestAt = at;
      }
    }
    return best;
  }
}

/// 입금 기한 카드 — 남은 시간이 주인공이고, 계좌번호가 카드 안에 있어 홈에서 입금이 끝난다.
class _PaymentDueCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> reg;
  const _PaymentDueCard({required this.reg});

  @override
  ConsumerState<_PaymentDueCard> createState() => _PaymentDueCardState();
}

class _PaymentDueCardState extends ConsumerState<_PaymentDueCard> {
  Timer? _ticker;
  bool _askedRefresh = false;

  bool get _expired {
    final due = DateTime.tryParse((_va['vaDueDate'] ?? '').toString());
    return due == null || !due.isAfter(DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    // 남은 시간이 주인공이므로 1초마다 다시 그린다. 화면을 벗어나면 dispose에서 멈춘다.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_expired) {
        // 0이 되면 더 셀 것이 없다. 대신 서버 상태를 한 번 다시 읽는다 —
        // 만료 처리(스케줄러)는 최대 3분 뒤에 반영되므로 그때 카드가 자연히 사라진다.
        _ticker?.cancel();
        if (!_askedRefresh) {
          _askedRefresh = true;
          ref.invalidate(myRegistrationsProvider);
        }
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Map<String, dynamic> get _va =>
      Map<String, dynamic>.from(widget.reg['virtualAccount'] as Map);

  String get _remaining {
    final due = DateTime.tryParse((_va['vaDueDate'] ?? '').toString());
    if (due == null) return '--:--';
    final left = due.difference(DateTime.now());
    if (left.isNegative) return '00:00';
    final h = left.inHours;
    final m = left.inMinutes % 60;
    final s = left.inSeconds % 60;
    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _money(dynamic v) {
    final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
    return n.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final bank = (_va['vaBankName'] ?? '').toString();
    final acc = (_va['vaAccountNumber'] ?? '').toString();
    final amount = _va['amount'] ?? widget.reg['fee'];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.board,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          // 반상 격자 — 소재를 들이되 아주 옅게
          Positioned.fill(
            child: CustomPaint(painter: _GobanGridPainter()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      '입금 기한',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: (_expired ? Colors.white : AppColors.boardAccent)
                            .withValues(alpha: _expired ? 0.10 : 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _expired ? '취소 처리 중' : '지나면 자동 취소',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: _expired
                              ? Colors.white.withValues(alpha: 0.6)
                              : AppColors.boardAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    _expired ? '시간 만료' : _remaining,
                    style: TextStyle(
                      fontSize: _expired ? 30 : 44,
                      height: 1,
                      fontWeight: FontWeight.bold,
                      letterSpacing: _expired ? -1 : -2,
                      color: _expired
                          ? Colors.white.withValues(alpha: 0.72)
                          : AppColors.boardAccent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    _expired ? '입금 시간이 지나 곧 자동 취소됩니다' : '남은 시간',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Divider(color: Colors.white.withValues(alpha: 0.11), height: 1),
                const SizedBox(height: 12),
                _row('금액', '${_money(amount)}원'),
                if (bank.isNotEmpty || acc.isNotEmpty)
                  _row('입금처', '$bank $acc'.trim()),
                _row('대회', (widget.reg['contestName'] ?? '').toString()),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => context.push(
                      _expired ? '/contests' : '/profile/registrations'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _expired ? '다시 신청하기' : '입금 정보 보기',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.board,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 두 번째부터의 할 일 — 초를 다투지 않으므로 한 줄로 내린다.
class _UpcomingRow extends StatelessWidget {
  final Map<String, dynamic> reg;
  const _UpcomingRow({required this.reg});

  @override
  Widget build(BuildContext context) {
    final at = DateTime.tryParse((reg['contestStartDate'] ?? '').toString());
    final days = at == null ? null : at.difference(DateTime.now()).inDays;
    final dday = days == null
        ? ''
        : (days <= 0 ? 'D-DAY' : 'D-$days');

    return GestureDetector(
      onTap: () => context.push('/profile/registrations'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (reg['contestName'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (reg['categoryName'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              dday,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 반상 격자. 카드 위에 옅게 깔아 "바둑" 소재를 화면에 들인다.
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
