class ContestHistory {
  final int contestId;
  final int? gameRoomId;  // 라운드별 상세 결과 조회용
  final String contestName;
  final DateTime date;
  final String sortName;
  final int? finalRank;
  final int? totalParticipants;
  final int wins;
  final int losses;
  final int? scoreChange;
  final String? contestType;  // MCM, SWISS, FULL_LEAGUE, TEAM_SWISS, TEAM_FULL_LEAGUE, DE
  final String? teamName;     // 단체전용 팀명

  // DE 전용: 예선(그룹)/본선(토너먼트) 구분
  final int? groupWins;
  final int? groupLosses;
  final int? tournamentWins;
  final int? tournamentLosses;
  final bool? advancedToTournament;

  ContestHistory({
    required this.contestId,
    this.gameRoomId,
    required this.contestName,
    required this.date,
    required this.sortName,
    this.finalRank,
    this.totalParticipants,
    required this.wins,
    required this.losses,
    this.scoreChange,
    this.contestType,
    this.teamName,
    this.groupWins,
    this.groupLosses,
    this.tournamentWins,
    this.tournamentLosses,
    this.advancedToTournament,
  });

  factory ContestHistory.fromJson(Map<String, dynamic> json) {
    return ContestHistory(
      contestId: json['contestId'] ?? 0,
      gameRoomId: json['gameRoomId'],
      contestName: json['contestName'] ?? '',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      sortName: json['sortName'] ?? json['category'] ?? '',
      finalRank: json['finalRank'] ?? json['rank'],
      totalParticipants: json['totalParticipants'],
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      scoreChange: json['scoreChange'],
      contestType: json['contestType'],
      teamName: json['teamName'],
      groupWins: json['groupWins'],
      groupLosses: json['groupLosses'],
      tournamentWins: json['tournamentWins'],
      tournamentLosses: json['tournamentLosses'],
      advancedToTournament: json['advancedToTournament'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contestId': contestId,
      'gameRoomId': gameRoomId,
      'contestName': contestName,
      'date': date.toIso8601String(),
      'sortName': sortName,
      'finalRank': finalRank,
      'totalParticipants': totalParticipants,
      'wins': wins,
      'losses': losses,
      'scoreChange': scoreChange,
      'contestType': contestType,
      'teamName': teamName,
    };
  }

  String get dateText {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  String get recordText => '$wins승 $losses패';

  /// DE 대회인지 여부
  bool get isDE => contestType == 'DE';

  /// DE 대회에서 예선/본선 구분 데이터가 있는지
  bool get hasDeStageData => isDE && (groupWins != null || tournamentWins != null);

  String get rankText {
    if (finalRank == null || finalRank == 0) return '-';
    return '$finalRank위';
  }

  /// 대회 유형 표시명
  String get contestTypeText {
    switch (contestType) {
      case 'MCM':
        return '맥마흔';
      case 'SWISS':
        return '스위스';
      case 'FULL_LEAGUE':
        return '풀리그';
      case 'TEAM_SWISS':
        return '단체전';
      case 'TEAM_FULL_LEAGUE':
        return '단체 풀리그';
      case 'DE':
        return '더블엘리미네이션';
      default:
        return '';
    }
  }

  /// MCM 대회인지 여부
  bool get isMcm => contestType == 'MCM';
}
