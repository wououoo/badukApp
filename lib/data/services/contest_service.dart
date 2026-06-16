import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/contest.dart';
import '../models/contest_photo.dart';
import '../models/contest_sort.dart';
import '../models/homepage_image.dart';
import '../models/calendar_contest.dart';
import 'cache_service.dart';

class ContestService {
  final ApiClient _apiClient;

  ContestService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// 대회 목록 조회 (Mobile API - ContestHomepage 테이블)
  /// GET /api/mobile/contests
  Future<List<Contest>> getContests({String type = 'ALL'}) async {
    try {
      final response = await _apiClient.get(ApiConstants.contests);
      final data = response.data;

      List<Contest> contests = [];

      if (data is Map<String, dynamic> && data['content'] is List) {
        contests = (data['content'] as List)
            .map((e) => Contest.fromJson(e))
            .toList();
      } else if (data is List) {
        contests = data.map((e) => Contest.fromJson(e)).toList();
      }

      // 캐시 저장 (원본 데이터)
      await CacheService.instance.save(CacheKeys.contestsList, data);

      // 필터 적용 (백엔드 contestStatus와 1:1 매칭)
      if (type != 'ALL' && contests.isNotEmpty) {
        contests = contests.where((contest) {
          final status = contest.status?.toUpperCase() ?? '';
          return status == type;
        }).toList();
      }

      return contests;
    } catch (e) {
      // 오프라인 fallback: 캐시에서 로드
      debugPrint('[ContestService] getContests 실패, 캐시 로드 시도');
      try {
        final cached = await CacheService.instance.load(CacheKeys.contestsList);
        if (cached != null) {
          List<Contest> contests = [];
          if (cached is Map<String, dynamic> && cached['content'] is List) {
            contests = (cached['content'] as List)
                .whereType<Map<String, dynamic>>()
                .map((e) => Contest.fromJson(e))
                .toList();
          } else if (cached is List) {
            contests = cached
                .whereType<Map<String, dynamic>>()
                .map((e) => Contest.fromJson(e))
                .toList();
          }
          if (type != 'ALL' && contests.isNotEmpty) {
            contests = contests.where((contest) {
              final status = contest.status?.toUpperCase() ?? '';
              return status == type;
            }).toList();
          }
          return contests;
        }
      } catch (cacheError) {
        debugPrint('[ContestService] 캐시 로드 실패: $cacheError');
      }
      rethrow;
    }
  }

  /// 대회 목록 조회 (페이징) - Mobile API
  Future<ContestPageResponse> getContestsPaged({
    String type = 'ALL',
    int page = 0,
    int size = 10,
    bool publicOnly = true,
  }) async {
    final response = await _apiClient.get(ApiConstants.contests);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final pageResponse = ContestPageResponse.fromJson(data);

      // 필터 적용
      if (type != 'ALL') {
        final filteredContests = pageResponse.contests.where((contest) {
          final status = contest.status?.toUpperCase() ?? '';
          return status == type;
        }).toList();

        return ContestPageResponse(
          contests: filteredContests,
          totalPages: 1,
          totalElements: filteredContests.length,
          currentPage: 0,
        );
      }

      return pageResponse;
    }
    return ContestPageResponse(contests: [], totalPages: 0, totalElements: 0, currentPage: 0);
  }

  /// 대회 상세 조회 (Mobile API - ContestHomepage)
  /// GET /api/mobile/contests/{homepageId}
  Future<ContestDetail> getContestDetail(int homepageId) async {
    try {
      final response = await _apiClient.get('${ApiConstants.contestDetail}/$homepageId');
      // 캐시 저장
      await CacheService.instance.save(
        CacheKeys.contestDetail(homepageId),
        response.data,
      );
      return ContestDetail.fromJson(response.data);
    } catch (e) {
      // 오프라인 fallback: 캐시에서 로드
      debugPrint('[ContestService] 대회 상세 조회 실패 (id=$homepageId), 캐시 시도');
      try {
        final cached = await CacheService.instance.load(
          CacheKeys.contestDetail(homepageId),
        );
        if (cached is Map<String, dynamic>) {
          return ContestDetail.fromJson(cached);
        }
      } catch (cacheError) {
        debugPrint('[ContestService] 캐시 로드 실패: $cacheError');
      }
      rethrow;
    }
  }

  /// 예정된 대회 목록 (접수중 또는 접수예정)
  Future<List<Contest>> getUpcomingContests({int limit = 5}) async {
    final contests = await getContests(type: 'OPEN');
    return contests.take(limit).toList();
  }

  /// 진행중인 대회 목록
  Future<List<Contest>> getOngoingContests({int limit = 5}) async {
    final contests = await getContests(type: 'LIVE');
    return contests.take(limit).toList();
  }

  /// 완료된 대회 목록
  Future<List<Contest>> getCompletedContests({int limit = 5}) async {
    final contests = await getContests(type: 'CLOSED');
    return contests.take(limit).toList();
  }

  /// Live API: 부문 상세 조회 (순위표/대진표용)
  /// GET /api/live/contests/{contestId}/sorts/{sortId}
  Future<SortDetail> getSortDetail(int contestId, int sortId) async {
    final response = await _apiClient.get(
      '${ApiConstants.liveContestDetail}/$contestId/sorts/$sortId',
    );
    return SortDetail.fromJson(response.data);
  }

  /// Live API: 순위표 조회
  /// GET /api/live/contests/{contestId}/sorts/{sortId}/rankings
  Future<List<Map<String, dynamic>>> getRankings(int contestId, int sortId) async {
    final response = await _apiClient.get(
      '${ApiConstants.liveContestDetail}/$contestId/sorts/$sortId/rankings',
    );
    final data = response.data;

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// Live API: 대진표 조회 (전체 라운드)
  /// GET /api/live/contests/{contestId}/sorts/{sortId}/pairings
  Future<PairingsResponse> getPairings(int contestId, int sortId) async {
    final response = await _apiClient.get(
      '${ApiConstants.liveContestDetail}/$contestId/sorts/$sortId/pairings',
    );
    return PairingsResponse.fromJson(response.data);
  }

  /// Live API: 대진표 조회 (특정 라운드)
  /// GET /api/live/contests/{contestId}/sorts/{sortId}/pairings/{round}
  Future<PairingsResponse> getPairingsByRound(
    int contestId,
    int sortId,
    int round,
  ) async {
    final response = await _apiClient.get(
      '${ApiConstants.liveContestDetail}/$contestId/sorts/$sortId/pairings/$round',
    );
    return PairingsResponse.fromJson(response.data);
  }

  /// 홈페이지 대회 결과 조회 (순위표)
  /// GET /api/contest-homepage/{homepageId}/rankings
  Future<List<SortRankings>> getHomepageRankings(int homepageId) async {
    final response = await _apiClient.get(
      '/contest-homepage/$homepageId/rankings',
    );
    final data = response.data;

    if (data is List) {
      return data.map((e) => SortRankings.fromJson(e)).toList();
    }
    return [];
  }

  /// 캘린더 대회 조회
  /// GET /api/mobile/contests/calendar?year=2026&month=2
  Future<List<CalendarContest>> getCalendarContests(int year, int month) async {
    try {
      final response = await _apiClient.get(
        '/mobile/contests/calendar',
        queryParameters: {'year': year, 'month': month},
      );
      final data = response.data;
      if (data is Map && data['success'] == true) {
        final list = data['contests'] as List? ?? [];
        return list.map((e) => CalendarContest.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[캘린더] 대회 조회 실패: $e');
      return [];
    }
  }

  // ========== 홈페이지 안내 이미지 ==========

  /// 홈페이지 안내 이미지 목록 조회
  /// GET /contest-homepage/{homepageId}/images
  /// 운영진이 올린 부문/상금/지도/대진표/결과 안내 이미지
  Future<List<HomepageImage>> getHomepageImages(int homepageId) async {
    try {
      final response = await _apiClient.get('/contest-homepage/$homepageId/images');
      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((e) => HomepageImage.fromJson(e))
            .toList();
      }
      return <HomepageImage>[];
    } catch (e) {
      debugPrint('[ContestService] 홈페이지 이미지 조회 실패: $e');
      return <HomepageImage>[];
    }
  }

  // ========== 대회 사진 갤러리 ==========

  /// 대회 사진 목록 조회
  /// GET /contest-homepage/{homepageId}/photos
  Future<Map<String, dynamic>> getContestPhotos(int homepageId, {int page = 0, int size = 30}) async {
    try {
      final response = await _apiClient.get(
        '/contest-homepage/$homepageId/photos',
        queryParameters: {'page': page, 'size': size},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['success'] == true) {
        final photosJson = data['photos'] as List<dynamic>? ?? [];
        final photos = photosJson.map((e) => ContestPhoto.fromJson(e)).toList();
        return {
          'photos': photos,
          'hasNext': data['hasNext'] ?? false,
        };
      }
      return {'photos': <ContestPhoto>[], 'hasNext': false};
    } catch (e) {
      debugPrint('[ContestService] 대회 사진 조회 실패: $e');
      rethrow;
    }
  }

  /// 대회 사진 업로드
  /// POST /contest-homepage/{homepageId}/photos
  Future<Map<String, dynamic>> uploadContestPhotos(int homepageId, List<MultipartFile> files, {String? caption}) async {
    try {
      final formData = FormData.fromMap({
        'files': files,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
      });
      final response = await _apiClient.post(
        '/contest-homepage/$homepageId/photos',
        data: formData,
      );
      return response.data;
    } catch (e) {
      debugPrint('[ContestService] 대회 사진 업로드 실패: $e');
      rethrow;
    }
  }

  /// 대회 사진 삭제
  /// DELETE /contest-homepage/{homepageId}/photos/{photoId}
  Future<void> deleteContestPhoto(int homepageId, int photoId) async {
    try {
      await _apiClient.delete('/contest-homepage/$homepageId/photos/$photoId');
    } catch (e) {
      debugPrint('[ContestService] 대회 사진 삭제 실패: $e');
      rethrow;
    }
  }
}

/// 부문별 순위 결과
class SortRankings {
  final int? contestId;
  final int? sortId;
  final String sortName;
  final int? gameRoomId;
  final String? gameRoomType;
  final List<RankingEntry> rankings;

  SortRankings({
    this.contestId,
    this.sortId,
    required this.sortName,
    this.gameRoomId,
    this.gameRoomType,
    required this.rankings,
  });

  factory SortRankings.fromJson(Map<String, dynamic> json) {
    final rankingsData = json['rankings'] as List<dynamic>? ?? [];
    return SortRankings(
      contestId: json['contestId'],
      sortId: json['sortId'],
      sortName: json['sortName'] ?? '',
      gameRoomId: json['gameRoomId'],
      gameRoomType: json['gameRoomType'],
      rankings: rankingsData.map((e) => RankingEntry.fromJson(e)).toList(),
    );
  }
}

/// 순위 항목
class RankingEntry {
  final int rank;
  final String participantName;
  final int? participantNumber;
  final int totalWins;
  final double? sos;
  final double? sosos;
  final double? totalPoints; // 맥마흔 점수

  RankingEntry({
    required this.rank,
    required this.participantName,
    this.participantNumber,
    required this.totalWins,
    this.sos,
    this.sosos,
    this.totalPoints,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    return RankingEntry(
      rank: json['rank'] ?? 0,
      participantName: json['participantName'] ?? '',
      participantNumber: json['participantNumber'],
      totalWins: json['totalWins'] ?? 0,
      sos: (json['sos'] as num?)?.toDouble(),
      sosos: (json['sosos'] as num?)?.toDouble(),
      totalPoints: (json['totalPoints'] as num?)?.toDouble(),
    );
  }
}

/// 대회 목록 페이징 응답
class ContestPageResponse {
  final List<Contest> contests;
  final int totalPages;
  final int totalElements;
  final int currentPage;

  ContestPageResponse({
    required this.contests,
    required this.totalPages,
    required this.totalElements,
    required this.currentPage,
  });

  factory ContestPageResponse.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as List<dynamic>? ?? [];
    return ContestPageResponse(
      contests: content.map((e) => Contest.fromJson(e)).toList(),
      totalPages: json['totalPages'] ?? 1,
      totalElements: json['totalElements'] ?? content.length,
      currentPage: json['number'] ?? json['page'] ?? 0,
    );
  }

  bool get hasMore => currentPage < totalPages - 1;
}

/// 대회 상세 정보 (ContestHomepage 기반)
class ContestDetail {
  final int id;
  final String name;           // title
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
  final List<ContestCategory> categories;
  final List<ContestPrize> prizes;
  final List<ContestGameMethod> gameMethods;
  final List<int>? contestIds;  // 연결된 Contest ID 목록

  // 대회 일정
  final DateTime? contestStartDate;

  // 접수 관련 필드
  final DateTime? registrationStartDate;
  final DateTime? registrationEndDate;
  final bool? registrationOpen;
  final bool registrationAvailable;
  final String? registrationStatus; // OPEN, CLOSED, UPCOMING, ENDED
  // 백엔드 ContestHomepage.getContestStatus() 결과 (통합 5단계):
  // UPCOMING / OPEN / ENDED / LIVE / CLOSED — 가장 정확한 단일 진실
  final String? contestStatus;

  // 문의 담당자 MobileUser ID 목록 (콤마 구분 문자열을 파싱)
  final List<int> hostMobileUserIds;

  // 위치 좌표
  final String? address;
  final double? latitude;
  final double? longitude;

  ContestDetail({
    required this.id,
    required this.name,
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
    this.contestStartDate,
    this.registrationStartDate,
    this.registrationEndDate,
    this.registrationOpen,
    this.registrationAvailable = true,
    this.registrationStatus,
    this.contestStatus,
    this.hostMobileUserIds = const [],
    this.address,
    this.latitude,
    this.longitude,
  });

  /// 첫 번째 문의 담당자 ID
  int? get primaryChatManagerId =>
      hostMobileUserIds.isNotEmpty ? hostMobileUserIds.first : null;

  bool get hasChatManager => hostMobileUserIds.isNotEmpty;

  // 메인 화면(Contest)과 동일한 fallback 체인 — 백엔드 contestStatus 우선
  // (예전엔 null 반환 → ContestStatusBadge가 default로 빠져서 모든 대회 상세가 "접수중"으로 표시되는 버그가 있었음)
  String? get status => contestStatus ?? registrationStatus;
  String get dateText => schedule ?? '';
  String get fullLocation => venue ?? '';
  int get totalParticipants => registrationCount ?? 0;
  List<dynamic>? get linkedContests => null;
  List<ContestSort> get allSorts => categories.map((cat) => ContestSort(
    id: cat.id,
    name: cat.categoryName,
    participantCount: cat.maxParticipants,
    contestType: cat.contestType,
    teamSize: cat.teamSize,
  )).toList();

  factory ContestDetail.fromJson(Map<String, dynamic> json) {
    final categoriesData = json['categories'] as List<dynamic>? ?? [];
    final prizesData = json['prizes'] as List<dynamic>? ?? [];
    final gameMethodsData = json['gameMethods'] as List<dynamic>? ?? [];
    final contestIdsData = json['contestIds'] as List<dynamic>? ?? [];

    return ContestDetail(
      id: json['id'] ?? 0,
      name: json['title'] ?? json['name'] ?? '',
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
      categories: categoriesData.map((e) => ContestCategory.fromJson(e)).toList(),
      prizes: prizesData.map((e) => ContestPrize.fromJson(e)).toList(),
      gameMethods: gameMethodsData.map((e) => ContestGameMethod.fromJson(e)).toList(),
      contestIds: contestIdsData.map((e) => e as int).toList(),
      contestStartDate: _parseDateTime(json['contestStartDate']),
      registrationStartDate: _parseDateTime(json['registrationStartDate']),
      registrationEndDate: _parseDateTime(json['registrationEndDate']),
      registrationOpen: json['registrationOpen'],
      registrationAvailable: json['registrationAvailable'] ?? true,
      registrationStatus: json['registrationStatus'],
      contestStatus: json['contestStatus'],
      hostMobileUserIds: _parseIdList(json['hostMobileUserId']),
      address: json['address'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  static List<int> _parseIdList(dynamic value) {
    if (value == null) return [];
    if (value is String && value.isNotEmpty) {
      return value.split(',').map((s) => int.tryParse(s.trim()) ?? 0).where((id) => id > 0).toList();
    }
    if (value is List) {
      return value.map((e) => (e as num).toInt()).toList();
    }
    return [];
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
class ContestCategory {
  final int id;
  final String categoryName;
  final String? skillRequirement;
  final int? maxParticipants;
  final String? participantsDisplayText;
  final String? gameTime;
  final String? note;
  final String? contestType;
  final String? birthInputType; // "NONE" / "YEAR_ONLY" / "FULL_DATE", null이면 contestType에 따른 기본값(CHILD=YEAR_ONLY, 그 외=NONE)
  final int? teamSize;
  final String? teamFormationType; // SELF(자유조편성), ORGANIZER(랜덤조편성) - PAIR에서 사용
  final int? displayOrder;
  final int? fee;              // 참가비
  final String? feeDescription; // 참가비 설명
  final int? currentParticipants; // 현재 참가자 수
  final bool onsiteOnly;       // 현장 접수 전용 (true면 온라인 신청 차단)
  final bool registrationClosed;       // 부문 접수 마감 (운영자 강제마감 CLOSED 또는 접수기간 종료)
  final String? registrationOverride;  // "AUTO" / "OPEN" / "CLOSED"
  final String? groupName;     // 그룹명 (예: "금학산부", "유소년부") - 부문 묶음 표시용

  ContestCategory({
    required this.id,
    required this.categoryName,
    this.skillRequirement,
    this.maxParticipants,
    this.participantsDisplayText,
    this.gameTime,
    this.note,
    this.contestType,
    this.birthInputType,
    this.teamSize,
    this.teamFormationType,
    this.displayOrder,
    this.fee,
    this.feeDescription,
    this.currentParticipants,
    this.onsiteOnly = false,
    this.registrationClosed = false,
    this.registrationOverride,
    this.groupName,
  });

  factory ContestCategory.fromJson(Map<String, dynamic> json) {
    return ContestCategory(
      id: json['id'] ?? 0,
      categoryName: json['categoryName'] ?? '',
      skillRequirement: json['skillRequirement'],
      maxParticipants: json['maxParticipants'],
      participantsDisplayText: json['participantsDisplayText'],
      gameTime: json['gameTime'],
      note: json['note'],
      contestType: json['contestType'],
      birthInputType: json['birthInputType'],
      teamSize: json['teamSize'],
      teamFormationType: json['teamFormationType'],
      displayOrder: json['displayOrder'],
      fee: json['fee'],
      feeDescription: json['feeDescription'],
      currentParticipants: json['currentParticipants'],
      onsiteOnly: json['onsiteOnly'] == true,
      registrationClosed: json['registrationClosed'] == true,
      registrationOverride: json['registrationOverride'],
      groupName: json['groupName'],
    );
  }

  /// 페어 자유조편성인지 (팀 일괄 신청)
  /// teamFormationType이 null이어도 teamSize가 있으면 자유조편성으로 판단
  bool get isPairSelf {
    if (contestType?.toUpperCase() != 'PAIR') return false;
    if (teamFormationType == 'SELF') return true;
    if (teamFormationType == null && teamSize != null && teamSize! > 0) return true;
    return false;
  }

  /// 페어 랜덤조편성인지 (개인 신청)
  bool get isPairOrganizer {
    if (contestType?.toUpperCase() != 'PAIR') return false;
    if (teamFormationType == 'ORGANIZER') return true;
    if (teamFormationType == null && (teamSize == null || teamSize == 0)) return true;
    return false;
  }

  /// 참가비가 있는지 확인
  bool get hasFee => fee != null && fee! > 0;
}

/// 상금 정보
class ContestPrize {
  final int id;
  final String? groupName;
  final String? prizeTitle;
  final String? rankName;
  final String? prizeContent;
  final int? displayOrder;
  final bool isFullRow;
  final String? remarks; // 비고 (장학금/철원사랑상품권 등)

  ContestPrize({
    required this.id,
    this.groupName,
    this.prizeTitle,
    this.rankName,
    this.prizeContent,
    this.displayOrder,
    this.isFullRow = false,
    this.remarks,
  });

  factory ContestPrize.fromJson(Map<String, dynamic> json) {
    return ContestPrize(
      id: json['id'] ?? 0,
      groupName: json['groupName'],
      prizeTitle: json['prizeTitle'],
      rankName: json['rankName'],
      prizeContent: json['prizeContent'],
      displayOrder: json['displayOrder'],
      isFullRow: json['isFullRow'] == true,
      remarks: json['remarks'] as String?,
    );
  }
}

/// 게임 진행 방법
class ContestGameMethod {
  final int id;
  final String? gameType;
  final String? description;
  final String? thinkingTime;
  final String? handicapSystem;
  final int? displayOrder;

  ContestGameMethod({
    required this.id,
    this.gameType,
    this.description,
    this.thinkingTime,
    this.handicapSystem,
    this.displayOrder,
  });

  factory ContestGameMethod.fromJson(Map<String, dynamic> json) {
    return ContestGameMethod(
      id: json['id'] ?? 0,
      gameType: json['gameType'],
      description: json['description'],
      thinkingTime: json['thinkingTime'],
      handicapSystem: json['handicapSystem'],
      displayOrder: json['displayOrder'],
    );
  }
}

/// 부문 상세 정보 (Live API용)
class SortDetail {
  final int sortId;
  final String sortName;
  final int? gameRoomId;
  final int? participantCount;
  final int? currentRound;
  final int? maxRound;
  final int? teamSize;
  final int? teamCount;
  final String? contestType;

  SortDetail({
    required this.sortId,
    required this.sortName,
    this.gameRoomId,
    this.participantCount,
    this.currentRound,
    this.maxRound,
    this.teamSize,
    this.teamCount,
    this.contestType,
  });

  factory SortDetail.fromJson(Map<String, dynamic> json) {
    return SortDetail(
      sortId: json['sortId'] ?? 0,
      sortName: json['sortName'] ?? '',
      gameRoomId: json['gameRoomId'],
      participantCount: json['participantCount'],
      currentRound: json['currentRound'],
      maxRound: json['maxRound'],
      teamSize: json['teamSize'],
      teamCount: json['teamCount'],
      contestType: json['contestType'],
    );
  }
}

/// 대진표 응답
class PairingsResponse {
  final List<Map<String, dynamic>> pairings;
  final int maxRound;
  final int? round;
  final int? gameRoomId;
  final String? contestType;

  PairingsResponse({
    required this.pairings,
    required this.maxRound,
    this.round,
    this.gameRoomId,
    this.contestType,
  });

  factory PairingsResponse.fromJson(Map<String, dynamic> json) {
    final pairingsData = json['pairings'] as List<dynamic>? ?? [];
    return PairingsResponse(
      pairings: pairingsData.map((e) => Map<String, dynamic>.from(e)).toList(),
      maxRound: json['maxRound'] ?? 0,
      round: json['round'],
      gameRoomId: json['gameRoomId'],
      contestType: json['contestType'],
    );
  }
}
