/// 내 참가 대회 DTO (MyContestDTO)
class MyContest {
  final int contestId;
  final String contestName;
  final String contestType;
  final DateTime? startDate;
  final DateTime? endDate;

  // 참가 정보
  final int participantId;
  final int gameRoomId;
  final String sortName;
  final String? teamName;
  final String? participantName;

  // 현재 경기 정보
  final int currentRound;
  final String? opponent;
  final int? matchNumber;
  final String? matchStatus;

  // 체크인 정보
  final bool checkedIn;
  final DateTime? checkInTime;
  final bool checkInEnabled;
  final List<DateTime> contestDates;
  final List<DateTime> checkedInDates;

  // 단체전 개인 매치 정보
  final String? myOpponent;      // 개인 상대 이름
  final int? boardNumber;        // 기 번호
  final int? myWins;             // 개인 승수
  final int? myLosses;           // 개인 패수

  // DE 토너먼트 상태
  final bool? tournamentStarted;
  final bool? advancedToTournament;
  final String? tournamentStage;
  final String? tournamentOpponent;

  // 동명이인 처리
  final bool needsSelection;
  final List<CandidateInfo> candidates;

  MyContest({
    required this.contestId,
    required this.contestName,
    required this.contestType,
    this.startDate,
    this.endDate,
    required this.participantId,
    required this.gameRoomId,
    required this.sortName,
    this.teamName,
    this.participantName,
    this.currentRound = 0,
    this.opponent,
    this.matchNumber,
    this.matchStatus,
    this.myOpponent,
    this.boardNumber,
    this.myWins,
    this.myLosses,
    this.checkedIn = false,
    this.checkInTime,
    this.checkInEnabled = true,
    this.contestDates = const [],
    this.checkedInDates = const [],
    this.tournamentStarted,
    this.advancedToTournament,
    this.tournamentStage,
    this.tournamentOpponent,
    this.needsSelection = false,
    this.candidates = const [],
  });

  factory MyContest.fromJson(Map<String, dynamic> json) {
    return MyContest(
      contestId: json['contestId'] ?? 0,
      contestName: json['contestName'] ?? '',
      contestType: json['contestType'] ?? '',
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      participantId: json['participantId'] ?? 0,
      gameRoomId: json['gameRoomId'] ?? 0,
      sortName: json['sortName'] ?? '',
      teamName: json['teamName'],
      participantName: json['participantName'],
      currentRound: json['currentRound'] ?? 0,
      opponent: json['opponent'],
      matchNumber: json['matchNumber'],
      matchStatus: json['matchStatus'],
      myOpponent: json['myOpponent'],
      boardNumber: json['boardNumber'],
      myWins: json['myWins'],
      myLosses: json['myLosses'],
      checkedIn: json['checkedIn'] ?? false,
      checkInTime: json['checkInTime'] != null
          ? DateTime.parse(json['checkInTime'])
          : null,
      checkInEnabled: json['checkInEnabled'] ?? true,
      contestDates: (json['contestDates'] as List<dynamic>?)
          ?.map((d) => DateTime.parse(d))
          .toList() ?? [],
      checkedInDates: (json['checkedInDates'] as List<dynamic>?)
          ?.map((d) => DateTime.parse(d))
          .toList() ?? [],
      tournamentStarted: json['tournamentStarted'],
      advancedToTournament: json['advancedToTournament'],
      tournamentStage: json['tournamentStage'],
      tournamentOpponent: json['tournamentOpponent'],
      needsSelection: json['needsSelection'] ?? false,
      candidates: (json['candidates'] as List<dynamic>?)
          ?.map((c) => CandidateInfo.fromJson(c))
          .toList() ?? [],
    );
  }

  /// 대회 타입 표시명
  String get contestTypeLabel {
    switch (contestType) {
      case 'MCM':
        return '맥마흔';
      case 'SWISS':
        return '스위스리그';
      case 'TEAM_SWISS':
        return '단체 스위스리그';
      case 'FULL_LEAGUE':
        return '풀리그';
      case 'TEAM_FULL_LEAGUE':
        return '단체 풀리그';
      case 'DE':
        return '더블엘리미네이션';
      default:
        return contestType;
    }
  }

  /// 다일 대회 여부
  bool get isMultiDay => contestDates.length > 1;

  /// 오늘 체크인 필요 여부
  bool get needsCheckInToday {
    if (!checkInEnabled) return false;
    if (checkedIn) return false;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // 시작일~종료일 사이인지 확인
    if (startDate != null && todayDate.isBefore(startDate!)) return false;
    if (endDate != null && todayDate.isAfter(endDate!)) return false;

    return true;
  }
}

/// 동명이인 후보 정보
class CandidateInfo {
  final int participantId;
  final int gameRoomId;
  final String name;
  final String sortName;
  final String? teamName;
  final String? club;
  final int? participantNumber;

  CandidateInfo({
    required this.participantId,
    required this.gameRoomId,
    required this.name,
    required this.sortName,
    this.teamName,
    this.club,
    this.participantNumber,
  });

  factory CandidateInfo.fromJson(Map<String, dynamic> json) {
    return CandidateInfo(
      participantId: json['participantId'] ?? 0,
      gameRoomId: json['gameRoomId'] ?? 0,
      name: json['name'] ?? '',
      sortName: json['sortName'] ?? '',
      teamName: json['teamName'],
      club: json['club'],
      participantNumber: json['participantNumber'],
    );
  }

  /// 표시용 설명 (부문명, 팀명, 소속 등)
  String get displayDescription {
    final parts = <String>[];
    parts.add(sortName);
    if (teamName != null && teamName!.isNotEmpty) parts.add(teamName!);
    if (club != null && club!.isNotEmpty) parts.add(club!);
    if (participantNumber != null) parts.add('$participantNumber번');
    return parts.join(' / ');
  }
}
