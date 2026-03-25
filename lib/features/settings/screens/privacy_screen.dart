import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 개인정보처리방침 화면
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('개인정보처리방침'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '바둑대회 앱(이하 "앱")은 이용자의 개인정보를 중요시하며, '
              '「개인정보 보호법」을 준수하고 있습니다.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. 수집하는 개인정보 항목',
              '앱은 서비스 제공을 위해 다음과 같은 개인정보를 수집합니다:\n\n'
              '• 필수항목: 이름, 휴대폰번호, 생년월일, 성별\n'
              '• 선택항목: 기력, 지역, 소속\n'
              '• 자동수집항목: 서비스 이용기록, 접속 로그, 기기정보',
            ),
            _buildSection(
              '2. 개인정보의 수집 및 이용목적',
              '수집한 개인정보는 다음의 목적을 위해 이용됩니다:\n\n'
              '• 회원 식별 및 본인인증\n'
              '• 대회 참가신청 및 관리\n'
              '• 대회 결과 기록 및 순위 관리\n'
              '• 서비스 이용에 관한 통계 분석\n'
              '• 고객 문의 응대',
            ),
            _buildSection(
              '3. 개인정보의 보유 및 이용기간',
              '앱은 개인정보 수집 및 이용목적이 달성된 후에는 해당 정보를 지체 없이 파기합니다. '
              '단, 관계법령의 규정에 의하여 보존할 필요가 있는 경우 법령이 정한 기간 동안 보관합니다.\n\n'
              '• 회원 탈퇴 시: 즉시 파기\n'
              '• 대회 참가 기록: 5년 보관 (기록 관리 목적)\n'
              '• 전자상거래 관련 기록: 5년 (전자상거래법)',
            ),
            _buildSection(
              '4. 개인정보의 제3자 제공',
              '앱은 이용자의 개인정보를 원칙적으로 외부에 제공하지 않습니다. '
              '다만, 아래의 경우에는 예외로 합니다:\n\n'
              '• 이용자가 사전에 동의한 경우\n'
              '• 대회 주최측에 참가자 정보 제공 (대회 운영 목적)\n'
              '• 법령의 규정에 의한 경우',
            ),
            _buildSection(
              '5. 개인정보의 파기절차 및 방법',
              '앱은 원칙적으로 개인정보 수집 및 이용목적이 달성된 후에는 해당 정보를 지체없이 파기합니다.\n\n'
              '• 파기절차: 이용목적 달성 후 별도의 DB로 옮겨져 보관 기간 후 파기\n'
              '• 파기방법: 전자적 파일 형태는 기술적 방법을 사용하여 삭제',
            ),
            _buildSection(
              '6. 이용자의 권리',
              '이용자는 언제든지 다음의 권리를 행사할 수 있습니다:\n\n'
              '• 개인정보 열람 요구\n'
              '• 오류 등이 있을 경우 정정 요구\n'
              '• 삭제 요구\n'
              '• 처리정지 요구\n\n'
              '권리 행사는 앱 내 설정 메뉴 또는 고객센터를 통해 가능합니다.',
            ),
            _buildSection(
              '7. 개인정보 보호책임자',
              '앱은 개인정보 처리에 관한 업무를 총괄해서 책임지고, '
              '개인정보 처리와 관련한 불만처리 및 피해구제를 위하여 아래와 같이 개인정보 보호책임자를 지정하고 있습니다:\n\n'
              '• 개인정보 보호책임자: 우경주\n'
              '• 이메일: dnrudwn3693@gmail.com\n'
              '• 전화: 010-2520-3603',
            ),
            _buildSection(
              '8. 개인정보 처리방침 변경',
              '이 개인정보 처리방침은 시행일로부터 적용되며, 법령 및 방침에 따른 변경내용의 추가, '
              '삭제 및 정정이 있는 경우에는 변경사항의 시행 7일 전부터 공지사항을 통하여 고지할 것입니다.',
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '시행일: 2026년 1월 1일',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
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
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
