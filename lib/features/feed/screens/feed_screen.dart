import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_notification.dart';
import '../../../data/providers/feed_provider.dart';
import '../../../core/widgets/shimmer_loading.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(feedListProvider.notifier).loadFeed();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(feedListProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('피드'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(feedListProvider.notifier).loadFeed(),
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(FeedListState state) {
    if (state.isLoading && state.items.isEmpty) {
      return SkeletonBuilders.notificationList();
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text('피드를 불러올 수 없습니다', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.read(feedListProvider.notifier).loadFeed(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Icon(Icons.dynamic_feed_outlined, size: 64, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Text('아직 피드가 없습니다',
                    style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text('클럽에 가입하면 활동 소식이 여기에 표시됩니다',
                    style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return _FeedItem(
          notification: state.items[index],
          onTap: () => _handleTap(state.items[index]),
        );
      },
    );
  }

  void _handleTap(UserNotification notification) {
    final data = notification.data;
    if (data == null) return;

    final clubId = data['clubId'];
    final contestId = data['contestId'];

    if (clubId != null) {
      context.push('/clubs/$clubId');
    } else if (contestId != null) {
      context.push('/contests/$contestId');
    }
  }
}

/// 피드 타입별 메타 정보
class _FeedTypeMeta {
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _FeedTypeMeta(this.icon, this.color, this.bgColor);
}

_FeedTypeMeta _getTypeMeta(String? type) {
  switch (type) {
    case 'team_win':
      return _FeedTypeMeta(Icons.emoji_events, const Color(0xFFF59E0B), const Color(0xFFFEF3C7));
    case 'club_contest_result':
      return _FeedTypeMeta(Icons.leaderboard, const Color(0xFF10B981), const Color(0xFFDCFCE7));
    case 'club_contest_round':
      return _FeedTypeMeta(Icons.grid_view, const Color(0xFF3B82F6), const Color(0xFFDBEAFE));
    case 'club_contest_finished':
      return _FeedTypeMeta(Icons.flag, const Color(0xFF8B5CF6), const Color(0xFFEDE9FE));
    case 'club_contest':
      return _FeedTypeMeta(Icons.emoji_events_outlined, AppColors.clubPrimary, AppColors.clubBgTint);
    case 'club_post':
      return _FeedTypeMeta(Icons.article, AppColors.clubPrimary, AppColors.clubBgTint);
    case 'club_schedule':
      return _FeedTypeMeta(Icons.event, const Color(0xFFF59E0B), const Color(0xFFFEF3C7));
    default:
      return _FeedTypeMeta(Icons.notifications_outlined, AppColors.textSecondary, const Color(0xFFF1F5F9));
  }
}

class _FeedItem extends StatelessWidget {
  final UserNotification notification;
  final VoidCallback onTap;

  const _FeedItem({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = _getTypeMeta(notification.type);
    final isHighlight = notification.type == 'team_win';

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isHighlight ? const Color(0xFFFFFBEB) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: meta.bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(meta.icon, color: meta.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(notification.createdAt),
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }
}
