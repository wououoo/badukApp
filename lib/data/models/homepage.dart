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

  // === 결제·환불 PG 수수료 정책 (옛 백엔드 호환을 위해 모두 nullable) ===
  /// 결제 PG 수수료 부담자: HOST(운영자) / USER(참가자)
  final String? pgFeeBearer;
  /// 결제 PG 수수료 비율 (카드 결제 등)
  final double? pgFeeRate;
  /// 결제 PG 수수료 정액 (가상계좌, 기본 400원)
  final int? paymentFeeFixed;
  /// 환불 PG 수수료 부담자: HOST / USER
  final String? refundFeeBearer;
  /// 환불 PG 수수료 정액 (가상계좌, 기본 200원)
  final int? refundFeeFixed;
  /// 당일 취소 시 환불율 무시 + 전액 환불 (기본 true)
  final bool? sameDayFreeRefund;
  /// 환불 시 결제 PG 수수료 함께 환급 여부 (기본 true)
  final bool? paymentFeeRefundOnCancel;
  /// 운영자가 직접 입력한 환불 안내 문구 (있으면 자동 생성 안내 대체)
  final String? refundNoticeOverride;

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
    this.pgFeeBearer,
    this.pgFeeRate,
    this.paymentFeeFixed,
    this.refundFeeBearer,
    this.refundFeeFixed,
    this.sameDayFreeRefund,
    this.paymentFeeRefundOnCancel,
    this.refundNoticeOverride,
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
      pgFeeBearer: homepage['pgFeeBearer'] as String?,
      pgFeeRate: (homepage['pgFeeRate'] as num?)?.toDouble(),
      paymentFeeFixed: (homepage['paymentFeeFixed'] as num?)?.toInt(),
      refundFeeBearer: homepage['refundFeeBearer'] as String?,
      refundFeeFixed: (homepage['refundFeeFixed'] as num?)?.toInt(),
      sameDayFreeRefund: homepage['sameDayFreeRefund'] as bool?,
      paymentFeeRefundOnCancel: homepage['paymentFeeRefundOnCancel'] as bool?,
      refundNoticeOverride: homepage['refundNoticeOverride'] as String?,
    );
  }

  // === 정책 헬퍼 (기본값 적용) ===
  bool get isUserPaysPaymentFee => pgFeeBearer == 'USER';
  bool get isUserPaysRefundFee => refundFeeBearer == 'USER';
  bool get sameDayFree => sameDayFreeRefund != false; // null/true → true
  bool get refundPaymentFeeOnCancel => paymentFeeRefundOnCancel != false; // null/true → true
  int get paymentFeeFixedOrDefault => paymentFeeFixed ?? 400;
  int get refundFeeFixedOrDefault => refundFeeFixed ?? 200;

  /// 카테고리 fee 기준 사용자 부담 PG 수수료 (USER이면 정액 우선, 없으면 비율)
  int computeUserPaymentPgFee(int baseFee) {
    if (!isUserPaysPaymentFee) return 0;
    if (paymentFeeFixed != null && paymentFeeFixed! > 0) return paymentFeeFixed!;
    if (pgFeeRate != null && pgFeeRate! > 0) {
      return (baseFee * pgFeeRate! / 100).round();
    }
    return 0;
  }

  /// 환불 시뮬레이션 — 백엔드 RefundService.calculateRefund와 동일 공식
  ///   refundBase = userPaid - paymentPgUserPays - refundPgUserPays
  ///   refunded   = floor(refundBase * refundRate / 100)
  /// 당일 취소(sameDayFree)는 호출자가 별도 처리 (전액 환불).
  int simulateRefund(int userPaid, int refundRate) {
    final paymentPgUserPays = (isUserPaysPaymentFee && !refundPaymentFeeOnCancel)
        ? paymentFeeFixedOrDefault
        : 0;
    final refundPgUserPays = isUserPaysRefundFee ? refundFeeFixedOrDefault : 0;
    final refundBase = (userPaid - paymentPgUserPays - refundPgUserPays).clamp(0, 1 << 31);
    return ((refundBase * refundRate) / 100).floor().clamp(0, 1 << 31);
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
