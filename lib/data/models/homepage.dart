/// 대회 홈페이지 모델 (공개 목록용)
class ContestHomepage {
  final int homepageId;
  final String title;
  final String? subtitle;
  final String? organizer;
  final String? venue;
  final String? schedule;
  final String? participationFee;
  final String? registrationPeriod;
  final DateTime? createdAt;
  final int registrationCount;
  final int categoryCount;

  ContestHomepage({
    required this.homepageId,
    required this.title,
    this.subtitle,
    this.organizer,
    this.venue,
    this.schedule,
    this.participationFee,
    this.registrationPeriod,
    this.createdAt,
    this.registrationCount = 0,
    this.categoryCount = 0,
  });

  factory ContestHomepage.fromJson(Map<String, dynamic> json) {
    return ContestHomepage(
      homepageId: json['homepageId'] ?? 0,
      title: json['title'] ?? '',
      subtitle: json['subtitle'],
      organizer: json['organizer'],
      venue: json['venue'],
      schedule: json['schedule'],
      participationFee: json['participationFee'],
      registrationPeriod: json['registrationPeriod'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      registrationCount: json['registrationCount'] ?? 0,
      categoryCount: json['categoryCount'] ?? 0,
    );
  }
}

/// 대회 홈페이지 상세 모델
class HomepageDetail {
  final int homepageId;
  final String title;
  final String? subtitle;
  final String? organizer;
  final String? sponsor;
  final String? eligibility;
  final String? participationFee;
  final String? schedule;
  final String? venue;
  final String? registrationPeriod;
  final String? contactInfo;
  final bool isPublished;
  final List<HomepageCategory> categories;
  final List<HomepagePrize>? prizes;
  final List<HomepageGameMethod>? gameMethods;
  final int registrationCount;

  HomepageDetail({
    required this.homepageId,
    required this.title,
    this.subtitle,
    this.organizer,
    this.sponsor,
    this.eligibility,
    this.participationFee,
    this.schedule,
    this.venue,
    this.registrationPeriod,
    this.contactInfo,
    this.isPublished = false,
    this.categories = const [],
    this.prizes,
    this.gameMethods,
    this.registrationCount = 0,
  });

  factory HomepageDetail.fromJson(Map<String, dynamic> json) {
    final homepage = json['homepage'] ?? json;
    final categoriesData = json['categories'] as List<dynamic>? ?? [];
    final prizesData = json['prizes'] as List<dynamic>?;
    final gameMethodsData = json['gameMethods'] as List<dynamic>?;

    return HomepageDetail(
      homepageId: homepage['homepageId'] ?? homepage['id'] ?? 0,
      title: homepage['title'] ?? '',
      subtitle: homepage['subtitle'],
      organizer: homepage['organizer'],
      sponsor: homepage['sponsor'],
      eligibility: homepage['eligibility'],
      participationFee: homepage['participationFee'],
      schedule: homepage['schedule'],
      venue: homepage['venue'],
      registrationPeriod: homepage['registrationPeriod'],
      contactInfo: homepage['contactInfo'],
      isPublished: homepage['isPublished'] ?? false,
      categories: categoriesData.map((e) => HomepageCategory.fromJson(e)).toList(),
      prizes: prizesData?.map((e) => HomepagePrize.fromJson(e)).toList(),
      gameMethods: gameMethodsData?.map((e) => HomepageGameMethod.fromJson(e)).toList(),
      registrationCount: json['registrationCount'] ?? 0,
    );
  }
}

/// 참가 부문
class HomepageCategory {
  final int categoryId;
  final String categoryName;
  final String? categoryType; // CHILD, ADULT, TEAM
  final String? skillRange;
  final String? fee;
  final int? maxParticipants;
  final int displayOrder;

  HomepageCategory({
    required this.categoryId,
    required this.categoryName,
    this.categoryType,
    this.skillRange,
    this.fee,
    this.maxParticipants,
    this.displayOrder = 0,
  });

  factory HomepageCategory.fromJson(Map<String, dynamic> json) {
    return HomepageCategory(
      categoryId: json['categoryId'] ?? json['id'] ?? 0,
      categoryName: json['categoryName'] ?? json['name'] ?? '',
      categoryType: json['categoryType'],
      skillRange: json['skillRange'],
      fee: json['fee']?.toString(),
      maxParticipants: json['maxParticipants'],
      displayOrder: json['displayOrder'] ?? 0,
    );
  }

  String get feeText {
    if (fee == null || fee!.isEmpty || fee == '0') return '무료';
    return fee!;
  }

  String get categoryTypeText {
    switch (categoryType) {
      case 'CHILD':
        return '유소년부';
      case 'ADULT':
        return '일반부';
      case 'TEAM':
        return '단체전';
      default:
        return categoryType ?? '';
    }
  }
}

/// 상금 정보
class HomepagePrize {
  final int prizeId;
  final int? categoryId;
  final String rank;
  final String prize;

  HomepagePrize({
    required this.prizeId,
    this.categoryId,
    required this.rank,
    required this.prize,
  });

  factory HomepagePrize.fromJson(Map<String, dynamic> json) {
    return HomepagePrize(
      prizeId: json['prizeId'] ?? json['id'] ?? 0,
      categoryId: json['categoryId'],
      rank: json['rank'] ?? '',
      prize: json['prize'] ?? '',
    );
  }
}

/// 게임 진행 방법
class HomepageGameMethod {
  final int methodId;
  final String gameType;
  final String description;

  HomepageGameMethod({
    required this.methodId,
    required this.gameType,
    required this.description,
  });

  factory HomepageGameMethod.fromJson(Map<String, dynamic> json) {
    return HomepageGameMethod(
      methodId: json['methodId'] ?? json['id'] ?? 0,
      gameType: json['gameType'] ?? '',
      description: json['description'] ?? '',
    );
  }
}
