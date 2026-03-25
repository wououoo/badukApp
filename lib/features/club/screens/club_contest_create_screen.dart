import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/club_contest_service.dart';

/// 클럽 대회 생성 화면 (다중 부문 지원)
class ClubContestCreateScreen extends StatefulWidget {
  final int clubId;

  const ClubContestCreateScreen({super.key, required this.clubId});

  @override
  State<ClubContestCreateScreen> createState() => _ClubContestCreateScreenState();
}

class _ClubContestCreateScreenState extends State<ClubContestCreateScreen> {
  final ClubContestService _service = ClubContestService();
  final _nameController = TextEditingController();
  final _eloKController = TextEditingController(text: '32');
  final _mcmKController = TextEditingController(text: '50');
  DateTime _selectedDate = DateTime.now();
  bool _isRated = true;
  bool _isCreating = false;

  // 부문 목록: {name, gameType}
  final List<Map<String, String>> _sections = [];

  static const List<String> _gameTypes = ['스위스리그', '풀리그', '맥마흔', '더블엘리미네이션', '토너먼트', '단체전 스위스리그', '단체전 풀리그'];

  bool get _hasMcMahon => _sections.any((s) => s['gameType'] == '맥마흔');

  @override
  void dispose() {
    _nameController.dispose();
    _eloKController.dispose();
    _mcmKController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.clubPrimary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showAddSectionDialog() {
    final sectionNameController = TextEditingController();
    String selectedType = _gameTypes.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('부문 추가'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: sectionNameController,
                    decoration: InputDecoration(
                      labelText: '부문 이름',
                      hintText: '예: 초급반, 고급반',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    maxLength: 30,
                  ),
                  const SizedBox(height: 12),
                  const Text('대회 유형', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  ...List.generate(_gameTypes.length, (index) {
                    final type = _gameTypes[index];
                    return RadioListTile<String>(
                      title: Text(type),
                      value: type,
                      groupValue: selectedType,
                      activeColor: AppColors.clubPrimary,
                      onChanged: (v) => setDialogState(() => selectedType = v!),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
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
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final name = sectionNameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('부문 이름을 입력해주세요.')),
                        );
                        return;
                      }
                      setState(() {
                        _sections.add({'name': name, 'gameType': selectedType});
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.clubPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('추가'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createContest() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('대회 이름을 입력해주세요.')),
      );
      return;
    }

    if (_sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 1개 부문을 추가해주세요.')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final dateStr = '${_selectedDate.year}-'
          '${_selectedDate.month.toString().padLeft(2, '0')}-'
          '${_selectedDate.day.toString().padLeft(2, '0')}';

      // 1. Contest 생성
      int? eloK = int.tryParse(_eloKController.text.trim());
      int? mcmK = int.tryParse(_mcmKController.text.trim());
      final result = await _service.createContest(
        widget.clubId, name, dateStr, _isRated,
        eloKFactor: _isRated ? eloK : null,
        mcmahonKFactor: _isRated && _hasMcMahon ? mcmK : null,
      );

      if (!mounted) return;

      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '생성 실패')),
        );
        return;
      }

      final contestId = (result['contestId'] as num).toInt();

      // 2. 각 부문 추가
      for (final section in _sections) {
        await _service.addSection(
          widget.clubId, contestId,
          section['name']!, section['gameType']!,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('대회가 생성되었습니다.')),
      );
      context.pushReplacement(
        '/clubs/${widget.clubId}/contests/$contestId/manage',
      );
    } catch (e) {
      debugPrint('[Error] 대회 생성 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('대회 생성'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '대회 이름',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: '예: 2월 정기 대회',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.clubPrimary),
                ),
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 20),
            Text(
              '대회 날짜',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Text(
                      '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일',
                      style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, size: 20, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 레이팅 반영 토글
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: SwitchListTile(
                title: const Text('레이팅 반영',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _isRated ? 'Elo 레이팅이 변동됩니다' : '친선 대회 (레이팅 변동 없음)',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                value: _isRated,
                onChanged: (v) => setState(() => _isRated = v),
                activeColor: AppColors.clubPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            // K-factor 설정 (레이팅 반영 시만 표시)
            if (_isRated) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('K-factor 설정',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _eloKController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Elo K-factor',
                              helperText: '기본값 32',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_hasMcMahon) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _mcmKController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: '맥마흔 K-factor',
                                helperText: '기본값 50',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // 부문 섹션
            Row(
              children: [
                Text(
                  '부문',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showAddSectionDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('부문 추가'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.clubPrimary),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_sections.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    Icon(Icons.category_outlined, size: 32, color: AppColors.textTertiary),
                    const SizedBox(height: 8),
                    Text(
                      '부문을 추가해주세요',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    Text(
                      '초급반, 중급반, 고급반 등으로 나눌 수 있습니다',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_sections.length, (index) {
                final section = _sections[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: section['gameType'] == '풀리그'
                                ? Colors.orange.withOpacity(0.1)
                                : AppColors.clubPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            section['gameType']!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: section['gameType'] == '풀리그'
                                  ? Colors.orange
                                  : AppColors.clubPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            section['name']!,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _sections.removeAt(index)),
                          icon: Icon(Icons.close, size: 18, color: AppColors.textTertiary),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32),
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.clubPrimary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.clubPrimary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '각 부문은 독립적으로 대진/결과/순위를 관리합니다.\n대회 생성 후 참가자를 추가하고 대진표를 만들어보세요.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createContest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.clubPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isCreating
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('대회 생성', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
