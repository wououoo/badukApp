import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/club_contest_service.dart';

/// 대회 이름 수정 / 부문 추가·수정·삭제 다이얼로그 모음
class ContestSectionDialogs {
  static final ClubContestService _service = ClubContestService();

  static void showEditContestDialog(
    BuildContext context,
    int clubId,
    int contestId,
    String currentName,
    VoidCallback onReload,
  ) {
    final nameController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('대회 수정'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: '대회 이름',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _service.updateContest(clubId, contestId, name, '');
                onReload();
              } catch (e) {
                debugPrint('[Error] 대회 수정 오류: $e');
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.clubPrimary, foregroundColor: Colors.white),
            child: const Text('수정'),
          ),
        ],
      ),
    );
  }

  static void showAddSectionDialog(
    BuildContext context,
    int clubId,
    int contestId,
    VoidCallback onReload,
  ) {
    final sectionNameController = TextEditingController();
    String selectedType = '스위스리그';
    int selectedTeamSize = 5;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isTeam = selectedType.contains('단체전');
          return AlertDialog(
            title: const Text('부문 추가'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: sectionNameController,
                      decoration: InputDecoration(
                        labelText: '부문 이름',
                        hintText: '예: 초급반',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      maxLength: 30,
                    ),
                    const SizedBox(height: 8),
                    ...['스위스리그', '풀리그', '맥마흔', '더블엘리미네이션', '토너먼트', '단체전 스위스리그', '단체전 풀리그'].map((type) => RadioListTile<String>(
                      title: Text(type, style: const TextStyle(fontSize: 14)),
                      value: type,
                      groupValue: selectedType,
                      activeColor: AppColors.clubPrimary,
                      onChanged: (v) => setDialogState(() => selectedType = v!),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    )),
                    if (isTeam) ...[
                      const Divider(),
                      const Text('팀 인원 수 (N장제)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [3, 5, 7].map((size) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text('${size}장제'),
                            selected: selectedTeamSize == size,
                            selectedColor: AppColors.clubPrimary,
                            labelStyle: TextStyle(fontSize: 13, color: selectedTeamSize == size ? Colors.white : AppColors.textPrimary),
                            onSelected: (v) { if (v) setDialogState(() => selectedTeamSize = size); },
                          ),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = sectionNameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('부문 이름을 입력해주세요.')));
                          return;
                        }
                        Navigator.pop(ctx);
                        try {
                          await _service.addSection(clubId, contestId, name, selectedType, teamSize: isTeam ? selectedTeamSize : null);
                          onReload();
                        } catch (e) {
                          debugPrint('[Error] 부문 추가 오류: $e');
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.clubPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: const Text('추가'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static void showEditSectionDialog(
    BuildContext context,
    int clubId,
    int contestId,
    int sortId,
    Map<String, dynamic> currentSection,
    VoidCallback onReload,
  ) {
    final sectionNameController = TextEditingController(text: currentSection['name']?.toString() ?? '');
    String selectedType = currentSection['type']?.toString() ?? '스위스리그';
    int selectedTeamSize = (currentSection['teamSize'] is num) ? (currentSection['teamSize'] as num).toInt() : 5;
    final gameTypes = ['스위스리그', '풀리그', '맥마흔', '더블엘리미네이션', '토너먼트', '단체전 스위스리그', '단체전 풀리그'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isTeam = selectedType.contains('단체전');
          return AlertDialog(
            title: const Text('부문 수정'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: sectionNameController,
                    decoration: InputDecoration(
                      labelText: '부문 이름',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    maxLength: 30,
                  ),
                  const SizedBox(height: 8),
                  ...gameTypes.map((type) => RadioListTile<String>(
                    title: Text(type, style: const TextStyle(fontSize: 14)),
                    value: type,
                    groupValue: selectedType,
                    activeColor: AppColors.clubPrimary,
                    onChanged: (v) => setDialogState(() => selectedType = v!),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  )),
                  if (isTeam) ...[
                    const Divider(),
                    const Text('팀 인원 수 (N장제)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [3, 5, 7].map((size) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text('${size}장제'),
                          selected: selectedTeamSize == size,
                          selectedColor: AppColors.clubPrimary,
                          labelStyle: TextStyle(fontSize: 13, color: selectedTeamSize == size ? Colors.white : AppColors.textPrimary),
                          onSelected: (v) { if (v) setDialogState(() => selectedTeamSize = size); },
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = sectionNameController.text.trim();
                        if (name.isEmpty) return;
                        Navigator.pop(ctx);
                        try {
                          await _service.updateSection(clubId, contestId, sortId, name, selectedType, teamSize: isTeam ? selectedTeamSize : null);
                          onReload();
                        } catch (e) {
                          debugPrint('[Error] 부문 수정 오류: $e');
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.clubPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: const Text('수정'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> deleteCurrentSection(
    BuildContext context,
    int clubId,
    int contestId,
    int sortId,
    String sectionName,
    VoidCallback onReload,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('부문 삭제'),
        content: Text('"$sectionName" 부문을 삭제하시겠습니까?\n참가자, 대진 결과가 모두 삭제됩니다.'),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('삭제', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.deleteSection(clubId, contestId, sortId);
      onReload();
    } catch (e) {
      debugPrint('[Error] 부문 삭제 오류: $e');
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
    }
  }
}
