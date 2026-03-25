import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/user.dart';
import '../models/user_stats.dart';
import '../models/contest_history.dart';
import '../models/mcmahon_history.dart';
import 'cache_service.dart';

class UserService {
  final ApiClient _apiClient;

  UserService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// 내 정보 조회
  Future<User> getMyProfile() async {
    try {
      final response = await _apiClient.get(ApiConstants.userProfile);
      // 캐시 저장
      await CacheService.instance.save(CacheKeys.userProfile, response.data);
      // 응답이 {success: true, user: {...}} 형식인 경우 처리
      if (response.data is Map && response.data['user'] != null) {
        return User.fromJson(response.data['user']);
      }
      return User.fromJson(response.data);
    } catch (e) {
      debugPrint('[UserService] getMyProfile 실패, 캐시 시도: $e');
      final cached = await CacheService.instance.load(CacheKeys.userProfile);
      if (cached != null) {
        final data = Map<String, dynamic>.from(cached);
        if (data['user'] != null) {
          return User.fromJson(Map<String, dynamic>.from(data['user']));
        }
        return User.fromJson(data);
      }
      rethrow;
    }
  }

  /// 사용자 정보 조회
  Future<User> getUserProfile(int userId) async {
    final response = await _apiClient.get('/mobile/users/$userId');
    if (response.data is Map && response.data['user'] != null) {
      return User.fromJson(response.data['user']);
    }
    return User.fromJson(response.data);
  }

  /// 프로필 수정
  Future<User> updateProfile({
    String? name,
    String? rank,
    String? region,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (rank != null) data['rank'] = rank;
    if (region != null) data['region'] = region;

    final response = await _apiClient.put(ApiConstants.userProfileUpdate, data: data);
    if (response.data is Map && response.data['user'] != null) {
      return User.fromJson(response.data['user']);
    }
    return User.fromJson(response.data);
  }

  /// 내 통계 조회
  Future<UserStats> getMyStats() async {
    try {
      final response = await _apiClient.get(ApiConstants.userStats);
      await CacheService.instance.save(CacheKeys.userStats, response.data);
      return UserStats.fromJson(response.data);
    } catch (e) {
      debugPrint('[UserService] getMyStats 실패, 캐시 시도: $e');
      final cached = await CacheService.instance.load(CacheKeys.userStats);
      if (cached != null) {
        return UserStats.fromJson(Map<String, dynamic>.from(cached));
      }
      rethrow;
    }
  }

  /// 대회 참가 이력 조회
  Future<ContestHistoryResponse> getContestHistory({
    int page = 0,
    int size = 10,
  }) async {
    final response = await _apiClient.get(
      ApiConstants.userHistory,
      queryParameters: {'page': page, 'size': size},
    );
    return ContestHistoryResponse.fromJson(response.data);
  }

  /// 맥마흔 점수 이력 조회
  Future<McMahonScoreSummary> getMcMahonHistory() async {
    final response = await _apiClient.get(ApiConstants.mcmahonScore);
    return McMahonScoreSummary.fromJson(response.data);
  }

  /// 내 참가신청 내역 조회
  Future<List<Map<String, dynamic>>> getMyRegistrations() async {
    final response = await _apiClient.get(ApiConstants.myRegistrations);
    if (response.data is List) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 디버그 정보 조회 (개발용)
  Future<Map<String, dynamic>> getDebugInfo() async {
    try {
      final response = await _apiClient.get('/mobile/users/dev/debug');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// 즐겨찾기 목록 조회
  Future<List<Map<String, dynamic>>> getMyFavorites() async {
    final response = await _apiClient.get(ApiConstants.myFavorites);
    if (response.data is List) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 즐겨찾기 토글 (추가/해제)
  /// 반환값: true면 추가됨, false면 해제됨
  Future<bool> toggleFavorite(int homepageId, {required bool currentlyFavorited}) async {
    if (currentlyFavorited) {
      await _apiClient.delete('${ApiConstants.myFavorites}/$homepageId');
      return false;
    } else {
      await _apiClient.post('${ApiConstants.myFavorites}/$homepageId');
      return true;
    }
  }

  /// 즐겨찾기 ID 목록만 조회 (빠른 초기화용)
  Future<List<int>> getFavoriteIds() async {
    final favorites = await getMyFavorites();
    return favorites
        .map((f) => f['homepageId'] as int? ?? 0)
        .where((id) => id > 0)
        .toList();
  }

  /// 맥마흔 대회 라운드별 결과 조회 (한방 쿼리)
  Future<List<McMahonRoundResult>> getMcMahonRoundResults(int gameRoomId) async {
    try {
      // 새로운 한방 쿼리 API 사용
      final response = await _apiClient.get(
        '${ApiConstants.mcmahonRoundsDetail}/$gameRoomId',
      );

      if (response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final success = data['success'] ?? false;

        if (!success) {
          return [];
        }

        final rounds = data['rounds'] as List<dynamic>? ?? [];
        return rounds.map((round) => McMahonRoundResult(
          round: round['round'] ?? 0,
          opponentName: round['opponentName'] ?? '부전승',
          isWin: round['isWin'] ?? false,
          color: round['color'],
          pointChange: round['pointChange'],
        )).toList();
      }

      return [];
    } catch (e) {
      // 실패 시 빈 목록 반환
      return [];
    }
  }

  /// 비-MCM 대회 라운드별 결과 조회
  Future<List<McMahonRoundResult>> getContestRoundResults(int gameRoomId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.contestRoundsDetail}/$gameRoomId',
      );

      if (response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final success = data['success'] ?? false;

        if (!success) {
          return [];
        }

        final rounds = data['rounds'] as List<dynamic>? ?? [];
        return rounds.map((round) => McMahonRoundResult(
          round: round['round'] ?? 0,
          opponentName: round['opponentName'] ?? '부전승',
          isWin: round['isWin'] ?? false,
          color: round['color'],
          pointChange: null,
        )).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }
}

/// 대회 참가 이력 응답
class ContestHistoryResponse {
  final List<ContestHistory> history;
  final int totalPages;
  final int totalElements;
  final int currentPage;

  ContestHistoryResponse({
    required this.history,
    required this.totalPages,
    required this.totalElements,
    required this.currentPage,
  });

  factory ContestHistoryResponse.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as List<dynamic>? ?? [];
    return ContestHistoryResponse(
      history: content.map((e) => ContestHistory.fromJson(e)).toList(),
      totalPages: json['totalPages'] ?? 0,
      totalElements: json['totalElements'] ?? 0,
      currentPage: json['number'] ?? json['page'] ?? 0,
    );
  }

  bool get hasMore => currentPage < totalPages - 1;
}
