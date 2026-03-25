import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../services/portal_service.dart';
import '../models/portal/portal_contest.dart';
import '../models/portal/portal_participant.dart';
import '../models/portal/search_result.dart';
import '../models/portal/check_in_result.dart';
import '../models/portal/on_site_registration.dart';
import '../models/portal/round_result.dart';
import '../models/portal/ranking.dart';

/// 포털 서비스 프로바이더
final portalServiceProvider = Provider<PortalService>((ref) {
  return PortalService();
});

/// 포털 상태
class PortalState {
  final bool isLoading;
  final String? error;
  final PortalContest? contest;
  final List<String> contestDates;
  final bool isMultiDayContest;
  final PortalParticipant? selectedParticipant;
  final SearchResult? searchResult;
  final String searchQuery;
  final String language;

  const PortalState({
    this.isLoading = false,
    this.error,
    this.contest,
    this.contestDates = const [],
    this.isMultiDayContest = false,
    this.selectedParticipant,
    this.searchResult,
    this.searchQuery = '',
    this.language = 'ko',
  });

  PortalState copyWith({
    bool? isLoading,
    String? error,
    PortalContest? contest,
    List<String>? contestDates,
    bool? isMultiDayContest,
    PortalParticipant? selectedParticipant,
    SearchResult? searchResult,
    String? searchQuery,
    String? language,
    bool clearError = false,
    bool clearSelectedParticipant = false,
    bool clearSearchResult = false,
  }) {
    return PortalState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      contest: contest ?? this.contest,
      contestDates: contestDates ?? this.contestDates,
      isMultiDayContest: isMultiDayContest ?? this.isMultiDayContest,
      selectedParticipant: clearSelectedParticipant
          ? null
          : (selectedParticipant ?? this.selectedParticipant),
      searchResult: clearSearchResult
          ? null
          : (searchResult ?? this.searchResult),
      searchQuery: searchQuery ?? this.searchQuery,
      language: language ?? this.language,
    );
  }
}

/// 포털 상태 관리 Notifier
class PortalNotifier extends StateNotifier<PortalState> {
  final PortalService _portalService;
  final int contestId;

  PortalNotifier(this._portalService, this.contestId) : super(const PortalState()) {
    _loadContestInfo();
  }

  /// 오늘 날짜 (한국 시간 기준)
  String get todayDate {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 오늘 체크인 여부 확인
  bool get isCheckedInForToday {
    final participant = state.selectedParticipant;
    if (participant == null) return false;

    if (state.isMultiDayContest) {
      return participant.checkedInDates.contains(todayDate);
    }
    return participant.checkedIn;
  }

  /// 오늘이 대회 날짜인지 확인
  bool get isTodayContestDate {
    if (!state.isMultiDayContest || state.contestDates.isEmpty) return true;
    return state.contestDates.contains(todayDate);
  }

  /// 대회 정보 로드
  Future<void> _loadContestInfo() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // 대회 정보 로드
      final contest = await _portalService.getContestInfo(contestId);
      state = state.copyWith(contest: contest);

      // 대회 날짜 목록 조회
      try {
        final dates = await _portalService.getContestDates(contestId);
        state = state.copyWith(
          contestDates: dates,
          isMultiDayContest: dates.length > 1,
        );
      } catch (e) {
        // 날짜 정보 없음 (단일 대회)
        state = state.copyWith(isMultiDayContest: false);
      }

      // 저장된 검색 결과 복원
      await _restoreSavedParticipant();

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '대회 정보를 불러올 수 없습니다.',
      );
    }
  }

  /// 저장된 참가자 정보 복원
  Future<void> _restoreSavedParticipant() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'portal_$contestId';
      final stored = prefs.getString(key);

      if (stored != null) {
        final parsed = jsonDecode(stored);
        final searchQuery = parsed['searchQuery'] as String?;

        if (searchQuery != null && searchQuery.isNotEmpty) {
          state = state.copyWith(searchQuery: searchQuery);

          // 저장된 검색어로 다시 검색 (최신 데이터 반영)
          final result = await _portalService.searchParticipant(contestId, searchQuery);

          if (result.found && result.participants.isNotEmpty) {
            final savedParticipantId = parsed['participantId'];
            final savedGameRoomId = parsed['gameRoomId'];

            // 이전에 선택한 참가자 찾기
            final sameParticipant = result.participants.firstWhere(
              (p) => p.participantId == savedParticipantId && p.gameRoomId == savedGameRoomId,
              orElse: () => result.participants.first,
            );

            if (result.participants.length == 1) {
              state = state.copyWith(selectedParticipant: result.participants.first);
            } else {
              state = state.copyWith(selectedParticipant: sameParticipant);
            }
          }
        }
      }
    } catch (e) {
      // 복원 실패 시 무시
      debugPrint('[Portal] 저장된 참가자 복원 실패: $e');
    }
  }

  /// 참가자 저장
  Future<void> _saveParticipant(PortalParticipant participant) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'portal_$contestId';
      await prefs.setString(key, jsonEncode({
        'searchQuery': state.searchQuery,
        'participantId': participant.participantId,
        'gameRoomId': participant.gameRoomId,
      }));
    } catch (e) {
      debugPrint('[Portal] 참가자 저장 실패: $e');
    }
  }

  /// 저장된 참가자 삭제
  Future<void> _clearSavedParticipant() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('portal_$contestId');
    } catch (e) {
      debugPrint('[Portal] 저장 삭제 실패: $e');
    }
  }

  /// 언어 변경
  void setLanguage(String language) {
    state = state.copyWith(language: language);
  }

  /// 참가자 검색
  Future<void> searchParticipant(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(error: '이름을 입력하세요');
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      searchQuery: query,
    );

    try {
      final result = await _portalService.searchParticipant(contestId, query.trim());
      state = state.copyWith(
        isLoading: false,
        searchResult: result,
      );

      // 단일 결과면 바로 선택
      if (result.found && !result.multipleResults && result.participant != null) {
        selectParticipant(result.participant!);
      } else if (result.found && result.participants.length == 1) {
        selectParticipant(result.participants.first);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '검색 중 오류가 발생했습니다.',
      );
    }
  }

  /// 참가자 선택
  void selectParticipant(PortalParticipant participant) {
    state = state.copyWith(
      selectedParticipant: participant,
      clearSearchResult: true,
    );
    _saveParticipant(participant);
  }

  /// 새 검색
  void clearSelection() {
    state = state.copyWith(
      clearSelectedParticipant: true,
      clearSearchResult: true,
      searchQuery: '',
    );
    _clearSavedParticipant();
  }

  /// 체크인
  Future<CheckInResult> checkIn() async {
    final participant = state.selectedParticipant;
    if (participant == null) {
      return CheckInResult.error('참가자를 선택하세요');
    }

    if (!isTodayContestDate) {
      return CheckInResult.error('오늘은 대회 날짜가 아닙니다');
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _portalService.checkIn(contestId, participant);

      if (result.success) {
        // 체크인 상태 업데이트
        final updatedDates = [...participant.checkedInDates];
        if (!updatedDates.contains(todayDate)) {
          updatedDates.add(todayDate);
          updatedDates.sort();
        }

        state = state.copyWith(
          isLoading: false,
          selectedParticipant: participant.copyWithCheckIn(
            checkedIn: true,
            checkInTime: result.checkInTime,
            checkInDate: result.checkInDate,
            checkedInDates: updatedDates,
          ),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result.message,
        );
      }

      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '체크인 실패',
      );
      return CheckInResult.error('체크인 실패');
    }
  }

  /// 체크인 취소
  Future<CheckInResult> cancelCheckIn(String password) async {
    final participant = state.selectedParticipant;
    if (participant == null) {
      return CheckInResult.error('참가자를 선택하세요');
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _portalService.cancelCheckIn(
        contestId,
        participant,
        password,
      );

      if (result.success) {
        // 체크인 상태 업데이트
        final updatedDates = participant.checkedInDates
            .where((date) => date != todayDate)
            .toList();

        state = state.copyWith(
          isLoading: false,
          selectedParticipant: participant.copyWithCheckIn(
            checkedIn: updatedDates.isNotEmpty,
            checkedInDates: updatedDates,
          ),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result.message,
        );
      }

      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '체크인 취소 실패',
      );
      return CheckInResult.error('체크인 취소 실패');
    }
  }

  /// 현장 등록
  Future<OnSiteRegistrationResult> registerOnSite(OnSiteRegistrationRequest request) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _portalService.registerOnSite(contestId, request);
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '현장 등록 실패',
      );
      return OnSiteRegistrationResult.error('현장 등록 실패');
    }
  }
}

/// 포털 프로바이더 패밀리 (contestId별)
final portalProvider = StateNotifierProvider.family<PortalNotifier, PortalState, int>(
  (ref, contestId) {
    final service = ref.watch(portalServiceProvider);
    return PortalNotifier(service, contestId);
  },
);

// ==================== 상세 화면용 프로바이더 ====================

/// 라운드 결과 프로바이더
final roundResultsProvider = FutureProvider.family<RoundResult, RoundResultParams>(
  (ref, params) async {
    final service = ref.watch(portalServiceProvider);
    return service.getRoundResults(
      params.contestId,
      params.participantId,
      params.gameRoomId,
      params.round,
    );
  },
);

/// 라운드 결과 조회 파라미터
class RoundResultParams {
  final int contestId;
  final int participantId;
  final int gameRoomId;
  final int round;

  RoundResultParams({
    required this.contestId,
    required this.participantId,
    required this.gameRoomId,
    required this.round,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoundResultParams &&
          contestId == other.contestId &&
          participantId == other.participantId &&
          gameRoomId == other.gameRoomId &&
          round == other.round;

  @override
  int get hashCode => Object.hash(contestId, participantId, gameRoomId, round);
}

/// 순위표 프로바이더
final rankingsProvider = FutureProvider.family<List<Ranking>, RankingsParams>(
  (ref, params) async {
    final service = ref.watch(portalServiceProvider);
    return service.getRankings(params.contestId, params.sortId, sortBy: params.sortBy);
  },
);

/// 순위표 조회 파라미터
class RankingsParams {
  final int contestId;
  final int sortId;
  final String sortBy;  // wins: 승수순, score: 점수순 (MCM 전용)

  RankingsParams({
    required this.contestId,
    required this.sortId,
    this.sortBy = 'wins',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RankingsParams &&
          contestId == other.contestId &&
          sortId == other.sortId &&
          sortBy == other.sortBy;

  @override
  int get hashCode => Object.hash(contestId, sortId, sortBy);
}

/// 최대 라운드 프로바이더
final maxRoundProvider = FutureProvider.family<int, MaxRoundParams>(
  (ref, params) async {
    final service = ref.watch(portalServiceProvider);
    return service.getMaxRound(params.contestId, params.gameRoomId);
  },
);

/// 최대 라운드 조회 파라미터
class MaxRoundParams {
  final int contestId;
  final int gameRoomId;

  MaxRoundParams({
    required this.contestId,
    required this.gameRoomId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaxRoundParams &&
          contestId == other.contestId &&
          gameRoomId == other.gameRoomId;

  @override
  int get hashCode => Object.hash(contestId, gameRoomId);
}
