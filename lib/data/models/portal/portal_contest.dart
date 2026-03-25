/// 포털 대회 정보 모델
class PortalContest {
  final int id;
  final String contestName;
  final String? contestType;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool? checkInEnabled;

  PortalContest({
    required this.id,
    required this.contestName,
    this.contestType,
    this.startDate,
    this.endDate,
    this.checkInEnabled,
  });

  factory PortalContest.fromJson(Map<String, dynamic> json) {
    return PortalContest(
      id: json['id'] ?? json['contestId'] ?? 0,
      contestName: json['contestName'] ?? '',
      contestType: json['contestType'],
      startDate: _parseDateTime(json['startDate']),
      endDate: _parseDateTime(json['endDate']),
      checkInEnabled: json['checkInEnabled'],
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    if (value is List && value.length >= 3) {
      return DateTime(
        value[0],
        value[1],
        value[2],
        value.length > 3 ? value[3] : 0,
        value.length > 4 ? value[4] : 0,
      );
    }
    return null;
  }

  /// 대회 유형 라벨
  String get contestTypeLabel {
    switch (contestType) {
      case 'MCM':
        return '맥마흔';
      case 'SWISS':
        return '스위스리그';
      case 'TEAM_SWISS':
        return '단체 스위스리그';
      case 'FULL_LEAGUE':
        return '풀리그';
      case 'TEAM_FULL_LEAGUE':
        return '단체 풀리그';
      case 'DE':
        return '더블엘리미네이션';
      default:
        return contestType ?? '';
    }
  }
}
