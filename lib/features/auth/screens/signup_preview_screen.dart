import 'package:flutter/material.dart';

/// 카카오 심사 제출용 회원가입 화면 (캡처용)
/// 실제 동작하지 않으며, 수집하는 개인정보 항목을 시각적으로 보여주기 위한 화면
class SignupPreviewScreen extends StatelessWidget {
  const SignupPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('회원가입'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 안내 문구
            const Text(
              '바둑대회 서비스 이용을 위해\n아래 정보를 입력해주세요.',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '* 표시는 필수 항목입니다.',
              style: TextStyle(fontSize: 13, color: Colors.red),
            ),
            const SizedBox(height: 32),

            // 필수 회원정보
            _buildSectionTitle('필수 회원정보'),
            const SizedBox(height: 16),
            _buildTextField('이름 *', '이름을 입력하세요'),
            _buildTextField('휴대폰번호 *', '010-0000-0000'),
            _buildTextField('생년월일 *', 'YYYY-MM-DD'),
            _buildDropdownField('성별 *', '선택하세요', ['남성', '여성']),

            const SizedBox(height: 32),

            // 선택 회원정보
            _buildSectionTitle('추가 정보'),
            const SizedBox(height: 16),
            _buildDropdownField('기력 *', '선택하세요', ['프로', '아마 9단', '아마 8단', '...']),
            _buildDropdownField('지역 *', '시/도 선택', ['서울특별시', '경기도', '...']),
            _buildDropdownField('시/군/구 *', '시/군/구 선택', ['강남구', '서초구', '...']),
            _buildTextField('소속 클럽', '소속 클럽명 (선택사항)'),

            const SizedBox(height: 40),

            // 동의 항목
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildCheckItem('[필수] 이용약관 동의', false),
                  const SizedBox(height: 12),
                  _buildCheckItem('[필수] 개인정보 수집 및 이용 동의', false),
                  const SizedBox(height: 12),
                  _buildCheckItem('[선택] 대회 알림 수신 동의', false),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 가입 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '가입하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField(String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
            child: Text(
              hint,
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, String hint, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  hint,
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
                Icon(Icons.keyboard_arrow_down, color: Colors.grey[400]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text, bool checked) {
    return Row(
      children: [
        Icon(
          checked ? Icons.check_box : Icons.check_box_outline_blank,
          size: 22,
          color: checked ? Colors.blue : Colors.grey[400],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
