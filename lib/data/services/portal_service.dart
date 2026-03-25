import '../api/api_client.dart';
import '../models/portal/portal_contest.dart';
import '../models/portal/portal_participant.dart';
import '../models/portal/search_result.dart';
import '../models/portal/check_in_result.dart';
import '../models/portal/on_site_registration.dart';
import '../models/portal/round_result.dart';
import '../models/portal/ranking.dart';

/// 포털 API 서비스
class PortalService {
  final ApiClient _apiClient;

  PortalService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // ==================== 대회 정보 ====================

  /// 대회 정보 조회
  Future<PortalContest> getContestInfo(int contestId) async {
    final response = await _apiClient.get('/portal/contest/$contestId');
    return PortalContest.fromJson(response.data);
  }

  /// 대회 날짜 목록 조회 (다일 대회용)
  Future<List<String>> getContestDates(int contestId) async {
    final response = await _apiClient.get('/portal/contest/$contestId/dates');
    return List<String>.from(response.data);
  }

  // ==================== 참가자 검색 ====================

  /// 참가자 검색
  Future<SearchResult> searchParticipant(int contestId, String searchQuery) async {
    final response = await _apiClient.post(
      '/portal/search/$contestId',
      data: {'searchQuery': searchQuery},
    );
    return SearchResult.fromJson(response.data);
  }

  /// 참가자 정보 새로고침
  Future<PortalParticipant> refreshParticipant(
    int contestId,
    int participantId,
    int gameRoomId,
  ) async {
    final response = await _apiClient.get(
      '/portal/participant/$contestId/$participantId',
      queryParameters: {'gameRoomId': gameRoomId},
    );
    return PortalParticipant.fromJson(response.data);
  }

  // ==================== 체크인 ====================

  /// 체크인 등록
  Future<CheckInResult> checkIn(int contestId, PortalParticipant participant) async {
    final response = await _apiClient.post(
      '/portal/check-in/$contestId',
      data: {
        'participantName': participant.name,
        'gameRoomId': participant.gameRoomId,
        'sortName': participant.sortName,
        'phone': participant.phone,
        if (participant.teamName != null) 'teamName': participant.teamName,
      },
    );
    return CheckInResult.fromJson(response.data);
  }

  /// 체크인 취소
  Future<CheckInResult> cancelCheckIn(
    int contestId,
    PortalParticipant participant,
    String password,
  ) async {
    final response = await _apiClient.post(
      '/portal/check-in/$contestId/cancel',
      data: {
        'participantName': participant.name,
        'gameRoomId': participant.gameRoomId,
        'password': password,
        'phone': participant.phone,
        if (participant.teamName != null) 'teamName': participant.teamName,
      },
    );
    return CheckInResult.fromJson(response.data);
  }

  // ==================== 현장 등록 ====================

  /// 현장 등록 신청
  Future<OnSiteRegistrationResult> registerOnSite(
    int contestId,
    OnSiteRegistrationRequest request,
  ) async {
    final response = await _apiClient.post(
      '/check-in/on-site/$contestId',
      data: request.toJson(),
    );
    return OnSiteRegistrationResult.fromJson(response.data);
  }

  // ==================== 라운드 결과 ====================

  /// 라운드 결과 조회
  Future<RoundResult> getRoundResults(
    int contestId,
    int participantId,
    int gameRoomId,
    int round,
  ) async {
    final response = await _apiClient.get(
      '/portal/round-results/$contestId/$participantId/$round',
      queryParameters: {'gameRoomId': gameRoomId},
    );
    return RoundResult.fromJson(response.data);
  }

  /// 최대 라운드 수 조회
  Future<int> getMaxRound(int contestId, int gameRoomId) async {
    final response = await _apiClient.get(
      '/portal/max-round/$contestId/$gameRoomId',
    );
    return response.data['maxRound'] ?? 0;
  }

  // ==================== 순위표 ====================

  /// 순위표 조회
  /// [sortBy] - 정렬 기준 (wins: 승수순, score: 점수순) - MCM 전용
  Future<List<Ranking>> getRankings(int contestId, int sortId, {String sortBy = 'wins'}) async {
    final response = await _apiClient.get(
      '/portal/rankings/$contestId/$sortId',
      queryParameters: {'sortBy': sortBy},
    );
    final List<dynamic> data = response.data;
    return data
        .asMap()
        .entries
        .map((entry) => Ranking.fromJson(entry.value, entry.key))
        .toList();
  }
}
