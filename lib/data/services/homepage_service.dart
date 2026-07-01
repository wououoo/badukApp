import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/homepage.dart';
import '../models/registration.dart';

/// 대회 홈페이지 서비스
/// - 공개된 대회 목록 조회
/// - 대회 상세 조회
/// - 참가신청
class HomepageService {
  final ApiClient _apiClient;

  HomepageService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// 공개된 홈페이지 목록 조회
  /// GET /api/contest-homepage/public
  Future<List<ContestHomepage>> getPublicHomepages() async {
    final response = await _apiClient.get(ApiConstants.publicHomepages);

    final data = response.data;
    if (data is List) {
      return data.map((e) => ContestHomepage.fromJson(e)).toList();
    }
    return [];
  }

  /// 홈페이지 상세 조회
  /// GET /api/contest-homepage/{homepageId}
  Future<HomepageDetail> getHomepageDetail(int homepageId) async {
    final response = await _apiClient.get('${ApiConstants.homepageDetail}/$homepageId');
    return HomepageDetail.fromJson(response.data);
  }

  /// 신청 추가 옵션(티셔츠 사이즈 등) 정의 조회
  /// GET /api/registration-options/{homepageId}
  Future<List<Map<String, dynamic>>> getRegistrationOptions(int homepageId, {int? categoryId}) async {
    try {
      final path =
          '/registration-options/$homepageId${categoryId != null ? '?categoryId=$categoryId' : ''}';
      final response = await _apiClient.get(path);
      final data = response.data;
      if (data is Map && data['options'] is List) {
        return (data['options'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 홈페이지 접근 가능 여부 확인
  /// GET /api/contest-homepage/{homepageId}/accessible
  Future<bool> isHomepageAccessible(int homepageId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.homepageDetail}/$homepageId/accessible',
      );
      return response.data['accessible'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 참가 부문 목록 조회
  /// GET /api/contest-homepage/{homepageId}/categories
  Future<List<HomepageCategory>> getCategories(int homepageId) async {
    final response = await _apiClient.get(
      '${ApiConstants.homepageCategories}/$homepageId/categories',
    );

    final data = response.data;
    if (data is List) {
      return data.map((e) => HomepageCategory.fromJson(e)).toList();
    }
    return [];
  }

  /// 참가신청 제출
  /// POST /api/contest-registration
  Future<RegistrationResponse> submitRegistration(RegistrationData registration) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.registration,
        data: registration.toJson(),
      );
      return RegistrationResponse.fromJson(response.data);
    } on DioException catch (e) {
      // 400 에러 등에서도 응답 본문이 있으면 파싱
      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          return RegistrationResponse(
            success: data['success'] ?? false,
            message: data['message'] ?? '참가신청에 실패했습니다.',
            registrationId: data['registrationId'],
          );
        }
      }
      return RegistrationResponse(
        success: false,
        message: e.message ?? '네트워크 오류가 발생했습니다.',
      );
    }
  }

  /// 비밀번호로 참가신청 조회 (본인 확인)
  /// POST /api/contest-registration/verify
  Future<RegistrationInfo> verifyRegistration({
    required int homepageId,
    required String name,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.registrationVerify,
      data: {
        'homepageId': homepageId,
        'name': name,
        'password': password,
      },
    );
    return RegistrationInfo.fromJson(response.data);
  }

  /// 특정 부문의 팀 목록 조회 (단체전 팀 합류용)
  /// GET /api/contest-registration/homepage/{homepageId}/category/{categoryId}/teams
  Future<List<Map<String, dynamic>>> getTeamsForCategory(int homepageId, int categoryId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.registrationTeams}/$homepageId/category/$categoryId/teams',
      );
      final data = response.data;
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 참가신청 취소
  /// DELETE /api/contest-registration/{registrationId}
  Future<bool> cancelRegistration(int registrationId) async {
    try {
      await _apiClient.delete('${ApiConstants.registration}/$registrationId');
      return true;
    } catch (e) {
      return false;
    }
  }
}
