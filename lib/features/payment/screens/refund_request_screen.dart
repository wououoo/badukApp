import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/bank_codes.dart';
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
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();
  String? _selectedBankCode;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _reasonController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
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
                    // 공제 분해 (정책 변수 있을 때만)
                    if ((calculation.paymentPgUserPaid ?? 0) > 0) ...[
                      const SizedBox(height: 6),
                      _buildSubRow(
                        '└ 결제 PG 수수료 (미환급)',
                        '-${_formatNumber(calculation.paymentPgUserPaid!)}원',
                      ),
                    ],
                    if ((calculation.refundPgUserPaid ?? 0) > 0) ...[
                      const SizedBox(height: 6),
                      _buildSubRow(
                        '└ 환불 PG 수수료 (차감)',
                        '-${_formatNumber(calculation.refundPgUserPaid!)}원',
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // === 환불 차감 분해 (정책 기반 분쟁 방지 안내) ===
          _buildDeductionBreakdown(calculation),
          const SizedBox(height: 16),

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

          // 환불받을 계좌 정보 (가상계좌 환불 필수)
          if (calculation.refundable) ...[
            _buildSection(
              title: '환불받을 계좌',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '토스 정책상 가상계좌 환불은 본인 명의 계좌로만 가능합니다.\n예금주명이 일치하지 않으면 환불이 거부됩니다.',
                      style: TextStyle(fontSize: 12, color: const Color(0xFFB26A00), height: 1.4),
                    ),
                  ),
                  // 은행 선택
                  DropdownButtonFormField<String>(
                    value: _selectedBankCode,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: '은행',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: kBankCodes
                        .map((b) => DropdownMenuItem(value: b.code, child: Text(b.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedBankCode = v),
                  ),
                  const SizedBox(height: 12),
                  // 계좌번호
                  TextFormField(
                    controller: _accountNumberController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '계좌번호',
                      hintText: '- 없이 숫자만 입력',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 예금주명
                  TextFormField(
                    controller: _accountHolderController,
                    decoration: InputDecoration(
                      labelText: '예금주명',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

          // 환불 처리 안내
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
                  Icon(Icons.account_balance, color: AppColors.success, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '입력하신 계좌로 환불 처리되며,\n영업일 기준 1~3일 내 입금됩니다.',
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

  /// 환불 차감 분해 안내 (분쟁 방지)
  /// - 당일 면제 적용 시 → 녹색 박스
  /// - 환불 PG 수수료 차감 시 → 주황 강조 박스 (왜/얼마/면제 조건)
  /// - 결제 PG 수수료 미환급 시 → 회색 안내
  Widget _buildDeductionBreakdown(RefundCalculation calculation) {
    final paymentPg = calculation.paymentPgUserPaid ?? 0;
    final refundPg = calculation.refundPgUserPaid ?? 0;
    final sameDay = calculation.sameDayApplied == true;

    final notices = <Widget>[];

    // 당일 면제 적용
    if (sameDay) {
      notices.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.favorite, size: 18, color: Color(0xFF047857)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '결제 당일 취소 — 수수료 면제, 전액 ${_formatNumber(calculation.refundAmount)}원 환불됩니다.',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF047857), fontWeight: FontWeight.w600, height: 1.5),
              ),
            ),
          ],
        ),
      ));
    }

    // 환불 PG 수수료 강조 박스 (분쟁 방지)
    if (refundPg > 0) {
      notices.add(Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFDBA74), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFFED7AA))),
              ),
              child: Text(
                '⚠️ 환불 수수료 ${_formatNumber(refundPg)}원 차감 안내',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFC2410C)),
              ),
            ),
            const SizedBox(height: 8),
            _bulletLine('토스페이먼츠(결제대행사)가 가상계좌 환불 처리 시 부과하는 PG 환불 수수료로, 본 대회는 참가자 부담으로 설정되어 있습니다.'),
            _bulletLine('환불액에서 ${_formatNumber(refundPg)}원이 이미 차감되어 표시되고 있습니다.'),
            _bulletLine('결제 당일 취소 시에는 면제됩니다.'),
            _bulletLine(
                '예시: 결제 ${_formatNumber(calculation.originalAmount)}원 → 환불액 ${_formatNumber(calculation.refundAmount)}원 (환불율 ${calculation.refundRate}% + 수수료 차감 반영)'),
          ],
        ),
      ));
    }

    // 결제 PG 미환급 안내
    if (paymentPg > 0) {
      notices.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 18, color: Color(0xFF6B7280)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '결제 시 부담하신 결제 PG 수수료 ${_formatNumber(paymentPg)}원은 본 대회 정책상 환불되지 않습니다.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.5),
              ),
            ),
          ],
        ),
      ));
    }

    if (notices.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < notices.length; i++) ...[
          notices[i],
          if (i < notices.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _bulletLine(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2, right: 8),
            child: Text('•', style: TextStyle(fontSize: 13, color: Color(0xFFC2410C), fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF4B3A1F), height: 1.7),
            ),
          ),
        ],
      ),
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

  /// 공제 분해용 보조 행 (들여쓰기 + 작은 글씨)
  Widget _buildSubRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFFC2410C), fontWeight: FontWeight.w600),
          ),
        ],
      ),
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

    // 환불계좌 검증 (가상계좌 환불은 계좌 정보 필수)
    final accountNumber = _accountNumberController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final accountHolder = _accountHolderController.text.trim();
    if (_selectedBankCode == null || _selectedBankCode!.isEmpty) {
      setState(() => _errorMessage = '환불받을 은행을 선택해주세요.');
      return;
    }
    if (accountNumber.isEmpty) {
      setState(() => _errorMessage = '계좌번호를 입력해주세요.');
      return;
    }
    if (accountHolder.isEmpty) {
      setState(() => _errorMessage = '예금주명을 입력해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final selectedBank = kBankCodes.firstWhere(
      (b) => b.code == _selectedBankCode,
      orElse: () => const BankCode('', ''),
    );

    try {
      final service = ref.read(paymentServiceProvider);
      await service.requestRefund(
        registrationId: widget.registrationId,
        refundReason: _reasonController.text.trim().isNotEmpty
            ? _reasonController.text.trim()
            : '환불 요청',
        refundBankCode: _selectedBankCode,
        refundBankName: selectedBank.name,
        refundAccountNumber: accountNumber,
        refundAccountHolder: accountHolder,
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
