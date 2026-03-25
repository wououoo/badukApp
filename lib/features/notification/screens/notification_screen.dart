import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_notification.dart';
import '../../../data/providers/mobile_qr_provider.dart';
import '../../../data/providers/notification_provider.dart';
import '../../../data/providers/support_provider.dart';
import '../../../core/widgets/shimmer_loading.dart';

/// 알림 화면
/// - 받은 알림 (DB 기반 푸시 알림 목록)
/// - 중요 공지사항
/// - 내 대회 알림 (참가 중인 대회 정보)
class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 알림 목록 로드
    Future.microtask(() {
      ref.read(notificationListProvider.notifier).loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifState = ref.watch(notificationListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('알림'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (notifState.notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () async {
                await ref.read(notificationListProvider.notifier).markAllAsRead();
                ref.invalidate(unreadCountProvider);
              },
              child: const Text(
                '전체 읽음',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.accentLight,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(importantNoticesProvider);
          ref.invalidate(unreadCountProvider);
          await ref.read(notificationListProvider.notifier).loadNotifications();
          await ref.read(mobileQRProvider.notifier).refresh();
        },
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 받은 알림 섹션
            _buildSectionHeader(
              context,
              icon: Icons.notifications,
              title: '받은 알림',
              onMoreTap: () => context.push('/notifications/received'),
            ),
            const SizedBox(height: 12),
            _buildReceivedNotifications(context, ref),
            const SizedBox(height: 24),

            // 중요 공지사항 섹션
            _buildSectionHeader(
              context,
              icon: Icons.campaign,
              title: '중요 공지',
              onMoreTap: () => context.push('/support/notices'),
            ),
            const SizedBox(height: 12),
            _buildImportantNotices(context, ref),
            const SizedBox(height: 24),

            // 내 대회 알림 섹션
            _buildSectionHeader(
              context,
              icon: Icons.sports_esports,
              title: '내 대회 알림',
              onMoreTap: () => context.push('/qr/contests'),
            ),
            const SizedBox(height: 12),
            _buildMyContestNotifications(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onMoreTap,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        if (onMoreTap != null)
          TextButton(
            onPressed: onMoreTap,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(40, 30),
            ),
            child: Text(
              '더보기',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  // ========== 받은 알림 섹션 ==========

  Widget _buildReceivedNotifications(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationListProvider);

    if (state.isLoading && state.notifications.isEmpty) {
      return SkeletonBuilders.notificationList(count: 3);
    }

    if (state.error != null && state.notifications.isEmpty) {
      return _buildErrorCard('알림을 불러올 수 없습니다');
    }

    if (state.notifications.isEmpty) {
      return _buildEmptyCard('받은 알림이 없습니다');
    }

    // 최대 5개만 표시
    final displayList = state.notifications.take(5).toList();

    return Column(
      children: displayList.map((notification) {
        return _buildReceivedNotificationItem(context, ref, notification);
      }).toList(),
    );
  }

  Widget _buildReceivedNotificationItem(
    BuildContext context,
    WidgetRef ref,
    UserNotification notification,
  ) {
    final timeAgo = _formatTimeAgo(notification.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: notification.isRead ? AppColors.border : AppColors.accentLight.withOpacity(0.3),
        ),
      ),
      color: notification.isRead ? AppColors.surface : AppColors.accentLight.withOpacity(0.03),
      child: InkWell(
        onTap: () {
          if (!notification.isRead) {
            ref.read(notificationListProvider.notifier).markAsRead(notification.id);
            ref.invalidate(unreadCountProvider);
          }
          // 딥링크
          final data = notification.data;
          if (data != null) {
            final homepageId = data['homepageId'];
            final clubId = data['clubId'];
            if (homepageId != null) {
              context.push('/contest/$homepageId');
            } else if (clubId != null) {
              context.push('/clubs/$clubId');
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 안읽음 표시 점
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
              // 내용
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
                              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
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
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
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

  /// 시간 차이를 읽기 쉬운 문자열로 변환
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';

    return DateFormat('MM.dd').format(dateTime);
  }

  // ========== 중요 공지사항 섹션 ==========

  Widget _buildImportantNotices(BuildContext context, WidgetRef ref) {
    final noticesAsync = ref.watch(importantNoticesProvider);

    return noticesAsync.when(
      loading: () => _buildLoadingCard(),
      error: (err, stack) => _buildErrorCard('공지사항을 불러올 수 없습니다'),
      data: (notices) {
        if (notices.isEmpty) {
          return _buildEmptyCard('새로운 공지사항이 없습니다');
        }

        return Column(
          children: notices.take(3).map((notice) {
            return _buildNoticeItem(
              context,
              title: notice.title,
              date: notice.createdAt,
              isImportant: notice.isImportant,
              onTap: () => context.push('/support/notices/${notice.id}'),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildNoticeItem(
    BuildContext context, {
    required String title,
    required DateTime? date,
    bool isImportant = false,
    VoidCallback? onTap,
  }) {
    final dateFormat = DateFormat('MM.dd');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isImportant
              ? AppColors.error.withOpacity(0.3)
              : AppColors.border,
        ),
      ),
      color: isImportant
          ? AppColors.error.withOpacity(0.05)
          : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (isImportant) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '중요',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                date != null ? dateFormat.format(date) : '',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 내 대회 알림 섹션 ==========

  Widget _buildMyContestNotifications(BuildContext context, WidgetRef ref) {
    final qrState = ref.watch(mobileQRProvider);
    final contests = qrState.contests;

    if (qrState.isLoading && contests.isEmpty) {
      return _buildLoadingCard();
    }

    if (contests.isEmpty) {
      return _buildEmptyCard('참가 중인 대회가 없습니다');
    }

    return Column(
      children: contests.take(5).map((contest) {
        return _buildContestNotificationItem(context, contest);
      }).toList(),
    );
  }

  Widget _buildContestNotificationItem(BuildContext context, dynamic contest) {
    String notificationType;
    IconData notificationIcon;
    Color notificationColor;

    if (contest.currentRound > 0 && contest.opponent != null) {
      notificationType = '대국 진행 중';
      notificationIcon = Icons.sports_esports;
      notificationColor = AppColors.statusLive;
    } else if (!contest.checkedIn) {
      notificationType = '체크인 필요';
      notificationIcon = Icons.how_to_reg;
      notificationColor = AppColors.warning;
    } else {
      notificationType = '대기 중';
      notificationIcon = Icons.schedule;
      notificationColor = AppColors.textSecondary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      child: InkWell(
        onTap: () => context.push('/qr/contest/${contest.contestId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: notificationColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      notificationIcon,
                      size: 18,
                      color: notificationColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notificationType,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: notificationColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          contest.contestName ?? '대회',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              if (contest.opponent != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildInfoItem('라운드', '${contest.currentRound}R', flex: 1),
                      Container(width: 1, height: 24, color: AppColors.border),
                      _buildInfoItem('상대', contest.opponent ?? '-', flex: 2),
                      if (contest.matchNumber != null) ...[
                        Container(width: 1, height: 24, color: AppColors.border),
                        _buildInfoItem('테이블', '${contest.matchNumber}', flex: 1),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ========== 공통 위젯 ==========

  Widget _buildLoadingCard() {
    return const Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.error.withOpacity(0.3)),
      ),
      color: AppColors.error.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.error,
            ),
          ),
        ),
      ),
    );
  }
}
