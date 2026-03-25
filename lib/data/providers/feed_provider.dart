import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/user_notification.dart';

/// 피드 타입 필터 (소셜 피드에 표시할 알림 타입)
const feedTypes = [
  'club_contest',
  'club_contest_round',
  'club_contest_result',
  'club_contest_finished',
  'team_win',
  'club_post',
  'club_schedule',
];

/// 피드 목록 상태
class FeedListState {
  final List<UserNotification> items;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;

  const FeedListState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  FeedListState copyWith({
    List<UserNotification>? items,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return FeedListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }
}

/// 피드 목록 Notifier
class FeedListNotifier extends StateNotifier<FeedListState> {
  FeedListNotifier() : super(const FeedListState());

  /// 첫 페이지 로드
  Future<void> loadFeed() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await ApiClient.instance.get(
        '/mobile/users/me/notifications',
        queryParameters: {
          'page': 0,
          'size': 20,
          'types': feedTypes.join(','),
        },
      );
      final data = response.data;
      if (data is Map && data['success'] == true) {
        final list = (data['notifications'] as List)
            .map((json) => UserNotification.fromJson(json))
            .toList();
        final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;

        state = state.copyWith(
          items: list,
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
        queryParameters: {
          'page': nextPage,
          'size': 20,
          'types': feedTypes.join(','),
        },
      );
      final data = response.data;
      if (data is Map && data['success'] == true) {
        final list = (data['notifications'] as List)
            .map((json) => UserNotification.fromJson(json))
            .toList();
        final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;

        state = state.copyWith(
          items: [...state.items, ...list],
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
}

/// 피드 목록 프로바이더
final feedListProvider =
    StateNotifierProvider<FeedListNotifier, FeedListState>((ref) {
  return FeedListNotifier();
});
