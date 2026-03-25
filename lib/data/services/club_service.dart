import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../models/club.dart';
import '../models/club_photo.dart';
import '../models/club_post.dart';
import '../models/club_schedule.dart';

class ClubService {
  final ApiClient _apiClient;

  ClubService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// 클럽 검색
  Future<List<ClubSummary>> searchClubs({String? region, String? keyword}) async {
    final queryParams = <String, dynamic>{};
    if (region != null && region.isNotEmpty) queryParams['region'] = region;
    if (keyword != null && keyword.isNotEmpty) queryParams['keyword'] = keyword;

    final response = await _apiClient.get(
      '/mobile/clubs',
      queryParameters: queryParams,
    );

    final data = response.data;
    if (data['success'] == true && data['clubs'] != null) {
      return (data['clubs'] as List).map((e) => ClubSummary.fromJson(e)).toList();
    }
    return [];
  }

  /// 내 클럽 목록
  Future<List<ClubSummary>> getMyClubs() async {
    final response = await _apiClient.get('/mobile/clubs/my');

    final data = response.data;
    if (data['success'] == true && data['clubs'] != null) {
      return (data['clubs'] as List).map((e) => ClubSummary.fromJson(e)).toList();
    }
    return [];
  }

  /// 클럽 상세
  Future<ClubDetail> getClubDetail(int clubId) async {
    final response = await _apiClient.get('/mobile/clubs/$clubId');

    final data = response.data;
    if (data['success'] == true && data['club'] != null) {
      return ClubDetail.fromJson(data['club']);
    }
    throw Exception(data['message'] ?? '클럽 정보를 불러올 수 없습니다.');
  }

  /// 클럽 생성
  Future<Map<String, dynamic>> createClub({
    required String name,
    String? description,
    String? region,
    String? city,
  }) async {
    final response = await _apiClient.post(
      '/mobile/clubs',
      data: {
        'name': name,
        'description': description,
        'region': region,
        'city': city,
      },
    );
    return response.data;
  }

  /// 클럽 수정 (OWNER)
  Future<Map<String, dynamic>> updateClub(int clubId, {
    String? name,
    String? description,
    String? region,
    String? city,
  }) async {
    final response = await _apiClient.put(
      '/mobile/clubs/$clubId',
      data: {
        'name': name,
        'description': description,
        'region': region,
        'city': city,
      },
    );
    return response.data;
  }

  /// 클럽 삭제
  Future<Map<String, dynamic>> deleteClub(int clubId) async {
    final response = await _apiClient.delete('/mobile/clubs/$clubId');
    return response.data;
  }

  /// 가입 신청
  Future<Map<String, dynamic>> requestJoin(int clubId, {String? message}) async {
    final response = await _apiClient.post(
      '/mobile/clubs/$clubId/join',
      data: {'message': message},
    );
    return response.data;
  }

  /// 가입 신청 목록 (OWNER)
  Future<List<ClubJoinRequestInfo>> getJoinRequests(int clubId) async {
    final response = await _apiClient.get('/mobile/clubs/$clubId/join-requests');

    final data = response.data;
    if (data['success'] == true && data['requests'] != null) {
      return (data['requests'] as List).map((e) => ClubJoinRequestInfo.fromJson(e)).toList();
    }
    return [];
  }

  /// 가입 승인
  Future<Map<String, dynamic>> approveJoinRequest(int clubId, int requestId) async {
    final response = await _apiClient.post(
      '/mobile/clubs/$clubId/join-requests/$requestId/approve',
    );
    return response.data;
  }

  /// 가입 거절
  Future<Map<String, dynamic>> rejectJoinRequest(int clubId, int requestId) async {
    final response = await _apiClient.post(
      '/mobile/clubs/$clubId/join-requests/$requestId/reject',
    );
    return response.data;
  }

  /// 멤버 목록
  Future<List<ClubMemberInfo>> getClubMembers(int clubId) async {
    final response = await _apiClient.get('/mobile/clubs/$clubId/members');

    final data = response.data;
    if (data['success'] == true && data['members'] != null) {
      return (data['members'] as List).map((e) => ClubMemberInfo.fromJson(e)).toList();
    }
    return [];
  }

  /// 멤버 역할 변경 (OWNER 전용)
  Future<Map<String, dynamic>> updateMemberRole(int clubId, int targetUserId, String role) async {
    final response = await _apiClient.put(
      '/mobile/clubs/$clubId/members/$targetUserId/role',
      data: {'role': role},
    );
    return response.data;
  }

  /// 멤버 단수 변경 (ADMIN+)
  Future<Map<String, dynamic>> updateMemberLevel(int clubId, int targetUserId, int level) async {
    final response = await _apiClient.put(
      '/mobile/clubs/$clubId/members/$targetUserId/level',
      data: {'level': level},
    );
    return response.data;
  }

  /// 멤버 추방
  Future<Map<String, dynamic>> removeMember(int clubId, int userId) async {
    final response = await _apiClient.delete('/mobile/clubs/$clubId/members/$userId');
    return response.data;
  }

  /// 클럽 탈퇴
  Future<Map<String, dynamic>> leaveClub(int clubId) async {
    final response = await _apiClient.post('/mobile/clubs/$clubId/leave');
    return response.data;
  }

  // ==================== 사진 API ====================

  /// 클럽 사진 업로드
  Future<Map<String, dynamic>> uploadClubPhoto(int clubId, String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _apiClient.post(
      '/mobile/clubs/$clubId/photo',
      data: formData,
    );
    return response.data;
  }

  /// 클럽 사진 삭제
  Future<Map<String, dynamic>> deleteClubPhoto(int clubId) async {
    final response = await _apiClient.delete('/mobile/clubs/$clubId/photo');
    return response.data;
  }

  // ==================== 사진첩 API ====================

  /// 클럽 사진첩 사진 업로드 (여러 장)
  /// files: [{'bytes': Uint8List, 'name': String}, ...]
  Future<Map<String, dynamic>> uploadClubPhotos(int clubId, List<Map<String, dynamic>> files, {String? caption}) async {
    final formData = FormData();
    for (final file in files) {
      formData.files.add(MapEntry(
        'files',
        MultipartFile.fromBytes(file['bytes'] as List<int>, filename: file['name'] as String),
      ));
    }
    if (caption != null) {
      formData.fields.add(MapEntry('caption', caption));
    }
    final response = await _apiClient.post(
      '/mobile/clubs/$clubId/photos',
      data: formData,
    );
    return response.data;
  }

  /// 클럽 사진첩 목록 (페이지네이션)
  Future<Map<String, dynamic>> getClubPhotos(int clubId, {int page = 0, int size = 30}) async {
    final response = await _apiClient.get(
      '/mobile/clubs/$clubId/photos',
      queryParameters: {'page': page, 'size': size},
    );

    final data = response.data;
    if (data['success'] == true) {
      final photos = (data['photos'] as List?)
          ?.map((e) => ClubPhoto.fromJson(e))
          .toList() ?? [];
      return {
        'photos': photos,
        'hasNext': data['hasNext'] ?? false,
        'currentPage': data['currentPage'] ?? 0,
      };
    }
    throw Exception(data['message'] ?? '사진을 불러올 수 없습니다.');
  }

  /// 클럽 사진첩 사진 삭제
  Future<Map<String, dynamic>> deleteClubPhotoItem(int clubId, int photoId) async {
    final response = await _apiClient.delete('/mobile/clubs/$clubId/photos/$photoId');
    return response.data;
  }

  // ==================== 일정 API ====================

  /// 클럽 일정 목록
  Future<List<ClubSchedule>> getClubSchedules(int clubId) async {
    final response = await _apiClient.get('/mobile/clubs/$clubId/schedules');

    final data = response.data;
    if (data['success'] == true && data['schedules'] != null) {
      return (data['schedules'] as List).map((e) => ClubSchedule.fromJson(e)).toList();
    }
    return [];
  }

  /// 클럽 일정 생성 (OWNER)
  Future<Map<String, dynamic>> createClubSchedule(int clubId, {
    required String title,
    required String date,
    String? time,
    String? location,
    String? memo,
  }) async {
    final response = await _apiClient.post(
      '/mobile/clubs/$clubId/schedules',
      data: {
        'title': title,
        'date': date,
        if (time != null) 'time': time,
        if (location != null) 'location': location,
        if (memo != null) 'memo': memo,
      },
    );
    return response.data;
  }

  /// 클럽 일정 수정 (OWNER)
  Future<Map<String, dynamic>> updateClubSchedule(int clubId, int scheduleId, {
    String? title,
    String? date,
    String? time,
    String? location,
    String? memo,
  }) async {
    final response = await _apiClient.put(
      '/mobile/clubs/$clubId/schedules/$scheduleId',
      data: {
        if (title != null) 'title': title,
        if (date != null) 'date': date,
        'time': time,
        'location': location,
        'memo': memo,
      },
    );
    return response.data;
  }

  /// 클럽 일정 삭제 (OWNER)
  Future<Map<String, dynamic>> deleteClubSchedule(int clubId, int scheduleId) async {
    final response = await _apiClient.delete('/mobile/clubs/$clubId/schedules/$scheduleId');
    return response.data;
  }

  // ==================== 게시판 API ====================

  /// 게시글 목록 (고정글 + 일반글)
  Future<Map<String, dynamic>> getClubPosts(int clubId, {int page = 0, int size = 20}) async {
    final response = await _apiClient.get(
      '/mobile/clubs/$clubId/posts',
      queryParameters: {'page': page, 'size': size},
    );

    final data = response.data;
    if (data['success'] == true) {
      final pinnedPosts = (data['pinnedPosts'] as List?)
          ?.map((e) => ClubPostSummary.fromJson(e))
          .toList() ?? [];
      final generalPosts = (data['generalPosts'] as List?)
          ?.map((e) => ClubPostSummary.fromJson(e))
          .toList() ?? [];
      return {
        'pinnedPosts': pinnedPosts,
        'generalPosts': generalPosts,
        'hasNext': data['hasNext'] ?? false,
        'currentPage': data['currentPage'] ?? 0,
      };
    }
    throw Exception(data['message'] ?? '게시글을 불러올 수 없습니다.');
  }

  /// 게시글 상세
  Future<ClubPostDetail> getPostDetail(int clubId, int postId) async {
    final response = await _apiClient.get('/mobile/clubs/$clubId/posts/$postId');

    final data = response.data;
    if (data['success'] == true && data['post'] != null) {
      return ClubPostDetail.fromJson(data['post']);
    }
    throw Exception(data['message'] ?? '게시글을 불러올 수 없습니다.');
  }

  /// 게시글 작성
  Future<Map<String, dynamic>> createPost(int clubId, {
    required String title,
    String? content,
    bool isNotice = false,
  }) async {
    final response = await _apiClient.post(
      '/mobile/clubs/$clubId/posts',
      data: {
        'title': title,
        'content': content,
        'isNotice': isNotice,
      },
    );
    return response.data;
  }

  /// 게시글 수정
  Future<Map<String, dynamic>> updatePost(int clubId, int postId, {
    String? title,
    String? content,
  }) async {
    final response = await _apiClient.put(
      '/mobile/clubs/$clubId/posts/$postId',
      data: {
        'title': title,
        'content': content,
      },
    );
    return response.data;
  }

  /// 게시글 삭제
  Future<Map<String, dynamic>> deletePost(int clubId, int postId) async {
    final response = await _apiClient.delete('/mobile/clubs/$clubId/posts/$postId');
    return response.data;
  }

  /// 게시글 고정 토글
  Future<Map<String, dynamic>> togglePin(int clubId, int postId) async {
    final response = await _apiClient.post('/mobile/clubs/$clubId/posts/$postId/pin');
    return response.data;
  }

  // ==================== 댓글 API ====================

  /// 댓글 목록
  Future<List<Map<String, dynamic>>> getComments(int clubId, int postId) async {
    final response = await _apiClient.get('/mobile/clubs/$clubId/posts/$postId/comments');

    final data = response.data;
    if (data['success'] == true && data['comments'] != null) {
      return (data['comments'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// 댓글/답글 작성
  Future<Map<String, dynamic>> addComment(int clubId, int postId, String content, {int? parentId}) async {
    final data = <String, dynamic>{'content': content};
    if (parentId != null) data['parentId'] = parentId;

    final response = await _apiClient.post(
      '/mobile/clubs/$clubId/posts/$postId/comments',
      data: data,
    );
    return response.data;
  }

  /// 댓글 삭제
  Future<Map<String, dynamic>> deleteComment(int clubId, int postId, int commentId) async {
    final response = await _apiClient.delete(
      '/mobile/clubs/$clubId/posts/$postId/comments/$commentId',
    );
    return response.data;
  }

  // ==================== 클럽 대회 API ====================

  /// 클럽 대회 목록
  Future<List<Map<String, dynamic>>> getClubContests(int clubId) async {
    final response = await _apiClient.get('/mobile/clubs/$clubId/contests');

    final data = response.data;
    if (data['success'] == true && data['contests'] != null) {
      return (data['contests'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }
}
