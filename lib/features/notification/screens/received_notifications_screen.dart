import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_notification.dart';
import '../../../data/providers/notification_provider.dart';

/// 받은 알림 전체 목록 화면 (페이징)
class ReceivedNotificationsScreen extends ConsumerStatefulWidget {
  const ReceivedNotificationsScreen({super.key});

  @override
  ConsumerState<ReceivedNotificationsScreen> createState() =>
      _ReceivedNotificationsScreenState();
}

class _ReceivedNotificationsScreenState
    extends ConsumerState<ReceivedNotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(notificationListProvider.notifier).loadNotifications();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('받은 알림'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (state.notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () async {
                await ref
                    .read(notificationListProvider.notifier)
                    .markAllAsRead();
                ref.invalidate(unreadCountProvider);
              },
              child: const Text(
                '전체 읽음',
                style: TextStyle(fontSize: 13, color: AppColors.accentLight),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(notificationListProvider.notifier).loadNotifications();
          ref.invalidate(unreadCountProvider);
        },
        color: AppColors.primary,
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(NotificationListState state) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.error != null && state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text('알림을 불러올 수 없습니다',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  ref.read(notificationListProvider.notifier).loadNotifications(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 48, color: AppColors.textTertiary),
            SizedBox(height: 12),
            Text('받은 알림이 없습니다',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: state.notifications.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.notifications.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          );
        }
        return _buildNotificationItem(state.notifications[index]);
      },
    );
  }

  Widget _buildNotificationItem(UserNotification notification) {
    final timeAgo = _formatTimeAgo(notification.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: notification.isRead
              ? AppColors.border
              : AppColors.accentLight.withOpacity(0.3),
        ),
      ),
      color: notification.isRead
          ? AppColors.surface
          : AppColors.accentLight.withOpacity(0.03),
      child: InkWell(
        onTap: () {
          if (!notification.isRead) {
            ref.read(notificationListProvider.notifier).markAsRead(notification.id);
            ref.invalidate(unreadCountProvider);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!notification.isRead)
                Container(
                  margin: const EdgeInsets.only(top: 4, right: 10),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accentLight,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgo,
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';

    return DateFormat('MM.dd').format(dateTime);
  }
}
