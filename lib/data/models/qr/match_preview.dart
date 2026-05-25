/// 매치 미리보기 DTO (MatchPreviewDTO)
/// 홈 화면 "내 대회" 카드에서 본인 매치 옆 인접 테이블 매치를 간단히 보여줄 때 사용.
class MatchPreview {
  final int? matchNumber;
  final String? player1Name;
  final String? player2Name; // null이면 부전승
  final String? status; // ONGOING / COMPLETED / SCHEDULED
  final String? winnerName;
  final bool isMyMatch;

  MatchPreview({
    this.matchNumber,
    this.player1Name,
    this.player2Name,
    this.status,
    this.winnerName,
    this.isMyMatch = false,
  });

  factory MatchPreview.fromJson(Map<String, dynamic> json) {
    return MatchPreview(
      matchNumber: json['matchNumber'],
      player1Name: json['player1Name'],
      player2Name: json['player2Name'],
      status: json['status'],
      winnerName: json['winnerName'],
      isMyMatch: json['isMyMatch'] ?? false,
    );
  }

  bool get isCompleted => status == 'COMPLETED';
  bool get isBye => player2Name == null;
}
