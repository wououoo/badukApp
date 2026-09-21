import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/payment.dart';

/// 결제 결과 화면(개편본).
///
/// 우리 정책상 유료 결제는 가상계좌만 쓴다 → 이 화면에 오는 거의 모든 경우가
/// "아직 안 끝났고, 입금해야 끝난다"이다. 그래서 축하 문구가 아니라
/// **얼마를 언제까지 넣어야 하는지**를 화면에서 제일 크게 둔다.
///
/// 반상(검은 면)은 화면당 하나만 쓰기로 한 색이다. 여기서는 입금 안내가 그 하나다.
/// 이미 결제가 끝난 경우(무료·즉시결제)는 급할 게 없으므로 흰 카드로 조용히 알린다.
class PaymentSuccessScreenV2 extends StatelessWidget {
  final Payment payment;

  const PaymentSuccessScreenV2({super.key, required this.payment});

  bool get _waiting => payment.isWaitingForDeposit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              _buildHeadline(),
              const SizedBox(height: 20),
              if (_waiting) _buildDepositCard() else _buildDoneCard(),
              const SizedBox(height: 14),
              _buildDetails(),
              const SizedBox(height: 22),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  // ── 머리말 ───────────────────────────────────────────
  Widget _buildHeadline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _waiting ? Icons.schedule_rounded : Icons.check_circle_rounded,
              size: 20,
              color: _waiting ? AppColors.primary : AppColors.success,
            ),
            const SizedBox(width: 7),
            Text(
              _waiting ? '신청 접수됨' : '참가 확정',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: _waiting ? AppColors.primary : AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _waiting
              ? '입금하면 자리가 확정됩니다'
              : '${payment.participantName ?? ''}님, 신청이 끝났습니다',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
            height: 1.25,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── 입금 카드(반상) ──────────────────────────────────
  Widget _buildDepositCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        color: AppColors.board,
        child: Stack(
          children: [
            // 격자를 아주 옅게 깔아 검은 면이 그냥 검은 상자로 보이지 않게 한다
            Positioned.fill(
              child: CustomPaint(painter: _GobanGridPainter()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '입금할 금액',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: Color(0xFF8A97A6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    payment.amountText,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.8,
                      height: 1.05,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(height: 1, color: const Color(0x1AFFFFFF)),
                  const SizedBox(height: 14),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 16, color: AppColors.boardAccent),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          // 가상계좌는 발급 후 30분이 지나면 자동으로 취소된다(의도된 정책).
                          // 이 화면에 온 시점이 발급 직후이므로 "30분"을 그대로 말해도 어긋나지 않는다.
                          '30분 안에 입금하지 않으면 신청이 자동 취소됩니다.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                            color: AppColors.boardAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '계좌번호는 토스 알림톡으로 발송되며, [내 참가신청]에서도 볼 수 있습니다.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: Color(0xFF8A97A6),
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

  // ── 이미 끝난 경우 ───────────────────────────────────
  Widget _buildDoneCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '결제 금액',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            payment.amountText,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              height: 1.05,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── 무엇에 대한 결제인지 ─────────────────────────────
  Widget _buildDetails() {
    final rows = <List<String>>[
      ['대회', payment.contestName ?? '-'],
      ['부문', payment.categoryName ?? '-'],
      ['참가자', payment.participantName ?? '-'],
      ['결제 방법', payment.methodText],
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 74,
                    child: Text(
                      r[0],
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r[1],
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
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

  // ── 다음 행동 ────────────────────────────────────────
  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            // 입금 대기면 계좌를 봐야 하므로 그쪽이 주 버튼이다.
            onPressed: () => context.go(
              _waiting ? '/profile/registrations' : '/home',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              _waiting ? '계좌 확인하러 가기' : '홈으로',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        if (_waiting) ...[
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton(
              onPressed: () => context.go('/home'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '홈으로',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 반상 격자. 홈의 '지금 할 일' 카드와 같은 간격을 써서 두 화면이 같은 재질로 보이게 한다.
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
