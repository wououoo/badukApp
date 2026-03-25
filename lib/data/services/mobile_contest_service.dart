import '../api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/mobile_contest.dart';

/// 모바일 앱 전용 대회 서비스 (ContestHomepage 기반)
class MobileContestService {
  final ApiClient _apiClient;

  MobileContestService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// 대회 목록 조회 (ContestHomepage 기반)
  /// GET /api/mobile/contests
  Future<List<MobileContest>> getContests() async {
    final response = await _apiClient.get(ApiConstants.contests);

    final data = response.data;
    if (data is Map<String, dynamic> && data['content'] is List) {
      return (data['content'] as List)
          .map((e) => MobileContest.fromJson(e))
          .toList();
    }
    if (data is List) {
      return data.map((e) => MobileContest.fromJson(e)).toList();
    }
    return [];
  }

  /// 대회 상세 조회 (ContestHomepage 상세)
  /// GET /api/mobile/contests/{homepageId}
  Future<MobileContestDetail> getContestDetail(int homepageId) async {
    final response = await _apiClient.get('${ApiConstants.contestDetail}/$homepageId');
    return MobileContestDetail.fromJson(response.data);
  }
}
