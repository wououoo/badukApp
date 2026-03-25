/// DE(더블엘리미네이션) 예선 순위
class DEPreliminaryRanking {
  final int rank;
  final int? participantId;
  final String participantName;
  final int wins;
  final int losses;
  final String status; // '본선진출', '탈락', '진행중'

  DEPreliminaryRanking({
    required this.rank,
    this.participantId,
    required this.participantName,
    required this.wins,
    required this.losses,
    required this.status,
  });

  factory DEPreliminaryRanking.fromJson(Map<String, dynamic> json) {
    return DEPreliminaryRanking(
      rank: json['rank'] ?? 0,
      participantId: json['participantId'],
      participantName: json['participantName'] ?? json['playerName'] ?? '',
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      status: json['status'] ?? '진행중',
    );
  }

  bool get isQualified => status == '본선진출';
  bool get isEliminated => status == '탈락';
}

/// DE 예선 대진
class DEPreliminaryPairing {
  final int round;
  final String player1;
  final int? player1Number;
  final String player2;
  final int? player2Number;
  final String? winner;
  final bool isEnd;

  DEPreliminaryPairing({
    required this.round,
    required this.player1,
    this.player1Number,
    required this.player2,
    this.player2Number,
    this.winner,
    this.isEnd = false,
  });

  factory DEPreliminaryPairing.fromJson(Map<String, dynamic> json) {
    return DEPreliminaryPairing(
      round: json['round'] ?? 1,
      player1: json['player1']?.toString() ?? '',
      player1Number: json['player1Number'],
      player2: json['player2']?.toString() ?? '',
      player2Number: json['player2Number'],
      winner: json['winner']?.toString(),
      isEnd: json['end'] == true,
    );
  }

  bool get isPlayer1Winner => isEnd && winner == player1;
  bool get isPlayer2Winner => isEnd && winner == player2;
}

/// DE 예선 대진표 응답
class DEPreliminaryPairingsResponse {
  final List<DEPreliminaryPairing> pairings;
  final int maxRound;
  final int? group;

  DEPreliminaryPairingsResponse({
    required this.pairings,
    required this.maxRound,
    this.group,
  });

  factory DEPreliminaryPairingsResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['pairings'] as List<dynamic>?)
            ?.map((e) => DEPreliminaryPairing.fromJson(e))
            .toList() ??
        [];
    return DEPreliminaryPairingsResponse(
      pairings: list,
      maxRound: json['maxRound'] ?? 0,
      group: json['group'],
    );
  }
}

/// DE 토너먼트 순위
class DETournamentRanking {
  final int? rank;
  final int? playerId;
  final String playerName;
  final int? originalGroup;
  final String status; // '우승', '준우승', '4강', '8강', '진행중', '탈락' 등

  DETournamentRanking({
    this.rank,
    this.playerId,
    required this.playerName,
    this.originalGroup,
    required this.status,
  });

  factory DETournamentRanking.fromJson(Map<String, dynamic> json) {
    return DETournamentRanking(
      rank: json['rank'],
      playerId: json['playerId'],
      playerName: json['playerName'] ?? '',
      originalGroup: json['originalGroup'],
      status: json['status'] ?? '진행중',
    );
  }

  bool get isChampion => status == '우승';
  bool get isRunnerUp => status == '준우승';
  bool get isEliminated => status.contains('탈락');
  bool get isOngoing => status.contains('진행중');
}

/// DE 토너먼트 대진
class DETournamentPairing {
  final int round;
  final int? matchNumber;
  final String? player1;
  final int? player1Id;
  final String? player2;
  final int? player2Id;
  final int? winnerId;
  final bool isEnd;

  DETournamentPairing({
    required this.round,
    this.matchNumber,
    this.player1,
    this.player1Id,
    this.player2,
    this.player2Id,
    this.winnerId,
    this.isEnd = false,
  });

  factory DETournamentPairing.fromJson(Map<String, dynamic> json) {
    return DETournamentPairing(
      round: json['round'] ?? 0,
      matchNumber: json['matchNumber'],
      player1: json['player1']?.toString(),
      player1Id: json['player1Id'],
      player2: json['player2']?.toString(),
      player2Id: json['player2Id'],
      winnerId: json['winnerId'],
      isEnd: json['end'] == true,
    );
  }

  bool get isPlayer1Winner => isEnd && winnerId == player1Id;
  bool get isPlayer2Winner => isEnd && winnerId == player2Id;
}

/// DE 토너먼트 대진표 응답
class DETournamentPairingsResponse {
  final List<DETournamentPairing> pairings;
  final int maxRound;

  DETournamentPairingsResponse({
    required this.pairings,
    required this.maxRound,
  });

  factory DETournamentPairingsResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['pairings'] as List<dynamic>?)
            ?.map((e) => DETournamentPairing.fromJson(e))
            .toList() ??
        [];
    return DETournamentPairingsResponse(
      pairings: list,
      maxRound: json['maxRound'] ?? 0,
    );
  }
}
