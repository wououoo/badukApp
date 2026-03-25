import 'dart:convert';

/// 사용자 알림 모델
/// FCM 푸시 발송 시 DB에 저장된 알림을 표현
class UserNotification {
  final int id;
  final String? type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  UserNotification({
    required this.id,
    this.type,
    required this.title,
    required this.body,
    this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedData;
    final rawData = json['data'];
    if (rawData is String && rawData.isNotEmpty) {
      try {
        parsedData = jsonDecode(rawData) as Map<String, dynamic>;
      } catch (_) {
        parsedData = null;
      }
    } else if (rawData is Map) {
      parsedData = Map<String, dynamic>.from(rawData);
    }

    return UserNotification(
      id: json['id'] ?? 0,
      type: json['type'],
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: parsedData,
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  UserNotification copyWith({bool? isRead}) {
    return UserNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      data: data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
