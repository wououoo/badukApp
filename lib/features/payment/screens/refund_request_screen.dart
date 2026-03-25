import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/payment.dart';
import '../../../data/providers/payment_provider.dart';
import '../../profile/screens/my_registrations_screen.dart';

/// 환불 신청 화면
class RefundRequestScreen extends ConsumerStatefulWidget {
  final int registrationId;

  const RefundRequestScreen({
    super.key,
    required this.registrationId,
  });

  @override
  ConsumerState<RefundRequestScreen> createState() => _RefundRequestScreenState();
}

class _RefundRequestScreenState extends ConsumerState<RefundRequestScreen> {
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calculationAsync = ref.watch(refundCalculationProvider(widget.registrationId));

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
          '환불 신청',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: calculationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorView(_extractUserMessage(error)),
        data: (calculation) => _buildContent(calculation),
      ),
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  Widget? _buildBottomButton() {
    final calculationAsync = ref.watch(refundCalculationProvider(widget.registrationId));

    return calculationAsync.when(
      data: (calculation) {
        if (!calculation.refundable) return null;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () => _confirmAndSubmitRefund(calculation),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.textTertiary.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        '환불 신청하기 (${_formatNumber(calculation.refundAmount)}원)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
      loading: () => null,
      error: (_, __) => null,
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('돌아가기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(RefundCalculation calculation) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 환불 불가 안내
          if (!calculation.refundable) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.block, color: AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      calculation.message,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 환불 정보
          _buildSection(
            title: '환불 정보',
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildInfoRow('대회명', calculation.contestName ?? '-'),
                  const Divider(height: 24),
                  _buildInfoRow('참가 부문', calculation.categoryName ?? '-'),
                  const Divider(height: 24),
                  _buildInfoRow('참가자명', calculation.participantName ?? '-'),
                  const Divider(height: 24),
                  _buildInfoRow(
                    '결제 금액',
                    '${_formatNumber(calculation.originalAmount)}원',
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    '환불율',
                    '${calculation.refundRate}%',
                    valueStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: calculation.refundRate == 100
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    '환불 금액',
                    '${_formatNumber(calculation.refundAmount)}원',
                    valueStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                  if (calculation.deductionAmount > 0) ...[
                    const Divider(height: 24),
                    _buildInfoRow(
                      '공제 금액',
                      '-${_formatNumber(calculation.deductionAmount)}원',
                      valueStyle: const TextStyle(
                        fontSize: 14,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 환불 정책 안내
          if (calculation.policyDescription != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      calculation.policyDescription!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 환불 사유
          _buildSection(
            title: '환불 사유 (선택)',
            child: TextFormField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '환불 사유를 입력해주세요',
                hintStyle: TextStyle(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),

          // 토스 카드결제 환불 안내
          if (calculation.refundable) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.credit_card, color: AppColors.success, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '결제하신 카드로 자동 환불됩니다.\n환불 처리는 카드사에 따라 3~5 영업일이 소요될 수 있습니다.',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 에러 메시지
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

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
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  /// 환불 전 확인 다이얼로그
  Future<void> _confirmAndSubmitRefund(RefundCalculation calculation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('환불 신청 확인'),
        content: Text(
          '${_formatNumber(calculation.refundAmount)}원을 환불 신청하시겠습니까?\n\n'
          '환불 후에는 참가신청이 취소되며,\n되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('환불 신청'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    _submitRefund(calculation);
  }

  Future<void> _submitRefund(RefundCalculation calculation) async {
    if (!calculation.refundable) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(paymentServiceProvider);
      await service.requestRefund(
        registrationId: widget.registrationId,
        refundReason: _reasonController.text.trim().isNotEmpty
            ? _reasonController.text.trim()
            : '환불 요청',
      );

      if (mounted) {
        _showSuccessDialog(calculation);
      }
    } catch (e) {
      setState(() => _errorMessage = _extractUserMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(RefundCalculation calculation) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: AppColors.success, size: 28),
            SizedBox(width: 8),
            Text('환불 완료'),
          ],
        ),
        content: Text(
          '${_formatNumber(calculation.refundAmount)}원 환불이 완료되었습니다.\n'
          '결제하신 카드로 환불되며, 카드사에 따라\n3~5 영업일이 소요될 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 내 참가신청 목록 갱신 후 돌아가기
              ref.invalidate(myRegistrationsProvider);
              ref.invalidate(refundCalculationProvider(widget.registrationId));
              ref.invalidate(paymentByRegistrationProvider(widget.registrationId));
              context.pop();
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  String _extractUserMessage(Object error) {
    final raw = error.toString();

    final appExceptionMatch = RegExp(r'AppException:\s*(.+?)(?:\s*\(type:|$)').firstMatch(raw);
    if (appExceptionMatch != null) {
      return appExceptionMatch.group(1)!.trim();
    }

    final koreanMatch = RegExp(r'[가-힣][가-힣\s.,!?을를이가은는의에서로]+').firstMatch(raw);
    if (koreanMatch != null && koreanMatch.group(0)!.length > 3) {
      return koreanMatch.group(0)!.trim();
    }

    if (raw.contains('SocketException') || raw.contains('connection')) {
      return '네트워크 연결을 확인해주세요.';
    }
    if (raw.contains('timeout') || raw.contains('TimeoutException')) {
      return '서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요.';
    }

    return '환불 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
