/// 포털 참가자 정보 모델
class PortalParticipant {
  final int participantId;
  final String name;
  final String? phone;
  final String? maskedPhone;
  final int? sortId;  // ContestSort.id (순위표 조회에 필요)
  final int gameRoomId;
  final String? sortName;
  final String? contestType;
  final String? teamName;

  // 현재 경기 정보
  final int currentRound;
  final String? opponent;
  final int? matchNumber;
  final String? matchStatus;

  // 체크인 정보
  final bool checkedIn;
  final String? checkInTime;
  final String? checkInDate;
  final List<String> checkedInDates;
  final bool checkInEnabled;

  // 맥마흔 전용 정보
  final String? mcmahonRank;
  final int? wins;
  final int? losses;
  final double? mcmahonScore;

  // 팀 스위스 전용 정보
  final List<TeamMember>? teamMembers;

  PortalParticipant({
    required this.participantId,
    required this.name,
    this.phone,
    this.maskedPhone,
    this.sortId,
    required this.gameRoomId,
    this.sortName,
    this.contestType,
    this.teamName,
    this.currentRound = 0,
    this.opponent,
    this.matchNumber,
    this.matchStatus,
    this.checkedIn = false,
    this.checkInTime,
    this.checkInDate,
    this.checkedInDates = const [],
    this.checkInEnabled = true,
    this.mcmahonRank,
    this.wins,
    this.losses,
    this.mcmahonScore,
    this.teamMembers,
  });

  factory PortalParticipant.fromJson(Map<String, dynamic> json) {
    return PortalParticipant(
      participantId: json['participantId'] ?? 0,
      name: json['name'] ?? json['participantName'] ?? '',
      phone: json['phone'],
      maskedPhone: json['maskedPhone'],
      sortId: json['sortId'],
      gameRoomId: json['gameRoomId'] ?? 0,
      sortName: json['sortName'],
      contestType: json['contestType'],
      teamName: json['teamName'],
      currentRound: json['currentRound'] ?? 0,
      opponent: json['opponent'],
      matchNumber: json['matchNumber'],
      matchStatus: json['matchStatus'] ?? 'waiting',
      checkedIn: json['checkedIn'] ?? false,
      checkInTime: json['checkInTime'],
      checkInDate: json['checkInDate'],
      checkedInDates: json['checkedInDates'] != null
          ? List<String>.from(json['checkedInDates'])
          : [],
      checkInEnabled: json['checkInEnabled'] ?? true,
      mcmahonRank: json['mcmahonRank'],
      wins: json['wins'],
      losses: json['losses'],
      mcmahonScore: json['mcmahonScore']?.toDouble(),
      teamMembers: json['teamMembers'] != null
          ? (json['teamMembers'] as List)
              .map((e) => TeamMember.fromJson(e))
              .toList()
          : null,
    );
  }

  /// 체크인 된 참가자 (체크인 정보 업데이트)
  PortalParticipant copyWithCheckIn({
    required bool checkedIn,
    String? checkInTime,
    String? checkInDate,
    List<String>? checkedInDates,
  }) {
    return PortalParticipant(
      participantId: participantId,
      name: name,
      phone: phone,
      maskedPhone: maskedPhone,
      sortId: sortId,
      gameRoomId: gameRoomId,
      sortName: sortName,
      contestType: contestType,
      teamName: teamName,
      currentRound: currentRound,
      opponent: opponent,
      matchNumber: matchNumber,
      matchStatus: matchStatus,
      checkedIn: checkedIn,
      checkInTime: checkInTime ?? this.checkInTime,
      checkInDate: checkInDate ?? this.checkInDate,
      checkedInDates: checkedInDates ?? this.checkedInDates,
      checkInEnabled: checkInEnabled,
      mcmahonRank: mcmahonRank,
      wins: wins,
      losses: losses,
      mcmahonScore: mcmahonScore,
      teamMembers: teamMembers,
    );
  }

  /// 매치 상태 라벨
  String get matchStatusLabel {
    switch (matchStatus) {
      case 'waiting':
        return '대기중';
      case 'in_progress':
        return '진행중';
      case 'completed':
        return '완료';
      default:
        return matchStatus ?? '';
    }
  }
}

/// 팀 멤버 정보
class TeamMember {
  final int boardNumber;
  final String memberName;
  final bool isNone;

  TeamMember({
    required this.boardNumber,
    required this.memberName,
    this.isNone = false,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      boardNumber: json['boardNumber'] ?? 0,
      memberName: json['memberName'] ?? '',
      isNone: json['isNone'] ?? false,
    );
  }
}
