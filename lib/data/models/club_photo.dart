class ClubPhoto {
  final int id;
  final int clubId;
  final int uploaderId;
  final String? uploaderName;
  final String photoUrl;
  final String? caption;
  final String? createdAt;

  ClubPhoto({
    required this.id,
    required this.clubId,
    required this.uploaderId,
    this.uploaderName,
    required this.photoUrl,
    this.caption,
    this.createdAt,
  });

  factory ClubPhoto.fromJson(Map<String, dynamic> json) {
    return ClubPhoto(
      id: json['id'] as int,
      clubId: json['clubId'] as int,
      uploaderId: json['uploaderId'] as int,
      uploaderName: json['uploaderName'] as String?,
      photoUrl: json['photoUrl'] as String,
      caption: json['caption'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}
