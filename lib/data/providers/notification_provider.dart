import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/user_notification.dart';

/// 안읽은 알림 수 프로바이더 (홈 화면 뱃지용)
final unreadCountProvider = FutureProvider<int>((ref) async {
  try {
    final response = await ApiClient.instance.get('/mobile/users/me/notifications/unread-count');
    final data = response.data;
    if (data is Map && data['success'] == true) {
      return (data['unreadCount'] as num?)?.toInt() ?? 0;
    }
    return 0;
  } catch (e) {
    debugPrint('[알림] 안읽은 수 조회 실패: $e');
    return 0;
  }
});

/// 알림 목록 상태
class NotificationListState {
  final List<UserNotification> notifications;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;

  const NotificationListState({
    this.notifications = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  NotificationListState copyWith({
    List<UserNotification>? notifications,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return NotificationListState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }
}

/// 알림 목록 Notifier
class NotificationListNotifier extends StateNotifier<NotificationListState> {
  NotificationListNotifier() : super(const NotificationListState());

  /// 첫 페이지 로드
  Future<void> loadNotifications() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await ApiClient.instance.get(
        '/mobile/users/me/notifications',
        queryParameters: {'page': 0, 'size': 20},
      );
      final data = response.data;
      if (data is Map && data['success'] == true) {
        final list = (data['notifications'] as List)
            .map((json) => UserNotification.fromJson(json))
            .toList();
        final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;

        state = state.copyWith(
          notifications: list,
          isLoading: false,
          currentPage: 0,
          hasMore: totalPages > 1,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 다음 페이지 로드
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);

    try {
      final nextPage = state.currentPage + 1;
      final response = await ApiClient.instance.get(
        '/mobile/users/me/notifications',
        queryParameters: {'page': nextPage, 'size': 20},
      );
      final data = response.data;
      if (data is Map && data['success'] == true) {
        final list = (data['notifications'] as List)
            .map((json) => UserNotification.fromJson(json))
            .toList();
        final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;

        state = state.copyWith(
          notifications: [...state.notifications, ...list],
          isLoading: false,
          currentPage: nextPage,
          hasMore: nextPage + 1 < totalPages,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 개별 읽음 처리
  Future<void> markAsRead(int notificationId) async {
    try {
      await ApiClient.instance.put('/mobile/users/me/notifications/$notificationId/read');
      state = state.copyWith(
        notifications: state.notifications.map((n) {
          if (n.id == notificationId) return n.copyWith(isRead: true);
          return n;
        }).toList(),
      );
    } catch (e) {
      debugPrint('[알림] 읽음 처리 실패: $e');
    }
  }

  /// 전체 읽음 처리
  Future<void> markAllAsRead() async {
    try {
      await ApiClient.instance.put('/mobile/users/me/notifications/read-all');
      state = state.copyWith(
        notifications: state.notifications.map((n) => n.copyWith(isRead: true)).toList(),
      );
    } catch (e) {
      debugPrint('[알림] 전체 읽음 처리 실패: $e');
    }
  }
}

/// 알림 목록 프로바이더
final notificationListProvider =
    StateNotifierProvider<NotificationListNotifier, NotificationListState>((ref) {
  return NotificationListNotifier();
});
