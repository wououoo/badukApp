/// 부문 정보 모델 (LiveSortSummaryDTO 매핑)
class ContestSort {
  final int id;
  final String name;
  final int? gameRoomId;
  final int? participantCount;
  final int? currentRound;
  final int? maxRound;
  final int? teamSize; // 단체전 팀 인원 수
  final int? teamCount; // 단체전 팀 수
  final String? contestType; // SWISS, MCM, DE, TEAM_SWISS, FULL_LEAGUE, TEAM_FULL_LEAGUE, TOURNAMENT
  final int? fee; // 참가비 (ContestSort 엔티티에서 가져올 경우)

  ContestSort({
    required this.id,
    required this.name,
    this.gameRoomId,
    this.participantCount,
    this.currentRound,
    this.maxRound,
    this.teamSize,
    this.teamCount,
    this.contestType,
    this.fee,
  });

  factory ContestSort.fromJson(Map<String, dynamic> json) {
    return ContestSort(
      id: json['sortId'] ?? json['id'] ?? 0,
      name: json['sortName'] ?? json['name'] ?? '',
      gameRoomId: json['gameRoomId'],
      participantCount: json['participantCount'],
      currentRound: json['currentRound'],
      maxRound: json['maxRound'],
      teamSize: json['teamSize'],
      teamCount: json['teamCount'],
      contestType: json['contestType'] ?? json['type'],
      fee: json['fee'] ?? json['participationFee'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sortId': id,
      'sortName': name,
      'gameRoomId': gameRoomId,
      'participantCount': participantCount,
      'currentRound': currentRound,
      'maxRound': maxRound,
      'teamSize': teamSize,
      'teamCount': teamCount,
      'contestType': contestType,
      'fee': fee,
    };
  }

  /// 대회 유형 한글 변환
  String get contestTypeText {
    switch (contestType) {
      case 'SWISS':
        return '스위스리그';
      case 'MCM':
        return '맥마흔';
      case 'DE':
        return '더블엘리미네이션';
      case 'TEAM_SWISS':
        return '단체전 스위스리그';
      case 'FULL_LEAGUE':
        return '풀리그';
      case 'TEAM_FULL_LEAGUE':
        return '단체전 풀리그';
      case 'TOURNAMENT':
        return '토너먼트';
      default:
        return contestType ?? '';
    }
  }

  String get feeText {
    if (fee == null || fee == 0) return '무료';
    return '${_formatNumber(fee!)}원';
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  /// 라운드 진행 상황
  String get roundProgressText {
    if (currentRound == null || maxRound == null) return '';
    return '$currentRound/$maxRound 라운드';
  }
}
