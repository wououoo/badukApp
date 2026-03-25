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

  /// 기본 메뉴 아이템 10개
  static List<IconMenuItem> defaultItems() {
    return const [
      IconMenuItem(
        icon: Icons.emoji_events_outlined,
        label: '대회',
        color: Color(0xFFD4603C),
        routePath: '/contests',
      ),
      IconMenuItem(
        icon: Icons.history,
        label: '기록조회',
        color: Color(0xFF3B82F6),
        routePath: '/history',
      ),
      IconMenuItem(
        icon: Icons.how_to_reg,
        label: '신청내역',
        color: Color(0xFF7C3AED),
        routePath: '/profile/registrations',
      ),
      IconMenuItem(
        icon: Icons.qr_code_scanner,
        label: 'QR체크인',
        color: Color(0xFF10B981),
        routePath: '/qr/scan',
      ),
      IconMenuItem(
        icon: Icons.groups_outlined,
        label: '클럽',
        color: Color(0xFFF59E0B),
        routePath: '/clubs-tab',
      ),
      IconMenuItem(
        icon: Icons.leaderboard_outlined,
        label: '맥마흔점수',
        color: Color(0xFFEC4899),
        routePath: '/profile',
      ),
      IconMenuItem(
        icon: Icons.favorite_outline,
        label: '즐겨찾기',
        color: Color(0xFFEF4444),
        routePath: '/favorites',
      ),
      IconMenuItem(
        icon: Icons.notifications_outlined,
        label: '알림',
        color: Color(0xFF6366F1),
        routePath: '/notifications',
      ),
      IconMenuItem(
        icon: Icons.settings_outlined,
        label: '설정',
        color: Color(0xFF64748B),
        routePath: '/settings',
      ),
      IconMenuItem(
        icon: Icons.dynamic_feed_outlined,
        label: '피드',
        color: Color(0xFF8B5CF6),
        routePath: '/feed',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.count(
        crossAxisCount: 5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 4,
        childAspectRatio: 0.75,
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
              color: item.color.withOpacity(0.12),
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
