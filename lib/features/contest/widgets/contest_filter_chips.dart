import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 대회 필터 칩 위젯
class ContestFilterChips extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const ContestFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  static const filters = [
    {'key': 'ALL', 'label': '전체'},
    {'key': 'NEARBY', 'label': '내 근처'},
    {'key': 'OPEN', 'label': '접수중'},
    {'key': 'ENDED', 'label': '접수종료'},
    {'key': 'LIVE', 'label': '진행중'},
    {'key': 'CLOSED', 'label': '종료됨'},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter['key'];

          return _FilterChip(
            label: filter['label']!,
            isSelected: isSelected,
            onTap: () => onFilterChanged(filter['key']!),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
