import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/club_post.dart';
import '../../../data/services/club_service.dart';

/// 게시글 상세 화면
class ClubPostDetailScreen extends StatefulWidget {
  final int clubId;
  final int postId;

  const ClubPostDetailScreen({super.key, required this.clubId, required this.postId});

  @override
  State<ClubPostDetailScreen> createState() => _ClubPostDetailScreenState();
}

class _ClubPostDetailScreenState extends State<ClubPostDetailScreen> {
  final ClubService _clubService = ClubService();
  ClubPostDetail? _post;
  bool _isLoading = true;
  String? _error;

  // 댓글 관련 상태
  List<Map<String, dynamic>> _comments = [];
  final _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  // 답글 관련 상태
  int? _replyingTo;        // 답글 대상 댓글 ID
  String? _replyingToName; // 답글 대상 작성자 이름

  /// 루트 댓글 + 답글 전체 수
  int get _totalCommentCount {
    int count = _comments.length;
    for (final c in _comments) {
      final replies = c['replies'] as List?;
      if (replies != null) count += replies.length;
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final post = await _clubService.getPostDetail(widget.clubId, widget.postId);
      setState(() {
        _post = post;
        _isLoading = false;
      });
      _loadComments();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _clubService.getComments(widget.clubId, widget.postId);
      if (mounted) {
        setState(() => _comments = comments);
      }
    } catch (e) {
      debugPrint('댓글 로드 실패: $e');
    }
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmittingComment = true);
    try {
      final result = await _clubService.addComment(
        widget.clubId, widget.postId, content,
        parentId: _replyingTo,
      );
      if (result['success'] == true) {
        _commentController.clear();
        _cancelReply();
        _loadComments();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '댓글 작성 실패')),
        );
      }
    } catch (e) {
      debugPrint('[Error] 댓글 작성 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  void _startReply(int commentId, String authorName) {
    setState(() {
      _replyingTo = commentId;
      _replyingToName = authorName;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _replyingToName = null;
    });
  }

  Future<void> _deleteComment(int commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _clubService.deleteComment(widget.clubId, widget.postId, commentId);
      _loadComments();
    } catch (e) {
      debugPrint('[Error] 댓글 삭제 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    }
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text('이 게시글을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _clubService.deletePost(widget.clubId, widget.postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('게시글이 삭제되었습니다.')),
        );
        context.pop(true);
      }
    } catch (e) {
      debugPrint('[Error] 게시글 삭제 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    }
  }

  Future<void> _togglePin() async {
    try {
      final result = await _clubService.togglePin(widget.clubId, widget.postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '변경 완료')),
        );
        _loadPost();
      }
    } catch (e) {
      debugPrint('[Error] 고정 변경 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _formatCommentTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inHours < 1) return '${diff.inMinutes}분 전';
      if (diff.inDays < 1) return '${diff.inHours}시간 전';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('게시글'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (_post != null && (_post!.isAuthor || _post!.isOwner))
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit' && _post!.isAuthor) {
                  context.push(
                    '/clubs/${widget.clubId}/posts/create',
                    extra: _post,
                  ).then((result) {
                    if (result == true) _loadPost();
                  });
                }
                if (v == 'delete') _deletePost();
                if (v == 'pin' && _post!.isOwner) _togglePin();
              },
              itemBuilder: (_) => [
                if (_post!.isAuthor)
                  const PopupMenuItem(value: 'edit', child: Text('수정')),
                if (_post!.isOwner)
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(_post!.isPinned ? '고정 해제' : '고정'),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('삭제', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: AppColors.textSecondary)))
              : _buildContent(),
      // 하단 댓글 입력
      bottomNavigationBar: (!_isLoading && _error == null && _post != null)
          ? _buildCommentInput()
          : null,
    );
  }

  Widget _buildContent() {
    final post = _post!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 배지
          if (post.isNotice || post.isPinned)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  if (post.isNotice)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '공지',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error),
                      ),
                    ),
                  if (post.isPinned && !post.isNotice)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.clubPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '고정',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.clubPrimary),
                      ),
                    ),
                ],
              ),
            ),
          // 제목
          Text(
            post.title,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          // 작성자 정보
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.clubPrimary.withOpacity(0.1),
                child: Text(
                  post.authorName.isNotEmpty ? post.authorName[0] : '?',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.clubPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Text(post.authorName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(
                _formatDateTime(post.createdAt),
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 36),
              Icon(Icons.visibility_outlined, size: 13, color: AppColors.textTertiary),
              const SizedBox(width: 3),
              Text('${post.viewCount}', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          // 본문
          if (post.content != null && post.content!.isNotEmpty)
            Text(
              post.content!,
              style: TextStyle(fontSize: 15, height: 1.6, color: AppColors.textPrimary),
            )
          else
            Text(
              '내용 없음',
              style: TextStyle(fontSize: 15, color: AppColors.textTertiary, fontStyle: FontStyle.italic),
            ),

          // 댓글 섹션
          const SizedBox(height: 24),
          const Divider(thickness: 6, color: Color(0xFFF5F5F5)),
          const SizedBox(height: 16),
          Text(
            '댓글 ${_totalCommentCount}개',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('아직 댓글이 없습니다', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
              ),
            )
          else
            ..._comments.expand((comment) => [
              _buildCommentItem(comment, isReply: false),
              // 답글 목록 (들여쓰기)
              if (comment['replies'] != null)
                ...(comment['replies'] as List).map((reply) =>
                  _buildCommentItem(Map<String, dynamic>.from(reply), isReply: true),
                ),
            ]),
          // 하단 여백 (댓글 입력창 높이만큼)
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment, {bool isReply = false}) {
    final authorName = comment['authorName'] as String? ?? '알 수 없음';
    final content = comment['content'] as String? ?? '';
    final createdAt = comment['createdAt'] as String?;
    final canDelete = comment['canDelete'] == true;
    final commentId = comment['id'] as int? ?? 0;

    return Padding(
      padding: EdgeInsets.only(bottom: 12, left: isReply ? 40 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isReply)
            Padding(
              padding: const EdgeInsets.only(right: 6, top: 4),
              child: Icon(Icons.subdirectory_arrow_right, size: 14, color: AppColors.textTertiary),
            ),
          CircleAvatar(
            radius: isReply ? 12 : 14,
            backgroundColor: isReply ? AppColors.border.withOpacity(0.3) : AppColors.background,
            child: Text(
              authorName.isNotEmpty ? authorName[0] : '?',
              style: TextStyle(fontSize: isReply ? 10 : 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      authorName,
                      style: TextStyle(fontSize: isReply ? 12 : 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatCommentTime(createdAt),
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(fontSize: isReply ? 13 : 14, height: 1.4, color: AppColors.textPrimary),
                ),
                // 답글 버튼 (루트 댓글에만 표시)
                if (!isReply)
                  GestureDetector(
                    onTap: () => _startReply(commentId, authorName),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '답글',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (canDelete)
            GestureDetector(
              onTap: () => _deleteComment(commentId),
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Icon(Icons.close, size: 16, color: AppColors.textTertiary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 답글 모드 표시
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.reply, size: 14, color: AppColors.clubPrimary),
                  const SizedBox(width: 4),
                  Text(
                    '$_replyingToName님에게 답글',
                    style: TextStyle(fontSize: 12, color: AppColors.clubPrimary, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: Icon(Icons.close, size: 16, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: _replyingTo != null ? '답글을 입력하세요' : '댓글을 입력하세요',
                    hintStyle: TextStyle(fontSize: 14, color: AppColors.textHint),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: AppColors.clubPrimary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                  maxLines: 1,
                  maxLength: 500,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _addComment(),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _isSubmittingComment ? null : _addComment,
                icon: _isSubmittingComment
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send, color: AppColors.clubPrimary),
                iconSize: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
