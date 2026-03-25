import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/auth_provider.dart';

/// 전화번호 변경 화면 (카카오 본인인증으로 변경)
class ChangePhoneScreen extends ConsumerStatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  ConsumerState<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends ConsumerState<ChangePhoneScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final currentPhone = user?.phone ?? '등록된 번호 없음';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('전화번호 변경'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              Icon(
                Icons.phone_android,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),

              const Text(
                '전화번호 변경',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Text(
                '카카오 본인인증을 통해\n새로운 전화번호로 변경할 수 있습니다.',
                style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // 현재 전화번호 표시
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '현재 전화번호',
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentPhone,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 카카오 본인인증 버튼
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleChangePhone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE500),
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.chat_bubble,
                                size: 16,
                                color: Color(0xFFFEE500),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '카카오로 본인인증',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // 안내
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.info_outline, '카카오 계정에 등록된 전화번호로 변경됩니다'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.swap_horiz, '기존 번호의 대회 기록은 유지됩니다'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.security, '본인 명의의 전화번호만 등록 가능합니다'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        ),
      ],
    );
  }

  Future<void> _handleChangePhone() async {
    setState(() => _isLoading = true);

    try {
      // 카카오 추가 동의 요청
      OAuthToken token;
      try {
        token = await UserApi.instance.loginWithNewScopes(
          ['name', 'phone_number', 'birthyear', 'birthday', 'gender'],
        );
      } catch (e) {
        if (e.toString().contains('CANCELED') || e.toString().contains('cancelled')) {
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('카카오 동의에 실패했습니다. 다시 시도해주세요.')),
          );
        }
        return;
      }

      // 백엔드에 본인인증 요청 (전화번호 업데이트, 인증 상태 유지)
      final success = await ref.read(authProvider.notifier).changePhone(
        kakaoAccessToken: token.accessToken,
      );

      if (mounted && success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('전화번호가 변경되었습니다.'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('전화번호 변경에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
