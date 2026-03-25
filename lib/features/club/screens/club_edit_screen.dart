import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/club_service.dart';

/// 클럽 정보 수정 화면
class ClubEditScreen extends StatefulWidget {
  final int clubId;

  const ClubEditScreen({super.key, required this.clubId});

  @override
  State<ClubEditScreen> createState() => _ClubEditScreenState();
}

class _ClubEditScreenState extends State<ClubEditScreen> {
  final ClubService _clubService = ClubService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();

  static const _regions = [
    '서울특별시', '부산광역시', '대구광역시', '인천광역시', '광주광역시',
    '대전광역시', '울산광역시', '세종특별자치시',
    '경기도', '강원특별자치도', '충청북도', '충청남도',
    '전북특별자치도', '전라남도', '경상북도', '경상남도', '제주특별자치도',
  ];

  String? _selectedRegion;
  String? _photoUrl;
  bool _isUploadingPhoto = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClubInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadClubInfo() async {
    try {
      final club = await _clubService.getClubDetail(widget.clubId);
      setState(() {
        _nameController.text = club.name;
        _descriptionController.text = club.description ?? '';
        _selectedRegion = club.region;
        _cityController.text = club.city ?? '';
        _photoUrl = club.photoUrl;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveClub() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await _clubService.updateClub(
        widget.clubId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        region: _selectedRegion,
        city: _cityController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('클럽 정보가 수정되었습니다.')),
        );
        context.pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '수정에 실패했습니다.')),
        );
      }
    } catch (e) {
      debugPrint('[Error] 클럽 수정 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildPhotoSection() {
    final serverRoot = ApiConstants.baseUrl.replaceAll('/api', '');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '클럽 사진',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 14),
          Center(
            child: GestureDetector(
              onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: _isUploadingPhoto
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                        : _photoUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.network(
                                  '$serverRoot$_photoUrl',
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(Icons.groups, size: 40, color: AppColors.textHint),
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt_outlined, size: 32, color: AppColors.textHint),
                                  SizedBox(height: 4),
                                  Text('사진 추가', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                                ],
                              ),
                  ),
                  if (_photoUrl != null && !_isUploadingPhoto)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: GestureDetector(
                        onTap: _deletePhoto,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final result = await _clubService.uploadClubPhoto(widget.clubId, picked.path);
      debugPrint('[ClubEdit] uploadClubPhoto result: $result (type: ${result.runtimeType})');
      if (mounted) {
        if (result['success'] == true) {
          final url = result['photoUrl']?.toString();
          debugPrint('[ClubEdit] photoUrl: $url');
          setState(() => _photoUrl = url);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message']?.toString() ?? '업로드 실패')),
          );
        }
      }
    } catch (e, st) {
      debugPrint('[ClubEdit] 사진 업로드 오류: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진 업로드에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _deletePhoto() async {
    setState(() => _isUploadingPhoto = true);
    try {
      final result = await _clubService.deleteClubPhoto(widget.clubId);
      if (mounted && result['success'] == true) {
        setState(() => _photoUrl = null);
      }
    } catch (e) {
      debugPrint('[Error] 사진 삭제 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진 삭제에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('클럽 정보 수정'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _loadClubInfo, child: const Text('다시 시도')),
                    ],
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildPhotoSection(),
                      const SizedBox(height: 20),
                      _buildSection(
                        title: '기본 정보',
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: '클럽 이름',
                            hint: '예: 서울바둑클럽',
                            required: true,
                            maxLength: 100,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return '클럽 이름을 입력해주세요';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _descriptionController,
                            label: '소개',
                            hint: '클럽을 소개해주세요 (선택)',
                            maxLines: 3,
                            maxLength: 500,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSection(
                        title: '지역 정보',
                        children: [
                          _buildDropdownField(
                            label: '지역',
                            value: _selectedRegion,
                            items: _regions,
                            onChanged: (v) => setState(() => _selectedRegion = v),
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _cityController,
                            label: '시/구',
                            hint: '예: 강남구 (선택)',
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _saveClub,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.clubPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.clubPrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: onChanged,
    );
  }
}
