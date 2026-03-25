import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 수평 탭 메뉴 아이템
class TabMenuItem {
  final String label;
  final String? routePath;
  final bool isShellRoute; // ShellRoute 탭이면 go(), 아니면 push()

  const TabMenuItem({
    required this.label,
    this.routePath,
    this.isShellRoute = false,
  });
}

/// 수평 스크롤 탭 메뉴
class HorizontalTabMenu extends StatelessWidget {
  final List<TabMenuItem> tabs;
  final int selectedIndex;
  final ValueChanged<int>? onTabSelected;

  const HorizontalTabMenu({
    super.key,
    required this.tabs,
    this.selectedIndex = 0,
    this.onTabSelected,
  });

  /// 기본 탭 목록
  static List<TabMenuItem> defaultTabs() {
    return const [
      TabMenuItem(label: '홈', routePath: '/home', isShellRoute: true),
      TabMenuItem(label: '대회', routePath: '/contests', isShellRoute: true),
      TabMenuItem(label: '클럽', routePath: '/clubs-tab', isShellRoute: true),
      TabMenuItem(label: '내정보', routePath: '/profile', isShellRoute: true),
      TabMenuItem(label: '기록', routePath: '/history'),
      TabMenuItem(label: '더보기', routePath: '/support'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = index == selectedIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onTabSelected?.call(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? null
                        : Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    tabs[index].label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
