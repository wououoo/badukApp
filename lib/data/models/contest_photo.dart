class ContestPhoto {
  final int id;
  final int homepageId;
  final int uploaderId;
  final String? uploaderName;
  final String photoUrl;
  final String? caption;
  final String? createdAt;

  ContestPhoto({
    required this.id,
    required this.homepageId,
    required this.uploaderId,
    this.uploaderName,
    required this.photoUrl,
    this.caption,
    this.createdAt,
  });

  factory ContestPhoto.fromJson(Map<String, dynamic> json) {
    return ContestPhoto(
      id: json['id'] as int,
      homepageId: json['homepageId'] as int,
      uploaderId: json['uploaderId'] as int,
      uploaderName: json['uploaderName'] as String?,
      photoUrl: json['photoUrl'] as String,
      caption: json['caption'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}
