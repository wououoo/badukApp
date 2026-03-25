import '../api/api_client.dart';
import '../models/live_contest.dart';
import '../models/live_de.dart';

class LiveContestService {
  final ApiClient _apiClient;

  LiveContestService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// 라이브 대회 목록 (페이징)
  Future<LiveContestListResponse> getLiveContestsPaged({
    String type = 'ALL',
    int page = 0,
    int size = 10,
    bool publicOnly = true,
  }) async {
    final response = await _apiClient.get(
      '/live/contests/paged',
      queryParameters: {
        'type': type,
        'page': page,
        'size': size,
        'publicOnly': publicOnly,
      },
    );
    return LiveContestListResponse.fromJson(response.data);
  }

  /// 라이브 대회 목록 (전체)
  Future<List<LiveContest>> getLiveContests() async {
    final response = await _apiClient.get('/live/contests');
    final data = response.data;

    if (data is List) {
      return data.map((e) => LiveContest.fromJson(e)).toList();
    }

    final contests = (data as Map<String, dynamic>)['contests'] as List<dynamic>? ?? [];
    return contests.map((e) => LiveContest.fromJson(e)).toList();
  }

  /// 라이브 대회 상세
  Future<LiveContestDetail> getLiveContestDetail(int contestId) async {
    final response = await _apiClient.get('/live/contests/$contestId');
    return LiveContestDetail.fromJson(response.data);
  }

  /// 라이브 부문 상세
  Future<LiveSortDetail> getLiveSortDetail(int contestId, int sortId) async {
    final response = await _apiClient.get(
      '/live/contests/$contestId/sorts/$sortId',
    );
    return LiveSortDetail.fromJson(response.data);
  }

  /// 순위표 조회
  Future<List<LiveStanding>> getRankings(int contestId, int sortId) async {
    final response = await _apiClient.get(
      '/live/contests/$contestId/sorts/$sortId/rankings',
    );
    final data = response.data;

    if (data is List) {
      return data.map((e) => LiveStanding.fromJson(e)).toList();
    }
    return [];
  }

  /// 대진표 조회 (전체 라운드)
  Future<LivePairingsResponse> getPairings(int contestId, int sortId) async {
    final response = await _apiClient.get(
      '/live/contests/$contestId/sorts/$sortId/pairings',
    );
    return LivePairingsResponse.fromJson(response.data);
  }

  /// 대진표 조회 (특정 라운드)
  Future<LivePairingsResponse> getPairingsByRound(
    int contestId,
    int sortId,
    int round,
  ) async {
    final response = await _apiClient.get(
      '/live/contests/$contestId/sorts/$sortId/pairings/$round',
    );
    return LivePairingsResponse.fromJson(response.data);
  }

  // ==================== DE (더블엘리미네이션) 전용 API ====================

  /// DE 예선 그룹 목록 조회
  Future<List<int>> getDEGroups(int contestId, int sortId) async {
    final response = await _apiClient.get(
      '/live/contests/$contestId/sorts/$sortId/de/groups',
    );
    final data = response.data;
    final groups = (data['groups'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [];
    return groups;
  }

  /// DE 예선 그룹별 순위표
  Future<List<DEPreliminaryRanking>> getDEPreliminaryRankings(
    int contestId,
    int sortId,
    int group,
  ) async {
    final response = await _apiClient.get(
      '/live/contests/$contestId/sorts/$sortId/de/preliminary/rankings',
      queryParameters: {'group': group},
    );
    final data = response.data;
    if (data is List) {
      return data.map((e) => DEPreliminaryRanking.fromJson(e)).toList();
    }
    return [];
  }

  /// DE 예선 그룹별 대진표
  Future<DEPreliminaryPairingsResponse> getDEPreliminaryPairings(
    int contestId,
    int sortId,
    int group,
  ) async {
    final response = await _apiClient.get(
      '/live/contests/$contestId/sorts/$sortId/de/preliminary/pairings',
      queryParameters: {'group': group},
    );
    return DEPreliminaryPairingsResponse.fromJson(response.data);
  }

  /// DE 본선 토너먼트 순위표
  Future<List<DETournamentRanking>> getDETournamentRankings(
    int contestId,
    int sortId,
  ) async {
    final response = await _apiClient.get(
      '/live/contests/$contestId/sorts/$sortId/de/tournament/rankings',
    );
    final data = response.data;
    if (data is List) {
      return data.map((e) => DETournamentRanking.fromJson(e)).toList();
    }
    return [];
  }

  /// DE 본선 토너먼트 대진표
  Future<DETournamentPairingsResponse> getDETournamentPairings(
    int contestId,
    int sortId,
  ) async {
    final response = await _apiClient.get(
      '/live/contests/$contestId/sorts/$sortId/de/tournament/pairings',
    );
    return DETournamentPairingsResponse.fromJson(response.data);
  }
}
