import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/payment.dart';

/// 결제 결과 화면 (즉시결제 완료 / 가상계좌 발급 분기 표시)
/// 우리 시스템 정책: 유료 결제는 가상계좌만 사용 → 거의 항상 isWaitingForDeposit 케이스
class PaymentSuccessScreen extends StatelessWidget {
  final Payment payment;

  const PaymentSuccessScreen({
    super.key,
    required this.payment,
  });

  bool get _isWaitingForDeposit => payment.isWaitingForDeposit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // 상태 아이콘
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isWaitingForDeposit ? Icons.account_balance : Icons.check_circle,
                  size: 60,
                  color: _accentColor,
                ),
              ),

              const SizedBox(height: 32),

              // 제목
              Text(
                _isWaitingForDeposit ? '가상계좌가 발급되었습니다' : '결제가 완료되었습니다',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                _isWaitingForDeposit
                    ? '${payment.participantName}님,\n가상계좌로 입금이 완료되어야\n참가가 확정됩니다.'
                    : '${payment.participantName}님의 참가신청이\n정상적으로 처리되었습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // 입금 안내 박스 (가상계좌인 경우만)
              if (_isWaitingForDeposit)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '계좌 정보는 토스 알림톡으로 발송되며,\n[내 참가신청] 화면에서도 확인 가능합니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFFB26A00),
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              if (_isWaitingForDeposit) const SizedBox(height: 16),

              // 결제 정보 카드
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildInfoRow('대회', payment.contestName ?? '-'),
                    const Divider(height: 24),
                    _buildInfoRow('부문', payment.categoryName ?? '-'),
                    const Divider(height: 24),
                    _buildInfoRow('결제 방법', payment.methodText),
                    const Divider(height: 24),
                    _buildInfoRow(
                      _isWaitingForDeposit ? '입금 금액' : '결제 금액',
                      payment.amountText,
                      valueStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _accentColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 버튼들
              if (_isWaitingForDeposit) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.go('/profile/registrations'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB26A00),
                      side: const BorderSide(color: Color(0xFFFFE082)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '내 참가신청에서 계좌 확인',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '홈으로 돌아가기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Color get _accentColor =>
      _isWaitingForDeposit ? const Color(0xFFFFA000) : AppColors.success;

  Widget _buildInfoRow(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: valueStyle ??
                TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
