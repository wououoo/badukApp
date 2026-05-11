import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/region_data.dart';
import '../../../data/providers/auth_provider.dart';

/// 프로필 수정 화면
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedLevel;
  String? _selectedRegion;
  String? _selectedCity;
  final _clubController = TextEditingController();

  bool _isLoading = false;
  bool _hasChanges = false;

  // 기력 목록 (백엔드 level 체계: 아마 9단=10, 아마 1단=18, 1급=19, 30급=48)
  final List<Map<String, dynamic>> _levels = [
    // 아마 단 (level 10-18: 9단~1단)
    for (int i = 9; i >= 1; i--) {'value': 19 - i, 'label': '아마 $i단'},
    // 급 (level 19-48: 1급~30급)
    for (int i = 1; i <= 30; i++) {'value': 18 + i, 'label': '$i급'},
  ];

  // 지역/도시 데이터는 RegionData를 사용 (회원가입 화면과 동일)
  List<String> get _regions => RegionData.provinces;
  Map<String, List<String>> get _citiesByRegion => RegionData.cities;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  void _loadCurrentProfile() {
    final user = ref.read(authProvider).user;
    if (user != null) {
      setState(() {
        _selectedLevel = user.level;
        // 옛 명칭(예: '전라북도') → 신 명칭(예: '전북특별자치도') 자동 매핑
        final normalizedRegion = RegionData.normalizeRegion(user.region);
        _selectedRegion = _regions.contains(normalizedRegion) ? normalizedRegion : null;
        // 저장된 도시가 해당 지역의 목록에 있는지 확인
        final cities = _selectedRegion != null ? _citiesByRegion[_selectedRegion] : null;
        _selectedCity = (cities != null && cities.contains(user.city)) ? user.city : null;
        _clubController.text = user.club ?? '';
      });
    }
  }

  @override
  void dispose() {
    _clubController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).updateProfile(
        level: _selectedLevel,
        region: _selectedRegion,
        city: _selectedCity,
        club: _clubController.text.trim().isEmpty ? null : _clubController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프로필이 수정되었습니다.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('[Error] 프로필 수정 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('프로필 수정에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('프로필 수정'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _hasChanges && !_isLoading ? _saveProfile : null,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '저장',
                    style: TextStyle(
                      color: _hasChanges ? AppColors.primary : AppColors.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 이름 (수정 불가)
            _buildReadOnlyField(
              label: '이름',
              value: user?.name ?? '-',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),

            // 기력
            _buildDropdownField(
              label: '기력',
              icon: Icons.military_tech_outlined,
              value: _selectedLevel,
              items: _levels.map((level) => DropdownMenuItem<int>(
                value: level['value'],
                child: Text(level['label']),
              )).toList(),
              onChanged: (value) {
                setState(() => _selectedLevel = value);
                _onFieldChanged();
              },
            ),
            const SizedBox(height: 16),

            // 지역
            _buildDropdownField(
              label: '지역 (도/시)',
              icon: Icons.location_on_outlined,
              value: _selectedRegion,
              items: _regions.map((region) => DropdownMenuItem<String>(
                value: region,
                child: Text(region),
              )).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRegion = value;
                  _selectedCity = null; // 지역 변경시 도시 초기화
                });
                _onFieldChanged();
              },
            ),
            const SizedBox(height: 16),

            // 도시
            _buildDropdownField(
              label: '도시 (시/군/구)',
              icon: Icons.location_city_outlined,
              value: _selectedCity,
              items: (_selectedRegion != null ? _citiesByRegion[_selectedRegion] ?? [] : [])
                  .map((city) => DropdownMenuItem<String>(
                    value: city,
                    child: Text(city),
                  )).toList(),
              onChanged: (value) {
                setState(() => _selectedCity = value);
                _onFieldChanged();
              },
              enabled: _selectedRegion != null,
            ),
            const SizedBox(height: 16),

            // 소속
            _buildTextField(
              label: '소속 (선택)',
              icon: Icons.groups_outlined,
              controller: _clubController,
              hintText: '바둑 동호회, 학원 등',
              onChanged: (_) => _onFieldChanged(),
            ),
            const SizedBox(height: 32),

            // 안내 문구
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.textTertiary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '맥마흔 점수는 대회 참가 기록에 따라 자동으로 계산됩니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textTertiary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, color: AppColors.textTertiary, size: 18),
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: enabled ? AppColors.surface : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textTertiary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    value: value,
                    items: items,
                    onChanged: enabled ? onChanged : null,
                    isExpanded: true,
                    hint: Text(
                      enabled ? '선택하세요' : '지역을 먼저 선택하세요',
                      style: TextStyle(color: AppColors.textTertiary),
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: enabled ? AppColors.textSecondary : AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    String? hintText,
    void Function(String)? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textTertiary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextField(
                  controller: controller,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
