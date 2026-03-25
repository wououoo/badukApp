import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contest.dart';
import '../services/contest_service.dart';
export '../services/contest_service.dart' show SortRankings, RankingEntry;

/// ContestService 프로바이더
final contestServiceProvider = Provider<ContestService>((ref) => ContestService());

/// 대회 목록 상태
class ContestListState {
  final List<Contest> contests;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;
  final String typeFilter; // 대회 유형 필터

  const ContestListState({
    this.contests = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
    this.typeFilter = 'ALL',
  });

  ContestListState copyWith({
    List<Contest>? contests,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
    String? typeFilter,
  }) {
    return ContestListState(
      contests: contests ?? this.contests,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
      typeFilter: typeFilter ?? this.typeFilter,
    );
  }
}

/// 대회 목록 관리 Notifier
class ContestListNotifier extends StateNotifier<ContestListState> {
  final ContestService _contestService;

  ContestListNotifier(this._contestService) : super(const ContestListState());

  /// 대회 목록 로드 (페이징)
  Future<void> loadContests({String type = 'ALL', bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    if (refresh) {
      state = ContestListState(isLoading: true, typeFilter: type);
    } else {
      state = state.copyWith(isLoading: true, typeFilter: type);
    }

    try {
      final page = refresh ? 0 : state.currentPage;
      final response = await _contestService.getContestsPaged(
        type: type,
        page: page,
        publicOnly: true,
      );

      final newContests = refresh
          ? response.contests
          : [...state.contests, ...response.contests];

      state = ContestListState(
        contests: newContests,
        isLoading: false,
        hasMore: response.hasMore,
        currentPage: response.currentPage,
        typeFilter: type,
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
      final response = await _contestService.getContestsPaged(
        type: state.typeFilter,
        page: state.currentPage + 1,
        publicOnly: true,
      );

      state = ContestListState(
        contests: [...state.contests, ...response.contests],
        isLoading: false,
        hasMore: response.hasMore,
        currentPage: response.currentPage,
        typeFilter: state.typeFilter,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 새로고침
  Future<void> refresh() => loadContests(type: state.typeFilter, refresh: true);

  /// 대회 유형 필터 변경
  Future<void> setTypeFilter(String type) {
    return loadContests(type: type, refresh: true);
  }
}

/// 대회 목록 프로바이더
final contestListProvider =
    StateNotifierProvider<ContestListNotifier, ContestListState>((ref) {
  final service = ref.watch(contestServiceProvider);
  return ContestListNotifier(service);
});

/// 대회 상세 프로바이더 (Family)
final contestDetailProvider =
    FutureProvider.family<ContestDetail, int>((ref, contestId) async {
  final service = ref.watch(contestServiceProvider);
  return service.getContestDetail(contestId);
});

/// 전체 대회 목록 프로바이더 (리스트 형태)
final allContestsProvider = FutureProvider<List<Contest>>((ref) async {
  final service = ref.watch(contestServiceProvider);
  return service.getContests(type: 'ALL');
});

/// 예정된 대회 프로바이더
final upcomingContestsProvider = FutureProvider<List<Contest>>((ref) async {
  final service = ref.watch(contestServiceProvider);
  return service.getUpcomingContests(limit: 5);
});

/// 진행중인 대회 프로바이더
final ongoingContestsProvider = FutureProvider<List<Contest>>((ref) async {
  final service = ref.watch(contestServiceProvider);
  return service.getOngoingContests(limit: 5);
});

/// 종료된 대회 프로바이더
final completedContestsProvider = FutureProvider<List<Contest>>((ref) async {
  final service = ref.watch(contestServiceProvider);
  return service.getCompletedContests(limit: 5);
});

/// 순위표 프로바이더
final rankingsProvider = FutureProvider.family<List<Map<String, dynamic>>, ({int contestId, int sortId})>(
  (ref, params) async {
    final service = ref.watch(contestServiceProvider);
    return service.getRankings(params.contestId, params.sortId);
  },
);

/// 대진표 프로바이더
final pairingsProvider = FutureProvider.family<PairingsResponse, ({int contestId, int sortId})>(
  (ref, params) async {
    final service = ref.watch(contestServiceProvider);
    return service.getPairings(params.contestId, params.sortId);
  },
);

/// 부문 상세 프로바이더
final sortDetailProvider = FutureProvider.family<SortDetail, ({int contestId, int sortId})>(
  (ref, params) async {
    final service = ref.watch(contestServiceProvider);
    return service.getSortDetail(params.contestId, params.sortId);
  },
);

/// 홈페이지 대회 결과 (순위표) 프로바이더
final homepageRankingsProvider = FutureProvider.family<List<SortRankings>, int>(
  (ref, homepageId) async {
    final service = ref.watch(contestServiceProvider);
    return service.getHomepageRankings(homepageId);
  },
);
