class User {
  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? rank; // 기력 표시명 (예: "5단", "3급")
  final int? level; // 기력 레벨 (1-48)
  final int? mcmahonScore; // 기력 기반 계산 점수
  final double? mcmahonNationalScore; // 전국 맥마흔 점수 (대회 결과 반영)
  final int? mcmahonNationalUserId; // 연동된 전국 맥마흔 유저 ID
  final int? mcmahonTotalGames; // 총 대국 수
  final int? mcmahonContestCount; // 총 대회 참가 수
  final String? region; // 시/도
  final String? city; // 시/군/구
  final String? club; // 소속 클럽
  final bool? identityVerified; // 본인인증 완료 여부
  final bool? profileCompleted; // 프로필 설정 완료 여부

  // 역할 및 주최자 관련
  final String? role; // PARTICIPANT, HOST, ADMIN
  final String? hostStatus; // NONE, PENDING, APPROVED, REJECTED
  final String? organization; // 소속 (협회, 도장 등)
  final String? organizationType; // 협회, 도장, 동호회, 개인
  final bool? openbankingConnected; // 오픈뱅킹 연동 여부

  // 개인정보 동의 관련
  final bool? privacyConsented; // 개인정보 동의 완료 여부
  final String? privacyConsentVersion; // 동의한 약관 버전

  User({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.rank,
    this.level,
    this.mcmahonScore,
    this.mcmahonNationalScore,
    this.mcmahonNationalUserId,
    this.mcmahonTotalGames,
    this.mcmahonContestCount,
    this.region,
    this.city,
    this.club,
    this.identityVerified,
    this.profileCompleted,
    this.role,
    this.hostStatus,
    this.organization,
    this.organizationType,
    this.openbankingConnected,
    this.privacyConsented,
    this.privacyConsentVersion,
  });

  /// 맥마흔 전국 유저와 연동되어 있는지 확인
  bool get hasMcmahonNationalUser => mcmahonNationalUserId != null;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['userId'] ?? 0,
      name: json['name'] ?? json['userName'] ?? '',
      phone: json['phone'] ?? json['phoneNumber'],
      email: json['email'],
      rank: json['rank'] ?? json['levelDisplayName'],
      level: json['level'],
      mcmahonScore: json['mcmahonScore'],
      mcmahonNationalScore: json['mcmahonNationalScore']?.toDouble(),
      mcmahonNationalUserId: json['mcmahonNationalUserId'],
      mcmahonTotalGames: json['mcmahonTotalGames'],
      mcmahonContestCount: json['mcmahonContestCount'],
      region: json['region'],
      city: json['city'],
      club: json['club'],
      identityVerified: json['identityVerified'],
      profileCompleted: json['profileCompleted'],
      role: json['role'],
      hostStatus: json['hostStatus'],
      organization: json['organization'],
      organizationType: json['organizationType'],
      openbankingConnected: json['openbankingConnected'],
      privacyConsented: json['privacyConsented'],
      privacyConsentVersion: json['privacyConsentVersion'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'rank': rank,
      'level': level,
      'mcmahonScore': mcmahonScore,
      'mcmahonNationalScore': mcmahonNationalScore,
      'mcmahonNationalUserId': mcmahonNationalUserId,
      'mcmahonTotalGames': mcmahonTotalGames,
      'mcmahonContestCount': mcmahonContestCount,
      'region': region,
      'city': city,
      'club': club,
      'identityVerified': identityVerified,
      'profileCompleted': profileCompleted,
      'role': role,
      'hostStatus': hostStatus,
      'organization': organization,
      'organizationType': organizationType,
      'openbankingConnected': openbankingConnected,
      'privacyConsented': privacyConsented,
      'privacyConsentVersion': privacyConsentVersion,
    };
  }

  // 역할 관련 헬퍼 메서드
  bool get isAdmin => role == 'ADMIN';
  bool get isHost => role == 'HOST';
  bool get isParticipant => role == 'PARTICIPANT' || role == null;
  bool get isHostPending => hostStatus == 'PENDING';
  bool get isHostApproved => hostStatus == 'APPROVED';
  bool get canCreateContest => isHost || isAdmin;
  bool get needsOpenBanking => isHost && openbankingConnected != true;

  /// 프로필이 완성되었는지 확인
  bool get isProfileComplete =>
      identityVerified == true && profileCompleted == true;

  /// 복사본 생성 (값 변경용)
  User copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? rank,
    int? level,
    int? mcmahonScore,
    double? mcmahonNationalScore,
    int? mcmahonNationalUserId,
    int? mcmahonTotalGames,
    int? mcmahonContestCount,
    String? region,
    String? city,
    String? club,
    bool? identityVerified,
    bool? profileCompleted,
    String? role,
    String? hostStatus,
    String? organization,
    String? organizationType,
    bool? openbankingConnected,
    bool? privacyConsented,
    String? privacyConsentVersion,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      rank: rank ?? this.rank,
      level: level ?? this.level,
      mcmahonScore: mcmahonScore ?? this.mcmahonScore,
      mcmahonNationalScore: mcmahonNationalScore ?? this.mcmahonNationalScore,
      mcmahonNationalUserId: mcmahonNationalUserId ?? this.mcmahonNationalUserId,
      mcmahonTotalGames: mcmahonTotalGames ?? this.mcmahonTotalGames,
      mcmahonContestCount: mcmahonContestCount ?? this.mcmahonContestCount,
      region: region ?? this.region,
      city: city ?? this.city,
      club: club ?? this.club,
      identityVerified: identityVerified ?? this.identityVerified,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      role: role ?? this.role,
      hostStatus: hostStatus ?? this.hostStatus,
      organization: organization ?? this.organization,
      organizationType: organizationType ?? this.organizationType,
      openbankingConnected: openbankingConnected ?? this.openbankingConnected,
      privacyConsented: privacyConsented ?? this.privacyConsented,
      privacyConsentVersion: privacyConsentVersion ?? this.privacyConsentVersion,
    );
  }
}
