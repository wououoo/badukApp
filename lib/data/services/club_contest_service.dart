import '../api/api_client.dart';

/// 클럽 대회 운영 API 서비스
/// 다중 부문(Section) 지원 + 대회 수정/삭제
class ClubContestService {
  final ApiClient _apiClient;

  ClubContestService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  String _basePath(int clubId) => '/mobile/clubs/$clubId/contests';

  // ==================== 대회 CRUD ====================

  /// 대회 생성
  Future<Map<String, dynamic>> createContest(
      int clubId, String name, String date, bool rated,
      {int? eloKFactor, int? mcmahonKFactor}) async {
    final data = <String, String>{
      'name': name,
      'date': date,
      'rated': rated.toString(),
    };
    if (eloKFactor != null) data['eloKFactor'] = eloKFactor.toString();
    if (mcmahonKFactor != null) data['mcmahonKFactor'] = mcmahonKFactor.toString();
    final response = await _apiClient.post(
      _basePath(clubId),
      data: data,
    );
    return response.data;
  }

  /// 대회 수정
  Future<Map<String, dynamic>> updateContest(int clubId, int contestId, String name, String date,
      {bool? rated, int? eloKFactor, int? mcmahonKFactor}) async {
    final data = <String, String>{'name': name, 'date': date};
    if (rated != null) data['rated'] = rated.toString();
    if (eloKFactor != null) data['eloKFactor'] = eloKFactor.toString();
    if (mcmahonKFactor != null) data['mcmahonKFactor'] = mcmahonKFactor.toString();
    final response = await _apiClient.put(
      '${_basePath(clubId)}/$contestId',
      data: data,
    );
    return response.data;
  }

  /// 대회 삭제
  Future<Map<String, dynamic>> deleteContest(int clubId, int contestId) async {
    final response = await _apiClient.delete(
      '${_basePath(clubId)}/$contestId',
    );
    return response.data;
  }

  /// 대회 상세 조회
  Future<Map<String, dynamic>> getContestDetail(int clubId, int contestId) async {
    final response = await _apiClient.get('${_basePath(clubId)}/$contestId');
    return response.data;
  }

  // ==================== 부문(Section) CRUD ====================

  /// 부문 추가
  Future<Map<String, dynamic>> addSection(int clubId, int contestId, String name, String gameType, {int? teamSize}) async {
    final data = <String, dynamic>{'name': name, 'gameType': gameType};
    if (teamSize != null) data['teamSize'] = teamSize;
    final response = await _apiClient.post(
      '${_basePath(clubId)}/$contestId/sections',
      data: data,
    );
    return response.data;
  }

  /// 부문 수정
  Future<Map<String, dynamic>> updateSection(int clubId, int contestId, int sortId, String name, String gameType, {int? teamSize}) async {
    final data = <String, dynamic>{'name': name, 'gameType': gameType};
    if (teamSize != null) data['teamSize'] = teamSize;
    final response = await _apiClient.put(
      '${_basePath(clubId)}/$contestId/sections/$sortId',
      data: data,
    );
    return response.data;
  }

  /// 부문 삭제
  Future<Map<String, dynamic>> deleteSection(int clubId, int contestId, int sortId) async {
    final response = await _apiClient.delete(
      '${_basePath(clubId)}/$contestId/sections/$sortId',
    );
    return response.data;
  }

  /// 부문 목록 조회
  Future<Map<String, dynamic>> getSections(int clubId, int contestId) async {
    final response = await _apiClient.get('${_basePath(clubId)}/$contestId/sections');
    return response.data;
  }

  // ==================== 참가자 관리 (부문별) ====================

  /// 참가자 목록 조회
  Future<Map<String, dynamic>> getParticipants(int clubId, int contestId, int sortId) async {
    final response = await _apiClient.get('${_basePath(clubId)}/$contestId/sections/$sortId/participants');
    return response.data;
  }

  /// 참가자 추가 (멤버 userId 목록)
  Future<Map<String, dynamic>> addParticipants(int clubId, int contestId, int sortId, List<int> memberUserIds) async {
    final response = await _apiClient.post(
      '${_basePath(clubId)}/$contestId/sections/$sortId/participants',
      data: {'memberUserIds': memberUserIds},
    );
    return response.data;
  }

  /// 게스트(비회원) 참가자 추가
  Future<Map<String, dynamic>> addGuestParticipant(int clubId, int contestId, int sortId, String name, {int? level}) async {
    final data = <String, dynamic>{'name': name};
    if (level != null) data['level'] = level;
    final response = await _apiClient.post(
      '${_basePath(clubId)}/$contestId/sections/$sortId/participants/guest',
      data: data,
    );
    return response.data;
  }

  /// 참가자 수정 (이름/기력)
  Future<Map<String, dynamic>> updateParticipant(int clubId, int contestId, int sortId, int participantId, {String? name, int? level}) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (level != null) data['level'] = level;
    final response = await _apiClient.put(
      '${_basePath(clubId)}/$contestId/sections/$sortId/participants/$participantId',
      data: data,
    );
    return response.data;
  }

  /// 참가자 제거
  Future<Map<String, dynamic>> removeParticipant(int clubId, int contestId, int participantId) async {
    final response = await _apiClient.delete(
      '${_basePath(clubId)}/$contestId/participants/$participantId',
    );
    return response.data;
  }

  // ==================== 팀 관리 (단체전용) ====================

  /// 팀 목록 조회
  Future<Map<String, dynamic>> getTeams(int clubId, int contestId, int sortId) async {
    final response = await _apiClient.get('${_basePath(clubId)}/$contestId/sections/$sortId/teams');
    return response.data;
  }

  /// 팀 추가
  Future<Map<String, dynamic>> addTeam(int clubId, int contestId, int sortId, String teamName) async {
    final response = await _apiClient.post(
      '${_basePath(clubId)}/$contestId/sections/$sortId/teams',
      data: {'teamName': teamName},
    );
    return response.data;
  }

  /// 팀 삭제
  Future<Map<String, dynamic>> deleteTeam(int clubId, int contestId, int sortId, int teamId) async {
    final response = await _apiClient.delete(
      '${_basePath(clubId)}/$contestId/sections/$sortId/teams/$teamId',
    );
    return response.data;
  }

  /// 팀원 일괄 추가 (클럽 멤버 여러 명)
  Future<Map<String, dynamic>> addTeamMembers(int clubId, int contestId, int sortId, int teamId, List<Map<String, dynamic>> members) async {
    final response = await _apiClient.post(
      '${_basePath(clubId)}/$contestId/sections/$sortId/teams/$teamId/members',
      data: {'members': members},
    );
    return response.data;
  }

  /// 팀원 추가
  Future<Map<String, dynamic>> addTeamMember(int clubId, int contestId, int sortId, int teamId, {int? userId, required String name, required int position}) async {
    final response = await _apiClient.post(
      '${_basePath(clubId)}/$contestId/sections/$sortId/teams/$teamId/members',
      data: {'userId': userId, 'name': name, 'position': position},
    );
    return response.data;
  }

  /// 팀원 삭제
  Future<Map<String, dynamic>> removeTeamMember(int clubId, int contestId, int sortId, int teamId, int memberId) async {
    final response = await _apiClient.delete(
      '${_basePath(clubId)}/$contestId/sections/$sortId/teams/$teamId/members/$memberId',
    );
    return response.data;
  }

  // ==================== 대진표/라운드 관리 (부문별) ====================

  /// 대진표 생성
  Future<Map<String, dynamic>> generateRound(
      int clubId, int contestId, int sortId,
      {String matchingType = 'default', bool avoidClub = false}) async {
    final response = await _apiClient.post(
      '${_basePath(clubId)}/$contestId/sections/$sortId/generate-round',
      queryParameters: {
        'matchingType': matchingType,
        'avoidClub': avoidClub.toString(),
      },
    );
    return response.data;
  }

  /// 전체 대진표 조회
  Future<Map<String, dynamic>> getAllPairings(int clubId, int contestId, int sortId) async {
    final response = await _apiClient.get('${_basePath(clubId)}/$contestId/sections/$sortId/pairings');
    return response.data;
  }

  /// 라운드별 대진표 조회
  Future<Map<String, dynamic>> getPairingsByRound(int clubId, int contestId, int sortId, int round) async {
    final response = await _apiClient.get('${_basePath(clubId)}/$contestId/sections/$sortId/pairings/$round');
    return response.data;
  }

  /// 결과 저장
  Future<Map<String, dynamic>> saveResults(int clubId, int contestId, int sortId, List<Map<String, dynamic>> results) async {
    final response = await _apiClient.post(
      '${_basePath(clubId)}/$contestId/sections/$sortId/save-results',
      data: {'results': results},
    );
    return response.data;
  }

  /// 라운드 삭제
  Future<Map<String, dynamic>> deleteRound(int clubId, int contestId, int sortId, int round) async {
    final response = await _apiClient.delete(
      '${_basePath(clubId)}/$contestId/sections/$sortId/rounds/$round',
    );
    return response.data;
  }

  /// 순위 조회
  /// [sortBy] - 정렬 기준: 'wins' (승수순, 기본), 'score' (점수순) - 맥마흔 전용
  Future<Map<String, dynamic>> getRankings(int clubId, int contestId, int sortId, {String sortBy = 'wins'}) async {
    final response = await _apiClient.get(
      '${_basePath(clubId)}/$contestId/sections/$sortId/rankings',
      queryParameters: {'sortBy': sortBy},
    );
    return response.data;
  }

  /// 대진 선수 교체 (맥마흔 전용)
  Future<Map<String, dynamic>> swapPairingPlayers(int clubId, int contestId, int sortId, int round, int player1Id, int player2Id) async {
    final response = await _apiClient.post(
      '${_basePath(clubId)}/$contestId/sections/$sortId/pairings/swap',
      data: {'round': round, 'player1Id': player1Id, 'player2Id': player2Id},
    );
    return response.data;
  }

  // ==================== 맥마흔 설정 ====================

  /// 맥마흔 설정 조회
  Future<Map<String, dynamic>> getMcMahonConfig(int clubId, int contestId, int sortId) async {
    final response = await _apiClient.get('${_basePath(clubId)}/$contestId/sections/$sortId/mcmahon-config');
    return response.data;
  }

  /// 맥마흔 설정 수정
  Future<Map<String, dynamic>> updateMcMahonConfig(int clubId, int contestId, int sortId, Map<String, dynamic> config) async {
    final response = await _apiClient.put(
      '${_basePath(clubId)}/$contestId/sections/$sortId/mcmahon-config',
      data: config,
    );
    return response.data;
  }

  // ==================== 대회 종료/레이팅 ====================

  /// 대회 종료 + 레이팅 반영
  Future<Map<String, dynamic>> finishContest(int clubId, int contestId) async {
    final response = await _apiClient.post(
      '${_basePath(clubId)}/$contestId/finish',
    );
    return response.data;
  }

  /// 대회 종료 취소 + 레이팅 롤백
  Future<Map<String, dynamic>> unfinishContest(int clubId, int contestId) async {
    final response = await _apiClient.post(
      '${_basePath(clubId)}/$contestId/unfinish',
    );
    return response.data;
  }

  /// 클럽 랭킹 (type: 'elo' 또는 'mcmahon')
  Future<Map<String, dynamic>> getClubRatings(int clubId, {String type = 'elo'}) async {
    final response = await _apiClient.get(
      '${_basePath(clubId)}/ratings',
      queryParameters: {'type': type},
    );
    return response.data;
  }

  /// 레이팅 변동 히스토리 (type: 'elo' 또는 'mcmahon')
  Future<Map<String, dynamic>> getRatingHistory(int clubId, int userId, {String type = 'elo'}) async {
    final response = await _apiClient.get(
      '${_basePath(clubId)}/ratings/$userId/history',
      queryParameters: {'type': type},
    );
    return response.data;
  }
}
