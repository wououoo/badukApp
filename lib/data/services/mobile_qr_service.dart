import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/qr/my_contest.dart';
import '../models/qr/my_contest_detail.dart';

/// 모바일 QR/체크인 API 서비스
/// - 로그인된 사용자의 전화번호 기반 자동 대회 조회
/// - 체크인/체크인 취소
class MobileQRService {
  final ApiClient _apiClient;

  MobileQRService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// 내 참가 중인 활성 대회 목록 조회
  Future<List<MyContest>> getMyActiveContests() async {
    final response = await _apiClient.get('/mobile/qr/my-contests');

    if (response.data['success'] == true) {
      final contests = response.data['contests'] as List<dynamic>? ?? [];
      debugPrint('[내대회] API 응답 ${contests.length}건');
      for (final c in contests) {
        debugPrint('[내대회] contestId=${c['contestId']}, type=${c['contestType']}, sort=${c['sortName']}');
      }
      final result = <MyContest>[];
      for (final c in contests) {
        try {
          result.add(MyContest.fromJson(c));
        } catch (e) {
          debugPrint('[내대회] 파싱 실패: $e / data=$c');
        }
      }
      return result;
    }

    return [];
  }

  /// 특정 대회에서 내 상세 정보 조회
  Future<MyContestDetail?> getMyContestDetail(int contestId) async {
    final response = await _apiClient.get('/mobile/qr/contests/$contestId/me');

    if (response.data['success'] == true && response.data['contest'] != null) {
      return MyContestDetail.fromJson(response.data['contest']);
    }

    return null;
  }

  /// 체크인
  Future<CheckInResponse> checkIn(int contestId, {int? sortId}) async {
    final response = await _apiClient.post(
      '/mobile/qr/contests/$contestId/check-in',
      data: sortId != null ? {'sortId': sortId} : {},
    );

    return CheckInResponse.fromJson(response.data);
  }

  /// 체크인 취소
  Future<CheckInResponse> cancelCheckIn(int contestId, {int? sortId}) async {
    final response = await _apiClient.post(
      '/mobile/qr/contests/$contestId/check-in/cancel',
      data: sortId != null ? {'sortId': sortId} : {},
    );

    return CheckInResponse.fromJson(response.data);
  }

  /// 라운드 결과 조회
  Future<RoundResultResponse> getRoundResults(
    int contestId,
    int round, {
    int? sortId,
    String? contestType,
  }) async {
    final queryParams = <String, dynamic>{};
    if (sortId != null) queryParams['sortId'] = sortId;
    if (contestType != null) queryParams['contestType'] = contestType;

    final response = await _apiClient.get(
      '/mobile/qr/contests/$contestId/rounds/$round',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    return RoundResultResponse.fromJson(response.data);
  }

  /// 순위표 조회
  /// [sortBy] - 정렬 기준 (wins: 승수순, score: 점수순) - MCM 전용
  Future<RankingsResponse> getRankings(int contestId, {int? sortId, String sortBy = 'wins', String? contestType}) async {
    final queryParams = <String, dynamic>{'sortBy': sortBy};
    if (sortId != null) queryParams['sortId'] = sortId;
    if (contestType != null) queryParams['contestType'] = contestType;

    final response = await _apiClient.get(
      '/mobile/qr/contests/$contestId/rankings',
      queryParameters: queryParams,
    );

    return RankingsResponse.fromJson(response.data);
  }

  /// 풀리그 전체 스케줄 조회 (Circle Method 기반 모든 라운드)
  Future<FullLeagueScheduleResponse> getFullLeagueSchedule(int gameRoomId) async {
    final response = await _apiClient.get('/fullleague/schedule/$gameRoomId');

    return FullLeagueScheduleResponse.fromJson(response.data);
  }

  /// 단체 풀리그 전체 스케줄 조회 (팀 매치 + 기별 상세)
  Future<TeamFullLeagueScheduleResponse> getTeamFullLeagueSchedule(int gameRoomId) async {
    final response = await _apiClient.get('/team-league/$gameRoomId/schedule');
    return TeamFullLeagueScheduleResponse.fromJson(response.data);
  }

  /// 토너먼트(본선) 대진표 전체 조회 (TournamentPlayer 기반 동적 생성 + 저장된 결과 병합)
  Future<TournamentBracketResponse> getTournamentBracket(int gameRoomId) async {
    final response = await _apiClient.get('/tournament/full-bracket/$gameRoomId');
    return TournamentBracketResponse.fromJson(response.data);
  }

  /// 동명이인 선택 - 참가자와 전화번호 연결
  Future<LinkParticipantResponse> linkParticipant(
    int contestId,
    int participantId,
    int gameRoomId,
  ) async {
    final response = await _apiClient.post(
      '/mobile/qr/contests/$contestId/link',
      data: {
        'participantId': participantId,
        'gameRoomId': gameRoomId,
      },
    );

    return LinkParticipantResponse.fromJson(response.data);
  }
}

/// 동명이인 연결 응답
class LinkParticipantResponse {
  final bool success;
  final String? message;
  final String? participantName;

  LinkParticipantResponse({
    required this.success,
    this.message,
    this.participantName,
  });

  factory LinkParticipantResponse.fromJson(Map<String, dynamic> json) {
    return LinkParticipantResponse(
      success: json['success'] ?? false,
      message: json['message'],
      participantName: json['participantName'],
    );
  }
}

/// 체크인 응답
class CheckInResponse {
  final bool success;
  final String? message;
  final DateTime? checkInTime;
  final DateTime? checkInDate;

  CheckInResponse({
    required this.success,
    this.message,
    this.checkInTime,
    this.checkInDate,
  });

  factory CheckInResponse.fromJson(Map<String, dynamic> json) {
    return CheckInResponse(
      success: json['success'] ?? false,
      message: json['message'],
      checkInTime: json['checkInTime'] != null
          ? DateTime.parse(json['checkInTime'])
          : null,
      checkInDate: json['checkInDate'] != null
          ? DateTime.parse(json['checkInDate'])
          : null,
    );
  }
}

/// 라운드 결과 응답
class RoundResultResponse {
  final bool success;
  final int round;
  final List<MatchResult> matches;
  final String? message;

  RoundResultResponse({
    required this.success,
    this.round = 0,
    this.matches = const [],
    this.message,
  });

  factory RoundResultResponse.fromJson(Map<String, dynamic> json) {
    return RoundResultResponse(
      success: json['success'] ?? false,
      round: json['round'] ?? 0,
      matches: (json['matches'] as List<dynamic>?)
          ?.map((m) => MatchResult.fromJson(m))
          .toList() ?? [],
      message: json['message'],
    );
  }
}

/// 매치 결과
class MatchResult {
  final String player1;
  final String? player2;
  final int player1Id;
  final int? player2Id;
  final int? winnerId;
  final int? tableNumber;
  final bool isByeMatch;
  final bool isNone; // 양패 (둘 다 패배 처리)
  final bool isTie;  // 단체전 팀 무승부 (TEAM1/TEAM2 어느 쪽도 아닌 TIE)
  final bool isCompleted;
  final int? group;  // DE 조 번호

  // 단체전 전용
  final int? team1Wins;
  final int? team2Wins;
  final List<BoardResult> boards;

  MatchResult({
    required this.player1,
    this.player2,
    required this.player1Id,
    this.player2Id,
    this.winnerId,
    this.tableNumber,
    this.isByeMatch = false,
    this.isNone = false,
    this.isTie = false,
    this.isCompleted = false,
    this.group,
    this.team1Wins,
    this.team2Wins,
    this.boards = const [],
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    // 양패: 백엔드 isNone (또는 하위호환 none) true
    final bool none = json['isNone'] == true || json['none'] == true;
    // 부전승: player2가 없는 진짜 부전승만. (isByeMatch가 양패와 합쳐져 오는 옛 응답 방어)
    final bool bye = (json['player2Id'] == null && json['player2'] == null && !none)
        || (json['isByeMatch'] == true && !none);
    return MatchResult(
      player1: json['player1'] ?? '',
      player2: json['player2'],
      player1Id: json['player1Id'] ?? 0,
      player2Id: json['player2Id'],
      winnerId: json['winnerId'],
      tableNumber: json['tableNumber'],
      isByeMatch: bye,
      isNone: none,
      isTie: json['isTie'] == true,
      isCompleted: json['isCompleted'] ?? (json['winnerId'] != null || none),
      group: json['group'],
      team1Wins: json['team1Wins'],
      team2Wins: json['team2Wins'],
      boards: (json['boards'] as List<dynamic>?)
          ?.map((b) => BoardResult.fromJson(b))
          .toList() ?? [],
    );
  }

  /// 승자 이름
  String? get winnerName {
    if (winnerId == null) return null;
    if (winnerId == player1Id) return player1;
    if (winnerId == player2Id) return player2;
    return null;
  }
}

/// 단체전 기별 결과
class BoardResult {
  final int boardNumber;
  final int? team1MemberId;
  final String? team1MemberName;
  final int? team2MemberId;
  final String? team2MemberName;
  final int? winnerMemberId;
  final bool isCompleted;

  BoardResult({
    required this.boardNumber,
    this.team1MemberId,
    this.team1MemberName,
    this.team2MemberId,
    this.team2MemberName,
    this.winnerMemberId,
    this.isCompleted = false,
  });

  factory BoardResult.fromJson(Map<String, dynamic> json) {
    return BoardResult(
      boardNumber: json['boardNumber'] ?? 0,
      team1MemberId: json['team1MemberId'],
      team1MemberName: json['team1MemberName'],
      team2MemberId: json['team2MemberId'],
      team2MemberName: json['team2MemberName'],
      winnerMemberId: json['winnerMemberId'],
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

/// 순위표 응답
class RankingsResponse {
  final bool success;
  final List<RankingEntry> rankings;
  final String? message;

  RankingsResponse({
    required this.success,
    this.rankings = const [],
    this.message,
  });

  factory RankingsResponse.fromJson(Map<String, dynamic> json) {
    return RankingsResponse(
      success: json['success'] ?? false,
      rankings: (json['rankings'] as List<dynamic>?)
          ?.map((r) => RankingEntry.fromJson(r))
          .toList() ?? [],
      message: json['message'],
    );
  }
}

/// 순위 항목
class RankingEntry {
  final int rank;
  final String name;
  final int wins;
  final int losses;
  final double? score;
  final int? group;  // DE 조 번호
  final String? division;  // MCM 조 (갑, 을, 병 등)

  // 스위스리그 전용
  final double? sos;    // SOS (Sum of Opponent Scores)
  final double? sosos;  // SOSOS (Sum of Opponent SOS)

  // 풀리그 전용
  final String? winRate;

  // 단체전 전용
  final int? draws;
  final int? pointDiff;
  final int? boardWins;
  final List<int>? playerWins;  // 선수별 승수 (1장~N장)

  // 유럽식 맥마흔 전용
  final bool europeanMode;
  final double? displayGameScore;  // gameScore / 4.0
  final double? sodos;  // SODOS
  final int? jigoes;  // 비김 횟수
  final String? club;

  RankingEntry({
    required this.rank,
    required this.name,
    this.wins = 0,
    this.losses = 0,
    this.score,
    this.group,
    this.division,
    this.sos,
    this.sosos,
    this.winRate,
    this.draws,
    this.pointDiff,
    this.boardWins,
    this.playerWins,
    this.europeanMode = false,
    this.displayGameScore,
    this.sodos,
    this.jigoes,
    this.club,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    // 선수별 승수 파싱 (player1Wins ~ player10Wins)
    List<int>? playerWins;
    int count = 0;
    for (int i = 1; i <= 10; i++) {
      if (json['player${i}Wins'] != null) count = i;
    }
    if (count > 0) {
      playerWins = [];
      for (int i = 1; i <= count; i++) {
        playerWins.add((json['player${i}Wins'] as num?)?.toInt() ?? 0);
      }
    }

    return RankingEntry(
      rank: json['rank'] ?? 0,
      name: json['name'] ?? '',
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      score: json['score'] is num ? (json['score'] as num).toDouble() : null,
      group: json['group'],
      division: json['division'],
      sos: json['sos'] is num ? (json['sos'] as num).toDouble() : null,
      sosos: json['sosos'] is num ? (json['sosos'] as num).toDouble() : null,
      winRate: json['winRate']?.toString(),
      draws: (json['draws'] as num?)?.toInt(),
      pointDiff: (json['pointDiff'] as num?)?.toInt(),
      boardWins: (json['boardWins'] as num?)?.toInt(),
      playerWins: playerWins,
      europeanMode: json['europeanMode'] ?? false,
      displayGameScore: json['displayGameScore'] is num ? (json['displayGameScore'] as num).toDouble() : null,
      sodos: json['sodos'] is num ? (json['sodos'] as num).toDouble() : null,
      jigoes: (json['jigoes'] as num?)?.toInt(),
      club: json['club'],
    );
  }

  /// 전적 표시
  String get record => '$wins승 $losses패';
}

/// 토너먼트 브래킷 응답
class TournamentBracketResponse {
  final List<TournamentBracketMatch> matches;
  final int totalRounds; // 백엔드에서 참가자 수 기반으로 계산

  TournamentBracketResponse({this.matches = const [], this.totalRounds = 0});

  factory TournamentBracketResponse.fromJson(dynamic json) {
    if (json is List) {
      final parsed = json.map((m) => TournamentBracketMatch.fromJson(m)).toList();
      // 첫 번째 매치에서 totalRounds 추출
      final tr = parsed.isNotEmpty ? parsed.first.totalRounds : 0;
      return TournamentBracketResponse(matches: parsed, totalRounds: tr);
    }
    return TournamentBracketResponse();
  }

  /// 토너먼트 매치 (round 0 예선전 포함)
  List<TournamentBracketMatch> get mainMatches =>
      matches;

  /// 라운드 번호 목록 (정렬)
  List<int> get rounds {
    final r = mainMatches.map((m) => m.round).toSet().toList()..sort();
    return r;
  }

  /// 특정 라운드의 매치
  List<TournamentBracketMatch> matchesForRound(int round) =>
      mainMatches.where((m) => m.round == round).toList()
        ..sort((a, b) => a.matchNumber.compareTo(b.matchNumber));

  /// 라운드 번호 → 단계명 (totalRounds 기반)
  String getStageName(int round) {
    if (round == 0) return '예선전';
    if (rounds.isEmpty) return '$round회전';
    // totalRounds에서 예선전(round 0)이 있으면 1 차감
    final hasPreliminaries = rounds.contains(0);
    final maxRound = totalRounds > 0
        ? (hasPreliminaries ? totalRounds - 1 : totalRounds)
        : rounds.last;
    final distance = maxRound - round;
    switch (distance) {
      case 0: return '결승';
      case 1: return '4강';
      case 2: return '8강';
      case 3: return '16강';
      case 4: return '32강';
      default: return '$round회전';
    }
  }
}

/// 토너먼트 개별 매치
class TournamentBracketMatch {
  final int id;
  final int round;
  final int matchNumber;
  final int? player1Id;
  final String? player1Name;
  final int? player2Id;
  final String? player2Name;
  final int? winnerId;
  final bool isFirstStage;
  final int totalRounds;

  TournamentBracketMatch({
    required this.id,
    required this.round,
    required this.matchNumber,
    this.player1Id,
    this.player1Name,
    this.player2Id,
    this.player2Name,
    this.winnerId,
    this.isFirstStage = true,
    this.totalRounds = 0,
  });

  factory TournamentBracketMatch.fromJson(Map<String, dynamic> json) {
    final p1 = json['player1'];
    final p2 = json['player2'];
    return TournamentBracketMatch(
      id: json['id'] ?? 0,
      round: json['round'] ?? 0,
      matchNumber: json['matchNumber'] ?? 0,
      player1Id: p1 is Map ? p1['id'] : null,
      player1Name: p1 is Map ? p1['playerName'] : null,
      player2Id: p2 is Map ? p2['id'] : null,
      player2Name: p2 is Map ? p2['playerName'] : null,
      winnerId: json['winner'],
      isFirstStage: json['isFirstStage'] ?? json['firstStage'] ?? true,
      totalRounds: json['totalRounds'] ?? 0,
    );
  }

  bool get isCompleted => winnerId != null;
  bool get isWaiting => player1Id == null || player2Id == null;

  /// 기존 MatchResult 형식으로 변환 (카드 재사용)
  MatchResult toMatchResult() {
    return MatchResult(
      player1: player1Name ?? '대기',
      player2: player2Name ?? '대기',
      player1Id: player1Id ?? 0,
      player2Id: player2Id,
      winnerId: winnerId,
      tableNumber: null, // 토너먼트 본선은 테이블 번호 미표시
      isByeMatch: player2Id == null && player1Id != null && isCompleted,
      isCompleted: winnerId != null,
    );
  }
}

/// 풀리그 전체 스케줄 응답
class FullLeagueScheduleResponse {
  final int totalRounds;
  final int participantCount;
  final List<FullLeagueRound> rounds;

  FullLeagueScheduleResponse({
    this.totalRounds = 0,
    this.participantCount = 0,
    this.rounds = const [],
  });

  factory FullLeagueScheduleResponse.fromJson(Map<String, dynamic> json) {
    return FullLeagueScheduleResponse(
      totalRounds: json['totalRounds'] ?? 0,
      participantCount: json['participantCount'] ?? 0,
      rounds: (json['rounds'] as List<dynamic>?)
          ?.map((r) => FullLeagueRound.fromJson(r))
          .toList() ?? [],
    );
  }
}

/// 풀리그 라운드 정보
class FullLeagueRound {
  final int round;
  final List<FullLeagueMatch> matches;
  final String? restingPlayer;  // 홀수 인원 시 쉬는 선수
  final bool hasResults;
  final List<dynamic> results;  // ContestRoundResult 원본 데이터

  FullLeagueRound({
    required this.round,
    this.matches = const [],
    this.restingPlayer,
    this.hasResults = false,
    this.results = const [],
  });

  factory FullLeagueRound.fromJson(Map<String, dynamic> json) {
    final matches = (json['matches'] as List<dynamic>?)
        ?.map((m) => FullLeagueMatch.fromJson(m))
        .toList() ?? [];
    final hasResults = json['hasResults'] ?? false;
    final results = json['results'] as List<dynamic>? ?? [];

    // 결과가 있으면 매치에 승패 정보 병합 — id 기반(동명이인 안전), id 없으면 이름 폴백. 양패(none) 처리.
    if (hasResults && results.isNotEmpty) {
      for (final match in matches) {
        for (final r in results) {
          if (r is! Map<String, dynamic>) continue;
          final pid = r['participantId'];
          final oid = r['opponentId'];
          final bool byId = pid != null && oid != null &&
              ((pid == match.player1Id && oid == match.player2Id) ||
                  (pid == match.player2Id && oid == match.player1Id));
          final bool byName = (pid == null || oid == null) &&
              r['nonUserName']?.toString() == match.player1 &&
              r['opponentName']?.toString() == match.player2;
          if (!byId && !byName) continue;

          final bool end = r['end'] == true;
          final bool none = r['none'] == true;
          final bool win = r['win'] == true;
          match.isNone = none;
          if (none) {
            match.isCompleted = true;
            match.winnerId = null;
            match.winner = null;
          } else if (end) {
            match.isCompleted = true;
            // 이 레코드 관점(participantId)이 player1인지로 승자 id 결정
            final bool recIsP1 = byId
                ? (pid == match.player1Id)
                : (r['nonUserName']?.toString() == match.player1);
            match.winnerId = win
                ? (recIsP1 ? match.player1Id : match.player2Id)
                : (recIsP1 ? match.player2Id : match.player1Id);
            match.winner = r['winner']?.toString();
          }
          break;
        }
      }
    }

    return FullLeagueRound(
      round: json['round'] ?? 0,
      matches: matches,
      restingPlayer: json['restingPlayer']?.toString(),
      hasResults: hasResults,
      results: results,
    );
  }
}

/// 풀리그 매치 정보 (스케줄 기반)
class FullLeagueMatch {
  final String player1;
  final String player2;
  final int? player1Id;
  final int? player2Id;
  final int round;
  final int matchNumber;

  // 결과 정보 (hasResults일 때 results에서 매핑)
  String? winner;
  int? winnerId;   // id기반 승자 판정 (동명이인 안전)
  bool isCompleted;
  bool isNone;     // 양패 (둘 다 패배 처리)
  bool isBye;

  FullLeagueMatch({
    required this.player1,
    required this.player2,
    this.player1Id,
    this.player2Id,
    required this.round,
    this.matchNumber = 0,
    this.winner,
    this.winnerId,
    this.isCompleted = false,
    this.isNone = false,
    this.isBye = false,
  });

  factory FullLeagueMatch.fromJson(Map<String, dynamic> json) {
    final p2 = json['player2']?.toString() ?? '';
    return FullLeagueMatch(
      player1: json['player1']?.toString() ?? '',
      player2: p2,
      player1Id: json['player1Id'] as int?,
      player2Id: json['player2Id'] as int?,
      round: json['round'] ?? 0,
      matchNumber: json['matchNumber'] ?? 0,
      isBye: p2 == '없음' || p2.isEmpty,
    );
  }
}

/// 단체 풀리그 전체 스케줄 응답
class TeamFullLeagueScheduleResponse {
  final int totalRounds;
  final int teamCount;
  final int currentRound;
  final List<TeamFullLeagueRound> rounds;

  TeamFullLeagueScheduleResponse({
    this.totalRounds = 0,
    this.teamCount = 0,
    this.currentRound = 0,
    this.rounds = const [],
  });

  factory TeamFullLeagueScheduleResponse.fromJson(Map<String, dynamic> json) {
    return TeamFullLeagueScheduleResponse(
      totalRounds: json['totalRounds'] ?? 0,
      teamCount: json['teamCount'] ?? 0,
      currentRound: json['currentRound'] ?? 0,
      rounds: (json['rounds'] as List<dynamic>?)
          ?.map((r) => TeamFullLeagueRound.fromJson(r))
          .toList() ?? [],
    );
  }
}

/// 단체 풀리그 라운드 정보
class TeamFullLeagueRound {
  final int round;
  final bool started;
  final String? restingTeamName;
  final List<TeamFullLeagueMatch> matches;

  TeamFullLeagueRound({
    required this.round,
    this.started = false,
    this.restingTeamName,
    this.matches = const [],
  });

  factory TeamFullLeagueRound.fromJson(Map<String, dynamic> json) {
    return TeamFullLeagueRound(
      round: json['round'] ?? 0,
      started: json['started'] ?? false,
      restingTeamName: json['restingTeamName'],
      matches: (json['matches'] as List<dynamic>?)
          ?.map((m) => TeamFullLeagueMatch.fromJson(m))
          .toList() ?? [],
    );
  }
}

/// 단체 풀리그 팀 매치 정보
class TeamFullLeagueMatch {
  final int? id;
  final String team1Name;
  final String team2Name;
  final int team1Id;
  final int team2Id;
  final int team1Wins;
  final int team2Wins;
  final int? winnerTeamId;
  final bool isCompleted;
  final List<BoardResult> boards;

  TeamFullLeagueMatch({
    this.id,
    required this.team1Name,
    required this.team2Name,
    required this.team1Id,
    required this.team2Id,
    this.team1Wins = 0,
    this.team2Wins = 0,
    this.winnerTeamId,
    this.isCompleted = false,
    this.boards = const [],
  });

  factory TeamFullLeagueMatch.fromJson(Map<String, dynamic> json) {
    return TeamFullLeagueMatch(
      id: json['id'],
      team1Name: json['team1Name']?.toString() ?? '',
      team2Name: json['team2Name']?.toString() ?? '',
      team1Id: json['team1Id'] ?? 0,
      team2Id: json['team2Id'] ?? 0,
      team1Wins: json['team1Wins'] ?? 0,
      team2Wins: json['team2Wins'] ?? 0,
      winnerTeamId: json['winnerTeamId'],
      isCompleted: json['isCompleted'] ?? false,
      boards: (json['boards'] as List<dynamic>?)
          ?.map((b) => BoardResult.fromJson(b))
          .toList() ?? [],
    );
  }

  /// BYE 매치인지 확인
  bool get isBye => team2Name == '없음(BYE)' || team2Name == 'BYE';
}
