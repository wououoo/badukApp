/// 순위 정보 모델
///
/// 대회 유형별 백엔드 응답 키값:
///
/// MCM: ranking, userName, wins, losses, score, rank(급수문자열)
/// SWISS: participantName, totalWins, useSwissLeague, sososPoints, none
/// TEAM_SWISS: rank, teamName, totalWins, sos, totalIndividualWins, player1Wins~
class Ranking {
  final int rank;
  final String name;
  final int wins;
  final int? losses;
  final double? points;     // MCM: score, SWISS: useSwissLeague
  final double? sos;        // MCM: 없음, SWISS: sososPoints, TEAM_SWISS: sos
  final String? teamName;   // TEAM_SWISS 전용
  final int? totalIndividualWins;  // TEAM_SWISS: 총개인승
  final String? levelRank;  // MCM: 급수 문자열 (예: "3단", "2급")

  Ranking({
    required this.rank,
    required this.name,
    required this.wins,
    this.losses,
    this.points,
    this.sos,
    this.teamName,
    this.totalIndividualWins,
    this.levelRank,
  });

  factory Ranking.fromJson(Map<String, dynamic> json, int index) {
    return Ranking(
      // 순위: ranking(MCM) || rank(TEAM_SWISS가 int일 때) || index+1
      // MCM의 rank는 급수 문자열("3단")이므로 int 타입 체크 필요
      rank: json['ranking'] ?? (json['rank'] is int ? json['rank'] : null) ?? (index + 1),

      // 이름: userName(MCM) || participantName(SWISS) || teamName(TEAM_SWISS)
      name: json['userName'] ?? json['participantName'] ?? json['name'] ?? json['teamName'] ?? '',

      // 승수: wins(MCM) || totalWins(SWISS/TEAM_SWISS)
      wins: json['wins'] ?? json['totalWins'] ?? 0,

      // 패수: losses(MCM만)
      losses: json['losses'],

      // 점수: score(MCM) || useSwissLeague(SWISS) || points(공통)
      points: (json['score'] ?? json['useSwissLeague'] ?? json['points'])?.toDouble(),

      // SOS: sososPoints(SWISS) || sos(TEAM_SWISS) || sosScore(공통)
      sos: (json['sososPoints'] ?? json['sos'] ?? json['sosScore'])?.toDouble(),

      // 팀명 (TEAM_SWISS)
      teamName: json['teamName'],

      // 총개인승 (TEAM_SWISS)
      totalIndividualWins: json['totalIndividualWins'],

      // 급수 문자열 (MCM) - rank 키가 숫자가 아닌 문자열일 때
      levelRank: json['rank'] is String ? json['rank'] : null,
    );
  }
}
