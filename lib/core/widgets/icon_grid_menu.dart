import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 아이콘 그리드 메뉴 아이템
class IconMenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final String? routePath;
  final VoidCallback? onTap;

  const IconMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    this.routePath,
    this.onTap,
  });
}

/// 아이콘 그리드 메뉴 (5열 2행 = 10개)
class IconGridMenu extends StatelessWidget {
  final List<IconMenuItem> items;
  final ValueChanged<String?>? onItemTap;

  const IconGridMenu({
    super.key,
    required this.items,
    this.onItemTap,
  });

  /// 홈 빠른 실행 — 하단 탭·앱바에서 못 가는 것만 남긴다.
  ///
  /// 대회·클럽은 하단 탭, 설정은 내정보, 알림은 앱바 종 아이콘에 이미 있어서 뺐다.
  /// 같은 곳으로 가는 길이 여럿이면 무엇을 눌러야 할지 판단할 일만 늘어난다.
  /// QR 스캔은 대회장 포스터를 찍는 용도라 앱에 이미 로그인한 사람에겐 쓸 일이 드물어 뺐다.
  /// (즐겨찾기는 /favorites 라우트 자체가 없어 눌러도 이동하지 않던 항목이라 함께 제외)
  static List<IconMenuItem> defaultItems() {
    return const [
      IconMenuItem(
        icon: Icons.how_to_reg,
        label: '신청내역',
        color: Color(0xFF10B981),
        routePath: '/profile/registrations',
      ),
      IconMenuItem(
        icon: Icons.history,
        label: '기록조회',
        color: Color(0xFF3B82F6),
        routePath: '/history',
      ),
      IconMenuItem(
        icon: Icons.calendar_month_outlined,
        label: '대회일정',
        color: Color(0xFF8B5CF6),
        routePath: '/calendar',
      ),
      IconMenuItem(
        icon: Icons.dynamic_feed_outlined,
        label: '피드',
        color: Color(0xFFF59E0B),
        routePath: '/feed',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 4,
        childAspectRatio: 0.95,
        children: items.map((item) => _buildItem(item)).toList(),
      ),
    );
  }

  Widget _buildItem(IconMenuItem item) {
    return GestureDetector(
      onTap: () {
        if (item.onTap != null) {
          item.onTap!();
        } else {
          onItemTap?.call(item.routePath);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              color: item.color,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
