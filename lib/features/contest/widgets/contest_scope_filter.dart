import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/contest.dart';

/// 대회 목록의 "언제 / 어디서" 필터 바.
///
/// 상태 필터(접수중·종료 등)는 [ContestFilterChips]가 맡고, 여기서는 기간과 지역만 다룬다.
/// 선택지를 고정 목록으로 두지 않고 **실제 대회가 있는 달·지역만** 건수와 함께 보여준다.
/// 빈 달을 골라놓고 "대회가 없네" 하는 헛걸음을 없애기 위함이다.
class ContestScopeFilter extends StatelessWidget {
  /// 필터 대상 전체 목록 (상태 필터까지 적용된 뒤의 목록을 넘긴다)
  final List<Contest> contests;

  /// 선택된 달. null이면 전체 기간
  final DateTime? selectedMonth;

  /// 선택된 시·도. null이면 전국
  final String? selectedProvince;

  final ValueChanged<DateTime?> onMonthChanged;
  final ValueChanged<String?> onProvinceChanged;

  const ContestScopeFilter({
    super.key,
    required this.contests,
    required this.selectedMonth,
    required this.selectedProvince,
    required this.onMonthChanged,
    required this.onProvinceChanged,
  });

  // ── 집계 ────────────────────────────────────────────────

  /// 대회가 실제로 열리는 달 → 건수. 이른 달부터.
  static Map<DateTime, int> monthCounts(List<Contest> contests) {
    final counts = <DateTime, int>{};
    for (final c in contests) {
      final d = c.startDate;
      if (d == null) continue;
      final key = DateTime(d.year, d.month);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final sorted = counts.keys.toList()..sort();
    return {for (final k in sorted) k: counts[k]!};
  }

  /// 대회가 실제로 열리는 시·도 → 건수. 많은 지역부터.
  static Map<String, int> provinceCounts(List<Contest> contests) {
    final counts = <String, int>{};
    for (final c in contests) {
      final p = c.province;
      if (p == null || p.isEmpty) continue;
      counts[p] = (counts[p] ?? 0) + 1;
    }
    final sorted = counts.keys.toList()
      ..sort((a, b) {
        final diff = counts[b]!.compareTo(counts[a]!);
        return diff != 0 ? diff : a.compareTo(b);
      });
    return {for (final k in sorted) k: counts[k]!};
  }

  /// 목록에 이 필터를 적용한다. 화면과 위젯이 같은 규칙을 쓰도록 여기에 둔다.
  static List<Contest> apply(
    List<Contest> contests, {
    DateTime? month,
    String? province,
  }) {
    return contests.where((c) {
      if (month != null) {
        final d = c.startDate;
        if (d == null) return false;
        if (d.year != month.year || d.month != month.month) return false;
      }
      if (province != null && c.province != province) return false;
      return true;
    }).toList();
  }

  /// '강원특별자치도' → '강원' (칩에 들어갈 짧은 이름)
  static String shortName(String province) {
    const map = {
      '서울특별시': '서울',
      '부산광역시': '부산',
      '대구광역시': '대구',
      '인천광역시': '인천',
      '광주광역시': '광주',
      '대전광역시': '대전',
      '울산광역시': '울산',
      '세종특별자치시': '세종',
      '경기도': '경기',
      '강원특별자치도': '강원',
      '충청북도': '충북',
      '충청남도': '충남',
      '전북특별자치도': '전북',
      '전라남도': '전남',
      '경상북도': '경북',
      '경상남도': '경남',
      '제주특별자치도': '제주',
    };
    return map[province] ?? province;
  }

  static String monthLabel(DateTime m) {
    final now = DateTime.now();
    return m.year == now.year ? '${m.month}월' : '${m.year}년 ${m.month}월';
  }

  // ── 렌더 ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _DropButton(
              icon: Icons.calendar_today_outlined,
              label: selectedMonth == null ? '전체 기간' : monthLabel(selectedMonth!),
              active: selectedMonth != null,
              onTap: () => _openMonthSheet(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DropButton(
              icon: Icons.place_outlined,
              label: selectedProvince == null ? '전국' : shortName(selectedProvince!),
              active: selectedProvince != null,
              onTap: () => _openProvinceSheet(context),
            ),
          ),
        ],
      ),
    );
  }

  void _openMonthSheet(BuildContext context) {
    final counts = monthCounts(contests);
    // 대회 있는 월만 보여주면 중간 월(예: 12월)이 빠져 이상해 보인다.
    // → 올해 1~12월은 전부, 대회가 있는 다른 연도 월도 포함해 모두 선택 가능하게.
    final now = DateTime.now();
    final months = <DateTime>{
      for (int mo = 1; mo <= 12; mo++) DateTime(now.year, mo),
      ...counts.keys,
    }.toList()
      ..sort();
    _openSheet(
      context,
      title: '언제 열리는 대회를 볼까요?',
      allLabel: '전체 기간',
      allCount: contests.length,
      isAllSelected: selectedMonth == null,
      onAll: () => onMonthChanged(null),
      items: [
        for (final key in months)
          _SheetItem(
            label: monthLabel(key),
            count: counts[key] ?? 0,
            selected: selectedMonth != null &&
                selectedMonth!.year == key.year &&
                selectedMonth!.month == key.month,
            onTap: () => onMonthChanged(key),
          ),
      ],
    );
  }

  void _openProvinceSheet(BuildContext context) {
    final counts = provinceCounts(contests);
    _openSheet(
      context,
      title: '어느 지역 대회를 볼까요?',
      allLabel: '전국',
      allCount: contests.length,
      isAllSelected: selectedProvince == null,
      onAll: () => onProvinceChanged(null),
      items: [
        for (final e in counts.entries)
          _SheetItem(
            label: e.key,
            count: e.value,
            selected: selectedProvince == e.key,
            onTap: () => onProvinceChanged(e.key),
          ),
      ],
    );
  }

  void _openSheet(
    BuildContext context, {
    required String title,
    required String allLabel,
    required int allCount,
    required bool isAllSelected,
    required VoidCallback onAll,
    required List<_SheetItem> items,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  _row(
                    sheetContext,
                    label: allLabel,
                    count: allCount,
                    selected: isAllSelected,
                    onTap: onAll,
                  ),
                  for (final item in items)
                    _row(
                      sheetContext,
                      label: item.label,
                      count: item.count,
                      selected: item.selected,
                      onTap: item.onTap,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext sheetContext, {
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        onTap();
        Navigator.pop(sheetContext);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 19,
              color: selected ? AppColors.primary : AppColors.divider,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetItem {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _SheetItem({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
}

/// 필터 바에 놓이는 드롭다운 버튼. 선택되면 강조색으로 채워 현재 조건이 한눈에 보이게 한다.
class _DropButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DropButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: active ? Colors.white : AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
