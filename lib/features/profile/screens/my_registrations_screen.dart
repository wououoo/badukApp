import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/api_client.dart';
import '../../../data/providers/payment_provider.dart';
import '../../../data/services/user_service.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/services/notification_service_stub.dart'
    if (dart.library.io) '../../../data/services/notification_service.dart';

/// 내 참가신청 목록 Provider
final myRegistrationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final userService = UserService();
    return await userService.getMyRegistrations();
  } catch (e) {
    debugPrint('[참가신청] 목록 조회 실패: $e');
    return [];
  }
});

/// 내 참가신청 내역 화면
class MyRegistrationsScreen extends ConsumerStatefulWidget {
  const MyRegistrationsScreen({super.key});

  @override
  ConsumerState<MyRegistrationsScreen> createState() => _MyRegistrationsScreenState();
}

class _MyRegistrationsScreenState extends ConsumerState<MyRegistrationsScreen> {
  bool _isCancelling = false;

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
          data: (list) => list.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, index) => _buildRegistrationCard(context, list[index]),
                ),
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

  Widget _buildEmpty() {
    return ListView(
      children: [
        SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              Icon(Icons.how_to_reg_outlined, color: AppColors.textTertiary, size: 64),
              SizedBox(height: 16),
              Text(
                '참가신청 내역이 없습니다',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '대회에 참가신청하면 여기에 표시됩니다',
                style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationCard(BuildContext context, Map<String, dynamic> reg) {
    final status = reg['status'] as String? ?? 'PENDING';
    final paymentStatus = reg['paymentStatus'] as String? ?? 'UNPAID';
    final fee = (reg['fee'] as num?)?.toInt() ?? 0;
    final paidAmount = (reg['paidAmount'] as num?)?.toInt() ?? 0;
    final unpaid = fee - paidAmount;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      color: AppColors.surface,
      child: InkWell(
        onTap: () => _showDetail(context, reg),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 대회명 + 상태 배지
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reg['contestName'] ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(status),
                  // 주최자 문의(채팅) 버튼 - 일단 비활성
                  // if (reg['homepageId'] != null) ...[
                  //   const SizedBox(width: 6),
                  //   SizedBox(
                  //     width: 32,
                  //     height: 32,
                  //     child: IconButton(
                  //       padding: EdgeInsets.zero,
                  //       icon: Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.primary),
                  //       tooltip: '주최자에게 문의',
                  //       onPressed: () => _openChat(context, reg),
                  //     ),
                  //   ),
                  // ],
                ],
              ),
              const SizedBox(height: 8),
              // 부문명
              Text(
                reg['categoryName'] ?? '',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              // 결제 상태 + 금액 (참가비 있을 때만)
              if (fee > 0)
                Row(
                  children: [
                    _buildPaymentBadge(paymentStatus),
                    const Spacer(),
                    Text(
                      '₩${_formatNumber(fee)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (unpaid > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '미납 ₩${_formatNumber(unpaid)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              // 입금 대기 중이면 가상계좌 정보 박스
              if (paymentStatus == 'WAITING_FOR_DEPOSIT' && reg['virtualAccount'] != null) ...[
                const SizedBox(height: 10),
                _buildVirtualAccountBox(reg['virtualAccount'] as Map<String, dynamic>),
              ],
            ],
          ),
        ),
      ),
    );
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
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance, size: 16, color: const Color(0xFFB26A00)),
              const SizedBox(width: 6),
              Text(
                '입금 안내',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFB26A00)),
              ),
              const Spacer(),
              if (dueDate.isNotEmpty)
                Text(
                  '$dueDate까지',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFB26A00)),
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
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Text(
                    '복사',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFB26A00)),
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
              color: Colors.white.withOpacity(0.6),
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
        text = const Color(0xFFB26A00);
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

    // 액션 버튼 표시 조건
    final canEdit = status == 'PENDING' || status == 'APPROVED';
    final canCancel = status == 'PENDING' || (status == 'APPROVED' && paymentStatus != 'COMPLETED');
    final canRefund = status == 'APPROVED' && paymentStatus == 'COMPLETED';
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
      builder: (bottomSheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
            const SizedBox(height: 20),
            // 대회명
            Text(
              reg['contestName'] ?? '',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _detailRow('참가자', reg['participantName'] ?? ''),
            _detailRow('부문', reg['categoryName'] ?? ''),
            _detailRow('신청 상태', _statusLabel(status)),
            if (fee > 0) ...[
              _detailRow('결제 상태', _paymentStatusLabel(paymentStatus)),
              _detailRow('참가비', '₩${_formatNumber(fee)}'),
              _detailRow('납부 금액', '₩${_formatNumber(paidAmount)}'),
              if (unpaid > 0)
                _detailRow('잔액', '₩${_formatNumber(unpaid)}', valueColor: AppColors.error),
            ],
            if (registeredAt != null)
              _detailRow('신청일', _formatDate(registeredAt)),

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
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF7DD3FC)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: const Color(0xFF0369A1)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '부문을 바꾸시려면 [취소 신청]으로 환불받으신 후, 원하시는 부문으로 새로 신청해주세요.\n환불 정책에 따라 일부 차감될 수 있습니다.',
                        style: TextStyle(fontSize: 12, color: const Color(0xFF0369A1), height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 액션 버튼 영역
            if (canEdit || canCancel || canRefund || canPay) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              // 1행: 결제/수정
              Row(
                children: [
                  if (canPay)
                    Expanded(
                      child: _actionButton(
                        icon: Icons.payment_outlined,
                        label: '결제하기',
                        color: AppColors.success,
                        onTap: () {
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
                      ),
                    ),
                  if (canPay && canEdit)
                    const SizedBox(width: 10),
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
            const SizedBox(height: 8),
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'APPROVED': return '승인';
      case 'REJECTED': return '거절';
      case 'CANCELLED': return '취소';
      default: return '대기';
    }
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
                        '₩${_formatNumber(refund.refundAmount)}',
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
                    _detailRow('공제액', '₩${_formatNumber(refund.calculatedDeductionAmount)}', valueColor: AppColors.error),
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
