import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/document_service.dart';
import '../../contest/widgets/document_upload_section.dart' show pickDocumentFile;

/// 내 참가신청 → 제출 서류.
/// 낸 서류를 보고, 빠진 서류를 올리고, 보완 요청을 받은 서류를 바꾼다.
/// 본인 확인은 로그인으로 한다(서버가 mobileUserId·휴대폰 번호로 본인 신청인지 확인).
class MyDocumentsScreen extends StatefulWidget {
  final int registrationId;
  final String contestName;
  final String categoryName;

  const MyDocumentsScreen({
    super.key,
    required this.registrationId,
    this.contestName = '',
    this.categoryName = '',
  });

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  final _service = DocumentService();
  MyDocuments? _data;
  String? _error;
  bool _loading = true;
  /// 올리는 중인 요구서류 id / 처리 중인 파일 id
  final Set<int> _busyReq = {};
  final Set<int> _busyFile = {};
  /// 화면에서 무언가 바뀌었는지 — 돌아갈 때 목록을 새로 고치게 알린다.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _service.myList(widget.registrationId);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.error : null),
    );
  }

  Future<void> _upload(MyDocumentItem item) async {
    final picked = await pickDocumentFile(context);
    if (picked == null) return;
    setState(() => _busyReq.add(item.requirement.id));
    try {
      await _service.myUpload(
        registrationId: widget.registrationId,
        requirementId: item.requirement.id,
        fileName: picked.name,
        path: picked.path,
        bytes: picked.bytes,
      );
      _changed = true;
      _snack('올렸습니다. 주최측 확인을 기다려 주세요.');
      await _load();
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busyReq.remove(item.requirement.id));
    }
  }

  Future<void> _remove(MyDocumentFile f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('파일 지우기'),
        content: Text('${f.name}\n이 파일을 지울까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('지우기', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busyFile.add(f.id));
    try {
      await _service.myRemove(registrationId: widget.registrationId, fileId: f.id);
      _changed = true;
      await _load();
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busyFile.remove(f.id));
    }
  }

  /// 사진은 바로 보여주고, PDF는 공유 시트로 넘겨 다른 앱에서 열거나 저장하게 한다.
  Future<void> _open(MyDocumentFile f) async {
    setState(() => _busyFile.add(f.id));
    try {
      final bytes = await _service.myDownload(registrationId: widget.registrationId, fileId: f.id);
      if (!mounted) return;
      if (f.isImage) {
        await showDialog(
          context: context,
          builder: (ctx) => Dialog(
            insetPadding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain))),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
              ],
            ),
          ),
        );
      } else {
        await Share.shareXFiles(
          [XFile.fromData(bytes, name: f.name, mimeType: f.contentType ?? 'application/pdf')],
          fileNameOverrides: [f.name],
        );
      }
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busyFile.remove(f.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('제출 서류'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }
    final d = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (widget.contestName.isNotEmpty)
            Text(widget.contestName,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          if (widget.categoryName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(widget.categoryName, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              !d.editable
                  ? '취소·반려된 신청이라 서류를 올리거나 지울 수 없습니다.'
                  : d.pastDeadline
                      ? '접수 마감일이 지나 서류를 바꿀 수 없습니다. 주최측이 보완을 요청한 서류만 다시 올릴 수 있습니다.'
                      : 'PDF·JPG·PNG, 파일 하나 10MB 이하. 접수 마감일까지 바꿀 수 있고, 주최측이 확인을 마친 서류는 바꿀 수 없습니다.',
              style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 14),
          if (d.items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text('이 신청에는 제출할 서류가 없습니다.', style: TextStyle(color: AppColors.textTertiary)),
              ),
            ),
          for (final item in d.items) ...[
            _buildItem(item, d.editable),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(MyDocumentItem item, bool editable) {
    final r = item.requirement;
    // 서버 판정 우선(취소·확인 완료·접수 마감 후 잠금). 구버전 서버면 예전 기준.
    final canChange = item.locked != null ? !item.locked! : (editable && !item.confirmed);
    final canAdd = canChange && item.files.length < r.maxFiles;
    final busy = _busyReq.contains(r.id);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.reviewStatus == 'NEEDS_FIX' || item.reviewStatus == 'REJECTED'
              ? AppColors.warning
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                    text: r.title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  TextSpan(
                    text: r.required ? '  필수' : '  선택',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: r.required ? AppColors.error : AppColors.textTertiary,
                    ),
                  ),
                ])),
              ),
              _statusChip(item),
            ],
          ),
          if (r.description != null) ...[
            const SizedBox(height: 4),
            Text(r.description!, style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textSecondary)),
          ],
          if (item.reviewMemo != null && item.reviewMemo!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusSoonBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '주최측 안내: ${item.reviewMemo}',
                style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.statusSoonText),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (item.files.isEmpty)
            Text('아직 올린 파일이 없습니다.', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
          for (final f in item.files)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(f.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      onTap: _busyFile.contains(f.id) ? null : () => _open(f),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (f.uploadedByType == 'ADMIN')
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text('주최측 등록', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                    ),
                  const SizedBox(width: 4),
                  Text(DocumentService.formatSize(f.size),
                      style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
                  if (_busyFile.contains(f.id))
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (canChange)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '지우기',
                      icon: Icon(Icons.delete_outline, size: 19, color: AppColors.textTertiary),
                      onPressed: () => _remove(f),
                    ),
                ],
              ),
            ),
          if (canAdd) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => _upload(item),
                icon: busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file, size: 18),
                label: Text(busy ? '올리는 중…' : (item.files.isEmpty ? '파일 올리기' : '파일 더 올리기')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ] else if (canChange && item.files.length >= r.maxFiles) ...[
            const SizedBox(height: 6),
            Text('최대 ${r.maxFiles}개까지 올릴 수 있습니다. 바꾸려면 기존 파일을 지운 뒤 올려 주세요.',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(MyDocumentItem item) {
    String label;
    Color bg;
    Color fg;
    switch (item.reviewStatus) {
      case 'CONFIRMED':
        label = '확인 완료';
        bg = AppColors.statusOpenBg;
        fg = AppColors.statusOpenText;
        break;
      case 'NEEDS_FIX':
        label = '보완 요청';
        bg = AppColors.statusSoonBg;
        fg = AppColors.statusSoonText;
        break;
      case 'REJECTED':
        label = '반려';
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
      default:
        if (item.files.isEmpty) {
          label = '미제출';
          bg = AppColors.statusClosedBg;
          fg = AppColors.statusClosedText;
        } else {
          label = '확인 대기';
          bg = AppColors.statusLiveBg;
          fg = AppColors.statusLiveText;
        }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
