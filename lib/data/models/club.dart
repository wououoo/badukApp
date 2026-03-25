/// 클럽 요약 정보 (목록용)
class ClubSummary {
  final int id;
  final String name;
  final String? region;
  final String? city;
  final int memberCount;
  final bool isMyClub;
  final String? myRole;
  final String? photoUrl;

  ClubSummary({
    required this.id,
    required this.name,
    this.region,
    this.city,
    this.memberCount = 0,
    this.isMyClub = false,
    this.myRole,
    this.photoUrl,
  });

  factory ClubSummary.fromJson(Map<String, dynamic> json) {
    return ClubSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      region: json['region'] as String?,
      city: json['city'] as String?,
      memberCount: json['memberCount'] as int? ?? 0,
      isMyClub: json['isMyClub'] as bool? ?? false,
      myRole: json['myRole'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }
}

/// 클럽 상세 정보
class ClubDetail {
  final int id;
  final String name;
  final String? description;
  final String? region;
  final String? city;
  final int ownerId;
  final String? ownerName;
  final int memberCount;
  final List<ClubMemberInfo> members;
  final bool isMyClub;
  final String? myRole;
  final String? createdAt;
  final String? photoUrl;

  ClubDetail({
    required this.id,
    required this.name,
    this.description,
    this.region,
    this.city,
    required this.ownerId,
    this.ownerName,
    this.memberCount = 0,
    this.members = const [],
    this.isMyClub = false,
    this.myRole,
    this.createdAt,
    this.photoUrl,
  });

  factory ClubDetail.fromJson(Map<String, dynamic> json) {
    return ClubDetail(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      region: json['region'] as String?,
      city: json['city'] as String?,
      ownerId: json['ownerId'] as int,
      ownerName: json['ownerName'] as String?,
      memberCount: json['memberCount'] as int? ?? 0,
      members: json['members'] != null
          ? (json['members'] as List).map((e) => ClubMemberInfo.fromJson(e)).toList()
          : [],
      isMyClub: json['isMyClub'] as bool? ?? false,
      myRole: json['myRole'] as String?,
      createdAt: json['createdAt'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }
}

/// 클럽 멤버 정보
class ClubMemberInfo {
  final int userId;
  final String? name;
  final String? rank;
  final int? level;
  final String role;
  final String? joinedAt;

  ClubMemberInfo({
    required this.userId,
    this.name,
    this.rank,
    this.level,
    required this.role,
    this.joinedAt,
  });

  factory ClubMemberInfo.fromJson(Map<String, dynamic> json) {
    return ClubMemberInfo(
      userId: json['userId'] as int,
      name: json['name'] as String?,
      rank: json['rank'] as String?,
      level: json['level'] as int?,
      role: json['role'] as String? ?? 'MEMBER',
      joinedAt: json['joinedAt'] as String?,
    );
  }
}

/// 클럽 가입 신청 정보
class ClubJoinRequestInfo {
  final int id;
  final int userId;
  final String? userName;
  final String? userRank;
  final String? message;
  final String status;
  final String? createdAt;

  ClubJoinRequestInfo({
    required this.id,
    required this.userId,
    this.userName,
    this.userRank,
    this.message,
    required this.status,
    this.createdAt,
  });

  factory ClubJoinRequestInfo.fromJson(Map<String, dynamic> json) {
    return ClubJoinRequestInfo(
      id: json['id'] as int,
      userId: json['userId'] as int,
      userName: json['userName'] as String?,
      userRank: json['userRank'] as String?,
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['createdAt'] as String?,
    );
  }
}
