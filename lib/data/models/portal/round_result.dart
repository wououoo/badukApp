/// 라운드 결과 모델
class RoundResult {
  final int round;
  final List<MatchResult> matches;

  RoundResult({
    required this.round,
    required this.matches,
  });

  factory RoundResult.fromJson(Map<String, dynamic> json) {
    return RoundResult(
      round: json['round'] ?? 0,
      matches: json['matches'] != null
          ? (json['matches'] as List)
              .map((e) => MatchResult.fromJson(e))
              .toList()
          : [],
    );
  }
}

/// 매치 결과 모델
class MatchResult {
  final String? player1;
  final String? player2;
  final int? player1Id;
  final int? player2Id;
  final String? winner;
  final int? winnerId;
  final int? tableNumber;
  final bool isBye;
  final bool isNone; // 양패 (둘 다 패배 처리)

  MatchResult({
    this.player1,
    this.player2,
    this.player1Id,
    this.player2Id,
    this.winner,
    this.winnerId,
    this.tableNumber,
    this.isBye = false,
    this.isNone = false,
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    return MatchResult(
      player1: json['player1'] ?? json['player1Name'],
      player2: json['player2'] ?? json['player2Name'],
      player1Id: json['player1Id'],
      player2Id: json['player2Id'],
      winner: json['winner'],
      winnerId: json['winnerId'],
      tableNumber: json['tableNumber'],
      isBye: (json['isByeMatch'] == true) ||
          (json['player2'] == null && json['player2Id'] == null),
      isNone: json['isNone'] == true,
    );
  }

  /// player1이 승자인지 확인
  bool get isPlayer1Winner {
    if (winnerId != null && player1Id != null) {
      return winnerId == player1Id;
    }
    if (winner != null && player1 != null) {
      return winner == player1;
    }
    return false;
  }

  /// player2가 승자인지 확인
  bool get isPlayer2Winner {
    if (winnerId != null && player2Id != null) {
      return winnerId == player2Id;
    }
    if (winner != null && player2 != null) {
      return winner == player2;
    }
    return false;
  }
}
