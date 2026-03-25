/// 모바일용 대회 정보 모델 (ContestHomepage 기반)
class MobileContest {
  final int id;
  final String title;
  final String? subtitle;
  final String? organizer;
  final String? venue;
  final String? schedule;
  final String? participationFee;
  final String? registrationPeriod;
  final String? contactInfo;
  final DateTime? createdAt;
  final int? registrationCount;
  final int? categoryCount;

  MobileContest({
    required this.id,
    required this.title,
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
  });

  factory MobileContest.fromJson(Map<String, dynamic> json) {
    return MobileContest(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
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
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return DateTime.tryParse(value);
    }
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
}

/// 모바일용 대회 상세 정보 (ContestHomepage 기반)
class MobileContestDetail {
  final int id;
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
  final DateTime? createdAt;
  final int? registrationCount;
  final List<MobileCategory> categories;
  final List<MobilePrize> prizes;
  final List<MobileGameMethod> gameMethods;
  final List<int>? contestIds;

  MobileContestDetail({
    required this.id,
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
    this.createdAt,
    this.registrationCount,
    required this.categories,
    required this.prizes,
    required this.gameMethods,
    this.contestIds,
  });

  factory MobileContestDetail.fromJson(Map<String, dynamic> json) {
    final categoriesData = json['categories'] as List<dynamic>? ?? [];
    final prizesData = json['prizes'] as List<dynamic>? ?? [];
    final gameMethodsData = json['gameMethods'] as List<dynamic>? ?? [];
    final contestIdsData = json['contestIds'] as List<dynamic>? ?? [];

    return MobileContestDetail(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['name'] ?? '',
      subtitle: json['subtitle'],
      organizer: json['organizer'],
      sponsor: json['sponsor'],
      eligibility: json['eligibility'],
      participationFee: json['participationFee'],
      schedule: json['schedule'],
      venue: json['venue'],
      registrationPeriod: json['registrationPeriod'],
      contactInfo: json['contactInfo'],
      createdAt: _parseDateTime(json['createdAt']),
      registrationCount: json['registrationCount'],
      categories: categoriesData.map((e) => MobileCategory.fromJson(e)).toList(),
      prizes: prizesData.map((e) => MobilePrize.fromJson(e)).toList(),
      gameMethods: gameMethodsData.map((e) => MobileGameMethod.fromJson(e)).toList(),
      contestIds: contestIdsData.map((e) => e as int).toList(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return DateTime.tryParse(value);
    }
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
}

/// 참가 부문
class MobileCategory {
  final int id;
  final String categoryName;
  final String? skillRequirement;
  final int? maxParticipants;
  final String? participantsDisplayText;
  final String? gameTime;
  final String? note;
  final String? contestType;
  final int? teamSize;
  final int? displayOrder;
  final int? currentParticipants;

  MobileCategory({
    required this.id,
    required this.categoryName,
    this.skillRequirement,
    this.maxParticipants,
    this.participantsDisplayText,
    this.gameTime,
    this.note,
    this.contestType,
    this.teamSize,
    this.displayOrder,
    this.currentParticipants,
  });

  factory MobileCategory.fromJson(Map<String, dynamic> json) {
    return MobileCategory(
      id: json['id'] ?? 0,
      categoryName: json['categoryName'] ?? '',
      skillRequirement: json['skillRequirement'],
      maxParticipants: json['maxParticipants'],
      participantsDisplayText: json['participantsDisplayText'],
      gameTime: json['gameTime'],
      note: json['note'],
      contestType: json['contestType'],
      teamSize: json['teamSize'],
      displayOrder: json['displayOrder'],
      currentParticipants: json['currentParticipants'],
    );
  }
}

/// 상금 정보
class MobilePrize {
  final int id;
  final String? groupName;
  final String? prizeTitle;
  final String? rankName;
  final String? prizeContent;
  final int? displayOrder;

  MobilePrize({
    required this.id,
    this.groupName,
    this.prizeTitle,
    this.rankName,
    this.prizeContent,
    this.displayOrder,
  });

  factory MobilePrize.fromJson(Map<String, dynamic> json) {
    return MobilePrize(
      id: json['id'] ?? 0,
      groupName: json['groupName'],
      prizeTitle: json['prizeTitle'],
      rankName: json['rankName'],
      prizeContent: json['prizeContent'],
      displayOrder: json['displayOrder'],
    );
  }
}

/// 게임 진행 방법
class MobileGameMethod {
  final int id;
  final String? gameType;
  final String? description;
  final String? thinkingTime;
  final String? handicapSystem;
  final int? displayOrder;

  MobileGameMethod({
    required this.id,
    this.gameType,
    this.description,
    this.thinkingTime,
    this.handicapSystem,
    this.displayOrder,
  });

  factory MobileGameMethod.fromJson(Map<String, dynamic> json) {
    return MobileGameMethod(
      id: json['id'] ?? 0,
      gameType: json['gameType'],
      description: json['description'],
      thinkingTime: json['thinkingTime'],
      handicapSystem: json['handicapSystem'],
      displayOrder: json['displayOrder'],
    );
  }
}
