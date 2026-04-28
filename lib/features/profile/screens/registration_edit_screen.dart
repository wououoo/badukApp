import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/api_client.dart';
import 'my_registrations_screen.dart';

/// 참가신청 수정 화면 (부문, 지역, 소속 수정 가능)
class RegistrationEditScreen extends ConsumerStatefulWidget {
  final int registrationId;
  final Map<String, dynamic>? currentData;

  const RegistrationEditScreen({
    super.key,
    required this.registrationId,
    this.currentData,
  });

  @override
  ConsumerState<RegistrationEditScreen> createState() => _RegistrationEditScreenState();
}

class _RegistrationEditScreenState extends ConsumerState<RegistrationEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _clubController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  String? _selectedRegion;
  String? _selectedRank;
  int? _selectedCategoryId;
  bool _isLoading = false;

  // 부문 목록 (API에서 로드)
  List<Map<String, dynamic>> _categories = [];
  bool _categoriesLoading = true;

  /// 결제 완료 여부
  bool get _isPaid => widget.currentData?['paymentStatus'] == 'COMPLETED';

  // 기력 목록 (신청 폼의 GAME_LEVEL_OPTIONS와 동일하게 30급부터)
  static const List<String> _ranks = [
    '30급', '29급', '28급', '27급', '26급', '25급', '24급', '23급', '22급', '21급',
    '20급', '19급', '18급', '17급', '16급', '15급', '14급', '13급', '12급', '11급',
    '10급', '9급', '8급', '7급', '6급', '5급', '4급', '3급', '2급', '1급',
    '1단', '2단', '3단', '4단', '5단', '6단', '7단', '8단', '9단',
  ];

  // 지역 목록 (RegionData.js와 동일)
  static const List<String> _regions = [
    '서울특별시', '부산광역시', '대구광역시', '인천광역시',
    '광주광역시', '대전광역시', '울산광역시', '세종특별자치시',
    '경기도', '강원특별자치도', '충청북도', '충청남도',
    '전북특별자치도', '전라남도', '경상북도', '경상남도', '제주특별자치도',
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.currentData;
    _clubController = TextEditingController(text: data?['club'] ?? '');
    _nameController = TextEditingController(text: data?['participantName'] ?? '');
    // 백엔드 응답 필드명에 맞춤 (phone → phoneNumber, rank → skillLevel)
    _phoneController = TextEditingController(
        text: data?['phoneNumber'] ?? data?['phone'] ?? '');
    _selectedRegion = data?['region'];
    _selectedRank = data?['skillLevel'] ?? data?['rank'];
    _selectedCategoryId = (data?['categoryId'] as num?)?.toInt();
    _loadCategories();
  }

  @override
  void dispose() {
    _clubController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final homepageId = widget.currentData?['homepageId'];
    if (homepageId == null) {
      setState(() => _categoriesLoading = false);
      return;
    }

    try {
      final apiClient = ApiClient();
      final response = await apiClient.get(
        '${ApiConstants.homepageCategories}/$homepageId/categories',
      );

      if (!mounted) return;

      if (response.data is List) {
        setState(() {
          _categories = (response.data as List).map((c) {
            final map = c as Map<String, dynamic>;
            return {
              'categoryId': (map['categoryId'] as num?)?.toInt(),
              'categoryName': map['categoryName'] ?? '',
              'fee': (map['fee'] as num?)?.toInt() ?? 0,
            };
          }).toList();
          _categoriesLoading = false;
        });
      } else {
        setState(() => _categoriesLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _categoriesLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final apiClient = ApiClient();
      final response = await apiClient.put(
        '${ApiConstants.myRegistrationUpdate}/${widget.registrationId}',
        data: {
          'categoryId': _selectedCategoryId?.toString(),
          'region': _selectedRegion,
          'club': _clubController.text.trim(),
          'participantName': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'rank': _selectedRank,
        },
      );

      if (!mounted) return;

      final success = response.data is Map ? (response.data['success'] ?? false) : false;
      if (success) {
        ref.invalidate(myRegistrationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('참가신청이 수정되었습니다.')),
        );
        Navigator.of(context).pop();
      } else {
        final message = response.data is Map ? (response.data['message'] ?? '수정에 실패했습니다.') : '수정에 실패했습니다.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      debugPrint('[Error] 오류가 발생했습니다: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.currentData;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('참가신청 수정'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 읽기 전용: 대회명, 참가자
              if (data != null) ...[
                _buildReadOnlyField('대회', data['contestName'] ?? ''),
                const SizedBox(height: 12),
                _buildReadOnlyField('참가자', data['participantName'] ?? ''),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  '아래 항목을 수정할 수 있습니다',
                  style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 16),
              ],

              // 이름
              Text('이름', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('이름을 입력하세요'),
                validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력하세요' : null,
              ),
              const SizedBox(height: 20),

              // 연락처
              Text('연락처', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: _inputDecoration('연락처를 입력하세요'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),

              // 기력
              Text('기력', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _ranks.contains(_selectedRank) ? _selectedRank : null,
                decoration: _inputDecoration('기력을 선택하세요'),
                items: _ranks.map((rank) => DropdownMenuItem(
                  value: rank,
                  child: Text(rank),
                )).toList(),
                onChanged: (v) => setState(() => _selectedRank = v),
              ),
              const SizedBox(height: 20),

              // 부문
              Text('부문', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              _categoriesLoading
                  ? Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                    )
                  : DropdownButtonFormField<int>(
                      value: _categories.any((c) => c['categoryId'] == _selectedCategoryId)
                          ? _selectedCategoryId
                          : null,
                      decoration: _inputDecoration(_isPaid ? '결제 완료 후에는 변경 불가' : '부문을 선택하세요'),
                      isExpanded: true,
                      items: _categories.map((cat) {
                        final fee = cat['fee'] as int;
                        final label = fee > 0
                            ? '${cat['categoryName']} (₩${_formatNumber(fee)})'
                            : cat['categoryName'] as String;
                        return DropdownMenuItem<int>(
                          value: cat['categoryId'] as int,
                          child: Text(label, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: _isPaid ? null : (v) => setState(() => _selectedCategoryId = v),
                    ),
              if (_isPaid)
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '결제 완료 후에는 부문을 변경할 수 없습니다. 환불 후 재신청해주세요.',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                ),
              const SizedBox(height: 20),

              // 지역
              Text('지역', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _regions.contains(_selectedRegion) ? _selectedRegion : null,
                decoration: _inputDecoration('지역을 선택하세요'),
                items: _regions.map((region) => DropdownMenuItem(
                  value: region,
                  child: Text(region),
                )).toList(),
                onChanged: (v) => setState(() => _selectedRegion = v),
              ),
              const SizedBox(height: 20),

              // 소속/클럽
              Text('소속/클럽', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _clubController,
                decoration: _inputDecoration('소속 또는 클럽명을 입력하세요'),
              ),
              const SizedBox(height: 32),

              // 수정하기 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('수정하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}
