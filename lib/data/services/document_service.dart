import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../api/api_client.dart';

/// 제출 서류(재학증명서·주민등록초본 등) API.
///
/// - 신청 전: 요구 서류 조회 + 파일 임시 업로드(stage) → 받은 토큰을 신청 데이터 documentTokens 에 담아 제출.
///   (웹 신청 화면과 같은 공개 API: /api/document/homepage/{hp}/...)
/// - 신청 후: 로그인한 본인의 신청에 서류 보기·추가·삭제·내려받기.
///   (앱 전용 API: /api/mobile/users/me/registrations/{reg}/documents — 신청 비밀번호 대신 로그인으로 본인 확인)
///
/// 서버 검사: PDF·JPG·PNG만, 파일 하나 10MB 이하(내용까지 확인).
class DocumentService {
  final ApiClient _api = ApiClient();

  static const int maxFileBytes = 10 * 1024 * 1024;
  static const List<String> allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

  /// 이 대회의 요구 서류 전체 (부문 필터는 [DocumentRequirement.appliesTo]로)
  Future<List<DocumentRequirement>> getRequirements(int homepageId) async {
    try {
      final res = await _api.get('/document/homepage/$homepageId/requirements');
      final data = res.data;
      final list = (data is Map ? data['requirements'] : null) as List? ?? const [];
      return list
          .whereType<Map>()
          .map((e) => DocumentRequirement.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw DocumentApiException(_message(e, '제출 서류 정보를 불러오지 못했습니다.'));
    }
  }

  /// 신청 전 임시 업로드 → {token, name, size}
  Future<StagedDocument> stage({
    required int homepageId,
    required int requirementId,
    required String fileName,
    String? path,
    Uint8List? bytes,
  }) async {
    try {
      final form = FormData.fromMap({
        'requirementId': requirementId.toString(),
        'file': await _multipart(fileName, path: path, bytes: bytes),
      });
      final res = await _api.post('/document/homepage/$homepageId/stage', data: form);
      final f = Map<String, dynamic>.from((res.data as Map)['file'] as Map);
      return StagedDocument(
        token: f['token'].toString(),
        name: (f['name'] ?? fileName).toString(),
        size: (f['size'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      throw DocumentApiException(_message(e, '파일을 올리지 못했습니다.'));
    }
  }

  /// 내 신청의 서류 현황
  Future<MyDocuments> myList(int registrationId) async {
    try {
      final res = await _api.get('/mobile/users/me/registrations/$registrationId/documents');
      return MyDocuments.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      throw DocumentApiException(_message(e, '제출 서류를 불러오지 못했습니다.'));
    }
  }

  Future<void> myUpload({
    required int registrationId,
    required int requirementId,
    required String fileName,
    String? path,
    Uint8List? bytes,
  }) async {
    try {
      final form = FormData.fromMap({
        'requirementId': requirementId.toString(),
        'file': await _multipart(fileName, path: path, bytes: bytes),
      });
      await _api.post('/mobile/users/me/registrations/$registrationId/documents/upload', data: form);
    } on DioException catch (e) {
      throw DocumentApiException(_message(e, '파일을 올리지 못했습니다.'));
    }
  }

  Future<void> myRemove({required int registrationId, required int fileId}) async {
    try {
      await _api.post('/mobile/users/me/registrations/$registrationId/documents/files/$fileId/remove');
    } on DioException catch (e) {
      throw DocumentApiException(_message(e, '파일을 지우지 못했습니다.'));
    }
  }

  Future<Uint8List> myDownload({required int registrationId, required int fileId}) async {
    try {
      final res = await _api.dio.get<List<int>>(
        '/mobile/users/me/registrations/$registrationId/documents/files/$fileId/download',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data ?? const []);
    } on DioException catch (e) {
      throw DocumentApiException(_message(e, '파일을 열지 못했습니다.'));
    }
  }

  // ───────── 도우미 ─────────

  Future<MultipartFile> _multipart(String fileName, {String? path, Uint8List? bytes}) async {
    if (bytes != null) return MultipartFile.fromBytes(bytes, filename: fileName);
    if (path != null) return MultipartFile.fromFile(path, filename: fileName);
    throw DocumentApiException('파일을 읽지 못했습니다.');
  }

  /// 서버가 준 문장(message) 우선. 바이트 응답(내려받기 실패)은 본문이 bytes라 기본 문장.
  static String _message(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String && (data['message'] as String).isNotEmpty) {
      return data['message'] as String;
    }
    if (e.response?.statusCode == 401) return '로그인이 필요합니다.';
    if (e.response?.statusCode == 413) return '파일이 너무 큽니다. 10MB 이하로 올려 주세요.';
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
      return '인터넷 연결을 확인해 주세요.';
    }
    return fallback;
  }

  /// 확장자 검사(서버도 다시 검사함) — 맞으면 null, 아니면 안내 문장
  static String? checkLocalFile(String name, int size) {
    final dot = name.lastIndexOf('.');
    final ext = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
    if (!allowedExtensions.contains(ext)) return 'PDF, JPG, PNG 파일만 올릴 수 있습니다.';
    if (size > maxFileBytes) return '파일 하나는 10MB 이하만 올릴 수 있습니다.';
    if (size <= 0) return '빈 파일입니다.';
    return null;
  }

  static String formatSize(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    if (bytes >= 1024) return '${(bytes / 1024).round()}KB';
    return '${bytes}B';
  }
}

class DocumentApiException implements Exception {
  final String message;
  DocumentApiException(this.message);
  @override
  String toString() => message;
}

/// 요구 서류 항목
class DocumentRequirement {
  final int id;
  final String title;
  final String? description;
  final bool required;
  final int maxFiles;
  /// 비어 있으면 모든 부문
  final List<int> categoryIds;

  DocumentRequirement({
    required this.id,
    required this.title,
    this.description,
    required this.required,
    required this.maxFiles,
    required this.categoryIds,
  });

  bool appliesTo(int? categoryId) =>
      categoryIds.isEmpty || (categoryId != null && categoryIds.contains(categoryId));

  factory DocumentRequirement.fromJson(Map<String, dynamic> j) {
    final cats = <int>[];
    for (final c in (j['categoryIds'] as List? ?? const [])) {
      final v = c is num ? c.toInt() : int.tryParse(c.toString());
      if (v != null) cats.add(v);
    }
    return DocumentRequirement(
      id: (j['id'] as num).toInt(),
      title: (j['title'] ?? '').toString(),
      description: (j['description'] as String?)?.trim().isEmpty == true ? null : j['description'] as String?,
      required: j['required'] == true,
      maxFiles: (j['maxFiles'] as num?)?.toInt() ?? 1,
      categoryIds: cats,
    );
  }
}

/// 신청 전 임시로 올린 파일
class StagedDocument {
  final String token;
  final String name;
  final int size;
  StagedDocument({required this.token, required this.name, required this.size});
}

/// 신청 후 내 서류 현황
class MyDocuments {
  final int registrationId;
  final bool editable;
  /// 접수 마감일이 지났는지 — 지나면 보완 요청 받은 서류만 바꿀 수 있다
  final bool pastDeadline;
  final List<MyDocumentItem> items;

  MyDocuments({required this.registrationId, required this.editable, this.pastDeadline = false, required this.items});

  factory MyDocuments.fromJson(Map<String, dynamic> j) => MyDocuments(
        registrationId: (j['registrationId'] as num?)?.toInt() ?? 0,
        editable: j['editable'] != false,
        pastDeadline: j['pastDeadline'] == true,
        items: (j['items'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => MyDocumentItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class MyDocumentItem {
  final DocumentRequirement requirement;
  final List<MyDocumentFile> files;
  /// PENDING / CONFIRMED / NEEDS_FIX / REJECTED / null(아직 안 냄)
  final String? reviewStatus;
  final String? reviewMemo;
  /// 서버 판정: 신청자가 바꿀 수 없음(취소·확인 완료·접수 마감 후). null이면 구버전 서버.
  final bool? locked;

  MyDocumentItem({required this.requirement, required this.files, this.reviewStatus, this.reviewMemo, this.locked});

  bool get confirmed => reviewStatus == 'CONFIRMED';

  factory MyDocumentItem.fromJson(Map<String, dynamic> j) => MyDocumentItem(
        requirement: DocumentRequirement.fromJson(j),
        files: (j['files'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => MyDocumentFile.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        reviewStatus: j['reviewStatus'] as String?,
        reviewMemo: j['reviewMemo'] as String?,
        locked: j['locked'] is bool ? j['locked'] as bool : null,
      );
}

class MyDocumentFile {
  final int id;
  final String name;
  final int size;
  final String? contentType;
  final String? uploadedAt;
  /// APPLICANT / ADMIN
  final String? uploadedByType;

  MyDocumentFile({
    required this.id,
    required this.name,
    required this.size,
    this.contentType,
    this.uploadedAt,
    this.uploadedByType,
  });

  bool get isImage => (contentType ?? '').startsWith('image/');

  factory MyDocumentFile.fromJson(Map<String, dynamic> j) => MyDocumentFile(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? '').toString(),
        size: (j['size'] as num?)?.toInt() ?? 0,
        contentType: j['contentType'] as String?,
        uploadedAt: j['uploadedAt'] as String?,
        uploadedByType: j['uploadedByType'] as String?,
      );
}
