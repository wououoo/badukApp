/// 대회 개최 의뢰 모델

/// 대회 부문 모델
class ContestCategoryInput {
  String categoryName;
  String? skillRequirement;
  int? maxParticipants;
  String? gameTime;
  String contestType; // MCM, SWISS, FULL_LEAGUE, DE, TEAM_SWISS
  int? teamSize;
  int fee;
  String? feeDescription;
  String? note;

  ContestCategoryInput({
    this.categoryName = '',
    this.skillRequirement,
    this.maxParticipants,
    this.gameTime,
    this.contestType = 'MCM',
    this.teamSize,
    this.fee = 0,
    this.feeDescription,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'categoryName': categoryName,
      'skillRequirement': skillRequirement,
      'maxParticipants': maxParticipants,
      'gameTime': gameTime,
      'contestType': contestType,
      'teamSize': teamSize,
      'fee': fee,
      'feeDescription': feeDescription,
      'note': note,
    };
  }
}

/// 대회 개최 의뢰 입력 모델
class ContestRequestInput {
  // 기본 정보
  String title;
  String? subtitle;
  String? organizer;
  String? sponsor;
  String? eligibility;
  String? participationFee;
  String? schedule;
  String? venue;
  String? registrationPeriod;
  DateTime? registrationStartDate;
  DateTime? registrationEndDate;
  String? contactInfo;

  // 부문 목록
  List<ContestCategoryInput> categories;

  // 첨부파일 경로 (로컬)
  List<String> attachmentPaths;

  // 추가 요청사항
  String? additionalNotes;

  ContestRequestInput({
    this.title = '',
    this.subtitle,
    this.organizer,
    this.sponsor,
    this.eligibility,
    this.participationFee,
    this.schedule,
    this.venue,
    this.registrationPeriod,
    this.registrationStartDate,
    this.registrationEndDate,
    this.contactInfo,
    this.additionalNotes,
    List<ContestCategoryInput>? categories,
    List<String>? attachmentPaths,
  })  : categories = categories ?? [],
        attachmentPaths = attachmentPaths ?? [];

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'organizer': organizer,
      'sponsor': sponsor,
      'eligibility': eligibility,
      'participationFee': participationFee,
      'schedule': schedule,
      'venue': venue,
      'registrationPeriod': registrationPeriod,
      'registrationStartDate': registrationStartDate?.toIso8601String(),
      'registrationEndDate': registrationEndDate?.toIso8601String(),
      'contactInfo': contactInfo,
      'additionalNotes': additionalNotes,
      'categories': categories.map((c) => c.toJson()).toList(),
    };
  }
}

/// 대회 유형 enum
enum ContestTypeEnum {
  mcm('MCM', '맥마흔'),
  swiss('SWISS', '스위스리그'),
  fullLeague('FULL_LEAGUE', '풀리그'),
  de('DE', '더블엘리미네이션'),
  teamSwiss('TEAM_SWISS', '단체전 스위스리그');

  final String code;
  final String label;

  const ContestTypeEnum(this.code, this.label);

  static ContestTypeEnum fromCode(String code) {
    return ContestTypeEnum.values.firstWhere(
      (e) => e.code == code,
      orElse: () => ContestTypeEnum.mcm,
    );
  }
}
