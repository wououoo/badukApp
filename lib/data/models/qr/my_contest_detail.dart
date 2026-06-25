/// 내 대회 상세 정보 DTO (MyContestDetailDTO)
class MyContestDetail {
  final int contestId;
  final String contestName;
  final String? contestType;
  final DateTime? startDate;
  final DateTime? endDate;
  final int maxRound;
  final List<MyParticipation> participations;

  MyContestDetail({
    required this.contestId,
    required this.contestName,
    this.contestType,
    this.startDate,
    this.endDate,
    this.maxRound = 0,
    this.participations = const [],
  });

  factory MyContestDetail.fromJson(Map<String, dynamic> json) {
    return MyContestDetail(
      contestId: json['contestId'] ?? 0,
      contestName: json['contestName'] ?? '',
      contestType: json['contestType'],
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      maxRound: json['maxRound'] ?? 0,
      participations: (json['participations'] as List<dynamic>?)
          ?.map((p) => MyParticipation.fromJson(p))
          .toList() ?? [],
    );
  }
}

/// 부문별 참가 정보 (MyParticipationDTO)
class MyParticipation {
  final int participantId;
  final int gameRoomId;
  final String sortName;
  final String? contestType;  // 이 부문이 속한 대회의 유형 (그룹핑 시 자식 대회 타입)
  final String? teamName;
  final String? myName;  // 참가자 본인 이름

  // 현재 경기 정보
  final int currentRound;
  final int? totalRounds;
  final String? opponent;
  final String? opponentLevel;  // 상대 기력
  final int? matchNumber;
  final String? matchStatus;

  // 현재 순위 정보
  final int? currentRanking;
  final int? totalParticipants;

  // 체크인 정보
  final bool checkedIn;
  final DateTime? checkInTime;
  final bool checkInEnabled;
  final List<DateTime> checkedInDates;

  // 맥마흔 전용
  final String? mcmahonRank;
  final int wins;
  final int losses;
  final double? mcmahonScore;

  // DE 전용
  final int? deGroup;  // DE 그룹 번호 (새끼조)

  // DE 토너먼트 전용
  final bool tournamentStarted;
  final bool? advancedToTournament;
  final String? tournamentStage;
  final String? tournamentOpponent;
  final String? tournamentMatchStatus;
  final List<TournamentMatchInfo> tournamentMatches;
  final int? tournamentPlayerId;  // 본선 TournamentPlayer.id (본선 대진표 '내 경기' 강조)
  final String? deChampionStatus; // 본선 최종 상태 (우승/준우승/N강)

  // 팀 스위스 전용
  final List<TeamMember> teamMembers;

  MyParticipation({
    required this.participantId,
    required this.gameRoomId,
    required this.sortName,
    this.contestType,
    this.teamName,
    this.myName,
    this.currentRound = 0,
    this.totalRounds,
    this.opponent,
    this.opponentLevel,
    this.matchNumber,
    this.matchStatus,
    this.currentRanking,
    this.totalParticipants,
    this.checkedIn = false,
    this.checkInTime,
    this.checkInEnabled = true,
    this.checkedInDates = const [],
    this.mcmahonRank,
    this.wins = 0,
    this.losses = 0,
    this.mcmahonScore,
    this.deGroup,
    this.tournamentStarted = false,
    this.advancedToTournament,
    this.tournamentStage,
    this.tournamentOpponent,
    this.tournamentMatchStatus,
    this.tournamentMatches = const [],
    this.tournamentPlayerId,
    this.deChampionStatus,
    this.teamMembers = const [],
  });

  factory MyParticipation.fromJson(Map<String, dynamic> json) {
    return MyParticipation(
      participantId: json['participantId'] ?? 0,
      gameRoomId: json['gameRoomId'] ?? 0,
      sortName: json['sortName'] ?? '',
      contestType: json['contestType'],
      teamName: json['teamName'],
      myName: json['myName'],
      currentRound: json['currentRound'] ?? 0,
      totalRounds: json['totalRounds'],
      opponent: json['opponent'],
      opponentLevel: json['opponentLevel'],
      matchNumber: json['matchNumber'],
      matchStatus: json['matchStatus'],
      currentRanking: json['currentRanking'],
      totalParticipants: json['totalParticipants'],
      checkedIn: json['checkedIn'] ?? false,
      checkInTime: json['checkInTime'] != null
          ? DateTime.parse(json['checkInTime'])
          : null,
      checkInEnabled: json['checkInEnabled'] ?? true,
      checkedInDates: (json['checkedInDates'] as List<dynamic>?)
          ?.map((d) => DateTime.parse(d.toString()))
          .toList() ?? [],
      mcmahonRank: json['mcmahonRank']?.toString(),
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      mcmahonScore: (json['mcmahonScore'] as num?)?.toDouble(),
      deGroup: json['deGroup'],
      tournamentStarted: json['tournamentStarted'] ?? false,
      advancedToTournament: json['advancedToTournament'],
      tournamentStage: json['tournamentStage'],
      tournamentOpponent: json['tournamentOpponent'],
      tournamentMatchStatus: json['tournamentMatchStatus'],
      tournamentMatches: (json['tournamentMatches'] as List<dynamic>?)
          ?.map((m) => TournamentMatchInfo.fromJson(m as Map<String, dynamic>))
          .toList() ?? [],
      tournamentPlayerId: json['tournamentPlayerId'],
      deChampionStatus: json['deChampionStatus'],
      teamMembers: (json['teamMembers'] as List<dynamic>?)
          ?.map((m) => TeamMember.fromJson(m))
          .toList() ?? [],
    );
  }

  /// 전적 표시
  String get record => '$wins승 $losses패';

  /// 순위 표시
  String get rankingText {
    if (currentRanking == null) return '-';
    if (totalParticipants != null) {
      return '$currentRanking위 / $totalParticipants명';
    }
    return '$currentRanking위';
  }

  /// 라운드 진행 표시
  String get roundProgressText {
    if (totalRounds != null && totalRounds! > 0) {
      return '$currentRound / $totalRounds 라운드';
    }
    return '$currentRound라운드';
  }
}

/// 토너먼트 매치 정보
class TournamentMatchInfo {
  final int round;
  final String? stageName;
  final String? opponent;
  final String? status;
  final bool? won;
  final bool? bye;   // 부전승 여부 (round 0 등에서 상대 없음)

  TournamentMatchInfo({
    required this.round,
    this.stageName,
    this.opponent,
    this.status,
    this.won,
    this.bye,
  });

  factory TournamentMatchInfo.fromJson(Map<String, dynamic> json) {
    return TournamentMatchInfo(
      round: json['round'] ?? 0,
      stageName: json['stageName'],
      opponent: json['opponent'],
      status: json['status'],
      won: json['won'],
      bye: json['bye'],
    );
  }
}

/// 팀원 정보 (TeamMemberDTO)
class TeamMember {
  final int boardNumber;
  final String memberName;
  final bool isNone;
  final int wins;
  final int losses;

  TeamMember({
    required this.boardNumber,
    required this.memberName,
    this.isNone = false,
    this.wins = 0,
    this.losses = 0,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      boardNumber: json['boardNumber'] ?? 0,
      memberName: json['memberName'] ?? '',
      isNone: json['isNone'] ?? false,
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
    );
  }
}
