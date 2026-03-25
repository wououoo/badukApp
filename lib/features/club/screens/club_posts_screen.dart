import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/club_post.dart';
import '../../../data/services/club_service.dart';

/// 클럽 게시판 전체 목록 화면
class ClubPostsScreen extends StatefulWidget {
  final int clubId;
  final String? myRole;

  const ClubPostsScreen({super.key, required this.clubId, this.myRole});

  @override
  State<ClubPostsScreen> createState() => _ClubPostsScreenState();
}

class _ClubPostsScreenState extends State<ClubPostsScreen> {
  final ClubService _clubService = ClubService();
  List<ClubPostSummary> _pinnedPosts = [];
  List<ClubPostSummary> _generalPosts = [];
  bool _isLoading = true;
  bool _hasNext = false;
  int _currentPage = 0;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts({bool loadMore = false}) async {
    if (loadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final page = loadMore ? _currentPage + 1 : 0;
      final result = await _clubService.getClubPosts(widget.clubId, page: page);

      setState(() {
        if (loadMore) {
          _generalPosts.addAll(result['generalPosts'] as List<ClubPostSummary>);
          _isLoadingMore = false;
        } else {
          _pinnedPosts = result['pinnedPosts'] as List<ClubPostSummary>;
          _generalPosts = result['generalPosts'] as List<ClubPostSummary>;
          _isLoading = false;
        }
        _hasNext = result['hasNext'] as bool;
        _currentPage = result['currentPage'] as int;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  String _formatDate(String? dateStr) {
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadPosts, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    if (_pinnedPosts.isEmpty && _generalPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text('아직 게시글이 없습니다', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      color: AppColors.clubPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: (widget.myRole == null ? 1 : 0) + _pinnedPosts.length + _generalPosts.length + (_hasNext ? 1 : 0),
        itemBuilder: (context, index) {
          // Non-member join guidance banner
          if (widget.myRole == null) {
            if (index == 0) {
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.clubBgTint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.clubPrimary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: AppColors.clubPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '글을 쓰려면 클럽에 가입하세요',
                        style: TextStyle(fontSize: 13, color: AppColors.clubPrimary, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              );
            }
            index -= 1;
          }
          if (index < _pinnedPosts.length) {
            return _buildPostTile(_pinnedPosts[index], isPinned: true);
          }
          final generalIndex = index - _pinnedPosts.length;
          if (generalIndex < _generalPosts.length) {
            return _buildPostTile(_generalPosts[generalIndex]);
          }
          // 더보기 버튼
          if (!_isLoadingMore) {
            _loadPosts(loadMore: true);
          }
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
      ),
    );
  }

  Widget _buildPostTile(ClubPostSummary post, {bool isPinned = false}) {
    return InkWell(
      onTap: () async {
        final result = await context.push('/clubs/${widget.clubId}/posts/${post.id}');
        if (result == true) _loadPosts();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (post.isNotice || isPinned) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: post.isNotice
                                ? AppColors.error.withOpacity(0.1)
                                : AppColors.clubPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            post.isNotice ? '공지' : '고정',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: post.isNotice ? AppColors.error : AppColors.clubPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          post.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: (post.isNotice || isPinned) ? FontWeight.w600 : FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        post.authorName,
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(post.createdAt),
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.visibility_outlined, size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 2),
                      Text(
                        '${post.viewCount}',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chat_bubble_outline, size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 2),
                      Text(
                        '${post.commentCount}',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
