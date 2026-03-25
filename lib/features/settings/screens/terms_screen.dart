import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 이용약관 화면
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('이용약관'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              '제1조 (목적)',
              '이 약관은 바둑대회 앱(이하 "앱")이 제공하는 서비스의 이용조건 및 절차, 이용자와 앱의 권리, 의무, 책임사항과 기타 필요한 사항을 규정함을 목적으로 합니다.',
            ),
            _buildSection(
              '제2조 (용어의 정의)',
              '1. "서비스"란 앱이 제공하는 바둑대회 정보 제공, 참가신청, 대회 결과 조회 등의 서비스를 말합니다.\n\n'
              '2. "이용자"란 앱에 접속하여 이 약관에 따라 앱이 제공하는 서비스를 받는 회원 및 비회원을 말합니다.\n\n'
              '3. "회원"이란 앱에 개인정보를 제공하여 회원등록을 한 자로서, 앱의 정보를 지속적으로 제공받으며, 앱이 제공하는 서비스를 계속적으로 이용할 수 있는 자를 말합니다.',
            ),
            _buildSection(
              '제3조 (약관의 효력과 변경)',
              '1. 이 약관은 서비스를 이용하고자 하는 모든 이용자에게 그 효력이 발생합니다.\n\n'
              '2. 앱은 이 약관을 변경할 수 있으며, 변경된 약관은 앱 내 공지사항을 통해 공지합니다.\n\n'
              '3. 회원은 변경된 약관에 동의하지 않으면 서비스 이용을 중단하고 회원 탈퇴를 할 수 있습니다.',
            ),
            _buildSection(
              '제4조 (서비스의 제공)',
              '앱은 다음과 같은 서비스를 제공합니다:\n\n'
              '1. 바둑대회 정보 제공\n'
              '2. 대회 참가신청 서비스\n'
              '3. 대회 결과 및 순위 조회\n'
              '4. 개인 기록 관리\n'
              '5. 기타 앱이 정하는 서비스',
            ),
            _buildSection(
              '제5조 (서비스 이용)',
              '1. 서비스 이용은 앱의 업무상 또는 기술상 특별한 지장이 없는 한 연중무휴, 1일 24시간을 원칙으로 합니다.\n\n'
              '2. 앱은 시스템 정기점검, 증설 및 교체를 위해 앱이 정한 날이나 시간에 서비스를 일시 중단할 수 있습니다.',
            ),
            _buildSection(
              '제6조 (회원의 의무)',
              '1. 회원은 관계법령, 이 약관의 규정, 이용안내 및 서비스와 관련하여 공지한 주의사항을 준수하여야 합니다.\n\n'
              '2. 회원은 타인의 개인정보를 도용하거나 부정하게 사용해서는 안 됩니다.\n\n'
              '3. 회원은 서비스를 이용하여 얻은 정보를 앱의 사전 승낙 없이 영리 목적으로 사용해서는 안 됩니다.',
            ),
            _buildSection(
              '제7조 (개인정보보호)',
              '앱은 이용자의 개인정보를 보호하기 위해 관련 법령이 정하는 바에 따라 개인정보처리방침을 수립하여 시행합니다.',
            ),
            _buildSection(
              '제8조 (면책조항)',
              '1. 앱은 천재지변, 전쟁, 기간통신사업자의 서비스 중지 등 불가항력적인 사유로 서비스를 제공할 수 없는 경우 책임이 면제됩니다.\n\n'
              '2. 앱은 이용자의 귀책사유로 인한 서비스 이용 장애에 대해서는 책임을 지지 않습니다.',
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
