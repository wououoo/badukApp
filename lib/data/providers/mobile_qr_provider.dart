import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../api/api_client.dart';
import '../services/mobile_qr_service.dart';
import '../models/qr/my_contest.dart';
import '../models/qr/my_contest_detail.dart';

/// 모바일 QR 서비스 프로바이더
final mobileQRServiceProvider = Provider<MobileQRService>((ref) {
  return MobileQRService();
});

/// 모바일 QR 상태
class MobileQRState {
  final bool isLoading;
  final String? error;
  final List<MyContest> contests;
  final MyContestDetail? selectedContestDetail;

  const MobileQRState({
    this.isLoading = false,
    this.error,
    this.contests = const [],
    this.selectedContestDetail,
  });

  MobileQRState copyWith({
    bool? isLoading,
    String? error,
    List<MyContest>? contests,
    MyContestDetail? selectedContestDetail,
    bool clearError = false,
    bool clearSelectedContestDetail = false,
  }) {
    return MobileQRState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      contests: contests ?? this.contests,
      selectedContestDetail: clearSelectedContestDetail
          ? null
          : (selectedContestDetail ?? this.selectedContestDetail),
    );
  }
}

/// 모바일 QR 상태 관리 Notifier
class MobileQRNotifier extends StateNotifier<MobileQRState> {
  final MobileQRService _service;

  MobileQRNotifier(this._service) : super(const MobileQRState()) {
    loadMyContests();
  }

  /// 내 참가 대회 목록 로드
  Future<void> loadMyContests() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final contests = await _service.getMyActiveContests();
      state = state.copyWith(
        isLoading: false,
        contests: contests,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '대회 목록을 불러올 수 없습니다.',
      );
    }
  }

  /// 새로고침
  Future<void> refresh() async {
    await loadMyContests();
  }

  /// 특정 대회 상세 정보 로드
  Future<void> loadContestDetail(int contestId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final detail = await _service.getMyContestDetail(contestId);
      state = state.copyWith(
        isLoading: false,
        selectedContestDetail: detail,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '대회 정보를 불러올 수 없습니다.',
      );
    }
  }

  /// 체크인
  Future<CheckInResponse> checkIn(int contestId, {int? sortId}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _service.checkIn(contestId, sortId: sortId);

      if (result.success) {
        // 목록 새로고침
        await loadMyContests();
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
      return CheckInResponse(success: false, message: '체크인 실패');
    }
  }

  /// 체크인 취소
  Future<CheckInResponse> cancelCheckIn(int contestId, {int? sortId}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _service.cancelCheckIn(contestId, sortId: sortId);

      if (result.success) {
        // 목록 새로고침
        await loadMyContests();
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
      return CheckInResponse(success: false, message: '체크인 취소 실패');
    }
  }

  /// 동명이인 선택 - 참가자와 전화번호 연결
  Future<LinkParticipantResponse> linkParticipant(
    int contestId,
    int participantId,
    int gameRoomId,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _service.linkParticipant(contestId, participantId, gameRoomId);

      if (result.success) {
        // 목록 새로고침
        await loadMyContests();
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
        error: '연결 실패',
      );
      return LinkParticipantResponse(success: false, message: '연결 실패');
    }
  }

  /// 선택된 대회 상세 정보 초기화
  void clearSelectedContestDetail() {
    state = state.copyWith(clearSelectedContestDetail: true);
  }
}

/// 모바일 QR 프로바이더
final mobileQRProvider = StateNotifierProvider<MobileQRNotifier, MobileQRState>(
  (ref) {
    final service = ref.watch(mobileQRServiceProvider);
    return MobileQRNotifier(service);
  },
);

// ==================== 상세 조회용 프로바이더 ====================

/// 라운드 결과 프로바이더
final qrRoundResultsProvider = FutureProvider.family<RoundResultResponse, QRRoundResultParams>(
  (ref, params) async {
    final service = ref.watch(mobileQRServiceProvider);
    return service.getRoundResults(
      params.contestId,
      params.round,
      sortId: params.sortId,
      contestType: params.contestType,
    );
  },
);

/// 라운드 결과 조회 파라미터
class QRRoundResultParams {
  final int contestId;
  final int round;
  final int? sortId;
  final String? contestType;

  QRRoundResultParams({
    required this.contestId,
    required this.round,
    this.sortId,
    this.contestType,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QRRoundResultParams &&
          contestId == other.contestId &&
          round == other.round &&
          sortId == other.sortId &&
          contestType == other.contestType;

  @override
  int get hashCode => Object.hash(contestId, round, sortId, contestType);
}

/// 풀리그 전체 스케줄 프로바이더
final fullLeagueScheduleProvider = FutureProvider.family<FullLeagueScheduleResponse, int>(
  (ref, gameRoomId) async {
    final service = ref.watch(mobileQRServiceProvider);
    return service.getFullLeagueSchedule(gameRoomId);
  },
);

/// 단체 풀리그 전체 스케줄 프로바이더
final teamFullLeagueScheduleProvider = FutureProvider.family<TeamFullLeagueScheduleResponse, int>(
  (ref, gameRoomId) async {
    final service = ref.watch(mobileQRServiceProvider);
    return service.getTeamFullLeagueSchedule(gameRoomId);
  },
);

/// 토너먼트 브래킷 조회 프로바이더 (gameRoomId 파라미터)
final tournamentBracketProvider = FutureProvider.family<TournamentBracketResponse, int>(
  (ref, gameRoomId) async {
    final service = ref.watch(mobileQRServiceProvider);
    return service.getTournamentBracket(gameRoomId);
  },
);

/// 순위표 프로바이더
final qrRankingsProvider = FutureProvider.family<RankingsResponse, QRRankingsParams>(
  (ref, params) async {
    final service = ref.watch(mobileQRServiceProvider);
    return service.getRankings(params.contestId, sortId: params.sortId, sortBy: params.sortBy, contestType: params.contestType);
  },
);

/// 순위표 조회 파라미터
class QRRankingsParams {
  final int contestId;
  final int? sortId;
  final String sortBy;  // wins: 승수순, score: 점수순 (MCM 전용)
  final String? contestType;

  QRRankingsParams({
    required this.contestId,
    this.sortId,
    this.sortBy = 'wins',
    this.contestType,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QRRankingsParams &&
          contestId == other.contestId &&
          sortId == other.sortId &&
          sortBy == other.sortBy &&
          contestType == other.contestType;

  @override
  int get hashCode => Object.hash(contestId, sortId, sortBy, contestType);
}

// ==================== 내 클럽 대회 ====================

/// 내 클럽 대회 목록 Provider
final myClubContestsProvider = StateNotifierProvider<MyClubContestsNotifier, MyClubContestsState>((ref) {
  return MyClubContestsNotifier();
});

class MyClubContestsState {
  final bool isLoading;
  final List<Map<String, dynamic>> contests;

  const MyClubContestsState({this.isLoading = false, this.contests = const []});

  MyClubContestsState copyWith({bool? isLoading, List<Map<String, dynamic>>? contests}) {
    return MyClubContestsState(
      isLoading: isLoading ?? this.isLoading,
      contests: contests ?? this.contests,
    );
  }
}

class MyClubContestsNotifier extends StateNotifier<MyClubContestsState> {
  MyClubContestsNotifier() : super(const MyClubContestsState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await ApiClient.instance.get(ApiConstants.myClubContests);
      final data = response.data;
      if (data['success'] == true && data['contests'] != null) {
        final list = (data['contests'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        state = state.copyWith(isLoading: false, contests: list);
      } else {
        state = state.copyWith(isLoading: false, contests: []);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, contests: []);
    }
  }

  Future<void> refresh() async => await load();
}
