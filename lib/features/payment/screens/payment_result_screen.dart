import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

/// 웹 결제 완료 후 백엔드 리다이렉트로 진입하는 결과 화면
/// URL: /payment/result?status=success&orderId=...&amount=...
///       /payment/result?status=fail&code=...&message=...
///
/// 우리 시스템 정책: 유료 결제는 항상 가상계좌(VIRTUAL_ACCOUNT) 사용.
/// → 참가비 기준 분기:
///    - amount > 0 → 가상계좌 발급, 입금 대기
///    - amount == 0 → 무료 (사실 이 경로로는 안 옴, 안전망)
///
/// ⚠️ Flutter Web hash routing 환경에서는 query가 hash 앞 base URL에 붙는 경우가 있어
///    GoRouter의 state.uri.queryParameters에서 못 읽음. initState에서 Uri.base로 fallback.
class PaymentResultScreen extends ConsumerStatefulWidget {
  final String? status;
  final String? orderId;
  final String? code;
  final String? message;

  const PaymentResultScreen({
    super.key,
    this.status,
    this.orderId,
    this.code,
    this.message,
  });

  @override
  ConsumerState<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends ConsumerState<PaymentResultScreen> {
  late final String? _status;
  late final String? _orderId;
  late final String? _message;
  late final int _amount;

  @override
  void initState() {
    super.initState();
    final base = kIsWeb ? Uri.base.queryParameters : const <String, String>{};
    _status  = widget.status  ?? base['status'];
    _orderId = widget.orderId ?? base['orderId'];
    _message = widget.message ?? base['message'];
    _amount  = int.tryParse(base['amount'] ?? '') ?? 0;
  }

  bool get _isSuccess => _status == 'success';
  bool get _isWaitingForDeposit => _isSuccess && _amount > 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          _appBarTitle,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_icon, size: 96, color: _color),
              const SizedBox(height: 24),
              Text(
                _title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (_isWaitingForDeposit) ...[
                const SizedBox(height: 24),
                _buildVirtualAccountNotice(),
              ],
              if (_orderId != null && _isSuccess) ...[
                const SizedBox(height: 16),
                Text(
                  '주문번호: $_orderId',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    '홈으로',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVirtualAccountNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('입금 금액', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              Text(
                '${_formatNumber(_amount)}원',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFFB26A00)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '토스에서 발송한 알림톡으로 가상계좌 정보를 확인하시고\n기한 내에 입금하시면 참가가 확정됩니다.\n\n내 참가신청 화면에서도 계좌번호를 확인할 수 있습니다.',
            style: TextStyle(color: const Color(0xFFB26A00), fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String get _appBarTitle {
    if (!_isSuccess) return '결제 실패';
    return _isWaitingForDeposit ? '가상계좌 발급' : '결제 완료';
  }

  String get _title {
    if (!_isSuccess) return '결제에 실패했습니다';
    return _isWaitingForDeposit ? '가상계좌가 발급되었습니다' : '결제가 완료되었습니다';
  }

  String get _subtitle {
    if (!_isSuccess) return _message ?? '다시 시도해주세요.';
    return _isWaitingForDeposit
        ? '가상계좌로 입금이 완료되어야 참가가 확정됩니다.'
        : '참가가 확정되었습니다.';
  }

  IconData get _icon {
    if (!_isSuccess) return Icons.error;
    return _isWaitingForDeposit ? Icons.account_balance : Icons.check_circle;
  }

  Color get _color {
    if (!_isSuccess) return AppColors.error;
    return _isWaitingForDeposit ? const Color(0xFFFFA000) : Colors.green;
  }

  String _formatNumber(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
