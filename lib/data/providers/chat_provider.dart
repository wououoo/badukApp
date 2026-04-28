import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/chat_websocket_service.dart';
import 'auth_provider.dart';

// 서비스 인스턴스
final chatServiceProvider = Provider<ChatService>((ref) => ChatService());
final chatWebSocketProvider = Provider<ChatWebSocketService>((ref) => ChatWebSocketService());

// 채팅방 목록
final chatRoomListProvider = StateNotifierProvider<ChatRoomListNotifier, AsyncValue<List<ChatRoom>>>((ref) {
  return ChatRoomListNotifier(ref.read(chatServiceProvider));
});

class ChatRoomListNotifier extends StateNotifier<AsyncValue<List<ChatRoom>>> {
  final ChatService _chatService;

  ChatRoomListNotifier(this._chatService) : super(const AsyncValue.loading());

  Future<void> load() async {
    try {
      state = const AsyncValue.loading();
      final rooms = await _chatService.getMyRooms();
      state = AsyncValue.data(rooms);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    try {
      final rooms = await _chatService.getMyRooms();
      state = AsyncValue.data(rooms);
    } catch (e) {
      debugPrint('[ChatRoomList] refresh 실패: $e');
    }
  }
}

// 안읽은 메시지 수 (바텀탭 뱃지용)
final chatUnreadCountProvider = StateNotifierProvider<ChatUnreadCountNotifier, int>((ref) {
  return ChatUnreadCountNotifier(
    ref.read(chatServiceProvider),
    ref.read(chatWebSocketProvider),
  );
});

class ChatUnreadCountNotifier extends StateNotifier<int> {
  final ChatService _chatService;
  final ChatWebSocketService _wsService;
  Timer? _pollingTimer;

  ChatUnreadCountNotifier(this._chatService, this._wsService) : super(0);

  Future<void> fetch() async {
    try {
      final count = await _chatService.getUnreadCount();
      state = count;
    } catch (e) {
      debugPrint('[ChatUnread] fetch 실패: $e');
    }
  }

  void updateFromWebSocket(int count) {
    state = count;
  }

  /// WebSocket 연결 + 폴백 폴링
  void startPolling() {
    // WebSocket 연결 시도
    _wsService.onUnreadCountChanged = (count) => updateFromWebSocket(count);
    _wsService.onConnected = () {
      debugPrint('[ChatUnread] WebSocket 연결됨, 폴링 중지');
      _pollingTimer?.cancel();
      _pollingTimer = null;
      fetch(); // 초기값 조회
    };
    _wsService.onError = (_) {
      debugPrint('[ChatUnread] WebSocket 실패, 폴링 폴백');
      _startFallbackPolling();
    };
    _wsService.connect();

    // 폴백 폴링 (WebSocket 연결 전 or 실패 시)
    _startFallbackPolling();
  }

  void _startFallbackPolling() {
    if (_pollingTimer != null) return;
    fetch();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_wsService.isConnected) fetch();
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _wsService.disconnect();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

// 채팅 메시지 (개별 채팅방용)
final chatMessagesProvider = StateNotifierProvider.family<ChatMessagesNotifier, AsyncValue<List<ChatMessage>>, int>(
  (ref, roomId) {
    final myUserId = ref.read(authProvider).user?.id;
    return ChatMessagesNotifier(
      ref.read(chatServiceProvider),
      ref.read(chatWebSocketProvider),
      roomId,
      myUserId,
    );
  },
);

class ChatMessagesNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final ChatService _chatService;
  final ChatWebSocketService _wsService;
  final int roomId;
  final int? _myUserId;
  String? _myRoleInRoom; // 'STAFF' 또는 'INQUIRER' — ChatScreen에서 setMyRole로 설정
  Timer? _pollingTimer;
  int _currentPage = 0;
  bool _hasNext = true;

  ChatMessagesNotifier(this._chatService, this._wsService, this.roomId, this._myUserId)
      : super(const AsyncValue.loading());

  /// ChatScreen에서 호출: 내 역할 설정 (WS/REST 즉시 발송 시 isMine 판정용)
  void setMyRole(String role) {
    _myRoleInRoom = role;
  }

  /// 통합 isMine 판정: 본인 ID 또는 (내가 STAFF이고 발신자도 STAFF)
  bool _computeIsMine(int senderId, String? senderRole) {
    if (_myUserId != null && senderId == _myUserId) return true;
    if (_myRoleInRoom == 'STAFF' && senderRole == 'STAFF') return true;
    return false;
  }

  Future<void> loadInitial() async {
    try {
      state = const AsyncValue.loading();
      _currentPage = 0;
      final result = await _chatService.getMessages(roomId, page: 0);
      final messages = result['messages'] as List<ChatMessage>;
      _hasNext = result['hasNext'] as bool;
      state = AsyncValue.data(messages);

      // 읽음 처리
      if (messages.isNotEmpty) {
        _chatService.markAsRead(roomId, messages.first.id);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (!_hasNext) return;
    final current = state.valueOrNull ?? [];
    try {
      _currentPage++;
      final result = await _chatService.getMessages(roomId, page: _currentPage);
      final moreMessages = result['messages'] as List<ChatMessage>;
      _hasNext = result['hasNext'] as bool;
      state = AsyncValue.data([...current, ...moreMessages]);
    } catch (e) {
      _currentPage--;
      debugPrint('[ChatMessages] loadMore 실패: $e');
    }
  }

  /// 메시지 발송 — 옵티미스틱 UI + clientId 매칭
  /// 1. 즉시 sending 상태로 화면에 추가
  /// 2. WebSocket 또는 REST로 송신
  /// 3. 서버 응답/broadcast 도착 시 clientId로 매칭하여 실제 메시지로 교체
  /// 4. 실패 시 failed 상태로 변경 (재시도 가능)
  Future<void> sendMessage(String content) async {
    final clientId = _generateClientId();
    final tempMessage = ChatMessage(
      id: -DateTime.now().millisecondsSinceEpoch, // 임시 음수 ID
      senderId: _myUserId ?? 0,
      senderName: null,
      senderRole: _myRoleInRoom ?? 'INQUIRER',
      content: content,
      createdAt: DateTime.now().toIso8601String(),
      isMine: true,
      status: ChatMessageStatus.sending,
      clientId: clientId,
    );

    // 옵티미스틱 삽입
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([tempMessage, ...current]);

    if (_wsService.isConnected) {
      // WebSocket 송신 (서버 broadcast가 _onWebSocketMessage로 돌아오면 매칭됨)
      _wsService.sendMessage(roomId, content, clientId: clientId);
      // WS는 비동기이므로 별도 실패 감지 불가 — 7초 안에 매칭 안 되면 failed로 표시
      Future.delayed(const Duration(seconds: 7), () {
        if (!mounted) return;
        _markAsFailedIfStillSending(clientId);
      });
    } else {
      // REST 폴백 — 서버는 broadcast도 함께 호출함
      try {
        final raw = await _chatService.sendMessage(roomId, content, clientId: clientId);
        // 매칭: clientId 우선, 없으면 응답 message id로 dedup
        _replaceTempWithReal(
          clientId,
          ChatMessage(
            id: raw.id,
            senderId: raw.senderId,
            senderName: raw.senderName,
            senderRole: raw.senderRole,
            content: raw.content,
            createdAt: raw.createdAt,
            isMine: _computeIsMine(raw.senderId, raw.senderRole),
            status: ChatMessageStatus.sent,
          ),
        );
      } catch (e) {
        debugPrint('[ChatMessages] REST 송신 실패: $e');
        _markAsFailedIfStillSending(clientId);
        rethrow;
      }
    }
  }

  /// 송신 실패한 메시지 재시도
  Future<void> retrySend(String clientId) async {
    final current = state.valueOrNull ?? [];
    final failed = current.firstWhere(
      (m) => m.clientId == clientId,
      orElse: () => throw StateError('재시도할 메시지 없음'),
    );
    // 기존 failed 메시지 제거 후 재발송
    state = AsyncValue.data(current.where((m) => m.clientId != clientId).toList());
    await sendMessage(failed.content);
  }

  /// clientId 또는 message id로 임시 메시지를 실제 메시지로 교체
  void _replaceTempWithReal(String clientId, ChatMessage real) {
    final current = state.valueOrNull ?? [];
    // 1) clientId 매칭 시도
    final tempIdx = current.indexWhere((m) => m.clientId == clientId);
    if (tempIdx != -1) {
      final updated = [...current];
      updated[tempIdx] = real;
      state = AsyncValue.data(updated);
      return;
    }
    // 2) 이미 같은 id가 있으면 무시 (broadcast가 먼저 도착한 경우)
    if (current.any((m) => m.id == real.id)) return;
    // 3) 그 외엔 새 메시지로 추가
    state = AsyncValue.data([real, ...current]);
  }

  /// 일정 시간 후에도 sending 상태인 메시지를 failed로 표시
  void _markAsFailedIfStillSending(String clientId) {
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere(
      (m) => m.clientId == clientId && m.status == ChatMessageStatus.sending,
    );
    if (idx == -1) return;
    final updated = [...current];
    updated[idx] = current[idx].copyWith(status: ChatMessageStatus.failed);
    state = AsyncValue.data(updated);
  }

  String _generateClientId() {
    // 간단한 임시 ID — UUID 패키지 추가 없이
    return 'c-${DateTime.now().microsecondsSinceEpoch}-${_myUserId ?? 0}';
  }

  /// WebSocket 구독 시작 + 폴백 폴링
  void startListening() {
    if (_wsService.isConnected) {
      // WebSocket 구독
      _wsService.onMessageReceived = _onWebSocketMessage;
      _wsService.subscribeToRoom(roomId);
      debugPrint('[ChatMessages] WebSocket 구독 시작 - roomId: $roomId');
    } else {
      // 폴백 폴링
      debugPrint('[ChatMessages] WebSocket 미연결, 폴링 시작 - roomId: $roomId');
      _startPolling();
    }
  }

  void _onWebSocketMessage(Map<String, dynamic> data) {
    final senderId = (data['senderId'] is int)
        ? data['senderId'] as int
        : int.tryParse(data['senderId']?.toString() ?? '') ?? 0;
    final senderRole = data['senderRole']?.toString() ?? 'STAFF';
    // 서버가 per-recipient isMine을 계산해서 보내주므로 그대로 신뢰
    final serverIsMine = data['isMine'] as bool?;
    final clientId = data['clientId']?.toString();

    final message = ChatMessage(
      id: data['id'] ?? 0,
      senderId: senderId,
      senderName: data['senderName']?.toString(),
      senderRole: senderRole,
      content: data['content'] ?? '',
      createdAt: data['createdAt']?.toString() ?? '',
      isMine: serverIsMine ?? _computeIsMine(senderId, senderRole),
      status: ChatMessageStatus.sent,
    );

    final current = state.valueOrNull ?? [];

    // 1) clientId 매칭: 옵티미스틱 임시 메시지를 실제 메시지로 교체
    if (clientId != null) {
      final tempIdx = current.indexWhere((m) => m.clientId == clientId);
      if (tempIdx != -1) {
        final updated = [...current];
        updated[tempIdx] = message;
        state = AsyncValue.data(updated);
        _chatService.markAsRead(roomId, message.id);
        return;
      }
    }

    // 2) 이미 같은 id가 있으면 무시
    if (current.any((m) => m.id == message.id)) return;

    // 3) 새 메시지 추가
    state = AsyncValue.data([message, ...current]);
    _chatService.markAsRead(roomId, message.id);
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollNewMessages());
  }

  void stopListening() {
    _wsService.unsubscribeFromRoom(roomId);
    _wsService.onMessageReceived = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _pollNewMessages() async {
    try {
      final result = await _chatService.getMessages(roomId, page: 0);
      final latestMessages = result['messages'] as List<ChatMessage>;
      final current = state.valueOrNull ?? [];

      if (latestMessages.isEmpty) return;
      if (current.isNotEmpty && latestMessages.first.id == current.first.id) return;

      // 새 메시지만 추출 (기존에 없는 것만)
      final existingIds = current.map((m) => m.id).toSet();
      final newMessages = latestMessages.where((m) => !existingIds.contains(m.id)).toList();

      if (newMessages.isNotEmpty) {
        // 새 메시지를 앞에 추가 (기존 메시지 유지)
        state = AsyncValue.data([...newMessages, ...current]);
        _chatService.markAsRead(roomId, newMessages.first.id);
      }
    } catch (e) {
      debugPrint('[ChatMessages] poll 실패: $e');
    }
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
