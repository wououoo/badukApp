import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/error/error_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/payment.dart';
import '../../../data/models/registration.dart';
import '../../../data/providers/payment_provider.dart';
import '../../../data/services/homepage_service.dart';
import '../../../data/services/notification_service_stub.dart'
    if (dart.library.io) '../../../data/services/notification_service.dart';
import '../widgets/payment_summary_card.dart';

/// 결제 화면
/// - 토스페이먼츠 결제 진행
/// - 결제 완료 후 참가신청 저장
class PaymentScreen extends ConsumerStatefulWidget {
  final RegistrationData? registration;  // 참가신청 데이터 (신규 신청 시)
  final int? existingRegistrationId;     // 기존 참가신청 ID (미결제 재시도 시)
  final String participantName;
  final String categoryName;
  final String contestName;
  final int amount;
  final int? homepageId;
  final DateTime? contestStartDate;

  const PaymentScreen({
    super.key,
    this.registration,
    this.existingRegistrationId,
    required this.participantName,
    required this.categoryName,
    required this.contestName,
    required this.amount,
    this.homepageId,
    this.contestStartDate,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _homepageService = HomepageService();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '참가비 결제',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 결제 정보 요약
            PaymentSummaryCard(
              contestName: widget.contestName,
              categoryName: widget.categoryName,
              participantName: widget.participantName,
              amount: widget.amount,
            ),

            const SizedBox(height: 24),

            // 결제 안내
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance, color: AppColors.accent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '결제 안내',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• 가상계좌가 발급되며, 2시간 내에 입금하시면 참가신청이 확정됩니다.\n'
                    '• 입금 완료 후 결제 확인까지 은행/PG사 시스템에 따라 수 분~수십 분이 소요될 수 있습니다.\n'
                    '• 입금 후에도 "결제 대기"로 표시되면 잠시 후 새로고침해 주세요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            // 에러 메시지
            if (paymentState.errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        paymentState.errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            onPressed: _isProcessing || paymentState.isLoading
                ? null
                : _processPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isProcessing || paymentState.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    '${_formatNumber(widget.amount)}원 결제하기',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    try {
      final paymentNotifier = ref.read(paymentProvider.notifier);
      Payment? payment;

      if (widget.existingRegistrationId != null) {
        // 기존 미결제 재시도
        payment = await paymentNotifier.preparePayment(
          registrationId: widget.existingRegistrationId!,
          homepageId: widget.homepageId ?? 0,
          categoryId: 0,
          participantName: widget.participantName,
        );
      } else {
        // 신규 결제 — Registration 생성 없이 바로 결제 준비
        if (widget.registration == null) {
          _showErrorSnackBar('참가신청 정보가 없습니다');
          return;
        }

        payment = await paymentNotifier.preparePayment(
          registrationData: widget.registration!.toJson(),
          homepageId: widget.registration!.homepageId,
          categoryId: widget.registration!.categoryId,
          participantName: widget.participantName,
        );
      }

      if (payment == null) {
        _showErrorSnackBar('결제 준비 중 오류가 발생했습니다');
        return;
      }

      if (payment.isFree) {
        _showSuccessDialog(payment);
        return;
      }

      // 토스 결제 WebView로 이동 (가상계좌)
      if (!mounted) return;

      final result = await context.push<bool>(
        '/payment/toss-checkout',
        extra: {
          'orderId': payment.orderId!,
          'amount': payment.amount,
          'orderName': payment.orderName ?? '${widget.contestName} - ${widget.categoryName}',
        },
      );

      // 결제 성공 → 결과 화면 (Registration은 백엔드 confirm에서 생성됨)
      if (result == true && mounted) {
        if (widget.contestStartDate != null) {
          NotificationService().scheduleContestReminders(
            registrationId: 0,
            homepageId: widget.homepageId ?? 0,
            contestName: widget.contestName,
            contestStartDate: widget.contestStartDate!,
          );
        }
        final currentPayment = ref.read(paymentProvider).currentPayment;
        if (currentPayment != null) {
          context.pushReplacement('/payment/success', extra: currentPayment);
        }
      }
      // 결제 실패/취소 → 아무것도 안 함 (Registration이 생성되지 않았으므로)
    } catch (e) {
      _showErrorSnackBar(ErrorHandler.getUserFriendlyMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showSuccessDialog(Payment payment) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 28),
            SizedBox(width: 8),
            Text('신청 완료'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${payment.participantName ?? widget.participantName}님의 참가신청이 완료되었습니다.'),
            const SizedBox(height: 8),
            Text(
              '부문: ${payment.categoryName ?? widget.categoryName}',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/home');
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
