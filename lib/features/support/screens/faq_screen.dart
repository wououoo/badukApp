import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// FAQ 화면 (정적)
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  String _selectedCategory = '전체';

  final List<String> _categories = ['전체', '대회', '참가신청', '계정', '기타'];

  final List<FaqItem> _faqItems = [
    // 대회
    FaqItem(
      category: '대회',
      question: '대회 참가 자격은 어떻게 되나요?',
      answer: '각 대회마다 참가 자격이 다릅니다. 대회 상세 페이지에서 참가 자격을 확인해주세요. '
          '일반적으로 아마추어 기사라면 누구나 참가 가능하며, 일부 대회는 기력이나 나이 제한이 있을 수 있습니다.',
    ),
    FaqItem(
      category: '대회',
      question: '대회 당일 준비물은 무엇인가요?',
      answer: '신분증과 참가 확인 QR코드를 준비해주세요. QR코드는 앱 내 "내 정보" 메뉴에서 확인할 수 있습니다. '
          '바둑돌과 시계는 대회장에서 제공됩니다.',
    ),
    FaqItem(
      category: '대회',
      question: '대회 결과는 언제 확인할 수 있나요?',
      answer: '대회 종료 후 순위표가 실시간으로 업데이트됩니다. '
          '앱 내 대회 상세 페이지 또는 "기록" 탭에서 확인하실 수 있습니다.',
    ),

    // 참가신청
    FaqItem(
      category: '참가신청',
      question: '참가신청은 어떻게 하나요?',
      answer: '대회 목록에서 원하는 대회를 선택한 후 "참가신청" 버튼을 누르세요. '
          '참가 부문을 선택하고 필요한 정보를 입력하면 신청이 완료됩니다.',
    ),
    FaqItem(
      category: '참가신청',
      question: '참가신청 취소는 어떻게 하나요?',
      answer: '대회 상세 페이지에서 "참가취소" 버튼을 눌러 취소할 수 있습니다. '
          '단, 접수 마감 이후에는 취소가 불가능하며, 대회 주최측에 직접 문의하셔야 합니다.',
    ),
    FaqItem(
      category: '참가신청',
      question: '참가비는 어떻게 납부하나요?',
      answer: '대회에 따라 현장 납부 또는 사전 납부가 가능합니다. '
          '사전 납부 대회의 경우 참가신청 시 안내되는 계좌로 입금해주세요.',
    ),

    // 계정
    FaqItem(
      category: '계정',
      question: '기력은 어떻게 변경하나요?',
      answer: '"내 정보" > 설정(톱니바퀴) > "프로필 수정"에서 기력을 변경할 수 있습니다.',
    ),
    FaqItem(
      category: '계정',
      question: '회원 탈퇴는 어떻게 하나요?',
      answer: '고객센터 1:1 문의를 통해 탈퇴 요청을 해주세요. '
          '탈퇴 시 모든 대회 참가 기록이 삭제되며 복구가 불가능합니다.',
    ),
    FaqItem(
      category: '계정',
      question: '맥마흔 점수는 무엇인가요?',
      answer: '맥마흔 점수는 대회 참가 결과에 따라 자동으로 계산되는 실력 지표입니다. '
          '대회에서 좋은 성적을 거둘수록 점수가 올라갑니다.',
    ),

    // 기타
    FaqItem(
      category: '기타',
      question: '앱에서 오류가 발생해요.',
      answer: '앱을 완전히 종료 후 다시 실행해보세요. 문제가 계속되면 앱 업데이트 여부를 확인하거나, '
          '1:1 문의를 통해 오류 상황을 알려주세요.',
    ),
    FaqItem(
      category: '기타',
      question: '알림이 오지 않아요.',
      answer: '휴대폰 설정에서 앱의 알림 권한이 허용되어 있는지 확인해주세요. '
          '또한 앱 내 설정에서 푸시 알림이 켜져 있는지도 확인해주세요.',
    ),
  ];

  List<FaqItem> get _filteredFaqItems {
    if (_selectedCategory == '전체') {
      return _faqItems;
    }
    return _faqItems.where((item) => item.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('자주 묻는 질문'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 카테고리 칩
          Container(
            color: AppColors.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedCategory = category),
                      backgroundColor: AppColors.surface,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // FAQ 목록
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredFaqItems.length,
              itemBuilder: (context, index) {
                return _FaqTile(item: _filteredFaqItems[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final FaqItem item;

  const _FaqTile({required this.item});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.item.category,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.item.question,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.item.answer,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FaqItem {
  final String category;
  final String question;
  final String answer;

  FaqItem({
    required this.category,
    required this.question,
    required this.answer,
  });
}
