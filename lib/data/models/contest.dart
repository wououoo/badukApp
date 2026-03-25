/// 대회 정보 모델 (ContestHomepage 기반)
class Contest {
  final int id;
  final String name;           // title에서 매핑
  final String? subtitle;
  final String? organizer;     // 주최/주관
  final String? venue;         // 대회장소
  final String? schedule;      // 대회일정
  final String? participationFee; // 참가비
  final String? registrationPeriod; // 접수기간
  final String? contactInfo;   // 문의처
  final DateTime? createdAt;
  final int? registrationCount; // 참가신청자 수
  final int? categoryCount;    // 부문 수

  // 기존 필드 (하위 호환성)
  final String? contestProv;
  final String? contestLocation;
  final String? contestDetailLocation;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String>? types;
  final String? status;
  final int? sortCount;
  final int? totalParticipants;
  final bool? isHidden;
  final String? posterUrl;        // 대회 포스터 이미지 URL
  final List<LinkedContest>? linkedContests;

  // 위치 좌표
  final String? address;
  final double? latitude;
  final double? longitude;

  Contest({
    required this.id,
    required this.name,
    this.subtitle,
    this.organizer,
    this.venue,
    this.schedule,
    this.participationFee,
    this.registrationPeriod,
    this.contactInfo,
    this.createdAt,
    this.registrationCount,
    this.categoryCount,
    this.contestProv,
    this.contestLocation,
    this.contestDetailLocation,
    this.startDate,
    this.endDate,
    this.types,
    this.status,
    this.sortCount,
    this.totalParticipants,
    this.isHidden,
    this.posterUrl,
    this.linkedContests,
    this.address,
    this.latitude,
    this.longitude,
  });

  factory Contest.fromJson(Map<String, dynamic> json) {
    return Contest(
      id: json['id'] ?? 0,
      // 새 API: title, 기존 API: contestName
      name: json['title'] ?? json['contestName'] ?? '',
      subtitle: json['subtitle'],
      organizer: json['organizer'],
      venue: json['venue'],
      schedule: json['schedule'],
      participationFee: json['participationFee'],
      registrationPeriod: json['registrationPeriod'],
      contactInfo: json['contactInfo'],
      createdAt: _parseDateTime(json['createdAt']),
      registrationCount: json['registrationCount'],
      categoryCount: json['categoryCount'],
      // 기존 필드
      contestProv: json['contestProv'],
      contestLocation: json['contestLocation'],
      contestDetailLocation: json['contestDetailLocation'],
      startDate: _parseDateTime(json['contestStartDate'] ?? json['startDate']),
      endDate: _parseDateTime(json['contestEndDate'] ?? json['endDate']),
      types: json['types'] != null ? List<String>.from(json['types']) : null,
      // contestStatus(대회 날짜 기반) 우선, 없으면 registrationStatus(접수 상태), 기존 API는 status
      status: json['contestStatus'] ?? json['registrationStatus'] ?? json['status'],
      sortCount: json['sortCount'],
      totalParticipants: json['totalParticipants'] ?? json['registrationCount'],
      isHidden: json['isHidden'],
      posterUrl: json['posterUrl'],
      linkedContests: json['linkedContests'] != null
          ? (json['linkedContests'] as List)
              .map((e) => LinkedContest.fromJson(e))
              .toList()
          : null,
      address: json['address'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is List && value.length >= 3) {
      // [2024, 12, 15, 10, 0] 형태 처리
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': name,
      'subtitle': subtitle,
      'organizer': organizer,
      'venue': venue,
      'schedule': schedule,
      'participationFee': participationFee,
      'registrationPeriod': registrationPeriod,
      'contactInfo': contactInfo,
      'createdAt': createdAt?.toIso8601String(),
      'registrationCount': registrationCount,
      'categoryCount': categoryCount,
    };
  }

  /// 전체 위치 문자열 반환
  String get fullLocation {
    // 새 API: venue 사용
    if (venue != null && venue!.isNotEmpty) {
      return venue!;
    }
    // 기존 API: contestProv + contestLocation + contestDetailLocation
    final parts = <String>[];
    if (contestProv != null) parts.add(contestProv!);
    if (contestLocation != null) parts.add(contestLocation!);
    if (contestDetailLocation != null) parts.add(contestDetailLocation!);
    return parts.join(' ');
  }

  /// 짧은 지역명 반환 (카드 표시용)
  String get region {
    // 도/시 정보 우선
    if (contestProv != null && contestProv!.isNotEmpty) {
      return contestProv!;
    }
    // venue에서 첫 단어만 추출 (예: "서울시 강남구 ..." → "서울시")
    if (venue != null && venue!.isNotEmpty) {
      final parts = venue!.split(' ');
      if (parts.isNotEmpty) {
        return parts.first;
      }
    }
    if (contestLocation != null && contestLocation!.isNotEmpty) {
      return contestLocation!;
    }
    return '';
  }

  bool get isUpcoming => status == '예정';
  bool get isOngoing => status == '진행중';
  bool get isFinished => status == '종료';
}

/// 연결된 하위 대회 정보
class LinkedContest {
  final int id;
  final String contestName;
  final List<String>? types;
  final int? sortCount;
  final int? totalParticipants;

  LinkedContest({
    required this.id,
    required this.contestName,
    this.types,
    this.sortCount,
    this.totalParticipants,
  });

  factory LinkedContest.fromJson(Map<String, dynamic> json) {
    return LinkedContest(
      id: json['id'] ?? 0,
      contestName: json['contestName'] ?? '',
      types: json['types'] != null ? List<String>.from(json['types']) : null,
      sortCount: json['sortCount'],
      totalParticipants: json['totalParticipants'],
    );
  }
}
