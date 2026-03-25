import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/club_post.dart';
import '../../../data/services/club_service.dart';

/// 게시글 작성/수정 화면
class ClubPostCreateScreen extends StatefulWidget {
  final int clubId;
  final String? myRole;
  final ClubPostDetail? editPost; // null이면 작성, non-null이면 수정

  const ClubPostCreateScreen({
    super.key,
    required this.clubId,
    this.myRole,
    this.editPost,
  });

  @override
  State<ClubPostCreateScreen> createState() => _ClubPostCreateScreenState();
}

class _ClubPostCreateScreenState extends State<ClubPostCreateScreen> {
  final ClubService _clubService = ClubService();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isNotice = false;
  bool _isSubmitting = false;

  bool get _isEditing => widget.editPost != null;
  bool get _isOwner => widget.myRole == 'OWNER';

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.editPost!.title;
      _contentController.text = widget.editPost!.content ?? '';
      _isNotice = widget.editPost!.isNotice;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      Map<String, dynamic> result;
      if (_isEditing) {
        result = await _clubService.updatePost(
          widget.clubId,
          widget.editPost!.id,
          title: title,
          content: _contentController.text,
        );
      } else {
        result = await _clubService.createPost(
          widget.clubId,
          title: title,
          content: _contentController.text,
          isNotice: _isNotice,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '완료')),
        );
        context.pop(true);
      }
    } catch (e) {
      debugPrint('[Error] 게시글 저장 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? '게시글 수정' : '게시글 작성'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isEditing ? '수정' : '등록',
                    style: const TextStyle(
                      color: AppColors.clubPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // OWNER이고 새 글 작성 시: 공지 체크박스
            if (_isOwner && !_isEditing) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('공지사항으로 등록', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '게시판 상단에 고정됩니다',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                  value: _isNotice,
                  onChanged: (v) => setState(() => _isNotice = v ?? false),
                  activeColor: AppColors.clubPrimary,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              const SizedBox(height: 16),
            ],
            // 제목
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: '제목을 입력해주세요',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.clubPrimary),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
              maxLength: 200,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            // 내용
            TextField(
              controller: _contentController,
              decoration: InputDecoration(
                hintText: '내용을 입력해주세요',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.clubPrimary),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
              maxLines: 15,
              minLines: 8,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
