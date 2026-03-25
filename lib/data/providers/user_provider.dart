import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../models/user_stats.dart';
import '../models/contest_history.dart';
import '../models/mcmahon_history.dart';
import '../services/user_service.dart';
import '../services/notification_service_stub.dart'
    if (dart.library.io) '../services/notification_service.dart';

/// UserService 프로바이더
final userServiceProvider = Provider<UserService>((ref) => UserService());

/// 내 프로필 프로바이더
final myProfileProvider = FutureProvider<User>((ref) async {
  final service = ref.watch(userServiceProvider);
  return service.getMyProfile();
});

/// 사용자 프로필 프로바이더 (Family)
final userProfileProvider =
    FutureProvider.family<User, int>((ref, userId) async {
  final service = ref.watch(userServiceProvider);
  return service.getUserProfile(userId);
});

/// 내 통계 프로바이더
final myStatsProvider = FutureProvider<UserStats>((ref) async {
  final service = ref.watch(userServiceProvider);
  return service.getMyStats();
});

/// 대회 참가 이력 상태
class ContestHistoryState {
  final List<ContestHistory> history;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;

  const ContestHistoryState({
    this.history = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  ContestHistoryState copyWith({
    List<ContestHistory>? history,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return ContestHistoryState(
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }
}

/// 대회 참가 이력 Notifier
class ContestHistoryNotifier extends StateNotifier<ContestHistoryState> {
  final UserService _userService;

  ContestHistoryNotifier(this._userService)
      : super(const ContestHistoryState());

  /// 이력 로드
  Future<void> loadHistory({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    if (refresh) {
      state = const ContestHistoryState(isLoading: true);
    } else {
      state = state.copyWith(isLoading: true);
    }

    try {
      final page = refresh ? 0 : state.currentPage;
      final response = await _userService.getContestHistory(page: page);

      final newHistory =
          refresh ? response.history : [...state.history, ...response.history];

      state = ContestHistoryState(
        history: newHistory,
        isLoading: false,
        hasMore: response.hasMore,
        currentPage: response.currentPage,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 다음 페이지 로드
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final response = await _userService.getContestHistory(
        page: state.currentPage + 1,
      );

      state = ContestHistoryState(
        history: [...state.history, ...response.history],
        isLoading: false,
        hasMore: response.hasMore,
        currentPage: response.currentPage,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 새로고침
  Future<void> refresh() => loadHistory(refresh: true);
}

/// 대회 참가 이력 프로바이더
final contestHistoryProvider =
    StateNotifierProvider<ContestHistoryNotifier, ContestHistoryState>((ref) {
  final service = ref.watch(userServiceProvider);
  return ContestHistoryNotifier(service);
});

/// 맥마흔 점수 이력 프로바이더
final mcmahonHistoryProvider = FutureProvider<McMahonScoreSummary>((ref) async {
  final service = ref.watch(userServiceProvider);
  return service.getMcMahonHistory();
});

// ========== 즐겨찾기 ==========

/// 즐겨찾기 ID Set 관리 (빠른 조회용)
class FavoriteIdsNotifier extends StateNotifier<Set<int>> {
  final UserService _userService;

  FavoriteIdsNotifier(this._userService) : super({}) {
    _loadFavoriteIds();
  }

  Future<void> _loadFavoriteIds() async {
    try {
      final ids = await _userService.getFavoriteIds();
      state = ids.toSet();
    } catch (e) {
      // 로드 실패 시 빈 Set 유지
    }
  }

  /// 즐겨찾기 토글 (optimistic update)
  /// [contestName]과 [contestStartDate]가 전달되면 즐겨찾기 추가 시 알림 스케줄링
  Future<void> toggle(
    int homepageId, {
    String? contestName,
    DateTime? contestStartDate,
  }) async {
    final isFavorited = state.contains(homepageId);

    // Optimistic update
    if (isFavorited) {
      state = {...state}..remove(homepageId);
    } else {
      state = {...state, homepageId};
    }

    try {
      await _userService.toggleFavorite(homepageId, currentlyFavorited: isFavorited);

      // 알림 스케줄링/취소
      if (!kIsWeb) {
        if (!isFavorited && contestName != null && contestStartDate != null) {
          NotificationService().scheduleFavoriteReminders(
            homepageId: homepageId,
            contestName: contestName,
            contestStartDate: contestStartDate,
          );
        } else if (isFavorited) {
          NotificationService().cancelFavoriteReminders(homepageId);
        }
      }
    } catch (e) {
      // 실패 시 롤백
      if (isFavorited) {
        state = {...state, homepageId};
      } else {
        state = {...state}..remove(homepageId);
      }
    }
  }

  /// 새로고침
  Future<void> refresh() => _loadFavoriteIds();
}

/// 즐겨찾기 ID Set 프로바이더
final favoriteIdsProvider =
    StateNotifierProvider<FavoriteIdsNotifier, Set<int>>((ref) {
  final service = ref.watch(userServiceProvider);
  return FavoriteIdsNotifier(service);
});

/// 즐겨찾기 대회 목록 프로바이더
final favoritesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final service = ref.watch(userServiceProvider);
    return await service.getMyFavorites();
  } catch (e) {
    debugPrint('[즐겨찾기] 목록 조회 실패: $e');
    return [];
  }
});
