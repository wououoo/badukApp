import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/api_client.dart';

/// 부문 변경 화면
class CategoryChangeScreen extends ConsumerStatefulWidget {
  final int registrationId;
  final Map<String, dynamic> registration;

  const CategoryChangeScreen({
    super.key,
    required this.registrationId,
    required this.registration,
  });

  @override
  ConsumerState<CategoryChangeScreen> createState() => _CategoryChangeScreenState();
}

class _CategoryChangeScreenState extends ConsumerState<CategoryChangeScreen> {
  final _apiClient = ApiClient();
  List<Map<String, dynamic>> _categories = [];
  Map<String, dynamic>? _preview;
  int? _selectedCategoryId;
  bool _isLoadingCategories = true;
  bool _isLoadingPreview = false;
  bool _isProcessing = false;
  String? _error;

  int get _currentCategoryId => (widget.registration['categoryId'] as num?)?.toInt() ?? 0;
  int get _homepageId => (widget.registration['homepageId'] as num?)?.toInt() ?? 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await _apiClient.get(
        '/contest-homepage/$_homepageId',
      );
      final data = response.data;
      if (data is Map && data['categories'] != null) {
        final cats = (data['categories'] as List).cast<Map<String, dynamic>>();
        setState(() {
          _categories = cats;
          _isLoadingCategories = false;
        });
      } else {
        setState(() {
          _categories = [];
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint('[부문변경] 부문 목록 로드 실패: $e');
      setState(() {
        _isLoadingCategories = false;
        _error = '부문 목록을 불러올 수 없습니다.';
      });
    }
  }

  Future<void> _loadPreview(int newCategoryId) async {
    setState(() {
      _isLoadingPreview = true;
      _preview = null;
      _error = null;
    });

    try {
      final response = await _apiClient.get(
        ApiConstants.categoryChangePreview,
        queryParameters: {
          'registrationId': widget.registrationId,
          'newCategoryId': newCategoryId,
        },
      );

      final data = response.data;
      if (data['success'] == true && data['data'] != null) {
        setState(() {
          _preview = data['data'] as Map<String, dynamic>;
          _isLoadingPreview = false;
        });
      } else {
        setState(() {
          _error = data['message'] ?? '미리보기를 불러올 수 없습니다.';
          _isLoadingPreview = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '오류가 발생했습니다.';
        _isLoadingPreview = false;
      });
    }
  }

  Future<void> _executeCategoryChange() async {
    if (_preview == null || _isProcessing) return;

    final changeable = _preview!['changeable'] == true;
    if (!changeable) return;

    final changeType = _preview!['changeType'] as String? ?? '';
    final newCategoryId = (_preview!['newCategoryId'] as num?)?.toInt();

    if (newCategoryId == null) return;

    // 확인 다이얼로그
    final confirmed = await _showConfirmDialog(changeType);
    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      if (changeType == 'ADDITIONAL_PAYMENT') {
        // 추가 결제 필요 → 결제 준비 → 토스 결제 → 부문 변경 실행
        await _processAdditionalPayment(newCategoryId);
      } else {
        // 무료 또는 환불 → 즉시 실행
        final response = await _apiClient.post(
          ApiConstants.categoryChange,
          data: {
            'registrationId': widget.registrationId,
            'newCategoryId': newCategoryId,
          },
        );

        if (!mounted) return;

        final data = response.data;
        if (data['success'] == true) {
          _showSuccessAndPop(data['message'] ?? '부문이 변경되었습니다.');
        } else {
          setState(() {
            _error = data['message'] ?? '부문 변경에 실패했습니다.';
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '오류가 발생했습니다. 다시 시도해주세요.';
        _isProcessing = false;
      });
    }
  }

  Future<void> _processAdditionalPayment(int newCategoryId) async {
    // 1. 추가 결제 준비
    final prepareResponse = await _apiClient.post(
      ApiConstants.categoryChangePrepare,
      data: {
        'registrationId': widget.registrationId,
        'newCategoryId': newCategoryId,
      },
    );

    final prepareData = prepareResponse.data;
    if (prepareData['success'] != true || prepareData['data'] == null) {
      throw Exception(prepareData['message'] ?? '결제 준비 실패');
    }

    final paymentInfo = prepareData['data'] as Map<String, dynamic>;
    final orderId = paymentInfo['orderId'] as String;
    final amount = (paymentInfo['amount'] as num).toInt();
    final orderName = paymentInfo['orderName'] as String? ?? '부문 변경';

    if (!mounted) return;

    // 2. 토스 결제 화면으로 이동
    final result = await context.push<bool>(
      '/payment/toss-checkout',
      extra: {
        'orderId': orderId,
        'amount': amount,
        'orderName': orderName,
      },
    );

    if (result != true || !mounted) {
      setState(() => _isProcessing = false);
      return;
    }

    // 3. 토스 결제 성공 → confirm + 부문 변경 실행
    // 토스 WebView에서 paymentKey를 받아와야 하는데,
    // 기존 결제 흐름에서 confirm은 WebView 리다이렉트로 처리됨
    // 여기서는 orderId 기반으로 confirm 후 부문 변경
    final confirmResponse = await _apiClient.post(
      ApiConstants.categoryChange,
      data: {
        'registrationId': widget.registrationId,
        'newCategoryId': newCategoryId,
        'orderId': orderId,
        'amount': amount,
      },
    );

    if (!mounted) return;

    final confirmData = confirmResponse.data;
    if (confirmData['success'] == true) {
      _showSuccessAndPop(confirmData['message'] ?? '부문이 변경되었습니다.');
    } else {
      setState(() {
        _error = confirmData['message'] ?? '부문 변경에 실패했습니다.';
        _isProcessing = false;
      });
    }
  }

  void _showSuccessAndPop(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
    context.pop(true); // true를 반환하여 목록 새로고침 트리거
  }

  Future<bool?> _showConfirmDialog(String changeType) {
    String title;
    String content;

    final newName = _preview!['newCategoryName'] ?? '';

    switch (changeType) {
      case 'ADDITIONAL_PAYMENT':
        final amount = (_preview!['additionalPaymentAmount'] as num?)?.toInt() ?? (_preview!['difference'] as num?)?.toInt() ?? 0;
        title = '추가 결제 확인';
        content = '$newName 부문으로 변경하시겠습니까?\n\n'
            '차액 ₩${_formatNumber(amount)}이 추가 결제됩니다.\n'
            '(결제 수수료는 주최자가 부담합니다)';
        break;
      case 'PARTIAL_REFUND':
        final absDiff = ((_preview!['difference'] as num?)?.toInt() ?? 0).abs();
        final pgFee = (_preview!['pgFeeAmount'] as num?)?.toInt() ?? 0;
        final refund = (_preview!['refundAmount'] as num?)?.toInt() ?? 0;
        title = '부문 변경 확인';
        if (pgFee > 0) {
          content = '$newName 부문으로 변경하시겠습니까?\n\n'
              '참가비 차액: ₩${_formatNumber(absDiff)}\n'
              'PG 수수료 차감: -₩${_formatNumber(pgFee)}\n'
              '실제 환불 금액: ₩${_formatNumber(refund)}\n\n'
              '※ 환불 시 결제 대행 수수료는 참가자 부담입니다.';
        } else {
          content = '$newName 부문으로 변경하시겠습니까?\n₩${_formatNumber(refund)}이 환불됩니다.';
        }
        break;
      default:
        title = '부문 변경 확인';
        content = '$newName 부문으로 변경하시겠습니까?\n추가 비용 없이 변경됩니다.';
    }

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('변경하기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          '부문 변경',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 현재 부문 정보
                  _buildCurrentInfo(),
                  const SizedBox(height: 24),

                  // 안내문
                  _buildNotice(),
                  const SizedBox(height: 24),

                  // 새 부문 선택
                  _buildCategorySelector(),
                  const SizedBox(height: 20),

                  // 차액 미리보기
                  if (_isLoadingPreview)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),
                  if (_preview != null) _buildPreviewCard(),

                  // 에러 메시지
                  if (_error != null) _buildErrorMessage(),

                  const SizedBox(height: 24),

                  // 변경 버튼
                  if (_preview != null && _preview!['changeable'] == true)
                    _buildChangeButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.registration['contestName'] ?? '',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _infoRow('참가자', widget.registration['participantName'] ?? ''),
          _infoRow('현재 부문', widget.registration['categoryName'] ?? ''),
          _infoRow('결제 금액', '₩${_formatNumber((widget.registration['fee'] as num?)?.toInt() ?? 0)}'),
        ],
      ),
    );
  }

  Widget _buildNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: const Color(0xFFEA580C)),
              const SizedBox(width: 6),
              Text(
                '부문 변경 안내',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF9A3412),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _noticeText('• 같은 대회 내 다른 부문으로만 변경할 수 있습니다.'),
          _noticeText('• 높은 참가비 부문으로 변경 시, 차액만 추가 결제합니다.'),
          _noticeText('• 낮은 참가비 부문으로 변경 시, 차액에서 PG 수수료(결제 대행 수수료)를 차감한 금액이 환불됩니다.'),
          _noticeText('• 무료 부문에서 유료 부문으로 변경 시, 참가비를 결제합니다.'),
          _noticeText('• 참가비가 동일한 부문은 추가 비용 없이 변경됩니다.'),
          _noticeText('• 접수 마감 후에는 부문 변경이 불가합니다.'),
          _noticeText('• 정원이 마감된 부문으로는 변경할 수 없습니다.'),
          _noticeText('• 단체전/페어 부문은 변경할 수 없습니다.'),
        ],
      ),
    );
  }

  Widget _noticeText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.5, color: const Color(0xFF9A3412), height: 1.5),
      ),
    );
  }

  Widget _buildCategorySelector() {
    final availableCategories = _categories.where((cat) {
      final catId = (cat['categoryId'] as num?)?.toInt() ?? 0;
      final contestType = cat['contestType'] as String? ?? '';
      // 현재 부문 제외, 단체전/페어 제외
      return catId != _currentCategoryId && contestType != 'TEAM' && contestType != 'PAIR';
    }).toList();

    if (availableCategories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '변경 가능한 부문이 없습니다.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '변경할 부문 선택',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...availableCategories.map((cat) {
          final catId = (cat['categoryId'] as num?)?.toInt() ?? 0;
          final isSelected = _selectedCategoryId == catId;
          final fee = (cat['fee'] as num?)?.toInt() ?? 0;
          final name = cat['categoryName'] as String? ?? '';
          final maxP = (cat['maxParticipants'] as num?)?.toInt();

          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategoryId = catId);
              _loadPreview(catId);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? AppColors.primary : AppColors.textTertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (maxP != null && maxP > 0)
                          Text(
                            '정원 ${maxP}명',
                            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    fee > 0 ? '₩${_formatNumber(fee)}' : '무료',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPreviewCard() {
    final changeable = _preview!['changeable'] == true;
    final changeType = _preview!['changeType'] as String? ?? '';
    final difference = (_preview!['difference'] as num?)?.toInt() ?? 0;
    final pgFee = (_preview!['pgFeeAmount'] as num?)?.toInt() ?? 0;
    final refundAmount = (_preview!['refundAmount'] as num?)?.toInt() ?? 0;
    final additionalAmount = (_preview!['additionalPaymentAmount'] as num?)?.toInt() ?? 0;
    final message = _preview!['message'] as String? ?? '';

    if (!changeable) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 13, color: const Color(0xFF991B1B)),
              ),
            ),
          ],
        ),
      );
    }

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;

    switch (changeType) {
      case 'ADDITIONAL_PAYMENT':
        bgColor = const Color(0xFFEFF6FF);
        borderColor = const Color(0xFFBFDBFE);
        textColor = const Color(0xFF1E40AF);
        icon = Icons.add_circle_outline;
        break;
      case 'PARTIAL_REFUND':
        bgColor = const Color(0xFFF0FDF4);
        borderColor = const Color(0xFFBBF7D0);
        textColor = const Color(0xFF166534);
        icon = Icons.remove_circle_outline;
        break;
      default:
        bgColor = const Color(0xFFF3F4F6);
        borderColor = const Color(0xFFD1D5DB);
        textColor = const Color(0xFF374151);
        icon = Icons.swap_horiz;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: textColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          if (changeType == 'PARTIAL_REFUND' && pgFee > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _previewRow('참가비 차액', '₩${_formatNumber(difference.abs())}'),
                  _previewRow('PG 수수료 차감', '-₩${_formatNumber(pgFee)}'),
                  const Divider(height: 16),
                  _previewRow('실제 환불 금액', '₩${_formatNumber(refundAmount)}',
                      bold: true, color: textColor),
                ],
              ),
            ),
          ],
          if (changeType == 'ADDITIONAL_PAYMENT') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _previewRow('추가 결제 금액', '₩${_formatNumber(additionalAmount > 0 ? additionalAmount : difference)}',
                  bold: true, color: textColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(fontSize: 13, color: const Color(0xFF991B1B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeButton() {
    final changeType = _preview!['changeType'] as String? ?? '';
    final difference = (_preview!['difference'] as num?)?.toInt() ?? 0;
    final refundAmount = (_preview!['refundAmount'] as num?)?.toInt() ?? 0;
    final additionalAmount = (_preview!['additionalPaymentAmount'] as num?)?.toInt() ?? 0;

    String buttonText;
    switch (changeType) {
      case 'ADDITIONAL_PAYMENT':
        final amt = additionalAmount > 0 ? additionalAmount : difference;
        buttonText = '₩${_formatNumber(amt)} 추가 결제 후 변경';
        break;
      case 'PARTIAL_REFUND':
        buttonText = '변경하기 (₩${_formatNumber(refundAmount)} 환불)';
        break;
      default:
        buttonText = '부문 변경하기';
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _executeCategoryChange,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                buttonText,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}
