/// 맥마흔 대회 참가 이력
class McMahonHistory {
  final int? gameRoomId;
  final String contestName;
  final DateTime? contestDate;
  final double? scoreBefore;
  final double? scoreAfter;
  final double? scoreChange;
  final int wins;
  final int losses;
  final int? gamesPlayed;
  final int? finalRanking;
  final int? totalParticipants;

  McMahonHistory({
    this.gameRoomId,
    required this.contestName,
    this.contestDate,
    this.scoreBefore,
    this.scoreAfter,
    this.scoreChange,
    this.wins = 0,
    this.losses = 0,
    this.gamesPlayed,
    this.finalRanking,
    this.totalParticipants,
  });

  factory McMahonHistory.fromJson(Map<String, dynamic> json) {
    return McMahonHistory(
      gameRoomId: json['gameRoomId'],
      contestName: json['contestName'] ?? '',
      contestDate: _parseDate(json['contestDate']),
      scoreBefore: (json['scoreBefore'] as num?)?.toDouble(),
      scoreAfter: (json['scoreAfter'] as num?)?.toDouble(),
      scoreChange: (json['scoreChange'] as num?)?.toDouble(),
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      gamesPlayed: json['gamesPlayed'],
      finalRanking: json['finalRanking'],
      totalParticipants: json['totalParticipants'],
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'gameRoomId': gameRoomId,
      'contestName': contestName,
      'contestDate': contestDate?.toIso8601String(),
      'scoreBefore': scoreBefore,
      'scoreAfter': scoreAfter,
      'scoreChange': scoreChange,
      'wins': wins,
      'losses': losses,
      'gamesPlayed': gamesPlayed,
      'finalRanking': finalRanking,
      'totalParticipants': totalParticipants,
    };
  }

  String get dateText {
    if (contestDate == null) return '-';
    return '${contestDate!.year}.${contestDate!.month.toString().padLeft(2, '0')}.${contestDate!.day.toString().padLeft(2, '0')}';
  }

  String get shortDateText {
    if (contestDate == null) return '-';
    return '${contestDate!.month}/${contestDate!.day}';
  }

  String get changeText {
    if (scoreChange == null) return '-';
    final change = scoreChange!;
    if (change >= 0) return '+${change.toStringAsFixed(1)}';
    return change.toStringAsFixed(1);
  }

  String get recordText => '${wins}승 ${losses}패';

  String get rankText {
    if (finalRanking == null) return '-';
    if (totalParticipants != null) {
      return '$finalRanking위/$totalParticipants명';
    }
    return '$finalRanking위';
  }

  bool get isPositive => (scoreChange ?? 0) >= 0;
}

/// 맥마흔 점수 요약
class McMahonScoreSummary {
  final double currentScore;
  final int totalGames;
  final int contestCount;
  final List<McMahonHistory> history;

  McMahonScoreSummary({
    required this.currentScore,
    this.totalGames = 0,
    this.contestCount = 0,
    required this.history,
  });

  factory McMahonScoreSummary.fromJson(Map<String, dynamic> json) {
    final historyList = (json['history'] as List<dynamic>?)
            ?.map((e) => McMahonHistory.fromJson(e))
            .toList() ??
        [];

    return McMahonScoreSummary(
      currentScore: (json['currentScore'] as num?)?.toDouble() ?? 0.0,
      totalGames: json['totalGames'] ?? 0,
      contestCount: json['contestCount'] ?? 0,
      history: historyList,
    );
  }

  double? get recentChange {
    if (history.isEmpty) return null;
    return history.first.scoreChange;
  }

  String get currentScoreText => currentScore.toStringAsFixed(1);
}

/// 맥마흔 라운드 결과
class McMahonRoundResult {
  final int round;
  final String opponentName;
  final bool isWin;
  final String? color; // 흑/백
  final int? pointChange;
  final String? stage; // DE 전용: "GROUP"(예선) / "TOURNAMENT"(본선)

  McMahonRoundResult({
    required this.round,
    required this.opponentName,
    required this.isWin,
    this.color,
    this.pointChange,
    this.stage,
  });

  factory McMahonRoundResult.fromJson(Map<String, dynamic> json) {
    return McMahonRoundResult(
      round: json['round'] ?? 0,
      opponentName: json['opponentName'] ?? json['opponent'] ?? '부전승',
      isWin: json['isWin'] ?? json['win'] ?? false,
      color: json['color'],
      pointChange: json['pointChange'] ?? json['point'],
      stage: json['stage'],
    );
  }

  String get resultText => isWin ? '승' : '패';
  String get colorText => color == 'BLACK' ? '흑' : (color == 'WHITE' ? '백' : '');

  /// DE 예선(그룹 스테이지)인지
  bool get isGroupStage => stage == 'GROUP';
  /// DE 본선(토너먼트 스테이지)인지
  bool get isTournamentStage => stage == 'TOURNAMENT';
  /// 스테이지 표시명
  String get stageText => stage == 'TOURNAMENT' ? '본선' : (stage == 'GROUP' ? '예선' : '');
}
