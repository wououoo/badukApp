class UserStats {
  final int totalContests;
  final int totalWins;
  final int totalLosses;
  final double winRate;
  final int? currentMcMahonScore;
  final int? bestRank;
  final List<String> recentForm; // ["W", "W", "L", "W", "W"]

  UserStats({
    required this.totalContests,
    required this.totalWins,
    required this.totalLosses,
    required this.winRate,
    this.currentMcMahonScore,
    this.bestRank,
    this.recentForm = const [],
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalContests: json['totalContests'] ?? 0,
      totalWins: json['totalWins'] ?? 0,
      totalLosses: json['totalLosses'] ?? 0,
      winRate: (json['winRate'] ?? 0).toDouble(),
      currentMcMahonScore: json['currentMcMahonScore'],
      bestRank: json['bestRank'],
      recentForm: (json['recentForm'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalContests': totalContests,
      'totalWins': totalWins,
      'totalLosses': totalLosses,
      'winRate': winRate,
      'currentMcMahonScore': currentMcMahonScore,
      'bestRank': bestRank,
      'recentForm': recentForm,
    };
  }

  String get recordText => '$totalWins승 $totalLosses패';

  String get winRateText => '${winRate.toStringAsFixed(1)}%';
}
