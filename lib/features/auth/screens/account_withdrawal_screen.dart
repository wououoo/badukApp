import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/auth_provider.dart';

/// 회원 탈퇴 화면
class AccountWithdrawalScreen extends ConsumerStatefulWidget {
  const AccountWithdrawalScreen({super.key});

  @override
  ConsumerState<AccountWithdrawalScreen> createState() =>
      _AccountWithdrawalScreenState();
}

class _AccountWithdrawalScreenState
    extends ConsumerState<AccountWithdrawalScreen> {
  bool _isAgreed = false;
  bool _isLoading = false;
  String? _selectedReason;

  static const List<String> _reasons = [
    '서비스를 더 이상 사용하지 않아서',
    '개인정보 보호가 걱정되어서',
    '다른 서비스를 사용하려고',
    '기타',
  ];

  bool get _canWithdraw => _isAgreed && _selectedReason != null;

  Future<void> _handleWithdraw() async {
    // 확인 다이얼로그 표시
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴 확인'),
        content: const Text('정말 탈퇴하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).withdraw(reason: _selectedReason);
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('[Error] 탈퇴 처리 중 오류: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('탈퇴 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원 탈퇴'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 경고 아이콘 및 제목
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '회원 탈퇴',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 삭제되는 정보 안내
            _buildInfoSection(
              icon: Icons.delete_outline,
              iconColor: AppColors.error,
              title: '탈퇴 시 다음 정보가 삭제됩니다:',
              items: const [
                '개인정보 (이름, 전화번호, 이메일, 생년월일 등)',
                '소셜 로그인 연동 정보',
                '푸시 알림 설정',
              ],
            ),
            const SizedBox(height: 20),

            // 유지되는 정보 안내
            _buildInfoSection(
              icon: Icons.check_circle_outline,
              iconColor: AppColors.primary,
              title: '다음 정보는 유지됩니다:',
              items: const [
                '대회 참가 기록 (McMahon ID 기반)',
              ],
            ),
            const SizedBox(height: 32),

            // 탈퇴 사유 선택
            Text(
              '탈퇴 사유',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: _reasons.map((reason) {
                  return RadioListTile<String>(
                    title: Text(
                      reason,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    value: reason,
                    groupValue: _selectedReason,
                    activeColor: AppColors.error,
                    onChanged: (value) {
                      setState(() => _selectedReason = value);
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // 동의 체크박스
            CheckboxListTile(
              value: _isAgreed,
              onChanged: (value) {
                setState(() => _isAgreed = value ?? false);
              },
              activeColor: AppColors.error,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                '위 내용을 확인했으며, 회원 탈퇴에 동의합니다.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 탈퇴하기 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _canWithdraw && !_isLoading
                    ? _handleWithdraw
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  disabledBackgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
                    : const Text(
                        '탈퇴하기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
    );
  }

  /// 정보 안내 섹션 위젯
  Widget _buildInfoSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<String> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
