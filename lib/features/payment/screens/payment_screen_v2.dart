import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/registration.dart';
import '../../../data/providers/payment_provider.dart';
import '../../../data/services/homepage_service.dart';
import '../../../data/services/notification_service_stub.dart'
    if (dart.library.io) '../../../data/services/notification_service.dart';
import '../../../data/models/payment.dart';
import '../../../core/error/error_handler.dart';

/// 참가비 결제 화면(개편본).
///
/// 신청 → 여기 → 완료 순인데 가운데만 옛 모습이라 흐름이 끊겼다.
/// 앞뒤 화면과 같은 얼굴로 맞추고, 두 가지를 바로잡는다:
///
///   1. 옛 화면은 "2시간 내에 입금"이라고 알렸지만 서버는 30분이다
///      (PaymentController.VIRTUAL_ACCOUNT_VALID_MINUTES = 30).
///      2시간인 줄 알고 미루면 신청이 취소된다 — 디자인보다 급한 문제였다.
///   2. 주 버튼이 AppColors.accent(연한 살구색)라 눌러야 할 버튼이 흐렸다. 코랄로 세운다.
class PaymentScreenV2 extends ConsumerStatefulWidget {
  final RegistrationData? registration; // 참가신청 데이터 (신규 신청 시)
  final int? existingRegistrationId; // 기존 참가신청 ID (미결제 재시도 시)
  final String participantName;
  final String categoryName;
  final String contestName;
  final int amount;
  final int? homepageId;
  final DateTime? contestStartDate;

  const PaymentScreenV2({
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
  ConsumerState<PaymentScreenV2> createState() => _PaymentScreenV2State();
}

class _PaymentScreenV2State extends ConsumerState<PaymentScreenV2> {
  // ignore: unused_field
  final _homepageService = HomepageService();
  bool _isProcessing = false;

  /// 가상계좌 입금 기한(분). 서버 상수와 같은 값이어야 한다.
  /// 서버: PaymentController.VIRTUAL_ACCOUNT_VALID_MINUTES
  static const int _dueMinutes = 30;

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentProvider);
    final busy = _isProcessing || paymentState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '참가비 결제',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAmount(),
            const SizedBox(height: 14),
            _buildWhatFor(),
            const SizedBox(height: 14),
            _buildHowItWorks(),
            if (paymentState.errorMessage != null) ...[
              const SizedBox(height: 14),
              _buildError(paymentState.errorMessage!),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: busy ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      '${_formatNumber(widget.amount)}원 계좌 발급받기',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 얼마를 내는가 ────────────────────────────────────
  Widget _buildAmount() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '결제할 금액',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${_formatNumber(widget.amount)}원',
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

  // ── 무엇에 대한 결제인가 ─────────────────────────────
  Widget _buildWhatFor() {
    final rows = <List<String>>[
      ['대회', widget.contestName],
      ['부문', widget.categoryName],
      ['참가자', widget.participantName],
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
                    width: 62,
                    child: Text(
                      r[0],
                      style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
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

  // ── 앞으로 무슨 일이 일어나는가 ──────────────────────
  Widget _buildHowItWorks() {
    // 카드 결제가 아니라 계좌 입금이라는 것을 먼저 알려야 한다.
    // 버튼을 눌러도 돈이 빠져나가지 않는다는 사실이 불안을 줄인다.
    final steps = <List<String>>[
      ['1', '내 이름으로 된 계좌가 발급됩니다', '지금 돈이 빠져나가지는 않습니다'],
      ['2', '$_dueMinutes분 안에 그 계좌로 입금합니다', '넘기면 신청이 자동으로 취소됩니다'],
      ['3', '입금이 확인되면 참가 확정', '은행에 따라 몇 분 걸릴 수 있습니다'],
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이렇게 진행됩니다',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 13),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    // 기한이 걸린 걸음(2번)만 코랄로 세운다 — 놓치면 취소되는 유일한 지점이다
                    color: i == 1
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    steps[i][0],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: i == 1 ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[i][1],
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          fontWeight: i == 1 ? FontWeight.w800 : FontWeight.w600,
                          color: i == 1
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        steps[i][2],
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
