/// 결제 정보 모델 (토스 가상계좌 전용)
class Payment {
  final int? paymentId;
  final int registrationId;
  final String? orderId;
  final String paymentMethod; // TOSS, FREE
  final String paymentStatus; // PENDING, WAITING_FOR_DEPOSIT, COMPLETED, FAILED, CANCELLED, REFUNDED, PARTIAL_REFUNDED
  final int amount;

  // 토스페이먼츠 정보
  final String? paymentKey;
  final String? orderName;

  // 영수증
  final String? receiptUrl;

  // 시간 정보
  final String? createdAt;
  final String? completedAt;

  // 참가 정보
  final String? participantName;
  final String? categoryName;
  final String? contestName;

  Payment({
    this.paymentId,
    required this.registrationId,
    this.orderId,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.amount,
    this.paymentKey,
    this.orderName,
    this.receiptUrl,
    this.createdAt,
    this.completedAt,
    this.participantName,
    this.categoryName,
    this.contestName,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      paymentId: json['paymentId'],
      registrationId: json['registrationId'] ?? 0,
      orderId: json['orderId'],
      paymentMethod: json['paymentMethod'] ?? 'UNKNOWN',
      paymentStatus: json['paymentStatus'] ?? 'UNKNOWN',
      amount: json['amount'] ?? 0,
      paymentKey: json['paymentKey'],
      orderName: json['orderName'],
      receiptUrl: json['receiptUrl'],
      createdAt: json['createdAt'],
      completedAt: json['completedAt'],
      participantName: json['participantName'],
      categoryName: json['categoryName'],
      contestName: json['contestName'],
    );
  }

  bool get isPending => paymentStatus == 'PENDING';
  bool get isWaitingForDeposit => paymentStatus == 'WAITING_FOR_DEPOSIT';
  bool get isCompleted => paymentStatus == 'COMPLETED';
  bool get isFailed => paymentStatus == 'FAILED';
  bool get isRefunded => paymentStatus == 'REFUNDED';
  bool get isToss => paymentMethod == 'TOSS';
  bool get isFree => amount == 0 && paymentMethod == 'FREE';

  String get statusText {
    switch (paymentStatus) {
      case 'PENDING':
        return '결제 대기';
      case 'WAITING_FOR_DEPOSIT':
        return '입금 대기';
      case 'COMPLETED':
        return '결제 완료';
      case 'FAILED':
        return '결제 실패';
      case 'CANCELLED':
        return '결제 취소';
      case 'REFUNDED':
        return '환불 완료';
      case 'PARTIAL_REFUNDED':
        return '부분 환불';
      default:
        return '알 수 없음';
    }
  }

  String get methodText {
    switch (paymentMethod) {
      case 'TOSS':
        return '토스페이먼츠';
      case 'FREE':
        return '무료';
      default:
        return '기타';
    }
  }

  String get amountText {
    if (amount == 0) return '무료';
    return '${_formatNumber(amount)}원';
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

/// 환불 정보 모델
class Refund {
  final int refundId;
  final int paymentId;
  final int registrationId;
  final String refundStatus; // REQUESTED, APPROVED, REJECTED, COMPLETED
  final int originalAmount;
  final int refundAmount;
  final int? refundRate;
  final String? refundReason;
  final String? rejectReason;
  final String? refundBankName;
  final String? refundAccountNumber;
  final String? refundAccountHolder;

  // 수수료/정산 정보
  final String? pgFeeBearer;      // PG 수수료 부담자
  final double? pgFeeRate;         // PG 수수료율
  final int? pgFeeAmount;          // PG 수수료 금액
  final int? deductionAmount;      // 환불 공제금
  final String? deductionOwner;    // 공제금 귀속

  final String? requestedAt;
  final String? processedAt;
  final String? processedBy;
  final String? participantName;
  final String? categoryName;

  Refund({
    required this.refundId,
    required this.paymentId,
    required this.registrationId,
    required this.refundStatus,
    required this.originalAmount,
    required this.refundAmount,
    this.refundRate,
    this.refundReason,
    this.rejectReason,
    this.refundBankName,
    this.refundAccountNumber,
    this.refundAccountHolder,
    this.pgFeeBearer,
    this.pgFeeRate,
    this.pgFeeAmount,
    this.deductionAmount,
    this.deductionOwner,
    this.requestedAt,
    this.processedAt,
    this.processedBy,
    this.participantName,
    this.categoryName,
  });

  factory Refund.fromJson(Map<String, dynamic> json) {
    return Refund(
      refundId: json['refundId'] ?? 0,
      paymentId: json['paymentId'] ?? 0,
      registrationId: json['registrationId'] ?? 0,
      refundStatus: json['refundStatus'] ?? 'UNKNOWN',
      originalAmount: json['originalAmount'] ?? 0,
      refundAmount: json['refundAmount'] ?? 0,
      refundRate: json['refundRate'],
      refundReason: json['refundReason'],
      rejectReason: json['rejectReason'],
      refundBankName: json['refundBankName'],
      refundAccountNumber: json['refundAccountNumber'],
      refundAccountHolder: json['refundAccountHolder'],
      pgFeeBearer: json['pgFeeBearer'],
      pgFeeRate: (json['pgFeeRate'] as num?)?.toDouble(),
      pgFeeAmount: json['pgFeeAmount'],
      deductionAmount: json['deductionAmount'],
      deductionOwner: json['deductionOwner'],
      requestedAt: json['requestedAt'],
      processedAt: json['processedAt'],
      processedBy: json['processedBy'],
      participantName: json['participantName'],
      categoryName: json['categoryName'],
    );
  }

  String get statusText {
    switch (refundStatus) {
      case 'REQUESTED':
        return '환불 요청';
      case 'APPROVED':
        return '승인됨';
      case 'REJECTED':
        return '거절됨';
      case 'COMPLETED':
        return '환불 완료';
      default:
        return '알 수 없음';
    }
  }

  /// 환불 공제금 (서버에서 내려오지 않으면 계산)
  int get calculatedDeductionAmount => deductionAmount ?? (originalAmount - refundAmount);
}

/// 환불 금액 계산 응답 모델
class RefundCalculation {
  final int registrationId;
  final int originalAmount;
  final int refundAmount;
  final int refundRate;
  final int deductionAmount;
  final String? policyDescription;
  final int? daysUntilContest;
  final bool refundable;
  final String message;
  final String? participantName;
  final String? categoryName;
  final String? contestName;
  final String? contestDate;

  // === 환불 차감 분해 (정책 기반 안내용) ===
  /// 홈페이지 ID — 정책 추가 조회용
  final int? homepageId;
  /// 사용자 부담 결제 PG 수수료 (환불 시 미환급 금액)
  final int? paymentPgUserPaid;
  /// 사용자 부담 환불 PG 수수료 (환불 처리 시 차감 금액)
  final int? refundPgUserPaid;
  /// 당일 면제 적용 여부 (true: 정책 무시 + 전액 환불)
  final bool? sameDayApplied;

  RefundCalculation({
    required this.registrationId,
    required this.originalAmount,
    required this.refundAmount,
    required this.refundRate,
    required this.deductionAmount,
    this.policyDescription,
    this.daysUntilContest,
    required this.refundable,
    required this.message,
    this.participantName,
    this.categoryName,
    this.contestName,
    this.contestDate,
    this.homepageId,
    this.paymentPgUserPaid,
    this.refundPgUserPaid,
    this.sameDayApplied,
  });

  factory RefundCalculation.fromJson(Map<String, dynamic> json) {
    return RefundCalculation(
      registrationId: json['registrationId'] ?? 0,
      originalAmount: json['originalAmount'] ?? 0,
      refundAmount: json['refundAmount'] ?? 0,
      refundRate: json['refundRate'] ?? 0,
      deductionAmount: json['deductionAmount'] ?? 0,
      policyDescription: json['policyDescription'],
      daysUntilContest: json['daysUntilContest'],
      refundable: json['refundable'] ?? false,
      message: json['message'] ?? '',
      participantName: json['participantName'],
      categoryName: json['categoryName'],
      contestName: json['contestName'],
      contestDate: json['contestDate'],
      homepageId: (json['homepageId'] as num?)?.toInt(),
      paymentPgUserPaid: (json['paymentPgUserPaid'] as num?)?.toInt(),
      refundPgUserPaid: (json['refundPgUserPaid'] as num?)?.toInt(),
      sameDayApplied: json['sameDayApplied'] as bool?,
    );
  }
}

/// 환불 정책 모델
class RefundPolicy {
  final int policyId;
  final int? homepageId;
  final int daysBeforeContest;
  final int refundRate;
  final String? description;

  RefundPolicy({
    required this.policyId,
    this.homepageId,
    required this.daysBeforeContest,
    required this.refundRate,
    this.description,
  });

  factory RefundPolicy.fromJson(Map<String, dynamic> json) {
    return RefundPolicy(
      policyId: json['policyId'] ?? 0,
      homepageId: json['homepageId'],
      daysBeforeContest: json['daysBeforeContest'] ?? 0,
      refundRate: json['refundRate'] ?? 0,
      description: json['description'],
    );
  }
}

