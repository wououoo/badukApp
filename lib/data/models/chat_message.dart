/// 메시지 송신 상태
/// - sent: 서버에 정상 저장됨 (수신 메시지의 기본값)
/// - sending: 옵티미스틱 삽입, 서버 응답 대기 중
/// - failed: 송신 실패, 재시도 가능
enum ChatMessageStatus { sent, sending, failed }

class ChatMessage {
  final int id;
  final int senderId;
  final String? senderName;
  final String senderRole; // INQUIRER 또는 STAFF
  final String content;
  final String createdAt;
  final bool isMine;
  final ChatMessageStatus status;
  final String? clientId; // 옵티미스틱 매칭용 임시 ID (송신 측에서만 사용)

  ChatMessage({
    required this.id,
    required this.senderId,
    this.senderName,
    this.senderRole = 'INQUIRER',
    required this.content,
    required this.createdAt,
    required this.isMine,
    this.status = ChatMessageStatus.sent,
    this.clientId,
  });

  bool get isStaff => senderRole == 'STAFF';
  bool get isSending => status == ChatMessageStatus.sending;
  bool get isFailed => status == ChatMessageStatus.failed;

  ChatMessage copyWith({
    int? id,
    int? senderId,
    String? senderName,
    String? senderRole,
    String? content,
    String? createdAt,
    bool? isMine,
    ChatMessageStatus? status,
    String? clientId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isMine: isMine ?? this.isMine,
      status: status ?? this.status,
      clientId: clientId ?? this.clientId,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? 0,
      senderId: json['senderId'] ?? 0,
      senderName: json['senderName'],
      senderRole: json['senderRole'] ?? 'INQUIRER',
      content: json['content'] ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      isMine: json['isMine'] ?? false,
      clientId: json['clientId']?.toString(),
    );
  }
}
