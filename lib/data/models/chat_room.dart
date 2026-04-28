class ChatRoom {
  final int roomId;
  final String displayName; // 문의자에겐 대회명, 직원에겐 참가자명
  final String myRole; // INQUIRER 또는 STAFF
  final int? homepageId;
  final String? contestTitle;
  final int? inquirerId;
  final String? lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;

  ChatRoom({
    required this.roomId,
    required this.displayName,
    required this.myRole,
    this.homepageId,
    this.contestTitle,
    this.inquirerId,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.unreadCount = 0,
  });

  bool get isInquirer => myRole == 'INQUIRER';
  bool get isStaff => myRole == 'STAFF';

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      roomId: json['roomId'] ?? 0,
      displayName: json['displayName'] ?? '문의',
      myRole: json['myRole'] ?? 'INQUIRER',
      homepageId: json['homepageId'],
      contestTitle: json['contestTitle'],
      inquirerId: json['inquirerId'],
      lastMessageAt: json['lastMessageAt']?.toString(),
      lastMessagePreview: json['lastMessagePreview'],
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}
