// 주최자 운영 콘솔 모델 (MobileHostOperationController 응답)

/// 내가 운영할 대회 한 건 (A1 목록)
class HostContest {
  final int homepageId;
  final String title;
  final DateTime? contestStartDate;
  final String contestStatus; // 홈페이지 상태 문자열
  final int registrationCount;
  final int categoryCount;
  final List<int> contestIds;
  final bool operable; // Contest 엔진 연결 여부 (false면 아직 운영 불가)

  HostContest({
    required this.homepageId,
    required this.title,
    this.contestStartDate,
    required this.contestStatus,
    required this.registrationCount,
    required this.categoryCount,
    required this.contestIds,
    required this.operable,
  });

  factory HostContest.fromJson(Map<String, dynamic> json) {
    return HostContest(
      homepageId: json['homepageId'] ?? 0,
      title: json['title'] ?? '제목 없음',
      contestStartDate: json['contestStartDate'] != null
          ? DateTime.tryParse(json['contestStartDate'].toString())
          : null,
      contestStatus: json['contestStatus']?.toString() ?? '',
      registrationCount: (json['registrationCount'] as num?)?.toInt() ?? 0,
      categoryCount: (json['categoryCount'] as num?)?.toInt() ?? 0,
      contestIds: (json['contestIds'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      operable: json['operable'] == true,
    );
  }
}

/// 대회의 부문(운영 단위 = GameRoom) 한 건 (A2 목록)
class ContestSection {
  final int gameRoomId;
  final int sortId;
  final String sortName;
  final int contestId;
  final String contestName;
  final String type; // 한글 라벨 (맥마흔/스위스리그/…)
  final int? teamSize;
  final bool checkInEnabled;
  final bool gameStarted;
  final bool bracketMaterialized;
  final bool tournamentPublished;

  ContestSection({
    required this.gameRoomId,
    required this.sortId,
    required this.sortName,
    required this.contestId,
    required this.contestName,
    required this.type,
    this.teamSize,
    required this.checkInEnabled,
    required this.gameStarted,
    required this.bracketMaterialized,
    required this.tournamentPublished,
  });

  /// 맥마흔 부문 여부 (한글 라벨 기준)
  bool get isMcMahon => type.contains('맥마흔') || type.toUpperCase() == 'MCM';

  /// 단체전 여부
  bool get isTeam => type.contains('단체');

  /// 스위스리그(개인) 여부 — 단체전 스위스는 제외
  bool get isSwiss =>
      !isTeam && (type.contains('스위스') || type.toUpperCase() == 'SWISS');

  /// 단체 스위스 여부
  bool get isTeamSwiss => isTeam && type.contains('스위스');

  /// 풀리그(개인) 여부 — 단체전 풀리그 제외
  bool get isFullLeague =>
      !isTeam && (type.contains('풀리그') || type.toUpperCase() == 'FULL_LEAGUE');

  /// 단체 풀리그 여부
  bool get isTeamFullLeague => isTeam && type.contains('풀리그');

  /// 더블 엘리미네이션 여부 (DE) — 토너먼트 판정보다 먼저 확인해야 함
  bool get isDoubleElimination =>
      type.contains('더블') ||
      type.contains('엘리') ||
      type.toUpperCase() == 'DE';

  /// 싱글 토너먼트 여부 — DE(더블 엘리미네이션)는 제외
  bool get isTournament =>
      !isDoubleElimination &&
      (type.contains('토너먼트') || type.toUpperCase() == 'TOURNAMENT');

  /// 앱에서 운영 가능한 방식인지 (현재 MCM·스위스·단체 스위스·풀리그·단체 풀리그·싱글 토너먼트·DE)
  bool get appOperable =>
      isMcMahon ||
      isSwiss ||
      isTeamSwiss ||
      isFullLeague ||
      isTeamFullLeague ||
      isTournament ||
      isDoubleElimination;

  factory ContestSection.fromJson(Map<String, dynamic> json) {
    return ContestSection(
      gameRoomId: (json['gameRoomId'] as num?)?.toInt() ?? 0,
      sortId: (json['sortId'] as num?)?.toInt() ?? 0,
      sortName: json['sortName']?.toString() ?? '부문',
      contestId: (json['contestId'] as num?)?.toInt() ?? 0,
      contestName: json['contestName']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      teamSize: (json['teamSize'] as num?)?.toInt(),
      checkInEnabled: json['checkInEnabled'] == true,
      gameStarted: json['gameStarted'] == true,
      bracketMaterialized: json['bracketMaterialized'] == true,
      tournamentPublished: json['tournamentPublished'] == true,
    );
  }
}

/// 토너먼트 브래킷의 한 선수 슬롯
class TournamentPlayer {
  final int? id; // participant id (null=TBD/BYE)
  final String name; // 'TBD'면 미확정
  final String resultText; // 승/패/부전/''
  final bool isWinner;
  final String status;

  TournamentPlayer({
    this.id,
    required this.name,
    required this.resultText,
    required this.isWinner,
    required this.status,
  });

  bool get isTbd => id == null || name == 'TBD';
  bool get isByeSlot => name == 'BYE' || name == '부전';

  factory TournamentPlayer.fromJson(Map<String, dynamic> json) {
    return TournamentPlayer(
      id: (json['id'] as num?)?.toInt(),
      name: json['name']?.toString() ?? 'TBD',
      resultText: json['resultText']?.toString() ?? '',
      isWinner: json['isWinner'] == true,
      status: json['status']?.toString() ?? 'NO_SHOW',
    );
  }
}

/// 토너먼트 브래킷의 한 매치 (bracket-data 한 항목)
class TournamentMatch {
  final int matchDbId; // 결과 API 호출용 실제 DB id
  final int roundNumber; // 1,2,3...
  final String roundText; // "16강"/"결승" 등
  final String state; // DONE/SCHEDULED/WALK_OVER/NO_SHOW
  final bool isBye;
  final List<TournamentPlayer> participants; // [p1, p2]

  TournamentMatch({
    required this.matchDbId,
    required this.roundNumber,
    required this.roundText,
    required this.state,
    required this.isBye,
    required this.participants,
  });

  TournamentPlayer? get p1 =>
      participants.isNotEmpty ? participants[0] : null;
  TournamentPlayer? get p2 =>
      participants.length > 1 ? participants[1] : null;

  bool get isDone => state == 'DONE';
  bool get isWalkOver => state == 'WALK_OVER';

  factory TournamentMatch.fromJson(Map<String, dynamic> json) {
    final parts = (json['participants'] as List?)
            ?.map((e) =>
                TournamentPlayer.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        const [];
    return TournamentMatch(
      matchDbId: (json['matchDbId'] as num?)?.toInt() ?? 0,
      roundNumber: (json['roundNumber'] as num?)?.toInt() ?? 1,
      roundText: json['tournamentRoundText']?.toString() ?? '',
      state: json['state']?.toString() ?? 'NO_SHOW',
      isBye: json['isBye'] == true,
      participants: parts,
    );
  }
}

/// 토너먼트 현황 응답 (facade GET .../tournament)
class TournamentSection {
  final bool exists; // 대진 생성 여부(추첨/브래킷)
  final int? tournamentId;
  final String tournamentName;
  final int? bracketSize;
  final int maxRound;
  final List<TournamentMatch> bracket;
  final List<Map<String, dynamic>> rankings;

  TournamentSection({
    required this.exists,
    this.tournamentId,
    required this.tournamentName,
    this.bracketSize,
    required this.maxRound,
    required this.bracket,
    required this.rankings,
  });

  /// 라운드번호 → 그 라운드 매치들 (matchDbId 순 정렬은 화면에서)
  List<TournamentMatch> matchesOfRound(int round) {
    final out = <TournamentMatch>[];
    for (final m in bracket) {
      if (m.roundNumber == round) out.add(m);
    }
    return out;
  }

  factory TournamentSection.fromJson(Map<String, dynamic> json) {
    final exists = json['exists'] == true;
    final tour = json['tournament'] is Map
        ? Map<String, dynamic>.from(json['tournament'] as Map)
        : const <String, dynamic>{};
    final bracket = (json['bracket'] as List?)
            ?.map((e) =>
                TournamentMatch.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        const [];
    final rankings = (json['rankings'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        const [];
    return TournamentSection(
      exists: exists,
      tournamentId: (tour['id'] as num?)?.toInt(),
      tournamentName: tour['name']?.toString() ?? '토너먼트',
      bracketSize: (tour['bracketSize'] as num?)?.toInt(),
      maxRound: (json['maxRound'] as num?)?.toInt() ?? 0,
      bracket: bracket,
      rankings: rankings,
    );
  }
}

// ======================= 더블 엘리미네이션(DE) =======================

/// DE 예선 한 매치 (DERoundResult). winner 는 이름 문자열(빈값=미입력).
class DePrelimMatch {
  final int? id;
  final int round;
  final String player1;
  final String player2;
  final int player1Number;
  final int player2Number;
  final String winner; // 승자 이름('' = 미입력)
  final int winnerNumber;

  DePrelimMatch({
    this.id,
    required this.round,
    required this.player1,
    required this.player2,
    required this.player1Number,
    required this.player2Number,
    required this.winner,
    required this.winnerNumber,
  });

  bool get hasWinner => winner.isNotEmpty;
  bool get isBye => player1 == '부전승' || player2 == '부전승';

  factory DePrelimMatch.fromJson(Map<String, dynamic> json) {
    return DePrelimMatch(
      id: (json['id'] as num?)?.toInt(),
      round: (json['round'] as num?)?.toInt() ?? 1,
      player1: json['player1']?.toString() ?? '',
      player2: json['player2']?.toString() ?? '',
      player1Number: (json['player1Number'] as num?)?.toInt() ?? 0,
      player2Number: (json['player2Number'] as num?)?.toInt() ?? 0,
      winner: json['winner']?.toString() ?? '',
      winnerNumber: (json['winnerNumber'] as num?)?.toInt() ?? 0,
    );
  }
}

/// DE 예선 한 조 (조 번호 + 라운드별 매치)
class DeGroup {
  final int groupNumber;
  final int memberCount;
  final bool completed;
  final Map<int, List<DePrelimMatch>> rounds;

  DeGroup({
    required this.groupNumber,
    required this.memberCount,
    required this.completed,
    required this.rounds,
  });

  List<int> get roundNumbers {
    final ks = rounds.keys.toList()..sort();
    return ks;
  }

  int get maxRound => roundNumbers.isEmpty ? 0 : roundNumbers.last;

  factory DeGroup.fromJson(Map<String, dynamic> json) {
    final raw = json['rounds'];
    final rounds = <int, List<DePrelimMatch>>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final rnum = int.tryParse(k.toString());
        if (rnum != null && v is List) {
          rounds[rnum] = v
              .map((e) =>
                  DePrelimMatch.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      });
    }
    return DeGroup(
      groupNumber: (json['groupNumber'] as num?)?.toInt() ?? 0,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      completed: json['completed'] == true,
      rounds: rounds,
    );
  }
}

/// DE 예선 현황 (facade GET .../de/prelim)
class DePrelimSection {
  final bool started;
  final List<DeGroup> groups;

  DePrelimSection({required this.started, required this.groups});

  factory DePrelimSection.fromJson(Map<String, dynamic> json) {
    final groups = (json['groups'] as List?)
            ?.map((e) => DeGroup.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        const [];
    return DePrelimSection(
      started: json['started'] == true,
      groups: groups,
    );
  }
}

/// DE 본선 한 매치 (TournamentMatchDTO). winner 는 participant id(null=미입력).
class DeBracketMatch {
  final int round;
  final int matchNumber;
  final int? player1Id;
  final String player1Name;
  final int? player2Id;
  final String player2Name;
  final int? winnerId;

  DeBracketMatch({
    required this.round,
    required this.matchNumber,
    this.player1Id,
    required this.player1Name,
    this.player2Id,
    required this.player2Name,
    this.winnerId,
  });

  bool get hasBothPlayers => player1Id != null && player2Id != null;
  bool get hasWinner => winnerId != null;

  factory DeBracketMatch.fromJson(Map<String, dynamic> json) {
    final p1 = json['player1'] is Map
        ? Map<String, dynamic>.from(json['player1'] as Map)
        : const <String, dynamic>{};
    final p2 = json['player2'] is Map
        ? Map<String, dynamic>.from(json['player2'] as Map)
        : const <String, dynamic>{};
    return DeBracketMatch(
      round: (json['round'] as num?)?.toInt() ?? 1,
      matchNumber: (json['matchNumber'] as num?)?.toInt() ?? 1,
      player1Id: (p1['id'] as num?)?.toInt(),
      player1Name: p1['playerName']?.toString() ?? '',
      player2Id: (p2['id'] as num?)?.toInt(),
      player2Name: p2['playerName']?.toString() ?? '',
      winnerId: (json['winner'] as num?)?.toInt(),
    );
  }
}

/// DE 본선 현황 (facade GET .../de/bracket)
class DeBracketSection {
  final bool started;
  final List<DeBracketMatch> matches;

  DeBracketSection({required this.started, required this.matches});

  List<int> get roundNumbers {
    final set = <int>{};
    for (final m in matches) {
      set.add(m.round);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<DeBracketMatch> matchesOfRound(int round) {
    final out = <DeBracketMatch>[];
    for (final m in matches) {
      if (m.round == round) out.add(m);
    }
    out.sort((a, b) => a.matchNumber.compareTo(b.matchNumber));
    return out;
  }

  /// 본선 1라운드 매치 수 → 브래킷 크기(라운드 라벨용)
  int get round1Count {
    var c = 0;
    for (final m in matches) {
      if (m.round == 1) c++;
    }
    return c;
  }

  factory DeBracketSection.fromJson(Map<String, dynamic> json) {
    final matches = (json['bracket'] as List?)
            ?.map((e) =>
                DeBracketMatch.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        const [];
    return DeBracketSection(
      started: json['started'] == true,
      matches: matches,
    );
  }
}
