class ClubSchedule {
  final int id;
  final int clubId;
  final String title;
  final String date;
  final String? time;
  final String? location;
  final String? memo;
  final String? createdAt;

  ClubSchedule({
    required this.id,
    required this.clubId,
    required this.title,
    required this.date,
    this.time,
    this.location,
    this.memo,
    this.createdAt,
  });

  factory ClubSchedule.fromJson(Map<String, dynamic> json) {
    return ClubSchedule(
      id: json['id'] as int,
      clubId: json['clubId'] as int,
      title: json['title'] as String,
      date: json['date'] as String,
      time: json['time'] as String?,
      location: json['location'] as String?,
      memo: json['memo'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}
