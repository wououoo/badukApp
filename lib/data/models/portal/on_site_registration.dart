/// 현장 등록 요청 모델
class OnSiteRegistrationRequest {
  final String participantName;
  final String phone;
  final String? playerRank;
  final String? province;
  final String? city;
  final String? memo;

  OnSiteRegistrationRequest({
    required this.participantName,
    required this.phone,
    this.playerRank,
    this.province,
    this.city,
    this.memo,
  });

  Map<String, dynamic> toJson() {
    return {
      'participantName': participantName,
      'phone': phone,
      if (playerRank != null) 'playerRank': playerRank,
      if (province != null) 'province': province,
      if (city != null) 'city': city,
      if (memo != null) 'memo': memo,
    };
  }
}

/// 현장 등록 결과 모델
class OnSiteRegistrationResult {
  final bool success;
  final String? message;
  final int? registrationId;
  final String? registeredAt;

  OnSiteRegistrationResult({
    required this.success,
    this.message,
    this.registrationId,
    this.registeredAt,
  });

  factory OnSiteRegistrationResult.fromJson(Map<String, dynamic> json) {
    return OnSiteRegistrationResult(
      success: json['success'] ?? false,
      message: json['message'],
      registrationId: json['registrationId'],
      registeredAt: json['registeredAt'],
    );
  }

  factory OnSiteRegistrationResult.error(String message) {
    return OnSiteRegistrationResult(
      success: false,
      message: message,
    );
  }
}
