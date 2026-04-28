import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/providers/chat_provider.dart';
import '../../../data/providers/auth_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final int roomId;
  final String? contestTitle;
  final String? myRole; // INQUIRER 또는 STAFF

  const ChatScreen({
    super.key,
    required this.roomId,
    this.contestTitle,
    this.myRole,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  String _myRole = 'INQUIRER'; // 채팅 목록에서 전달받은 역할
  ChatMessagesNotifier? _notifier; // dispose에서 ref.read 못 쓰니 캐시

  @override
  void initState() {
    super.initState();
    _myRole = widget.myRole ?? 'INQUIRER';
    _notifier = ref.read(chatMessagesProvider(widget.roomId).notifier);
    _notifier!.setMyRole(_myRole); // WS/REST 즉시 발송 시 isMine 판정용
    _notifier!.loadInitial();
    _notifier!.startListening();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
        _notifier?.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _notifier?.stopListening();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await ref.read(chatMessagesProvider(widget.roomId).notifier).sendMessage(content);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메시지 발송에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.roomId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.contestTitle ?? '문의',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          // 메시지 목록
          Expanded(
            child: messagesAsync.when(
              data: (messages) => messages.isEmpty
                  ? Center(
                      child: Text('메시지를 보내 문의를 시작하세요.',
                          style: TextStyle(color: Colors.grey[500])),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) => _buildBubble(messages[index]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('메시지를 불러올 수 없습니다.')),
            ),
          ),
          // 입력 바
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage message) {
    // 같은 팀 = 백엔드/클라이언트가 계산한 isMine (본인 + 같은 STAFF 팀원)
    final isMyTeam = message.isMine;
    // 진짜 본인 메시지인지 (팀원과 구분)
    final myUserId = ref.read(authProvider).user?.id;
    final isSelf = myUserId != null && message.senderId == myUserId;
    // 우측(우리 팀) 메시지 중 본인이 아니면 발신자 이름 표시 (A직원/B직원 구분)
    final showName = isMyTeam && !isSelf && message.senderName != null;
    // 상대방(좌측) 메시지에 이름 표시
    final showOtherName = !isMyTeam && message.senderName != null;
    // 송신 상태별 시각 효과
    final isSending = message.isSending;
    final isFailed = message.isFailed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: isMyTeam ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // 같은 팀 직원 이름 (우측 위에 작게)
          if (showName && message.senderName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2, right: 4),
              child: Text(message.senderName!,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ),
          // 상대방 이름 (좌측 위에)
          if (showOtherName)
            Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 4),
              child: Text(message.senderName!,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
            ),
          Row(
            mainAxisAlignment: isMyTeam ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isMyTeam) ...[
                Text(_formatTime(message.createdAt),
                    style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Opacity(
                  opacity: isSending ? 0.55 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isFailed
                          ? Colors.red.shade400
                          : (isMyTeam ? AppColors.primary : Colors.white),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMyTeam ? 16 : 4),
                        bottomRight: Radius.circular(isMyTeam ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: isMyTeam ? Colors.white : Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              if (isFailed && message.clientId != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    _notifier?.retrySend(message.clientId!);
                  },
                  child: Icon(Icons.refresh, size: 18, color: Colors.red.shade400),
                ),
              ],
              if (!isMyTeam) ...[
                const SizedBox(width: 6),
                Text(_formatTime(message.createdAt),
                    style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 8, top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: _isSending ? null : _sendMessage,
            icon: Icon(
              Icons.send_rounded,
              color: _isSending ? Colors.grey : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String dateTimeStr) {
    try {
      final dt = DateTime.parse(dateTimeStr);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
