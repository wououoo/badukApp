import '../api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/host_operation.dart';

/// 주최자 운영 콘솔 서비스 (MobileHostOperationController 호출)
///
/// MCM 은 GameRoom.id == ContestSort.id 라 gameRoomId 를 그대로 전달한다.
class HostOperationService {
  final ApiClient _apiClient;

  HostOperationService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  String get _base => ApiConstants.hostOperationContests;

  /// A1 — 내가 운영할 대회 목록
  Future<List<HostContest>> getMyContests() async {
    final res = await _apiClient.get(_base);
    final data = res.data;
    if (data is Map && data['contests'] is List) {
      return (data['contests'] as List)
          .map((e) => HostContest.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  /// A2 — 대회의 부문(운영 단위) 목록
  Future<List<ContestSection>> getSections(int homepageId) async {
    final res = await _apiClient.get('$_base/$homepageId');
    final data = res.data;
    if (data is Map && data['sections'] is List) {
      return (data['sections'] as List)
          .map((e) => ContestSection.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  // ── 맥마흔(MCM) 운영 ──

  /// #3 — 부문 운영 현황 (현재 라운드 매치 + 참가자 + 순위). 원본 Map 그대로 반환.
  Future<Map<String, dynamic>> getMcmahon(int homepageId, int gameRoomId,
      {int? round}) async {
    final res = await _apiClient.get(
      '$_base/$homepageId/sections/$gameRoomId/mcmahon',
      queryParameters: round != null ? {'round': round} : null,
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// #4a — 1라운드 편성 시작
  Future<Map<String, dynamic>> startMcmahon(int homepageId, int gameRoomId,
      {Map<String, dynamic>? options}) async {
    final res = await _apiClient.post(
      '$_base/$homepageId/sections/$gameRoomId/mcmahon/start',
      data: options ?? {},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// #4b — 다음 라운드 편성 (자동 MWPM 기본)
  Future<Map<String, dynamic>> nextRoundMcmahon(
      int homepageId, int gameRoomId) async {
    final res = await _apiClient.post(
      '$_base/$homepageId/sections/$gameRoomId/mcmahon/next-round',
      data: {},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// #4c — 매치 결과 입력/수정 (승자 지정 · 비김)
  Future<Map<String, dynamic>> saveResult(
    int homepageId,
    int gameRoomId,
    int matchId, {
    int? winnerId,
    bool isJigo = false,
  }) async {
    final res = await _apiClient.put(
      '$_base/$homepageId/sections/$gameRoomId/mcmahon/matches/$matchId/result',
      data: {'winnerId': winnerId, 'isJigo': isJigo},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// #4d — 순위 확정 (+레이팅)
  Future<Map<String, dynamic>> finalizeMcmahon(
    int homepageId,
    int gameRoomId, {
    String? password,
  }) async {
    final res = await _apiClient.post(
      '$_base/$homepageId/sections/$gameRoomId/mcmahon/finalize',
      data: {'password': password},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ── 스위스리그(SWISS) 운영 ──

  /// 부문 운영 현황 (라운드 대진 + 순위). 원본 Map 반환.
  Future<Map<String, dynamic>> getSwiss(int homepageId, int gameRoomId,
      {int? round}) async {
    final res = await _apiClient.get(
      '$_base/$homepageId/sections/$gameRoomId/swiss',
      queryParameters: round != null ? {'round': round} : null,
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// 라운드 편성 (1라운드 시작 & 다음 라운드 공통, 자동)
  Future<Map<String, dynamic>> generateSwiss(
      int homepageId, int gameRoomId) async {
    final res = await _apiClient.post(
      '$_base/$homepageId/sections/$gameRoomId/swiss/generate',
      data: {},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// 단일 매치 결과 저장/수정 — (round, player1Id, player2Id) 키.
  /// 양패는 none=true, winnerId=null.
  Future<Map<String, dynamic>> saveSwissResult(
    int homepageId,
    int gameRoomId, {
    required int round,
    int? player1Id,
    int? player2Id,
    int? winnerId,
    bool none = false,
  }) async {
    final res = await _apiClient.post(
      '$_base/$homepageId/sections/$gameRoomId/swiss/save-result',
      data: {
        'round': round,
        'player1Id': player1Id,
        'player2Id': player2Id,
        'winnerId': winnerId,
        'none': none,
        'end': true,
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// 순위 확정 (+레이팅)
  Future<Map<String, dynamic>> finalizeSwiss(
      int homepageId, int gameRoomId) async {
    final res = await _apiClient.post(
      '$_base/$homepageId/sections/$gameRoomId/swiss/finalize',
      data: {},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ── 단체 스위스(TEAM_SWISS) 운영 ──

  Future<Map<String, dynamic>> getTeamSwiss(int homepageId, int gameRoomId,
      {int? round}) async {
    final res = await _apiClient.get(
      '$_base/$homepageId/sections/$gameRoomId/team-swiss',
      queryParameters: round != null ? {'round': round} : null,
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> generateTeamSwiss(
      int homepageId, int gameRoomId) async {
    final res = await _apiClient.post(
      '$_base/$homepageId/sections/$gameRoomId/team-swiss/generate',
      data: {},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// 라운드 전체 결과 저장 — results:[{team1Name, team2Name, results:[{playerIndex, winner}]}]
  Future<Map<String, dynamic>> saveTeamSwissResults(
    int homepageId,
    int gameRoomId, {
    required int round,
    required List<Map<String, dynamic>> results,
  }) async {
    final res = await _apiClient.post(
      '$_base/$homepageId/sections/$gameRoomId/team-swiss/save-results',
      data: {'round': round, 'results': results},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> finalizeTeamSwiss(
      int homepageId, int gameRoomId) async {
    final res = await _apiClient.post(
      '$_base/$homepageId/sections/$gameRoomId/team-swiss/finalize',
      data: {},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ── 풀리그(FULL_LEAGUE) 운영 ──

  Future<Map<String, dynamic>> getFullLeague(int homepageId, int gameRoomId,
      {int? round}) async {
    final res = await _apiClient.get(
      '$_base/$homepageId/sections/$gameRoomId/full-league',
      queryParameters: round != null ? {'round': round} : null,
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> generateFullLeague(
      int homepageId, int gameRoomId) async {
    final res = await _apiClient.post(
      '$_base/$homepageId/sections/$gameRoomId/full-league/generate',
      data: {},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> saveFullLeagueResult(
    int homepageId,
    int gameRoomId, {
    required int round,
    int? player1Id,
    int? player2Id,
    int? winnerId,
  }) async {
    final res = await _apiClient.post(
      '$_base/$homepageId/sections/$gameRoomId/full-league/save-result',
      data: {
        'round': round,
        'player1Id': player1Id,
        'player2Id': player2Id,
        'winnerId': winnerId,
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> finalizeFullLeague(
      int homepageId, int gameRoomId) async {
    final res = await _apiClient.post(
      '$_base/$homepageId/sections/$gameRoomId/full-league/finalize',
      data: {},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ── 단체 풀리그(TEAM_FULL_LEAGUE) 운영 ──

  Future<Map<String, dynamic>> getTeamFullLeague(int homepageId, int gameRoomId,
      {int? round}) async {
    final res = await _apiClient.get(
      '$_base/$homepageId/sections/$gameRoomId/team-full-league',
      queryParameters: round != null ? {'round': round} : null,
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// 대진표 생성+시작 (boardCount = 장 수 = teamSize)
  Future<Map<String, dynamic>> startTeamFullLeague(
      int homepageId, int gameRoomId, int boardCount) async {
    final res = await _apiClient.post(
      '$_base/$homepageId/sections/$gameRoomId/team-full-league/start',
      data: {'boardCount': boardCount},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// 장별 결과 저장 (boardResultId 단건, winnerMemberId=null이면 무승부/미정)
  Future<Map<String, dynamic>> saveTeamFullLeagueBoard(
    int homepageId,
    int gameRoomId, {
    required int boardResultId,
    int? winnerMemberId,
  }) async {
    final res = await _apiClient.post(
      '$_base/$homepageId/sections/$gameRoomId/team-full-league/save-board',
      data: {'boardResultId': boardResultId, 'winnerMemberId': winnerMemberId},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> finalizeTeamFullLeague(
      int homepageId, int gameRoomId) async {
    final res = await _apiClient.post(
      '$_base/$homepageId/sections/$gameRoomId/team-full-league/finalize',
      data: {},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ── 싱글 토너먼트(TOURNAMENT) 운영 ──
  // 서버 SSOT: 저장 후 항상 bracket 재조회. 승자 전파·패자 탈락·수정거부(400)는 서버가 처리.

  /// 토너먼트 현황 — 전체 브래킷 + 순위
  Future<TournamentSection> getTournament(int homepageId, int gameRoomId) async {
    final res = await _apiClient.get(
      '$_base/$homepageId/sections/$gameRoomId/tournament',
    );
    return TournamentSection.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// 매치 승자 지정/수정 — 서버가 다음 라운드 전파. 다음 라운드에 결과 있으면 400.
  Future<Map<String, dynamic>> setTournamentResult(
    int homepageId,
    int gameRoomId, {
    required int matchDbId,
    required int winnerId,
  }) async {
    final res = await _apiClient.post(
      '$_base/$homepageId/sections/$gameRoomId/tournament/matches/$matchDbId/result',
      data: {'winnerId': winnerId},
    );
    return res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : <String, dynamic>{};
  }

  /// 매치 결과 초기화 — 다음 라운드에 결과 있으면 400.
  Future<Map<String, dynamic>> resetTournamentResult(
    int homepageId,
    int gameRoomId, {
    required int matchDbId,
  }) async {
    final res = await _apiClient.post(
      '$_base/$homepageId/sections/$gameRoomId/tournament/matches/$matchDbId/reset',
      data: {},
    );
    return res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : <String, dynamic>{};
  }

  // ── 더블 엘리미네이션(DE) 운영 ──
  // 예선=조별, 본선=full-bracket SSOT. 저장/해제 후 항상 재조회(서버가 전파 처리).

  /// 예선 현황 (조별 라운드 매치)
  Future<DePrelimSection> getDePrelim(int homepageId, int gameRoomId) async {
    final res = await _apiClient.get(
      '$_base/$homepageId/sections/$gameRoomId/de/prelim',
    );
    return DePrelimSection.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// 예선 매치 결과 저장/수정/해제 — winner='' 이면 해제(winnerNumber=0)
  Future<Map<String, dynamic>> saveDePrelimResult(
    int homepageId,
    int gameRoomId, {
    required int round,
    required int group,
    required String player1,
    required String player2,
    required int player1Number,
    required int player2Number,
    required String winner,
    required int winnerNumber,
  }) async {
    final res = await _apiClient.put(
      '$_base/$homepageId/sections/$gameRoomId/de/prelim/result',
      data: {
        'round': round,
        'group': group,
        'player1': player1,
        'player2': player2,
        'player1Number': player1Number,
        'player2Number': player2Number,
        'winner': winner,
        'winnerNumber': winnerNumber,
      },
    );
    return res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : <String, dynamic>{};
  }

  /// 예선 다음 라운드 생성 (해당 조). participants:[{name, id}]
  Future<Map<String, dynamic>> makeDeNextRound(
    int homepageId,
    int gameRoomId, {
    required int round,
    required int group,
    required List<Map<String, dynamic>> participants,
  }) async {
    final res = await _apiClient.post(
      '$_base/$homepageId/sections/$gameRoomId/de/prelim/next-round',
      data: {'round': round, 'group': group, 'participants': participants},
    );
    return res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : <String, dynamic>{};
  }

  /// 본선 현황 (full-bracket)
  Future<DeBracketSection> getDeBracket(int homepageId, int gameRoomId) async {
    final res = await _apiClient.get(
      '$_base/$homepageId/sections/$gameRoomId/de/bracket',
    );
    return DeBracketSection.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  // ── 수정/정정: 라운드 삭제·리셋 ──
  // 비번 게이트: password 없이 호출 → {requirePassword:true}면 비번 받아 재호출.

  Map<String, dynamic> _asMap(dynamic d) =>
      d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};

  /// 라운드제 방식 공통 라운드 삭제 (kind: mcmahon/swiss/team-swiss/full-league/team-full-league)
  Future<Map<String, dynamic>> deleteRound(
    int homepageId,
    int gameRoomId, {
    required String kind,
    required int round,
    String? password,
  }) async {
    final res = await _apiClient.delete(
      '$_base/$homepageId/sections/$gameRoomId/$kind/round/$round',
      queryParameters: password != null ? {'password': password} : null,
    );
    return _asMap(res.data);
  }

  /// DE 예선 — 특정 조의 특정 라운드 삭제
  Future<Map<String, dynamic>> deleteDePrelimRound(
    int homepageId,
    int gameRoomId, {
    required int group,
    required int round,
    String? password,
  }) async {
    final qp = <String, dynamic>{'group': group, 'round': round};
    if (password != null) qp['password'] = password;
    final res = await _apiClient.delete(
      '$_base/$homepageId/sections/$gameRoomId/de/prelim/round',
      queryParameters: qp,
    );
    return _asMap(res.data);
  }

  /// DE 예선 — 특정 조 전체 라운드 삭제
  Future<Map<String, dynamic>> deleteDePrelimAllRounds(
    int homepageId,
    int gameRoomId, {
    required int group,
    String? password,
  }) async {
    final qp = <String, dynamic>{'group': group};
    if (password != null) qp['password'] = password;
    final res = await _apiClient.delete(
      '$_base/$homepageId/sections/$gameRoomId/de/prelim/rounds',
      queryParameters: qp,
    );
    return _asMap(res.data);
  }

  /// DE 본선 — 토너먼트 결과 전체 초기화 (비번 없음)
  Future<Map<String, dynamic>> resetDeBracket(
      int homepageId, int gameRoomId) async {
    final res = await _apiClient.delete(
      '$_base/$homepageId/sections/$gameRoomId/de/bracket/reset',
    );
    return _asMap(res.data);
  }

  /// 싱글 토너먼트 — 대진표 초기화 (비번 게이트)
  Future<Map<String, dynamic>> deleteTournamentBracket(
    int homepageId,
    int gameRoomId, {
    String? password,
  }) async {
    final res = await _apiClient.delete(
      '$_base/$homepageId/sections/$gameRoomId/tournament/bracket',
      queryParameters: password != null ? {'password': password} : null,
    );
    return _asMap(res.data);
  }

  /// 본선 매치 결과 저장/수정/해제 — winnerId=null 이면 해제. 서버가 승자 전파.
  Future<Map<String, dynamic>> saveDeBracketResult(
    int homepageId,
    int gameRoomId, {
    required int round,
    required int matchNumber,
    int? player1Id,
    String? player1Name,
    int? player2Id,
    String? player2Name,
    int? winnerId,
  }) async {
    final res = await _apiClient.put(
      '$_base/$homepageId/sections/$gameRoomId/de/bracket/result',
      data: {
        'round': round,
        'matchNumber': matchNumber,
        'player1Id': player1Id,
        'player1Name': player1Name,
        'player2Id': player2Id,
        'player2Name': player2Name,
        'winnerId': winnerId,
      },
    );
    return res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : <String, dynamic>{};
  }
}
