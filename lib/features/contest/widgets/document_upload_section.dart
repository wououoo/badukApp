import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/document_service.dart';

/// 고른 파일 하나 (경로 또는 바이트)
class PickedDocFile {
  final String name;
  final int size;
  final String? path;
  final Uint8List? bytes;
  PickedDocFile({required this.name, required this.size, this.path, this.bytes});
}

/// 파일 고르기 — 파일(PDF·사진) / 사진 앨범 / 카메라 중 선택.
/// 종이 서류를 바로 찍어 올리는 경우가 많아 카메라를 함께 둔다.
/// 형식·크기가 맞지 않으면 안내만 띄우고 null.
Future<PickedDocFile?> pickDocumentFile(BuildContext context) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('파일에서 선택 (PDF·사진)'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            if (!kIsWeb) ...[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('사진 앨범에서 선택'),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('카메라로 찍기'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  if (source == null) return null;

  PickedDocFile? picked;
  try {
    if (source == 'file') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: DocumentService.allowedExtensions,
        allowMultiple: false,
        withData: kIsWeb, // 웹은 경로가 없어 바이트로 받는다
      );
      if (result == null || result.files.isEmpty) return null;
      final f = result.files.first;
      picked = PickedDocFile(
        name: f.name,
        size: f.size,
        path: kIsWeb ? null : f.path,
        bytes: kIsWeb ? f.bytes : null,
      );
    } else {
      // imageQuality를 주면 iOS의 HEIC 사진도 JPEG로 바꿔 준다(서버는 JPG·PNG·PDF만 받음).
      final x = await ImagePicker().pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2400,
        maxHeight: 2400,
      );
      if (x == null) return null;
      final bytes = await x.readAsBytes();
      var name = x.name;
      final lower = name.toLowerCase();
      if (!(lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png'))) {
        name = '${name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name}.jpg';
      }
      picked = PickedDocFile(name: name, size: bytes.length, bytes: bytes);
    }
  } catch (e) {
    debugPrint('[서류 선택 실패] $e');
    if (context.mounted) _snack(context, '파일을 가져오지 못했습니다. 권한을 확인해 주세요.');
    return null;
  }

  final err = DocumentService.checkLocalFile(picked.name, picked.size);
  if (err != null) {
    if (context.mounted) _snack(context, err);
    return null;
  }
  return picked;
}

void _snack(BuildContext context, String msg, {bool error = true}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: error ? AppColors.error : null),
  );
}

/// 신청 중 올린 서류 상태. 걸음을 오가도 남아 있어야 하므로 신청 화면이 들고 있는다.
class DocumentStagingState {
  /// 요구서류 id → 올린 파일들
  final Map<int, List<StagedDocument>> staged = {};
  /// 지금 올리는 중인 요구서류 id
  final Set<int> uploading = {};

  bool get isUploading => uploading.isNotEmpty;

  /// 서버에 보낼 {요구서류id: [토큰...]} — 지금 부문에 해당하는 항목만
  Map<String, List<String>> tokensFor(List<DocumentRequirement> reqs) {
    final out = <String, List<String>>{};
    for (final r in reqs) {
      final list = staged[r.id];
      if (list == null || list.isEmpty) continue;
      out[r.id.toString()] = list.map((e) => e.token).toList();
    }
    return out;
  }

  /// 빠진 필수 서류 첫 번째 (없으면 null)
  DocumentRequirement? firstMissingRequired(List<DocumentRequirement> reqs) {
    for (final r in reqs) {
      if (r.required && (staged[r.id] == null || staged[r.id]!.isEmpty)) return r;
    }
    return null;
  }
}

/// 신청 화면 '제출 서류' 칸 — 고르는 즉시 서버에 임시로 올려 두고, 신청 제출 때 토큰으로 연결한다.
class DocumentUploadSection extends StatelessWidget {
  final int homepageId;
  final List<DocumentRequirement> requirements;
  final DocumentStagingState state;
  final VoidCallback onChanged;

  const DocumentUploadSection({
    super.key,
    required this.homepageId,
    required this.requirements,
    required this.state,
    required this.onChanged,
  });

  Future<void> _add(BuildContext context, DocumentRequirement r) async {
    final picked = await pickDocumentFile(context);
    if (picked == null) return;
    state.uploading.add(r.id);
    onChanged();
    try {
      final staged = await DocumentService().stage(
        homepageId: homepageId,
        requirementId: r.id,
        fileName: picked.name,
        path: picked.path,
        bytes: picked.bytes,
      );
      state.staged.putIfAbsent(r.id, () => []).add(staged);
    } catch (e) {
      if (context.mounted) _snack(context, e.toString());
    } finally {
      state.uploading.remove(r.id);
      onChanged();
    }
  }

  void _remove(DocumentRequirement r, int index) {
    final list = state.staged[r.id];
    if (list == null || index >= list.length) return;
    // 서버의 임시 파일은 신청에 연결되지 않으면 48시간 뒤 자동 삭제된다.
    list.removeAt(index);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'PDF·JPG·PNG, 파일 하나 10MB 이하. 종이 서류는 카메라로 찍어 올려도 됩니다.\n'
            '신청한 뒤에도 \'내 참가신청\'에서 추가·교체할 수 있습니다.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 14),
        for (final r in requirements) ...[
          _RequirementCard(
            requirement: r,
            files: state.staged[r.id] ?? const [],
            uploading: state.uploading.contains(r.id),
            onAdd: () => _add(context, r),
            onRemove: (i) => _remove(r, i),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _RequirementCard extends StatelessWidget {
  final DocumentRequirement requirement;
  final List<StagedDocument> files;
  final bool uploading;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const _RequirementCard({
    required this.requirement,
    required this.files,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final r = requirement;
    final full = files.length >= r.maxFiles;
    final missing = r.required && files.isEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: missing ? AppColors.primary.withValues(alpha: 0.45) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
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
                  ]),
                ),
              ),
              if (r.maxFiles > 1)
                Text('${files.length}/${r.maxFiles}', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
          if (r.description != null) ...[
            const SizedBox(height: 4),
            Text(r.description!, style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 10),
          for (var i = 0; i < files.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 18, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      files[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                  Text(DocumentService.formatSize(files[i].size),
                      style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '빼기',
                    icon: Icon(Icons.close, size: 18, color: AppColors.textTertiary),
                    onPressed: uploading ? null : () => onRemove(i),
                  ),
                ],
              ),
            ),
          if (!full)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: uploading ? null : onAdd,
                icon: uploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file, size: 18),
                label: Text(uploading ? '올리는 중…' : (files.isEmpty ? '파일 올리기' : '파일 더 올리기')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
