import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/services/version_service.dart';
import 'apple_sign_in_helper_stub.dart'
    if (dart.library.io) 'apple_sign_in_helper.dart' as apple;
import 'platform_helper.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  // 테스트 로그인 버튼 노출 여부 — 서버 AppConfig.testLoginEnabled에 따름 (기본 숨김)
  bool _testLoginEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadAppConfig();
  }

  Future<void> _loadAppConfig() async {
    try {
      final config = await VersionService.fetchConfig();
      if (mounted && config != null) {
        setState(() => _testLoginEnabled = config.testLoginEnabled);
      }
    } catch (_) {
      // 실패 시 기본값(false) 유지 — 노출 안 함
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // 로고
                      Semantics(
                        label: '바둑대회 로고',
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.grid_on_rounded,
                            size: 60,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 앱 이름
                      const Text(
                        '바둑대회',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '대회 참가부터 기록까지 한 번에',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),

                      const Spacer(flex: 2),

                      // 카카오 로그인 버튼
                      _buildKakaoLoginButton(authState),
                      const SizedBox(height: 12),

                      // 애플 로그인 (iOS만)
                      if (isIOS) ...[
                        _buildAppleLoginButton(authState),
                        const SizedBox(height: 12),
                      ],

                      const SizedBox(height: 24),

                      // 테스트 로그인 (심사용) — 백엔드 AppConfig.testLoginEnabled가 true일 때만 노출
                      if (_testLoginEnabled) ...[
                        _buildTestLoginButton(authState),
                        const SizedBox(height: 24),
                      ],

                      // 이용약관 안내
                      Text(
                        '로그인 시 이용약관 및 개인정보처리방침에\n동의하는 것으로 간주합니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey[400], height: 1.5),
                      ),

                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 카카오 로그인 버튼
  Widget _buildKakaoLoginButton(AuthState authState) {
    return Semantics(
      label: '카카오 계정으로 로그인',
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: (authState.isLoading || _isLoading) ? null : _handleKakaoLogin,
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
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
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
                        '카카오로 시작하기',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  /// 애플 로그인 버튼
  Widget _buildAppleLoginButton(AuthState authState) {
    return Semantics(
      label: 'Apple 계정으로 로그인',
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: (authState.isLoading || _isLoading) ? null : _handleAppleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.apple, size: 24),
              SizedBox(width: 12),
              Text(
                'Apple로 로그인',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 테스트 로그인 버튼 (토스 심사용)
  Widget _buildTestLoginButton(AuthState authState) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: (authState.isLoading || _isLoading) ? null : _handleTestLogin,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey[700],
          side: BorderSide(color: Colors.grey[300]!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.science_outlined, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                '테스트 계정으로 로그인',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 테스트 로그인 ==========

  Future<void> _handleTestLogin() async {
    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).loginWithTest(
        'toss_reviewer',
        'stoneworks2025!',
      );
    } catch (e) {
      debugPrint('[Login] 테스트 로그인 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('테스트 로그인에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ========== 카카오 로그인 ==========

  Future<void> _handleKakaoLogin() async {
    setState(() => _isLoading = true);

    try {
      OAuthToken token;

      if (await isKakaoTalkInstalled()) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      await ref.read(authProvider.notifier).loginWithKakao(token.accessToken);
    } catch (e) {
      if (e.toString().contains('CANCELED') || e.toString().contains('cancelled')) {
        return;
      }
      debugPrint('[Login] 카카오 로그인 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카카오 로그인에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ========== 애플 로그인 ==========

  Future<void> _handleAppleLogin() async {
    setState(() => _isLoading = true);

    try {
      final result = await apple.performAppleSignIn();
      if (result == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('애플 로그인이 취소되었습니다.')),
          );
        }
        return;
      }

      await ref.read(authProvider.notifier).loginWithApple(
        identityToken: result['identityToken']!,
        appleUserId: result['userIdentifier']!,
        authorizationCode: result['authorizationCode'],
      );
    } catch (e) {
      debugPrint('[Login] 애플 로그인 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('애플 로그인에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
