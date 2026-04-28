import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../../core/constants/api_constants.dart';

/// STOMP WebSocket 채팅 서비스
/// 실시간 메시지 수신 + 발송 담당
class ChatWebSocketService {
  StompClient? _stompClient;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // 콜백
  Function(Map<String, dynamic> message)? onMessageReceived;
  Function(int unreadCount)? onUnreadCountChanged;
  Function()? onConnected;
  Function(String error)? onError;

  // 구독 관리
  final Map<int, StompUnsubscribe?> _roomSubscriptions = {};
  StompUnsubscribe? _unreadSubscription;

  bool get isConnected => _stompClient?.connected ?? false;

  /// WebSocket URL 생성
  String get _wsUrl {
    // baseUrl: http://localhost:8080/api → ws://localhost:8080/ws/chat
    final httpUrl = ApiConstants.baseUrl.replaceAll('/api', '');
    final wsUrl = httpUrl.replaceFirst('http', 'ws').replaceFirst('https', 'wss');
    return '$wsUrl/ws/chat';
  }

  /// WebSocket 연결
  Future<void> connect() async {
    if (isConnected) return;

    final token = await _storage.read(key: 'access_token');
    if (token == null) {
      debugPrint('[ChatWS] 토큰 없음, 연결 불가');
      return;
    }

    _stompClient = StompClient(
      config: StompConfig(
        url: _wsUrl,
        stompConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        onConnect: _onConnect,
        onWebSocketError: (error) {
          debugPrint('[ChatWS] WebSocket 에러: $error');
          onError?.call(error.toString());
        },
        onStompError: (frame) {
          debugPrint('[ChatWS] STOMP 에러: ${frame.body}');
          onError?.call(frame.body ?? 'STOMP error');
        },
        onDisconnect: (frame) {
          debugPrint('[ChatWS] 연결 끊김');
        },
        reconnectDelay: const Duration(seconds: 5),
      ),
    );

    _stompClient!.activate();
    debugPrint('[ChatWS] 연결 시도: $_wsUrl');
  }

  void _onConnect(StompFrame frame) {
    debugPrint('[ChatWS] 연결 성공');
    onConnected?.call();

    // 개인 안읽은수 구독
    _unreadSubscription = _stompClient?.subscribe(
      destination: '/user/queue/chat/unread',
      callback: (frame) {
        if (frame.body != null) {
          try {
            final data = jsonDecode(frame.body!);
            onUnreadCountChanged?.call(data['unreadCount'] ?? 0);
          } catch (e) {
            debugPrint('[ChatWS] 안읽은수 파싱 실패: $e');
          }
        }
      },
    );
  }

  /// 특정 채팅방 구독 (실시간 메시지 수신)
  /// 개인 큐(/user/queue/chat/{roomId}) — Spring이 본인 세션에만 라우팅 → 도청 불가
  void subscribeToRoom(int roomId) {
    if (!isConnected) return;
    if (_roomSubscriptions.containsKey(roomId)) return;

    _roomSubscriptions[roomId] = _stompClient?.subscribe(
      destination: '/user/queue/chat/$roomId',
      callback: (frame) {
        if (frame.body != null) {
          try {
            final data = jsonDecode(frame.body!);
            onMessageReceived?.call(data);
          } catch (e) {
            debugPrint('[ChatWS] 메시지 파싱 실패: $e');
          }
        }
      },
    );
    debugPrint('[ChatWS] 채팅방 $roomId 구독 (/user/queue)');
  }

  /// 채팅방 구독 해제
  void unsubscribeFromRoom(int roomId) {
    _roomSubscriptions[roomId]?.call();
    _roomSubscriptions.remove(roomId);
    debugPrint('[ChatWS] 채팅방 $roomId 구독 해제');
  }

  /// STOMP로 메시지 발송
  /// [clientId] 옵티미스틱 매칭용 임시 ID (서버가 echo)
  void sendMessage(int roomId, String content, {String? clientId}) {
    if (!isConnected) {
      debugPrint('[ChatWS] 연결 안됨, 메시지 발송 불가');
      return;
    }

    final body = <String, String>{'content': content};
    if (clientId != null) body['clientId'] = clientId;

    _stompClient!.send(
      destination: '/app/chat/$roomId',
      body: jsonEncode(body),
    );
  }

  /// 연결 해제
  void disconnect() {
    for (final unsub in _roomSubscriptions.values) {
      unsub?.call();
    }
    _roomSubscriptions.clear();
    _unreadSubscription?.call();
    _unreadSubscription = null;
    _stompClient?.deactivate();
    _stompClient = null;
    debugPrint('[ChatWS] 연결 해제');
  }
}
