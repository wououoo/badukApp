/// 참가신청 데이터 모델
class RegistrationData {
  final int homepageId;
  final int categoryId;
  final String name;
  final String skillLevel;
  final String? phone;
  final String password; // 4자리 숫자
  final String type; // CHILD, ADULT, TEAM

  // 유소년부 전용
  final String? school;
  final String? academy;
  final String? birthYear;
  final String? address;
  final String? parentPhone;

  // 일반부 전용
  final String? region;
  final String? club;

  // 단체전 전용
  final String? teamName;
  final List<Map<String, dynamic>>? teamMembers; // 팀 대표 일괄 등록 시 팀원 정보
  final int? teamMemberOrder; // 팀 합류 시 자리 순서
  final int? parentRegistrationId; // 팀 합류 시 대표 등록 ID

  // 앱 사용자 연동 (푸시 알림용)
  final int? mobileUserId;

  RegistrationData({
    required this.homepageId,
    required this.categoryId,
    required this.name,
    required this.skillLevel,
    this.phone,
    required this.password,
    required this.type,
    this.school,
    this.academy,
    this.birthYear,
    this.address,
    this.parentPhone,
    this.region,
    this.club,
    this.teamName,
    this.teamMembers,
    this.teamMemberOrder,
    this.parentRegistrationId,
    this.mobileUserId,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'homepageId': homepageId,
      'categoryId': categoryId,
      'name': name,
      'skillLevel': skillLevel,
      'phone': _formatPhone(phone),
      'password': password,
      'type': type,
      'registeredAt': DateTime.now().toIso8601String(),
      if (mobileUserId != null) 'mobileUserId': mobileUserId,
    };

    if (type == 'CHILD') {
      data['school'] = school ?? '';
      data['academy'] = academy ?? '';
      data['birthYear'] = birthYear ?? '';
      data['address'] = address ?? '';
      data['parentPhone'] = _formatPhone(parentPhone) ?? '';
      data['emergencyContact'] = _formatPhone(parentPhone) ?? '';
    } else if (type == 'ADULT') {
      data['region'] = region ?? '';
      data['club'] = club ?? '';
      data['emergencyContact'] = _formatPhone(phone) ?? '';
    } else if (type == 'TEAM') {
      data['teamName'] = teamName ?? '';
      data['region'] = region ?? '';
      data['club'] = club ?? '';
      if (teamMembers != null) {
        data['teamMembers'] = teamMembers;
      }
      if (teamMemberOrder != null) {
        data['teamMemberOrder'] = teamMemberOrder;
      }
      if (parentRegistrationId != null) {
        data['parentRegistrationId'] = parentRegistrationId;
      }
    }

    return data;
  }

  String? _formatPhone(String? phone) {
    if (phone == null || phone.isEmpty) return null;
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length == 11) {
      return '${cleaned.substring(0, 3)}-${cleaned.substring(3, 7)}-${cleaned.substring(7)}';
    }
    return phone;
  }
}

/// 참가신청 결과 응답
class RegistrationResponse {
  final bool success;
  final String? message;
  final int? registrationId;

  RegistrationResponse({
    required this.success,
    this.message,
    this.registrationId,
  });

  factory RegistrationResponse.fromJson(Map<String, dynamic> json) {
    return RegistrationResponse(
      success: json['success'] ?? false,
      message: json['message'],
      registrationId: json['registrationId'],
    );
  }
}

/// 참가신청 조회용 (비밀번호 확인)
class RegistrationInfo {
  final int registrationId;
  final String name;
  final String skillLevel;
  final String? phone;
  final String categoryName;
  final String status;
  final DateTime? registeredAt;

  RegistrationInfo({
    required this.registrationId,
    required this.name,
    required this.skillLevel,
    this.phone,
    required this.categoryName,
    required this.status,
    this.registeredAt,
  });

  factory RegistrationInfo.fromJson(Map<String, dynamic> json) {
    return RegistrationInfo(
      registrationId: json['registrationId'] ?? 0,
      name: json['name'] ?? '',
      skillLevel: json['skillLevel'] ?? '',
      phone: json['phone'],
      categoryName: json['categoryName'] ?? '',
      status: json['status'] ?? '',
      registeredAt: json['registeredAt'] != null
          ? DateTime.tryParse(json['registeredAt'].toString())
          : null,
    );
  }

  String get statusText {
    switch (status) {
      case 'PENDING':
        return '신청완료';
      case 'APPROVED':
        return '승인완료';
      case 'REJECTED':
        return '신청거절';
      case 'CANCELLED':
        return '신청취소';
      default:
        return '알 수 없음';
    }
  }
}
