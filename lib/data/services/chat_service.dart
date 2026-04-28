import '../api/api_client.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';

class ChatService {
  final ApiClient _apiClient = ApiClient.instance;

  /// 문의 채팅방 생성/조회 (대회 ID로)
  Future<Map<String, dynamic>> getOrCreateRoom({required int homepageId}) async {
    final response = await _apiClient.post(
      '/mobile/chat/rooms',
      data: {'homepageId': homepageId},
    );
    return response.data['data'];
  }

  /// 내 채팅방 목록
  Future<List<ChatRoom>> getMyRooms() async {
    final response = await _apiClient.get('/mobile/chat/rooms');
    final data = response.data['data'] as List;
    return data.map((e) => ChatRoom.fromJson(e)).toList();
  }

  /// 메시지 목록 조회 (페이징)
  Future<Map<String, dynamic>> getMessages(int roomId, {int page = 0, int size = 50}) async {
    final response = await _apiClient.get(
      '/mobile/chat/rooms/$roomId/messages',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data['data'];
    final messages = (data['messages'] as List)
        .map((e) => ChatMessage.fromJson(e))
        .toList();
    return {
      'messages': messages,
      'totalPages': data['totalPages'],
      'hasNext': data['hasNext'],
    };
  }

  /// 메시지 발송
  Future<ChatMessage> sendMessage(int roomId, String content, {String? clientId}) async {
    final body = <String, dynamic>{'content': content};
    if (clientId != null) body['clientId'] = clientId;
    final response = await _apiClient.post(
      '/mobile/chat/rooms/$roomId/messages',
      data: body,
    );
    return ChatMessage.fromJson(response.data['data']);
  }

  /// 읽음 처리
  Future<void> markAsRead(int roomId, int lastMessageId) async {
    await _apiClient.put(
      '/mobile/chat/rooms/$roomId/read',
      data: {'lastMessageId': lastMessageId},
    );
  }

  /// 전체 안읽은 수
  Future<int> getUnreadCount() async {
    final response = await _apiClient.get('/mobile/chat/unread-count');
    return response.data['unreadCount'] ?? 0;
  }
}
