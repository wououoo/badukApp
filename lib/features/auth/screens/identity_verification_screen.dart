import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/auth_provider.dart';

/// 본인인증 화면 (카카오 추가 동의 방식)
/// SNS 로그인 후 카카오 계정의 이름, 전화번호, 생년월일, 성별 동의를 받아 본인인증
class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends ConsumerState<IdentityVerificationScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('본인인증'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              Icon(
                Icons.verified_user_outlined,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 32),
              const Text(
                '본인인증이 필요합니다',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '대회 참가를 위해 본인인증이 필요합니다.\n카카오 계정을 통해 간편하게 인증해주세요.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // 카카오로 본인인증 버튼
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleKakaoVerify,
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
              const SizedBox(height: 32),

              // 수집 정보 안내
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.info_outline, '수집 항목: 이름, 전화번호, 생년월일, 성별'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.lock_outline, '대회 참가 본인 확인 용도로만 사용됩니다'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.check_circle_outline, '카카오 계정에 등록된 정보로 자동 인증됩니다'),
                  ],
                ),
              ),

              const Spacer(flex: 3),
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

  /// 카카오 추가 동의 요청 후 본인인증
  Future<void> _handleKakaoVerify() async {
    setState(() => _isLoading = true);

    try {
      // 카카오 추가 동의 요청 (이름, 전화번호, 생년월일, 성별)
      OAuthToken token;
      try {
        token = await UserApi.instance.loginWithNewScopes(
          ['name', 'phone_number', 'birthyear', 'birthday', 'gender'],
        );
      } catch (e) {
        if (e.toString().contains('CANCELED') || e.toString().contains('cancelled')) {
          return;
        }
        debugPrint('[Identity] 카카오 추가 동의 실패: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('카카오 동의에 실패했습니다. 다시 시도해주세요.')),
          );
        }
        return;
      }

      // 백엔드에 카카오 액세스 토큰 전달하여 본인인증 처리
      final success = await ref.read(authProvider.notifier).verifyIdentityWithKakaoScopes(
        kakaoAccessToken: token.accessToken,
      );

      if (mounted && success) {
        // 인증 완료 → 라우터가 자동으로 다음 화면(프로필 설정)으로 이동
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
