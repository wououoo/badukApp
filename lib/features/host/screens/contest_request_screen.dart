import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/api_client.dart';
import '../../../data/providers/contest_request_provider.dart';
import '../../../data/models/create_contest_model.dart';
import 'admin_requests_screen.dart';

/// 대회 개최 의뢰 화면 (단일 폼)
/// requestId가 있으면 수정 모드, 없으면 생성 모드
class ContestRequestScreen extends ConsumerStatefulWidget {
  final int? requestId;  // null이면 생성, 있으면 수정
  final bool isAdmin;    // 관리자 모드

  const ContestRequestScreen({super.key, this.requestId, this.isAdmin = false});

  bool get isEditMode => requestId != null;

  @override
  ConsumerState<ContestRequestScreen> createState() => _ContestRequestScreenState();
}

class _ContestRequestScreenState extends ConsumerState<ContestRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _scheduleController = TextEditingController();
  final _organizerController = TextEditingController();
  final _venueController = TextEditingController();
  final _feeController = TextEditingController();
  final _contactController = TextEditingController();
  final _notesController = TextEditingController();

  final List<PlatformFile> _attachedFiles = [];
  final List<ContestCategoryInput> _categories = [];

  // 수정 모드에서 기존 첨부파일 목록
  final List<Map<String, String>> _existingAttachments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode) {
      _loadExistingData();
    }
  }

  Future<void> _loadExistingData() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ApiClient.instance;
      // 상세 조회 API는 공용 (관리자도 접근 가능)
      final response = await apiClient.get('/mobile/host/contest-requests/${widget.requestId}');
      final data = response.data as Map<String, dynamic>;

      _titleController.text = data['title'] ?? '';
      _scheduleController.text = data['schedule'] ?? '';
      _organizerController.text = data['organizer'] ?? '';
      _venueController.text = data['venue'] ?? '';
      _feeController.text = data['participationFee'] ?? '';
      _contactController.text = data['contactInfo'] ?? '';
      _notesController.text = data['additionalNotes'] ?? '';

      // 부문 로드
      final categories = data['categories'] as List? ?? [];
      for (final cat in categories) {
        _categories.add(ContestCategoryInput(
          categoryName: cat['categoryName'] ?? '',
          contestType: cat['contestType'] ?? 'MCM',
        ));
      }

      // 기존 첨부파일 로드
      final attachments = data['attachments'] as List? ?? [];
      for (final att in attachments) {
        final path = att['path'] as String? ?? '';
        final filename = path.split('/').last.split('\\').last;
        _existingAttachments.add({
          'originalFilename': att['originalFilename'] ?? '',
          'filename': filename,
        });
      }

      setState(() {});
    } catch (e) {
      if (mounted) {
        debugPrint('[Error] 데이터 로드 실패: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('데이터 로드에 실패했습니다. 다시 시도해주세요.'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _scheduleController.dispose();
    _organizerController.dispose();
    _venueController.dispose();
    _feeController.dispose();
    _contactController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contestRequestProvider);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(widget.isEditMode ? '의뢰 수정' : '대회 개최 의뢰'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEditMode ? '의뢰 수정' : '대회 개최 의뢰'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 안내
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '입력하신 정보로 대회 홈페이지를 제작해 드립니다.',
                              style: TextStyle(color: AppColors.primary, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 대회명 (필수)
                    _buildTextField(
                      controller: _titleController,
                      label: '대회명 *',
                      hint: '예: 제1회 OO배 바둑대회',
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),

                    // 대회 일시 (필수)
                    _buildTextField(
                      controller: _scheduleController,
                      label: '대회 일시 *',
                      hint: '예: 2026년 3월 15일(토) 09:00~18:00',
                      isRequired: true,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // 주최
                    _buildTextField(
                      controller: _organizerController,
                      label: '주최·주관',
                      hint: '예: OO바둑협회',
                    ),
                    const SizedBox(height: 16),

                    // 장소
                    _buildTextField(
                      controller: _venueController,
                      label: '대회 장소',
                      hint: '예: 서울시 강남구 OO회관',
                    ),
                    const SizedBox(height: 16),

                    // 참가비
                    _buildTextField(
                      controller: _feeController,
                      label: '참가비 안내',
                      hint: '예: 유단자부 3만원, 급수부 2만원',
                    ),
                    const SizedBox(height: 16),

                    // 문의처
                    _buildTextField(
                      controller: _contactController,
                      label: '문의처',
                      hint: '예: 010-1234-5678',
                    ),
                    const SizedBox(height: 24),

                    // 부문 설정
                    _buildSectionTitle('부문 설정'),
                    const SizedBox(height: 8),
                    Text(
                      '대회 부문을 미리 설정할 수 있습니다 (선택)',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ..._categories.asMap().entries.map((entry) {
                      return _buildCategoryChip(entry.value, entry.key);
                    }),
                    OutlinedButton.icon(
                      onPressed: _showAddCategoryDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('부문 추가'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 첨부파일
                    _buildSectionTitle('첨부파일'),
                    const SizedBox(height: 8),
                    Text(
                      '대회 규정, 포스터 등 (hwp, pdf, jpg, png)',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    // 기존 첨부파일 (수정 모드)
                    ..._existingAttachments.map((file) => _buildExistingFileChip(file)),
                    // 새로 추가한 첨부파일
                    ..._attachedFiles.map((file) => _buildFileChip(file)),
                    OutlinedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: const Text('파일 첨부'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 추가 요청사항
                    _buildTextField(
                      controller: _notesController,
                      label: '추가 요청사항',
                      hint: '홈페이지 제작 시 참고할 사항을 적어주세요',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
          // 하단 버튼
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: state.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          widget.isEditMode ? '수정하기' : '의뢰하기',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: isRequired
              ? (v) => v?.trim().isEmpty == true ? '필수 입력 항목입니다' : null
              : null,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(ContestCategoryInput category, int index) {
    final type = ContestTypeEnum.fromCode(category.contestType);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.categoryName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  type.label,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
            onPressed: () {
              setState(() => _categories.removeAt(index));
            },
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildFileChip(PlatformFile file) {
    IconData icon = Icons.insert_drive_file;
    if (file.name.endsWith('.hwp') || file.name.endsWith('.hwpx')) {
      icon = Icons.description;
    } else if (file.name.endsWith('.pdf')) {
      icon = Icons.picture_as_pdf;
    } else if (file.name.endsWith('.jpg') || file.name.endsWith('.png') || file.name.endsWith('.jpeg')) {
      icon = Icons.image;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              file.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
            onPressed: () {
              setState(() => _attachedFiles.remove(file));
            },
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // 기존 첨부파일 chip (수정 모드)
  Widget _buildExistingFileChip(Map<String, String> file) {
    final originalFilename = file['originalFilename'] ?? '';
    IconData icon = Icons.insert_drive_file;
    if (originalFilename.endsWith('.hwp') || originalFilename.endsWith('.hwpx')) {
      icon = Icons.description;
    } else if (originalFilename.endsWith('.pdf')) {
      icon = Icons.picture_as_pdf;
    } else if (originalFilename.endsWith('.jpg') || originalFilename.endsWith('.png') || originalFilename.endsWith('.jpeg')) {
      icon = Icons.image;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              originalFilename,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: AppColors.error),
            onPressed: () => _deleteExistingFile(file),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExistingFile(Map<String, String> file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('파일 삭제'),
        content: Text('${file['originalFilename']}을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final apiClient = ApiClient.instance;
      await apiClient.delete('/mobile/host/contest-requests/${widget.requestId}/files/${file['filename']}');
      setState(() => _existingAttachments.remove(file));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일이 삭제되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        debugPrint('[Error] 삭제 실패: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제에 실패했습니다. 다시 시도해주세요.'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['hwp', 'hwpx', 'pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _attachedFiles.addAll(result.files);
      });
    }
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    String contestType = 'MCM';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '부문 추가',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: '부문명',
                    hintText: '예: 유단자부, 1~3급부',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('대회 유형', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ContestTypeEnum.values.map((type) {
                    final isSelected = contestType == type.code;
                    return ChoiceChip(
                      label: Text(type.label),
                      selected: isSelected,
                      onSelected: (_) {
                        setModalState(() => contestType = type.code);
                      },
                      selectedColor: AppColors.primary.withOpacity(0.2),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameController.text.trim().isNotEmpty) {
                        setState(() {
                          _categories.add(ContestCategoryInput(
                            categoryName: nameController.text.trim(),
                            contestType: contestType,
                          ));
                        });
                        Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('추가'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.isEditMode) {
      // 수정 모드
      await _updateRequest();
    } else {
      // 생성 모드
      await _createRequest();
    }
  }

  Future<void> _createRequest() async {
    final notifier = ref.read(contestRequestProvider.notifier);
    notifier.setLoading(true);

    try {
      final apiClient = ApiClient.instance;

      // 1. 의뢰 생성
      final response = await apiClient.post(
        '/mobile/host/contest-requests',
        data: {
          'title': _titleController.text.trim(),
          'schedule': _scheduleController.text.trim(),
          'organizer': _organizerController.text.trim(),
          'venue': _venueController.text.trim(),
          'participationFee': _feeController.text.trim(),
          'contactInfo': _contactController.text.trim(),
          'additionalNotes': _notesController.text.trim(),
          'categories': _categories.map((c) => {
            'categoryName': c.categoryName,
            'contestType': c.contestType,
          }).toList(),
        },
      );

      final requestId = response.data['requestId'] as int;

      // 2. 첨부파일 업로드
      for (final file in _attachedFiles) {
        if (kIsWeb) {
          // 웹에서는 bytes 사용
          if (file.bytes != null) {
            await notifier.uploadFileBytes(requestId, file.name, file.bytes!);
          }
        } else {
          // 모바일에서는 path 사용
          if (file.path != null) {
            await notifier.uploadFile(requestId, file.path!);
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('대회 개최 의뢰가 접수되었습니다!'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.invalidate(myContestRequestsProvider);
        notifier.reset();
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        debugPrint('[Error] 의뢰 실패: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('의뢰에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      notifier.setLoading(false);
    }
  }

  Future<void> _updateRequest() async {
    final notifier = ref.read(contestRequestProvider.notifier);
    notifier.setLoading(true);

    try {
      final apiClient = ApiClient.instance;

      // 관리자용과 일반용 API 경로 구분
      final path = widget.isAdmin
          ? '/mobile/host/admin/contest-requests/${widget.requestId}'
          : '/mobile/host/contest-requests/${widget.requestId}';

      // 의뢰 수정
      await apiClient.put(
        path,
        data: {
          'title': _titleController.text.trim(),
          'schedule': _scheduleController.text.trim(),
          'organizer': _organizerController.text.trim(),
          'venue': _venueController.text.trim(),
          'participationFee': _feeController.text.trim(),
          'contactInfo': _contactController.text.trim(),
          'additionalNotes': _notesController.text.trim(),
          'categories': _categories.map((c) => {
            'categoryName': c.categoryName,
            'contestType': c.contestType,
          }).toList(),
        },
      );

      // 새 첨부파일 업로드
      for (final file in _attachedFiles) {
        if (kIsWeb) {
          // 웹에서는 bytes 사용
          if (file.bytes != null) {
            await notifier.uploadFileBytes(widget.requestId!, file.name, file.bytes!);
          }
        } else {
          // 모바일에서는 path 사용
          if (file.path != null) {
            await notifier.uploadFile(widget.requestId!, file.path!);
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('의뢰가 수정되었습니다!'),
            backgroundColor: AppColors.success,
          ),
        );
        if (widget.isAdmin) {
          ref.invalidate(adminContestRequestsProvider(null));
        } else {
          ref.invalidate(myContestRequestsProvider);
        }
        notifier.reset();
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        debugPrint('[Error] 수정 실패: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('수정에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      notifier.setLoading(false);
    }
  }
}
