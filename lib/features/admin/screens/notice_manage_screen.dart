import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/api/api_client.dart';
import '../../../data/providers/support_provider.dart';
import '../../../data/services/support_service.dart';

/// 관리자용 공지사항 관리 화면
class NoticeManageScreen extends ConsumerStatefulWidget {
  const NoticeManageScreen({super.key});

  @override
  ConsumerState<NoticeManageScreen> createState() => _NoticeManageScreenState();
}

class _NoticeManageScreenState extends ConsumerState<NoticeManageScreen> {
  @override
  Widget build(BuildContext context) {
    final noticesAsync = ref.watch(noticesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('공지사항 관리'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNoticeEditor(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(noticesProvider);
          ref.invalidate(importantNoticesProvider);
        },
        color: AppColors.primary,
        child: noticesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, stack) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('공지사항을 불러올 수 없습니다',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.invalidate(noticesProvider),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
          data: (notices) {
            if (notices.isEmpty) {
              return Center(
                child: Text('공지사항이 없습니다',
                    style: TextStyle(color: AppColors.textSecondary)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notices.length,
              itemBuilder: (context, index) {
                return _buildNoticeCard(notices[index]);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoticeCard(Notice notice) {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: notice.isImportant
              ? AppColors.error.withOpacity(0.3)
              : AppColors.border,
        ),
      ),
      color: AppColors.surface,
      child: InkWell(
        onTap: () => _showNoticeEditor(context, notice: notice),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (notice.isImportant)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '중요',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            notice.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          dateFormat.format(notice.createdAt),
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textTertiary),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.visibility,
                            size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          '${notice.viewCount}',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _confirmDelete(notice),
                icon: Icon(Icons.delete_outline,
                    size: 20, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Notice notice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공지사항 삭제'),
        content: Text('"${notice.title}"을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteNotice(notice.id);
            },
            child:
                const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNotice(int id) async {
    try {
      final response =
          await ApiClient.instance.delete('/mobile/support/notices/$id');
      if (response.data['success'] == true) {
        ref.invalidate(noticesProvider);
        ref.invalidate(importantNoticesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('공지사항이 삭제되었습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('[Error] 삭제 실패: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    }
  }

  void _showNoticeEditor(BuildContext context, {Notice? notice}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _NoticeEditorPage(
          notice: notice,
          onSaved: () {
            ref.invalidate(noticesProvider);
            ref.invalidate(importantNoticesProvider);
          },
        ),
      ),
    );
  }
}

/// 공지사항 작성/수정 페이지
class _NoticeEditorPage extends StatefulWidget {
  final Notice? notice;
  final VoidCallback onSaved;

  const _NoticeEditorPage({this.notice, required this.onSaved});

  @override
  State<_NoticeEditorPage> createState() => _NoticeEditorPageState();
}

class _NoticeEditorPageState extends State<_NoticeEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late bool _isImportant;
  bool _isSaving = false;

  bool get _isEdit => widget.notice != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.notice?.title ?? '');
    _contentController =
        TextEditingController(text: widget.notice?.content ?? '');
    _isImportant = widget.notice?.isImportant ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? '공지 수정' : '공지 작성'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(
              _isEdit ? '수정' : '등록',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _isSaving ? AppColors.textTertiary : AppColors.accentLight,
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
            // 중요 공지 토글
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.border),
              ),
              color: AppColors.surface,
              child: SwitchListTile(
                title: const Text('중요 공지',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text('알림 화면 상단에 표시됩니다',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                value: _isImportant,
                onChanged: (v) => setState(() => _isImportant = v),
                activeColor: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),

            // 제목
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: '제목',
                hintText: '공지사항 제목을 입력하세요',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.surface,
              ),
              maxLength: 200,
            ),
            const SizedBox(height: 16),

            // 내용
            TextField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: '내용',
                hintText: '공지사항 내용을 입력하세요',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.surface,
                alignLabelWithHint: true,
              ),
              maxLines: 10,
              minLines: 5,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final data = {
        'title': title,
        'content': _contentController.text.trim(),
        'isImportant': _isImportant,
      };

      final response = _isEdit
          ? await ApiClient.instance
              .put('/mobile/support/notices/${widget.notice!.id}', data: data)
          : await ApiClient.instance.post('/mobile/support/notices', data: data);

      if (response.data['success'] == true) {
        widget.onSaved();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(_isEdit ? '공지사항이 수정되었습니다.' : '공지사항이 등록되었습니다.')),
          );
        }
      } else {
        throw Exception(response.data['message'] ?? '저장 실패');
      }
    } catch (e) {
      if (mounted) {
        debugPrint('[Error] 저장 실패: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
