import 'contest_sort.dart';

/// 대회 목록 응답 (페이징)
class LiveContestListResponse {
  final List<LiveContest> content;
  final int totalElements;
  final int totalPages;
  final int number;
  final bool last;

  LiveContestListResponse({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.number,
    required this.last,
  });

  factory LiveContestListResponse.fromJson(Map<String, dynamic> json) {
    final contentList = (json['content'] as List<dynamic>?)
            ?.map((e) => LiveContest.fromJson(e))
            .toList() ??
        [];

    return LiveContestListResponse(
      content: contentList,
      totalElements: json['totalElements'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      number: json['number'] ?? 0,
      last: json['last'] ?? true,
    );
  }
}

/// 대회 목록 아이템
class LiveContest {
  final int id;
  final String name;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? type;
  final List<String> types;   // 복수 유형 (연결대회 포함) — 백엔드 제공, 표시용
  final String? status;
  final String? location;
  final String? contestProv;
  final String? contestDetailLocation;
  final int? sortCount;
  final int? totalParticipants;
  final int? currentRound;
  final int? maxRound;
  final List<LiveContestSort> sorts;
  final List<LiveLinkedContest> linkedContests;  // 묶은(연결) 대회들 — 목록 카드 표시용

  LiveContest({
    required this.id,
    required this.name,
    this.startDate,
    this.endDate,
    this.type,
    this.types = const [],
    this.status,
    this.location,
    this.contestProv,
    this.contestDetailLocation,
    this.sortCount,
    this.totalParticipants,
    this.currentRound,
    this.maxRound,
    this.sorts = const [],
    this.linkedContests = const [],
  });

  factory LiveContest.fromJson(Map<String, dynamic> json) {
    final sortsList = (json['sorts'] as List<dynamic>?)
            ?.map((e) => LiveContestSort.fromJson(e))
            .toList() ??
        [];

    // 복수 유형: types 우선, 없으면 단일 type로 폴백
    final typesList = (json['types'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        (json['type'] != null ? [json['type'].toString()] : <String>[]);

    return LiveContest(
      id: json['id'] ?? json['contestId'] ?? 0,
      name: json['name'] ?? json['contestName'] ?? '',
      startDate: _parseDate(json['startDate']),
      endDate: _parseDate(json['endDate']),
      type: json['type'],
      types: typesList,
      status: json['status'],
      location: json['contestLocation'] ?? json['location'],
      contestProv: json['contestProv'],
      contestDetailLocation: json['contestDetailLocation'],
      sortCount: json['sortCount'],
      totalParticipants: json['totalParticipants'],
      currentRound: json['currentRound'],
      maxRound: json['maxRound'] ?? json['totalRounds'],
      sorts: sortsList,
      linkedContests: (json['linkedContests'] as List<dynamic>?)
              ?.map((e) => LiveLinkedContest.fromJson(e))
              .toList() ??
          [],
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is List && value.length >= 3) {
      return DateTime(value[0], value[1], value[2]);
    }
    return DateTime.tryParse(value.toString());
  }

  String get roundText {
    if (currentRound == null || maxRound == null) return '';
    return '$currentRound/$maxRound 라운드';
  }

  bool get isOngoing => status == 'ONGOING';
}

/// 연결된(묶은) 대회 — 목록 카드의 "연결된 대회" 표시용
class LiveLinkedContest {
  final int id;
  final String contestName;
  final List<String> types;

  LiveLinkedContest({
    required this.id,
    required this.contestName,
    this.types = const [],
  });

  factory LiveLinkedContest.fromJson(Map<String, dynamic> json) {
    return LiveLinkedContest(
      id: json['id'] ?? 0,
      contestName: json['contestName'] ?? json['name'] ?? '',
      types: (json['types'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

/// 대회 상세
class LiveContestDetail {
  final int id;
  final String contestName;
  final String? contestProv;
  final String? contestLocation;
  final String? contestDetailLocation;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? type;
  final String? status;
  final List<LiveContestSort> sorts;
  final List<LinkedContestDetail> linkedContests;

  LiveContestDetail({
    required this.id,
    required this.contestName,
    this.contestProv,
    this.contestLocation,
    this.contestDetailLocation,
    this.startDate,
    this.endDate,
    this.type,
    this.status,
    this.sorts = const [],
    this.linkedContests = const [],
  });

  factory LiveContestDetail.fromJson(Map<String, dynamic> json) {
    final sortsList = (json['sorts'] as List<dynamic>?)
            ?.map((e) => LiveContestSort.fromJson(e))
            .toList() ??
        [];
    final linkedList = (json['linkedContests'] as List<dynamic>?)
            ?.map((e) => LinkedContestDetail.fromJson(e))
            .toList() ??
        [];

    return LiveContestDetail(
      id: json['id'] ?? 0,
      contestName: json['contestName'] ?? '',
      contestProv: json['contestProv'],
      contestLocation: json['contestLocation'],
      contestDetailLocation: json['contestDetailLocation'],
      startDate: LiveContest._parseDate(json['startDate']),
      endDate: LiveContest._parseDate(json['endDate']),
      type: json['type'],
      status: json['status'],
      sorts: sortsList,
      linkedContests: linkedList,
    );
  }

  String get fullLocation {
    final parts = <String>[];
    if (contestLocation != null) parts.add(contestLocation!);
    if (contestDetailLocation != null) parts.add(contestDetailLocation!);
    return parts.join(' ');
  }
}

/// 연결된 대회
class LinkedContestDetail {
  final int id;
  final String contestName;
  final String? type;
  final List<LiveContestSort> sorts;

  LinkedContestDetail({
    required this.id,
    required this.contestName,
    this.type,
    this.sorts = const [],
  });

  factory LinkedContestDetail.fromJson(Map<String, dynamic> json) {
    final sortsList = (json['sorts'] as List<dynamic>?)
            ?.map((e) => LiveContestSort.fromJson(e))
            .toList() ??
        [];

    return LinkedContestDetail(
      id: json['id'] ?? 0,
      contestName: json['contestName'] ?? '',
      type: json['type'],
      sorts: sortsList,
    );
  }
}

class LiveContestSort extends ContestSort {
  @override
  final int? currentRound;
  final String? sortType;

  LiveContestSort({
    required int id,
    required String name,
    int? fee,
    int? gameRoomId,
    int? participantCount,
    int? maxRound,
    int? teamSize,
    int? teamCount,
    String? contestType,
    this.currentRound,
    this.sortType,
  }) : super(
          id: id,
          name: name,
          fee: fee,
          gameRoomId: gameRoomId,
          participantCount: participantCount,
          currentRound: currentRound,
          maxRound: maxRound,
          teamSize: teamSize,
          teamCount: teamCount,
          contestType: contestType,
        );

  factory LiveContestSort.fromJson(Map<String, dynamic> json) {
    return LiveContestSort(
      id: json['id'] ?? json['sortId'] ?? 0,
      name: json['name'] ?? json['sortName'] ?? '',
      fee: json['fee'],
      gameRoomId: json['gameRoomId'],
      participantCount: json['participantCount'] ?? json['currentParticipants'],
      maxRound: json['maxRound'],
      teamSize: json['teamSize'],
      teamCount: json['teamCount'],
      contestType: json['contestType'] ?? json['type'] ?? json['gameType'],
      currentRound: json['currentRound'],
      sortType: json['sortType'],
    );
  }
}

/// 대진표 응답
class LivePairingsResponse {
  final List<LivePairing> pairings;
  final int maxRound;
  final int? round;
  final int? gameRoomId;
  final String? contestType;
  // 풀리그 홀수 인원: 라운드별 쉬는 선수(부전승) 이름 { round: name }
  final Map<int, String> restingByRound;

  LivePairingsResponse({
    required this.pairings,
    required this.maxRound,
    this.round,
    this.gameRoomId,
    this.contestType,
    this.restingByRound = const {},
  });

  factory LivePairingsResponse.fromJson(Map<String, dynamic> json) {
    List<LivePairing> pairingsList = [];
    final Map<int, String> restingByRound = {};

    // 기본 pairings 배열
    final contestType = json['contestType']?.toString();
    final rawPairings = json['pairings'] as List<dynamic>?;
    if (rawPairings != null) {
      for (var item in rawPairings) {
        if (item is Map<String, dynamic>) {
          // 풀리그/단체전 형식: rounds 배열 안에 matches 또는 results가 있음
          if (item.containsKey('matches') || item.containsKey('results')) {
            final round = item['round'] as int? ?? 1;
            final matches = item['matches'] as List<dynamic>? ?? [];
            final results = item['results'] as List<dynamic>? ?? [];

            // 풀리그 쉬는 선수(부전승) 라운드별 보존
            final resting = item['restingPlayer']?.toString();
            if (resting != null && resting.isNotEmpty) {
              restingByRound[round] = resting;
            }

            // 웹 LivePairingsTable과 동일한 소스 선택 (matches+results 둘 다 넣으면 중복됨):
            // TEAM_FULL_LEAGUE=matches, TEAM_SWISS=results, FULL_LEAGUE=results 우선·없으면 matches
            List<dynamic> source;
            bool fromMatches;
            if (contestType == 'TEAM_FULL_LEAGUE') {
              source = matches;
              fromMatches = true;
            } else if (contestType == 'TEAM_SWISS') {
              source = results;
              fromMatches = false;
            } else {
              // FULL_LEAGUE 등: 결과가 있으면 결과, 없으면 스케줄
              if (results.isNotEmpty) {
                source = results;
                fromMatches = false;
              } else {
                source = matches;
                fromMatches = true;
              }
            }

            for (var m in source) {
              if (m is! Map<String, dynamic>) continue;
              if (m.containsKey('team1Name') || fromMatches) {
                pairingsList.add(LivePairing.fromFullLeagueJson(m, round));
              } else {
                pairingsList.add(LivePairing.fromJson(m));
              }
            }
          } else {
            // 일반 형식 (플랫 배열)
            pairingsList.add(LivePairing.fromJson(item));
          }
        }
      }
    }

    return LivePairingsResponse(
      pairings: pairingsList,
      maxRound: json['maxRound'] ?? 0,
      round: json['round'],
      gameRoomId: json['gameRoomId'],
      contestType: json['contestType'],
      restingByRound: restingByRound,
    );
  }
}

/// 단체전 보드별(장별) 개인 매치 결과
class BoardResult {
  final int? id;
  final int boardNumber;
  final int? team1MemberId;
  final String? team1MemberName;
  final int? team2MemberId;
  final String? team2MemberName;
  final int? winnerMemberId;
  final bool isCompleted;

  BoardResult({
    this.id,
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
      id: json['id'],
      boardNumber: json['boardNumber'] ?? 0,
      team1MemberId: json['team1MemberId'],
      team1MemberName: json['team1MemberName'],
      team2MemberId: json['team2MemberId'],
      team2MemberName: json['team2MemberName'],
      winnerMemberId: json['winnerMemberId'],
      isCompleted: json['isCompleted'] == true,
    );
  }

  bool get isTeam1Winner =>
      isCompleted && winnerMemberId != null && winnerMemberId == team1MemberId;
  bool get isTeam2Winner =>
      isCompleted && winnerMemberId != null && winnerMemberId == team2MemberId;
}

class LivePairing {
  final int? id;
  final int? round;
  final int? tableNumber;
  final String? status;

  // Player 1 (흑 또는 팀1)
  final int? player1Id;
  final String? player1Name;
  final int? player1Score;
  final String? player1Nationality;
  final String? player1Club;

  // Player 2 (백 또는 팀2)
  final int? player2Id;
  final String? player2Name;
  final int? player2Score;
  final String? player2Nationality;
  final String? player2Club;

  // 결과
  final int? winnerId;
  final String? winnerName;
  final bool isByeMatch;
  final bool isNone; // 양패 (둘 다 패배 처리)
  final bool isCompleted;

  // 단체전 보드별 결과
  final List<BoardResult> boards;

  LivePairing({
    this.id,
    this.round,
    this.tableNumber,
    this.status,
    this.player1Id,
    this.player1Name,
    this.player1Score,
    this.player1Nationality,
    this.player1Club,
    this.player2Id,
    this.player2Name,
    this.player2Score,
    this.player2Nationality,
    this.player2Club,
    this.winnerId,
    this.winnerName,
    this.isByeMatch = false,
    this.isNone = false,
    this.isCompleted = false,
    this.boards = const [],
  });

  factory LivePairing.fromJson(Map<String, dynamic> json) {
    // 통일 필드: player1Name (하위호환: player1, blackPlayer)
    final p1Name = json['player1Name'] ?? json['player1'] ?? json['blackPlayer'];
    // 통일 필드: player2Name (하위호환: player2, whitePlayer)
    final p2Name = json['player2Name'] ?? json['player2'] ?? json['whitePlayer'];
    // 통일 필드: isNone (하위호환: none) — 양패: 둘 다 패배 처리
    final isNone = json['isNone'] == true || json['none'] == true;
    // 통일 필드: isCompleted (하위호환: end)
    final isEnd = json['isCompleted'] == true || json['end'] == true || isNone;
    // 부전승: 진짜 부전승만 (player2 없음 또는 isByeMatch=true). 양패는 isBye에 포함하지 않음.
    final isBye = !isNone && (json['isByeMatch'] == true ||
        (p2Name == null || p2Name.toString().isEmpty));

    return LivePairing(
      id: json['id'],
      round: json['round'],
      // 통일 필드: matchNumber (하위호환: tableNumber, player1Number)
      tableNumber: json['matchNumber'] ?? json['tableNumber'] ?? json['player1Number'],
      status: json['status'],
      player1Id: json['player1Id'],
      player1Name: p1Name?.toString(),
      player1Score: json['player1Score'],
      player1Nationality: json['player1Nationality'],
      player1Club: json['player1Club'],
      player2Id: json['player2Id'],
      player2Name: p2Name?.toString(),
      player2Score: json['player2Score'],
      player2Nationality: json['player2Nationality'],
      player2Club: json['player2Club'],
      winnerId: json['winnerId'],
      // 통일 필드: winnerName (하위호환: winner)
      winnerName: json['winnerName'] ?? json['winner'],
      isByeMatch: isBye,
      isNone: isNone,
      isCompleted: isEnd,
    );
  }

  /// 풀리그/단체전풀리그 형식 파싱
  /// 통일 필드: team1Name/team2Name, winnerId(=winnerTeamId), isCompleted
  /// 하위호환: player1/player2, winner, end
  factory LivePairing.fromFullLeagueJson(Map<String, dynamic> json, int roundNum) {
    // 단체전 풀리그: team1Name/team2Name 사용
    final isTeamMatch = json.containsKey('team1Name');

    if (isTeamMatch) {
      final team1 = json['team1Name']?.toString() ?? '';
      final team2 = json['team2Name']?.toString() ?? '';
      final team1Id = json['team1Id'];
      final team2Id = json['team2Id'];
      // 통일 필드: winnerId (하위호환: winnerTeamId)
      final winnerTeamId = json['winnerId'] ?? json['winnerTeamId'];
      final isCompleted = json['isCompleted'] == true;
      final isBye = team1 == '부전승' || team2 == '부전승' ||
          team1.isEmpty || team2.isEmpty;

      // 보드별 결과 파싱 (TEAM_FULL_LEAGUE: boards, TEAM_SWISS: teamBoardResults)
      List<BoardResult> boardsList = [];
      if (json['boards'] != null) {
        boardsList = (json['boards'] as List<dynamic>)
            .map((e) => BoardResult.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (json['teamBoardResults'] != null) {
        // TEAM_SWISS 형식: teamBoardResults + team1Players/team2Players
        final team1Players = json['team1Players'] as List<dynamic>? ?? [];
        final team2Players = json['team2Players'] as List<dynamic>? ?? [];
        final boardResults = json['teamBoardResults'] as List<dynamic>? ?? [];
        boardsList = boardResults.map((e) {
          final br = e as Map<String, dynamic>;
          final idx = ((br['playerIndex'] as num?)?.toInt() ?? 1) - 1;
          final winner = br['winner']?.toString() ?? '';
          final completed = winner.isNotEmpty;
          // synthetic IDs for winner determination
          final t1Id = idx + 1;
          final t2Id = -(idx + 1);
          return BoardResult(
            boardNumber: idx + 1,
            team1MemberName: idx < team1Players.length ? team1Players[idx]?.toString() : null,
            team2MemberName: idx < team2Players.length ? team2Players[idx]?.toString() : null,
            team1MemberId: t1Id,
            team2MemberId: t2Id,
            winnerMemberId: winner == 'team1' ? t1Id : (winner == 'team2' ? t2Id : null),
            isCompleted: completed,
          );
        }).toList();
      }

      // 팀 승자 결정: winnerId(int) 또는 teamWinner(string)
      int? resolvedWinnerId;
      String? winnerName;
      if (winnerTeamId is int) {
        resolvedWinnerId = winnerTeamId;
      } else if (json['teamWinner'] != null) {
        final tw = json['teamWinner'].toString();
        if (tw == 'TEAM1') winnerName = team1;
        if (tw == 'TEAM2') winnerName = team2;
      }

      return LivePairing(
        id: json['id'],
        round: json['round'] ?? roundNum,
        player1Id: team1Id is int ? team1Id : null,
        player1Name: team1,
        player1Score: json['team1Wins'],
        player2Id: team2Id is int ? team2Id : null,
        player2Name: team2,
        player2Score: json['team2Wins'],
        winnerId: resolvedWinnerId,
        winnerName: winnerName,
        isByeMatch: isBye,
        isCompleted: isCompleted,
        boards: boardsList,
      );
    }

    // 일반 풀리그: 통일 필드: player1Name (하위호환: player1)
    final player1 = (json['player1Name'] ?? json['player1'])?.toString() ?? '';
    final player2 = (json['player2Name'] ?? json['player2'])?.toString() ?? '';
    // 통일 필드: winnerName (하위호환: winner)
    final winner = (json['winnerName'] ?? json['winner'])?.toString();
    // 통일 필드: isCompleted (하위호환: end)
    final isEnd = json['isCompleted'] == true || json['end'] == true;
    final isBye = player1 == '없음' || player2 == '없음';

    return LivePairing(
      round: json['round'] ?? roundNum,
      player1Name: player1,
      player2Name: player2,
      player1Id: json['player1Id'],
      player2Id: json['player2Id'],
      winnerId: json['winnerId'],
      winnerName: winner,
      isByeMatch: isBye,
      isCompleted: isEnd,
    );
  }

  String get resultText {
    if (isNone) return '양패';
    if (isByeMatch) return '부전승';
    if (!isCompleted) return '진행중';
    if (winnerId == player1Id) return '흑승';
    if (winnerId == player2Id) return '백승';
    return '완료';
  }
}

class LiveStanding {
  final int rank;
  final int? participantId;
  final int? participantNumber;
  final String name;
  final String? level; // 기력 (10-48: 9단~30급)
  final int? mcMahonScore;
  final int wins;
  final int losses;
  final int? draws; // 무승부 (팀전)
  final double? sos;
  final double? sodos;
  final double? useSwissLeague; // 승점 (스위스리그)
  final double? sososPoints; // SOS (스위스리그)
  final String? winRate; // 승률 (풀리그)
  final String? nationality;
  final String? club;
  final String? region;
  final bool isDeleted;
  final int? none; // 없음 처리 여부 (스위스리그)

  // 유럽식 맥마흔 필드
  final bool europeanMode;
  final double? displayGameScore; // gameScore / 4.0
  final double? sosos; // SOSOS (맥마흔 유럽식)
  final int? jigoes; // 비김 횟수

  // 단체전 필드
  final String? teamName;
  final int? pointDiff; // 득실 (팀전)
  final int? totalIndividualWins; // 총 개인승 (팀전)
  final List<int>? playerWins; // 각 선수별 승수 (팀전)

  LiveStanding({
    required this.rank,
    this.participantId,
    this.participantNumber,
    required this.name,
    this.level,
    this.mcMahonScore,
    required this.wins,
    required this.losses,
    this.draws,
    this.sos,
    this.sodos,
    this.useSwissLeague,
    this.sososPoints,
    this.winRate,
    this.nationality,
    this.club,
    this.region,
    this.isDeleted = false,
    this.none,
    this.europeanMode = false,
    this.displayGameScore,
    this.sosos,
    this.jigoes,
    this.teamName,
    this.pointDiff,
    this.totalIndividualWins,
    this.playerWins,
  });

  factory LiveStanding.fromJson(Map<String, dynamic> json) {
    // 선수별 승수 파싱 (player1Wins ~ player10Wins)
    List<int>? playerWins;
    int count = 0;
    for (int i = 1; i <= 10; i++) {
      if (json['player${i}Wins'] != null) count = i;
    }
    if (count > 0) {
      playerWins = [];
      for (int i = 1; i <= count; i++) {
        playerWins.add(json['player${i}Wins'] ?? 0);
      }
    }

    return LiveStanding(
      rank: json['rank'] ?? 0,
      // 통일 필드: entityId (하위호환: participantId)
      participantId: json['entityId'] ?? json['participantId'],
      participantNumber: json['participantNumber'],
      // 통일 필드: name (하위호환: participantName, playerName, teamName)
      name: json['name'] ?? json['participantName'] ?? json['playerName'] ?? json['teamName'] ?? '',
      level: json['level']?.toString(),
      mcMahonScore: json['mcMahonScore'],
      // 통일 필드: wins (하위호환: totalWins)
      wins: json['wins'] ?? json['totalWins'] ?? 0,
      // 통일 필드: losses (하위호환: totalLosses)
      losses: json['losses'] ?? json['totalLosses'] ?? 0,
      draws: json['draws'],
      sos: json['sos']?.toDouble(),
      sodos: json['sodos']?.toDouble(),
      // 통일 필드: swissPoints (하위호환: useSwissLeague)
      useSwissLeague: (json['swissPoints'] ?? json['useSwissLeague'])?.toDouble(),
      // 통일 필드: sosPoints (하위호환: sososPoints)
      sososPoints: (json['sosPoints'] ?? json['sososPoints'])?.toDouble(),
      winRate: json['winRate']?.toString(),
      nationality: json['nationality'],
      club: json['club'],
      region: json['region'],
      // 통일 필드: isExcluded (하위호환: isDeleted, deletedAt)
      isDeleted: json['isExcluded'] ?? json['isDeleted'] ?? json['deletedAt'] != null,
      none: json['none'],
      // 유럽식 맥마흔 필드
      europeanMode: json['europeanMode'] ?? false,
      displayGameScore: json['displayGameScore']?.toDouble(),
      sosos: json['sosos']?.toDouble(),
      jigoes: json['jigoes'],
      teamName: json['teamName'],
      pointDiff: json['pointDiff'],
      // 통일 필드: boardWins (하위호환: totalIndividualWins)
      totalIndividualWins: json['boardWins'] ?? json['totalIndividualWins'],
      playerWins: playerWins,
    );
  }

  String get recordText => '$wins승 $losses패';

  String get displayName {
    final parts = <String>[name];
    if (club != null && club!.isNotEmpty) parts.add('($club)');
    return parts.join(' ');
  }

  /// 이름에서 단수/급수 제거
  String get cleanName {
    return name.replaceAll(RegExp(r'\s+\d+(단|급)$'), '').trim();
  }
}

class LiveSortDetail {
  final int sortId;
  final String sortName;
  final String type;
  final int? currentRound;
  final int? totalRounds;
  final List<LivePairing> pairings;
  final List<LiveStanding> standings;

  LiveSortDetail({
    required this.sortId,
    required this.sortName,
    required this.type,
    this.currentRound,
    this.totalRounds,
    this.pairings = const [],
    this.standings = const [],
  });

  factory LiveSortDetail.fromJson(Map<String, dynamic> json) {
    final pairingsList = (json['pairings'] as List<dynamic>?)
            ?.map((e) => LivePairing.fromJson(e))
            .toList() ??
        [];

    final standingsList = (json['standings'] as List<dynamic>?)
            ?.map((e) => LiveStanding.fromJson(e))
            .toList() ??
        [];

    return LiveSortDetail(
      sortId: json['sortId'] ?? 0,
      sortName: json['sortName'] ?? '',
      type: json['type'] ?? 'MCMAHON',
      currentRound: json['currentRound'],
      totalRounds: json['totalRounds'],
      pairings: pairingsList,
      standings: standingsList,
    );
  }

  String get roundText {
    if (currentRound == null) return '';
    if (totalRounds != null) {
      return '$currentRound/$totalRounds 라운드';
    }
    return '$currentRound 라운드';
  }
}
