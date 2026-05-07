import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/region_data.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/host_provider.dart';
import '../widgets/level_selector.dart';

/// 프로필 설정 화면 (추가정보 입력)
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _clubController = TextEditingController();
  final _organizationController = TextEditingController();
  final _hostReasonController = TextEditingController();

  int _currentStep = 0;
  int? _selectedLevel;
  String? _selectedProvince;
  String? _selectedCity;
  bool _isLoading = false;
  bool _initialized = false;

  // 이름 입력 필요 여부 (OTP 로그인 신규 사용자)
  bool _needsName = false;

  // 주최자 신청 관련
  bool _wantToBeHost = false;


  /// 총 단계 수 (이름 필요 시 4단계, 아니면 3단계)
  int get _totalSteps => _needsName ? 4 : 3;

  @override
  void dispose() {
    _nameController.dispose();
    _clubController.dispose();
    _organizationController.dispose();
    _hostReasonController.dispose();
    super.dispose();
  }

  /// 가입 중단 후 로그인 화면으로 이동
  ///
  /// 라우터 가드(needsProfileSetup)가 /profile-setup으로 강제 redirect 하므로,
  /// 빠져나가려면 logout()을 호출해 AuthState를 unauthenticated로 변경해야 함.
  Future<void> _handleAbortToLogin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('가입을 중단하시겠어요?'),
        content: const Text('지금까지 입력한 정보가 모두 사라지고\n로그인 화면으로 돌아갑니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('계속하기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('중단하기'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    await ref.read(authProvider.notifier).logout();
    // 라우터 가드가 unauthenticated 상태 감지 시 자동으로 /login으로 이동
  }

  /// 연동된 맥마흔 유저 정보로 초기값 설정
  void _initFromUser() {
    if (_initialized) return;
    _initialized = true;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    // 이름이 없으면 이름 입력 단계 추가 (OTP 로그인 신규 사용자)
    if (user.name == null || user.name!.isEmpty) {
      _needsName = true;
    } else {
      _nameController.text = user.name!;
    }

    // 연동된 맥마흔 유저 정보가 있으면 미리 채우기
    if (user.level != null) {
      _selectedLevel = user.level;
    }
    if (user.region != null) {
      _selectedProvince = user.region;
    }
    if (user.city != null) {
      _selectedCity = user.city;
    }
    if (user.club != null) {
      _clubController.text = user.club!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // 연동된 맥마흔 유저 정보로 초기값 설정
    _initFromUser();

    return Scaffold(
      appBar: AppBar(
        title: Text('프로필 설정 (${_currentStep + 1}/$_totalSteps)'),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _currentStep--),
              )
            : null,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _handleAbortToLogin,
            child: const Text(
              '처음으로',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 프로그레스 인디케이터
              LinearProgressIndicator(
                value: (_currentStep + 1) / _totalSteps,
                backgroundColor: Colors.grey[200],
              ),
              // 스텝 콘텐츠
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _buildStepContent(),
                ),
              ),
              // 에러 메시지
              if (authState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    authState.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              // 하단 버튼
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onNextPressed,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _currentStep < _totalSteps - 1 ? '다음' : '완료',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    if (_needsName) {
      // 4단계: 이름 → 기력 → 지역 → 클럽
      switch (_currentStep) {
        case 0:
          return _buildNameStep();
        case 1:
          return _buildLevelStep();
        case 2:
          return _buildRegionStep();
        case 3:
          return _buildClubStep();
        default:
          return const SizedBox.shrink();
      }
    } else {
      // 3단계: 기력 → 지역 → 클럽
      switch (_currentStep) {
        case 0:
          return _buildLevelStep();
        case 1:
          return _buildRegionStep();
        case 2:
          return _buildClubStep();
        default:
          return const SizedBox.shrink();
      }
    }
  }

  /// Step: 이름 입력 (OTP 로그인 신규 사용자용)
  Widget _buildNameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이름을 입력해주세요',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '대회 참가 시 사용되는 이름입니다.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: _nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '예: 홍길동',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '실명을 입력해주세요. 대회 대진표와 순위표에 표시됩니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[800],
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Step 1: 기력 선택
  Widget _buildLevelStep() {
    final user = ref.watch(authProvider).user;
    final hasMcmahonScore = user?.mcmahonNationalScore != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '기력을 선택해주세요',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '대회 대진표 배정에 사용됩니다.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        // 연동된 맥마흔 점수가 있으면 표시
        if (hasMcmahonScore) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.verified, color: Colors.green[700], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '맥마흔 점수 연동됨',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${user!.mcmahonNationalScore!.toStringAsFixed(1)}점 (${user.mcmahonTotalGames ?? 0}국)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
        LevelSelector(
          initialLevel: _selectedLevel,
          onLevelChanged: (level) {
            setState(() => _selectedLevel = level);
          },
        ),
        const SizedBox(height: 24),
        // 기력 설명
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    '기력 안내',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                hasMcmahonScore
                    ? '• 맥마흔 점수는 대회 결과에 따라 자동 반영됩니다\n'
                      '• 아래 기력은 초기 대진표 배정에만 사용됩니다'
                    : '• 아마 9단~1단: 아마추어 고단자\n'
                      '• 1급~30급: 일반 동호인',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue[800],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Step 2: 지역 선택
  Widget _buildRegionStep() {
    final cities = _selectedProvince != null
        ? RegionData.getCities(_selectedProvince!)
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '거주 지역을 선택해주세요',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '지역별 대회 안내에 사용됩니다.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 32),
        // 시/도 선택
        const Text(
          '시/도',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildDropdown(
          value: _selectedProvince,
          items: RegionData.provinces,
          hint: '시/도 선택',
          onChanged: (value) {
            setState(() {
              _selectedProvince = value;
              _selectedCity = null; // 도시 초기화
            });
          },
        ),
        const SizedBox(height: 24),
        // 시/군/구 선택
        const Text(
          '시/군/구',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildDropdown(
          value: _selectedCity,
          items: cities,
          hint: '시/군/구 선택',
          onChanged: (value) {
            setState(() => _selectedCity = value);
          },
          enabled: _selectedProvince != null,
        ),
      ],
    );
  }

  /// Step 3: 클럽 입력 + 주최자 신청
  Widget _buildClubStep() {
    final user = ref.watch(authProvider).user;
    final hasMcmahonScore = user?.mcmahonNationalScore != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '소속 클럽 (선택)',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '소속 바둑 클럽이 있다면 입력해주세요.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: _clubController,
          decoration: InputDecoration(
            hintText: '예: 강남바둑클럽',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // 주최자 신청 섹션
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sports_esports, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  const Text(
                    '대회를 직접 개최하고 싶으신가요?',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _wantToBeHost,
                onChanged: (value) {
                  setState(() => _wantToBeHost = value ?? false);
                },
                title: const Text(
                  '주최자로 활동하기',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text(
                  '대회 개설, 참가자 관리, 대진표 운영 가능',
                  style: TextStyle(fontSize: 12),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: Colors.orange[700],
              ),

              // 주최자 신청 폼 (체크 시 표시)
              if (_wantToBeHost) ...[
                const Divider(height: 24),
                const Text(
                  '소속/단체 *',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _organizationController,
                  decoration: InputDecoration(
                    hintText: '예: 서울바둑협회, 홍길동 바둑도장',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '신청 사유 *',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _hostReasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: '대회 개최 계획이나 목적을 작성해주세요',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '* 관리자 승인 후 주최자 활동이 가능합니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),
        // 입력된 정보 요약
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '입력 정보 확인',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Divider(height: 24),
              // 맥마흔 점수가 있으면 표시
              if (hasMcmahonScore) ...[
                _buildSummaryRow(
                  '맥마흔 점수',
                  '${user!.mcmahonNationalScore!.toStringAsFixed(1)}점',
                  valueColor: Colors.green[700],
                ),
                const SizedBox(height: 8),
              ],
              _buildSummaryRow('기력', _selectedLevel != null
                  ? levelToDisplayName(_selectedLevel!)
                  : '-'),
              const SizedBox(height: 8),
              _buildSummaryRow('지역', _selectedProvince ?? '-'),
              const SizedBox(height: 8),
              _buildSummaryRow('시/군/구', _selectedCity ?? '-'),
              const SizedBox(height: 8),
              _buildSummaryRow('클럽', _clubController.text.isNotEmpty
                  ? _clubController.text
                  : '없음'),
              if (_wantToBeHost) ...[
                const SizedBox(height: 8),
                _buildSummaryRow('회원 유형', '주최자 신청', valueColor: Colors.orange[700]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: enabled ? Colors.grey[300]! : Colors.grey[200]!,
        ),
        borderRadius: BorderRadius.circular(12),
        color: enabled ? null : Colors.grey[100],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(hint),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[600]),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _onNextPressed() {
    // 현재 단계에 해당하는 실제 step 확인
    final int nameStep = _needsName ? 0 : -1;
    final int levelStep = _needsName ? 1 : 0;
    final int regionStep = _needsName ? 2 : 1;
    final int clubStep = _needsName ? 3 : 2;

    if (_currentStep == nameStep) {
      // 이름 확인
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이름을 입력해주세요.')),
        );
        return;
      }
      setState(() => _currentStep++);
    } else if (_currentStep == levelStep) {
      // 기력 선택 확인
      if (_selectedLevel == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기력을 선택해주세요.')),
        );
        return;
      }
      setState(() => _currentStep++);
    } else if (_currentStep == regionStep) {
      // 지역 선택 확인
      if (_selectedProvince == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('시/도를 선택해주세요.')),
        );
        return;
      }
      setState(() => _currentStep++);
    } else if (_currentStep == clubStep) {
      // 프로필 저장
      _saveProfile();
    }
  }

  Future<void> _saveProfile() async {
    // 주최자 신청 시 필수 정보 확인
    if (_wantToBeHost) {
      if (_organizationController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('소속/단체를 입력해주세요.')),
        );
        return;
      }
      if (_hostReasonController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신청 사유를 입력해주세요.')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // 1. 프로필 저장 (이름이 있으면 함께 전송)
      final success = await ref.read(authProvider.notifier).updateProfile(
        name: _needsName && _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : null,
        level: _selectedLevel!,
        region: _selectedProvince!,
        city: _selectedCity,
        club: _clubController.text.isNotEmpty ? _clubController.text : null,
      );

      // 2. 주최자 신청 (선택한 경우)
      if (success && _wantToBeHost && mounted) {
        try {
          await ref.read(hostApplyProvider.notifier).applyForHost(
            organization: _organizationController.text.trim(),
            reason: _hostReasonController.text.trim(),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('프로필 저장 및 주최자 신청이 완료되었습니다.\n관리자 승인을 기다려주세요.'),
              duration: Duration(seconds: 3),
            ),
          );
        } catch (e) {
          debugPrint('[Error] 주최자 신청 실패: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('프로필은 저장되었으나 주최자 신청에 실패했습니다. 다시 시도해주세요.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 저장되었습니다.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

}
