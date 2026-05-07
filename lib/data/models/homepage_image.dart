/// 대회 홈페이지 안내 이미지 (HomepageEdit에서 업로드)
/// 대회 진행 후 사진 갤러리(ContestPhoto)와는 다른 사전 안내용 이미지.
class HomepageImage {
  final int id;
  final int homepageId;
  final String imageUrl;
  final String? title;
  final String? description;
  final int? displayOrder;
  final String displayMode; // "always" 또는 "toggle"
  final bool isVisible;

  HomepageImage({
    required this.id,
    required this.homepageId,
    required this.imageUrl,
    this.title,
    this.description,
    this.displayOrder,
    this.displayMode = 'toggle',
    this.isVisible = true,
  });

  factory HomepageImage.fromJson(Map<String, dynamic> json) {
    return HomepageImage(
      id: (json['imageId'] ?? json['id']) as int,
      homepageId: (json['homepageId'] ?? 0) as int,
      imageUrl: json['imageUrl'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      displayOrder: json['displayOrder'] as int?,
      displayMode: (json['displayMode'] as String?) ?? 'toggle',
      isVisible: json['isVisible'] as bool? ?? true,
    );
  }
}
