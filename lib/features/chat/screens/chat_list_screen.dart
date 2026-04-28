import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/chat_room.dart';
import '../../../data/providers/chat_provider.dart';
import '../../../data/providers/auth_provider.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  void _loadRooms() {
    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      ref.read(chatRoomListProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final roomsAsync = ref.watch(chatRoomListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('문의', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: !authState.isAuthenticated
          ? _buildLoginRequired()
          : roomsAsync.when(
              data: (rooms) => rooms.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: () => ref.read(chatRoomListProvider.notifier).refresh(),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: rooms.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200], indent: 76),
                        itemBuilder: (context, index) => _buildRoomTile(rooms[index]),
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('채팅 목록을 불러올 수 없습니다.'),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _loadRooms, child: const Text('다시 시도')),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('로그인이 필요합니다', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('대회 주최자에게 문의하려면\n로그인해 주세요.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/login'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('로그인', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('아직 문의 내역이 없습니다', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('대회 상세 페이지에서\n주최자에게 문의할 수 있습니다.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomTile(ChatRoom room) {
    return InkWell(
      onTap: () async {
        await context.push('/chat/${room.roomId}', extra: {
          'contestTitle': room.contestTitle ?? room.displayName,
          'myRole': room.myRole,
        });
        // 돌아오면 목록 갱신
        ref.read(chatRoomListProvider.notifier).refresh();
        ref.read(chatUnreadCountProvider.notifier).fetch();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 아이콘
            CircleAvatar(
              radius: 24,
              backgroundColor: room.isStaff
                  ? Colors.blue.withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.1),
              child: Icon(
                room.isStaff ? Icons.person : Icons.support_agent,
                color: room.isStaff ? Colors.blue : AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // 이름, 메시지 미리보기
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.displayName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (room.lastMessageAt != null)
                        Text(
                          _formatTime(room.lastMessageAt!),
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (room.contestTitle != null)
                    Text(
                      room.contestTitle!,
                      style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (room.lastMessagePreview != null)
                    Text(
                      room.lastMessagePreview!,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // 안읽은 수 뱃지
            if (room.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String dateTimeStr) {
    try {
      final dt = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return '방금';
      if (diff.inHours < 1) return '${diff.inMinutes}분 전';
      if (diff.inDays < 1) return '${diff.inHours}시간 전';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }
}
