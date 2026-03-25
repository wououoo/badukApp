/// 캘린더용 대회 모델
class CalendarContest {
  final int id;
  final String title;
  final String? venue;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final String source; // "public" or "club"
  final int? clubId;
  final String? clubName;

  CalendarContest({
    required this.id,
    required this.title,
    this.venue,
    this.startDate,
    this.endDate,
    this.status,
    required this.source,
    this.clubId,
    this.clubName,
  });

  factory CalendarContest.fromJson(Map<String, dynamic> json) {
    return CalendarContest(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] ?? '',
      venue: json['venue'],
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      status: json['status'],
      source: json['source'] ?? 'public',
      clubId: (json['clubId'] as num?)?.toInt(),
      clubName: json['clubName'],
    );
  }

  bool get isPublic => source == 'public';
  bool get isClub => source == 'club';
}
