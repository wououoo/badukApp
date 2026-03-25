import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/api/api_client.dart';
import '../../../core/constants/api_constants.dart';

/// 개인정보 동의 화면 (회원가입 플로우에 삽입)
/// 개인정보보호법 제15조(수집·이용 동의), 제22조(동의 방법)
class PrivacyConsentScreen extends ConsumerStatefulWidget {
  const PrivacyConsentScreen({super.key});

  @override
  ConsumerState<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends ConsumerState<PrivacyConsentScreen> {
  // 필수 동의
  bool _agreeAll = false;
  bool _agreeRequiredPersonalInfo = false; // [필수] 개인정보 수집·이용 동의
  bool _agreeTermsOfService = false;       // [필수] 이용약관 동의

  // 선택 동의
  bool _agreeOptionalInfo = false;         // [선택] 선택 정보 수집 동의
  bool _agreePushNotification = false;     // [선택] 푸시 알림 수신 동의

  bool _isLoading = false;

  // 필수 동의가 모두 완료됐는지
  bool get _allRequiredAgreed =>
      _agreeRequiredPersonalInfo && _agreeTermsOfService;

  // 전체 동의 체크 상태
  bool get _isAllChecked =>
      _agreeRequiredPersonalInfo &&
      _agreeTermsOfService &&
      _agreeOptionalInfo &&
      _agreePushNotification;

  void _toggleAll(bool? value) {
    setState(() {
      _agreeAll = value ?? false;
      _agreeRequiredPersonalInfo = _agreeAll;
      _agreeTermsOfService = _agreeAll;
      _agreeOptionalInfo = _agreeAll;
      _agreePushNotification = _agreeAll;
    });
  }

  void _updateAgreeAll() {
    setState(() {
      _agreeAll = _isAllChecked;
    });
  }

  Future<void> _submitConsent() async {
    if (!_allRequiredAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 항목에 모두 동의해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiClient = ApiClient();

      // 동의 기록 API 호출
      final response = await apiClient.dio.post(
        ApiConstants.privacyConsent,
        data: {
          'consents': [
            {
              'consentType': 'SIGNUP',
              'consentItem': 'REQUIRED_PERSONAL_INFO',
              'consented': _agreeRequiredPersonalInfo,
            },
            {
              'consentType': 'SIGNUP',
              'consentItem': 'TERMS_OF_SERVICE',
              'consented': _agreeTermsOfService,
            },
            {
              'consentType': 'SIGNUP',
              'consentItem': 'OPTIONAL_PERSONAL_INFO',
              'consented': _agreeOptionalInfo,
            },
            {
              'consentType': 'SIGNUP',
              'consentItem': 'PUSH_NOTIFICATION',
              'consented': _agreePushNotification,
            },
          ],
          'deviceInfo': 'Flutter App',
        },
      );

      if (response.data['success'] == true) {
        // 동의 완료 → AuthProvider에 상태 반영
        final authNotifier = ref.read(authProvider.notifier);
        await authNotifier.completePrivacyConsent();

        if (mounted) {
          // 프로필 설정 화면으로 이동
          context.go('/profile-setup');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.data['message'] ?? '동의 처리 중 오류가 발생했습니다.')),
          );
        }
      }
    } catch (e) {
      debugPrint('동의 기록 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('네트워크 오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('개인정보 동의'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 안내 문구
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined, color: AppColors.primary, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '서비스 이용을 위해 아래 항목에 동의해주세요.\n동의 내역은 안전하게 기록·보관됩니다.',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 전체 동의
                    _buildAllAgreeItem(),

                    const Divider(height: 32),

                    // 필수 동의 항목들
                    _buildConsentItem(
                      title: '[필수] 개인정보 수집·이용 동의',
                      description: '이름, 전화번호, 생년월일, 성별을 대회 운영 및 회원 관리 목적으로 수집합니다.',
                      detailContent: _requiredPersonalInfoDetail,
                      value: _agreeRequiredPersonalInfo,
                      onChanged: (v) {
                        setState(() => _agreeRequiredPersonalInfo = v ?? false);
                        _updateAgreeAll();
                      },
                      required: true,
                    ),

                    const SizedBox(height: 12),

                    _buildConsentItem(
                      title: '[필수] 이용약관 동의',
                      description: '바둑대회 앱 서비스 이용약관에 동의합니다.',
                      onViewDetail: () => context.push('/terms'),
                      value: _agreeTermsOfService,
                      onChanged: (v) {
                        setState(() => _agreeTermsOfService = v ?? false);
                        _updateAgreeAll();
                      },
                      required: true,
                    ),

                    const SizedBox(height: 20),

                    // 선택 동의 항목들
                    _buildConsentItem(
                      title: '[선택] 선택 정보 수집 동의',
                      description: '기력, 지역, 소속 클럽 정보를 수집합니다. 동의하지 않아도 서비스 이용이 가능합니다.',
                      detailContent: _optionalInfoDetail,
                      value: _agreeOptionalInfo,
                      onChanged: (v) {
                        setState(() => _agreeOptionalInfo = v ?? false);
                        _updateAgreeAll();
                      },
                      required: false,
                    ),

                    const SizedBox(height: 12),

                    _buildConsentItem(
                      title: '[선택] 푸시 알림 수신 동의',
                      description: '대회 안내, 결과 알림 등을 푸시 알림으로 받습니다.',
                      value: _agreePushNotification,
                      onChanged: (v) {
                        setState(() => _agreePushNotification = v ?? false);
                        _updateAgreeAll();
                      },
                      required: false,
                    ),
                  ],
                ),
              ),
            ),

            // 하단 동의 버튼
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _allRequiredAgreed && !_isLoading
                      ? _submitConsent
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.border,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '동의하고 계속하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 전체 동의 체크박스
  Widget _buildAllAgreeItem() {
    return GestureDetector(
      onTap: () => _toggleAll(!_agreeAll),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _agreeAll ? AppColors.primary.withOpacity(0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _agreeAll ? AppColors.primary : AppColors.border,
            width: _agreeAll ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            _buildCheckIcon(_agreeAll),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '전체 동의',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 개별 동의 항목
  Widget _buildConsentItem({
    required String title,
    required String description,
    String? detailContent,
    VoidCallback? onViewDetail,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required bool required,
  }) {
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
          GestureDetector(
            onTap: () => onChanged(!value),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _buildCheckIcon(value),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: value ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 전문 보기 버튼
          if (detailContent != null || onViewDetail != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onViewDetail ?? () => _showDetailDialog(title, detailContent!),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '전문 보기',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckIcon(bool checked) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: checked ? AppColors.primary : AppColors.border,
          width: 2,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }

  void _showDetailDialog(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // 핸들 바
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === 동의서 전문 내용 ===

  static const String _requiredPersonalInfoDetail = '''
[개인정보 수집·이용 동의서]

1. 수집 항목
  • 필수: 이름, 휴대폰번호, 생년월일, 성별

2. 수집 및 이용 목적
  • 회원 식별 및 본인인증
  • 대회 참가신청 및 관리
  • 대회 결과 기록 및 순위 관리
  • 서비스 이용에 관한 통계 분석
  • 고객 문의 응대

3. 보유 및 이용 기간
  • 회원 탈퇴 시 즉시 파기
  • 대회 참가 기록: 대회 종료 후 5년
  • 전자상거래 관련 기록: 5년 (전자상거래법)
  • 접속 로그: 1년 (통신비밀보호법)

4. 동의 거부 권리 및 불이익
  • 귀하는 개인정보 수집·이용에 대한 동의를 거부할 권리가 있습니다.
  • 다만, 필수 항목 동의를 거부할 경우 서비스 이용이 제한됩니다.

5. 개인정보 보호책임자
  • 성명: 우경주
  • 이메일: dnrudwn3693@gmail.com
  • 전화: 010-2520-3603
''';

  static const String _optionalInfoDetail = '''
[선택 정보 수집·이용 동의서]

1. 수집 항목
  • 선택: 기력(단/급), 지역(시/도, 시/군/구), 소속 클럽

2. 수집 및 이용 목적
  • 대회 부문 자동 분류
  • 지역별 대회 추천
  • 클럽 커뮤니티 기능

3. 보유 및 이용 기간
  • 회원 탈퇴 시 즉시 파기
  • 동의 철회 시 해당 정보 즉시 삭제

4. 동의 거부 권리 및 불이익
  • 귀하는 선택 정보 수집에 대한 동의를 거부할 권리가 있습니다.
  • 동의하지 않아도 기본 서비스(회원가입, 대회 참가) 이용이 가능합니다.
  • 다만, 일부 편의 기능(자동 분류, 지역 추천)이 제한될 수 있습니다.
''';
}
