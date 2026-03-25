import '../api/api_client.dart';
import '../../core/error/app_exception.dart';

class SupportService {
  final ApiClient _apiClient;

  SupportService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // ==================== 공지사항 ====================

  /// 공지사항 목록
  Future<List<Notice>> getNotices({int page = 0, int size = 20}) async {
    final response = await _apiClient.get(
      '/mobile/support/notices',
      queryParameters: {'page': page, 'size': size},
    );

    final data = response.data;
    if (data['success'] == true && data['content'] != null) {
      return (data['content'] as List).map((e) => Notice.fromJson(e)).toList();
    }
    return [];
  }

  /// 공지사항 상세
  Future<Notice> getNotice(int id) async {
    final response = await _apiClient.get('/mobile/support/notices/$id');

    if (response.data['success'] == true && response.data['notice'] != null) {
      return Notice.fromJson(response.data['notice']);
    }
    throw AppException.notFound(message: response.data['message'] ?? '공지사항을 불러올 수 없습니다.');
  }

  /// 중요 공지사항 목록
  Future<List<Notice>> getImportantNotices() async {
    final response = await _apiClient.get('/mobile/support/notices/important');

    final data = response.data;
    if (data['success'] == true && data['notices'] != null) {
      return (data['notices'] as List).map((e) => Notice.fromJson(e)).toList();
    }
    return [];
  }

  // ==================== 1:1 문의 ====================

  /// 내 문의 목록
  Future<List<Inquiry>> getMyInquiries({int page = 0, int size = 20}) async {
    final response = await _apiClient.get(
      '/mobile/support/inquiries/my',
      queryParameters: {'page': page, 'size': size},
    );

    final data = response.data;
    if (data['success'] == true && data['content'] != null) {
      return (data['content'] as List).map((e) => Inquiry.fromJson(e)).toList();
    }
    return [];
  }

  /// 문의 상세
  Future<Inquiry> getInquiry(int id) async {
    final response = await _apiClient.get('/mobile/support/inquiries/$id');

    if (response.data['success'] == true && response.data['inquiry'] != null) {
      return Inquiry.fromJson(response.data['inquiry']);
    }
    throw AppException.notFound(message: response.data['message'] ?? '문의를 불러올 수 없습니다.');
  }

  /// 문의 등록
  Future<Inquiry> createInquiry({
    required String title,
    required String content,
    String category = '일반',
  }) async {
    final response = await _apiClient.post(
      '/mobile/support/inquiries',
      data: {
        'title': title,
        'content': content,
        'category': category,
      },
    );

    if (response.data['success'] == true && response.data['inquiry'] != null) {
      return Inquiry.fromJson(response.data['inquiry']);
    }
    throw AppException.validation(message: response.data['message'] ?? '문의 등록에 실패했습니다.');
  }

  /// 문의 삭제
  Future<void> deleteInquiry(int id) async {
    final response = await _apiClient.delete('/mobile/support/inquiries/$id');

    if (response.data['success'] != true) {
      throw AppException.server(message: response.data['message'] ?? '문의 삭제에 실패했습니다.');
    }
  }
}

/// 공지사항 모델
class Notice {
  final int id;
  final String title;
  final String? content;
  final bool isImportant;
  final DateTime createdAt;
  final int viewCount;

  Notice({
    required this.id,
    required this.title,
    this.content,
    required this.isImportant,
    required this.createdAt,
    required this.viewCount,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'],
      isImportant: json['isImportant'] ?? false,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      viewCount: json['viewCount'] ?? 0,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    if (value is List && value.length >= 3) {
      return DateTime(
        value[0], value[1], value[2],
        value.length > 3 ? value[3] : 0,
        value.length > 4 ? value[4] : 0,
      );
    }
    return null;
  }
}

/// 1:1 문의 모델
class Inquiry {
  final int id;
  final String title;
  final String? content;
  final String category;
  final String status; // PENDING, ANSWERED, CLOSED
  final String? answer;
  final DateTime createdAt;
  final DateTime? answeredAt;

  Inquiry({
    required this.id,
    required this.title,
    this.content,
    required this.category,
    required this.status,
    this.answer,
    required this.createdAt,
    this.answeredAt,
  });

  factory Inquiry.fromJson(Map<String, dynamic> json) {
    return Inquiry(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'],
      category: json['category'] ?? '일반',
      status: json['status'] ?? 'PENDING',
      answer: json['answer'],
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      answeredAt: _parseDateTime(json['answeredAt']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    if (value is List && value.length >= 3) {
      return DateTime(
        value[0], value[1], value[2],
        value.length > 3 ? value[3] : 0,
        value.length > 4 ? value[4] : 0,
      );
    }
    return null;
  }

  bool get isPending => status == 'PENDING';
  bool get isAnswered => status == 'ANSWERED';

  String get statusText {
    switch (status) {
      case 'PENDING':
        return '답변 대기';
      case 'ANSWERED':
        return '답변 완료';
      case 'CLOSED':
        return '종료';
      default:
        return status;
    }
  }
}
