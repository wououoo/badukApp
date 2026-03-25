/// 게시글 요약 (목록용)
class ClubPostSummary {
  final int id;
  final String title;
  final int authorId;
  final String authorName;
  final bool isNotice;
  final bool isPinned;
  final int viewCount;
  final int commentCount;
  final String? createdAt;

  ClubPostSummary({
    required this.id,
    required this.title,
    required this.authorId,
    this.authorName = '알 수 없음',
    this.isNotice = false,
    this.isPinned = false,
    this.viewCount = 0,
    this.commentCount = 0,
    this.createdAt,
  });

  factory ClubPostSummary.fromJson(Map<String, dynamic> json) {
    return ClubPostSummary(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      authorId: json['authorId'] as int? ?? 0,
      authorName: json['authorName'] as String? ?? '알 수 없음',
      isNotice: json['isNotice'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      viewCount: json['viewCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      createdAt: json['createdAt'] as String?,
    );
  }
}

/// 게시글 상세
class ClubPostDetail {
  final int id;
  final int clubId;
  final int authorId;
  final String authorName;
  final String title;
  final String? content;
  final bool isNotice;
  final bool isPinned;
  final int viewCount;
  final int commentCount;
  final bool isAuthor;
  final bool isOwner;
  final String? createdAt;
  final String? updatedAt;

  ClubPostDetail({
    required this.id,
    required this.clubId,
    required this.authorId,
    this.authorName = '알 수 없음',
    required this.title,
    this.content,
    this.isNotice = false,
    this.isPinned = false,
    this.viewCount = 0,
    this.commentCount = 0,
    this.isAuthor = false,
    this.isOwner = false,
    this.createdAt,
    this.updatedAt,
  });

  factory ClubPostDetail.fromJson(Map<String, dynamic> json) {
    return ClubPostDetail(
      id: json['id'] as int,
      clubId: json['clubId'] as int? ?? 0,
      authorId: json['authorId'] as int? ?? 0,
      authorName: json['authorName'] as String? ?? '알 수 없음',
      title: json['title'] as String? ?? '',
      content: json['content'] as String?,
      isNotice: json['isNotice'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      viewCount: json['viewCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      isAuthor: json['isAuthor'] as bool? ?? false,
      isOwner: json['isOwner'] as bool? ?? false,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}
