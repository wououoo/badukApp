import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/registration.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/services/contest_service.dart';
import '../../../data/services/homepage_service.dart';

/// 단체전 팀 대표 일괄 등록 화면
class TeamBulkRegistrationScreen extends ConsumerStatefulWidget {
  final int homepageId;
  final ContestDetail contest;
  final ContestCategory category;
  final String registrationType; // 'TEAM' 또는 'PAIR'

  const TeamBulkRegistrationScreen({
    super.key,
    required this.homepageId,
    required this.contest,
    required this.category,
    this.registrationType = 'TEAM',
  });

  @override
  ConsumerState<TeamBulkRegistrationScreen> createState() =>
      _TeamBulkRegistrationScreenState();
}

class _TeamBulkRegistrationScreenState
    extends ConsumerState<TeamBulkRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _homepageService = HomepageService();

  // 팀 정보
  final _teamNameController = TextEditingController();

  // 팀 대표 정보
  final _leaderNameController = TextEditingController();
  final _leaderPhoneController = TextEditingController();
  final _leaderPasswordController = TextEditingController();
  String? _leaderSkillLevel;

  // 팀원 정보 (동적)
  late List<_TeamMemberFields> _memberFields;

  bool _isLoading = false;
  bool _agreedToTerms = false;

  // 기력 옵션
  final _skillLevels = [
    '9단', '8단', '7단', '6단', '5단', '4단', '3단', '2단', '1단',
    '1급', '2급', '3급', '4급', '5급', '6급', '7급', '8급', '9급',
    '10급', '11급', '12급', '13급', '14급', '15급', '16급', '17급', '18급',
  ];

  int get _teamSize => widget.category.teamSize ?? 5;

  @override
  void initState() {
    super.initState();
    // 팀 대표 제외한 나머지 팀원 수만큼 필드 생성
    _memberFields = List.generate(
      _teamSize - 1,
      (_) => _TeamMemberFields(),
    );
    _initFromUserProfile();
  }

  void _initFromUserProfile() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _leaderNameController.text = user.name;
      _leaderPhoneController.text = user.phone ?? '';
      if (user.rank != null && _skillLevels.contains(user.rank)) {
        _leaderSkillLevel = user.rank;
      }
    }
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _leaderNameController.dispose();
    _leaderPhoneController.dispose();
    _leaderPasswordController.dispose();
    for (final member in _memberFields) {
      member.dispose();
    }
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _showError('개인정보 수집 및 이용에 동의해주세요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authProvider);
      final mobileUserId = authState.user?.id;

      // 팀원 정보 구성
      final teamMembers = <Map<String, dynamic>>[];
      for (int i = 0; i < _memberFields.length; i++) {
        final member = _memberFields[i];
        final name = member.nameController.text.trim();
        if (name.isEmpty) {
          _showError('${i + 2}번 팀원의 이름을 입력해주세요.');
          setState(() => _isLoading = false);
          return;
        }
        if (member.skillLevel == null || member.skillLevel!.isEmpty) {
          _showError('${i + 2}번 팀원의 기력을 선택해주세요.');
          setState(() => _isLoading = false);
          return;
        }
        teamMembers.add({
          'name': name,
          'skillLevel': member.skillLevel ?? '',
          'phone': member.phoneController.text.trim(),
        });
      }

      final registration = RegistrationData(
        homepageId: widget.homepageId,
        categoryId: widget.category.id,
        name: _leaderNameController.text.trim(),
        skillLevel: _leaderSkillLevel ?? '',
        phone: _leaderPhoneController.text.trim(),
        password: _leaderPasswordController.text,
        type: widget.registrationType,
        teamName: _teamNameController.text.trim(),
        teamMembers: teamMembers,
        teamMemberOrder: 1, // 팀 대표 = 1번
        mobileUserId: mobileUserId,
      );

      final fee = widget.category.fee ?? 0;

      // 참가비가 있으면 결제 화면으로 이동
      if (fee > 0) {
        if (mounted) {
          context.push('/payment', extra: {
            'registration': registration,
            'participantName': _teamNameController.text.trim(),
            'categoryName': widget.category.categoryName,
            'contestName': widget.contest.name,
            'amount': fee,
            'homepageId': widget.homepageId,
          });
        }
        return;
      }

      // 무료인 경우 바로 등록
      final response = await _homepageService.submitRegistration(registration);

      if (response.success) {
        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        _showError(response.message ?? '참가신청에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('[Error] 오류가 발생했습니다: $e');
      _showError('오류가 발생했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: AppColors.success),
            ),
            const SizedBox(width: 12),
            const Text('팀 등록 완료'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('단체전 팀 등록이 완료되었습니다.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('대회', widget.contest.name),
                  _buildInfoRow('부문', widget.category.categoryName),
                  _buildInfoRow('팀명', _teamNameController.text),
                  _buildInfoRow('대표', _leaderNameController.text),
                  _buildInfoRow('비밀번호', _leaderPasswordController.text),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '* 비밀번호는 참가신청 조회/취소 시 필요합니다.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 다이얼로그 닫기
              context.pop(); // 이전 화면 (참가신청)
              context.pop(); // 대회 상세
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('단체전 팀 등록'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 대회/부문 정보
              _buildContestInfo(),
              const SizedBox(height: 24),

              // 전원 입력 안내 배너
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '팀원 $_teamSize명 전원의 정보를 입력해주세요.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 팀명 입력
              _buildSection(
                title: '팀명',
                required: true,
                child: _buildTextField(
                  controller: _teamNameController,
                  label: '팀명',
                  hint: '팀 이름을 입력하세요',
                  required: true,
                  validator: (v) =>
                      v?.isEmpty ?? true ? '팀명을 입력하세요' : null,
                ),
              ),
              const SizedBox(height: 24),

              // 클럽에서 팀원 선택 버튼
              _buildClubPickerButton(),
              const SizedBox(height: 24),

              // 1번 팀원 (본인)
              _buildSection(
                title: '1번 팀원',
                required: true,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _leaderNameController,
                      label: '이름',
                      hint: '실명을 입력하세요',
                      required: true,
                      validator: (v) =>
                          v?.isEmpty ?? true ? '이름을 입력하세요' : null,
                    ),
                    const SizedBox(height: 14),
                    _buildDropdownField(
                      label: '기력',
                      required: true,
                      value: _leaderSkillLevel,
                      items: _skillLevels,
                      onChanged: (v) =>
                          setState(() => _leaderSkillLevel = v),
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _leaderPhoneController,
                      label: '연락처',
                      hint: '010-0000-0000',
                      required: true,
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          v?.isEmpty ?? true ? '연락처를 입력하세요' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2번~ 팀원
              ...List.generate(_memberFields.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _buildSection(
                    title: '${index + 2}번 팀원',
                    required: true,
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _memberFields[index].nameController,
                          label: '이름',
                          hint: '실명을 입력하세요',
                          required: true,
                          validator: (v) =>
                              v?.isEmpty ?? true ? '이름을 입력하세요' : null,
                        ),
                        const SizedBox(height: 14),
                        _buildDropdownField(
                          label: '기력',
                          required: true,
                          value: _memberFields[index].skillLevel,
                          items: _skillLevels,
                          onChanged: (v) => setState(
                              () => _memberFields[index].skillLevel = v),
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller:
                              _memberFields[index].phoneController,
                          label: '연락처 (선택)',
                          hint: '010-0000-0000',
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // 비밀번호
              _buildSection(
                title: '신청 비밀번호',
                subtitle: '참가신청 조회/취소 시 사용됩니다',
                child: _buildTextField(
                  controller: _leaderPasswordController,
                  label: '비밀번호',
                  hint: '숫자 4자리',
                  required: true,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  validator: (v) {
                    if (v?.isEmpty ?? true) return '비밀번호를 입력하세요';
                    if (v!.length != 4) return '4자리 숫자를 입력하세요';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 24),

              // 동의 체크박스
              _buildAgreementSection(),
              const SizedBox(height: 32),

              // 제출 버튼
              _buildSubmitButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildClubPickerButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _pickMembersFromClub,
        icon: const Icon(Icons.groups_outlined),
        label: const Text('클럽에서 팀원 선택', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _pickMembersFromClub() async {
    final result = await context.push<List<Map<String, dynamic>>>(
      '/clubs/pick-members',
      extra: _teamSize - 1, // 팀 대표 제외
    );

    if (result == null || result.isEmpty || !mounted) return;

    setState(() {
      for (int i = 0; i < result.length && i < _memberFields.length; i++) {
        final member = result[i];
        _memberFields[i].nameController.text = member['name'] ?? '';
        if (member['rank'] != null && _skillLevels.contains(member['rank'])) {
          _memberFields[i].skillLevel = member['rank'];
        }
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.length}명의 팀원이 입력되었습니다.')),
      );
    }
  }

  Widget _buildContestInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.groups, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contest.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.category.categoryName} (${_teamSize}인조)',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreementSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _agreedToTerms,
              onChanged: (v) =>
                  setState(() => _agreedToTerms = v ?? false),
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  setState(() => _agreedToTerms = !_agreedToTerms),
              child: Text(
                '개인정보 수집 및 이용에 동의합니다.\n(대회 운영 목적으로만 사용됩니다)',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final fee = widget.category.fee ?? 0;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitRegistration,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                fee > 0 ? '${_formatNumber(fee)}원 결제하기' : '팀 등록하기',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Widget _buildSection({
    required String title,
    String? subtitle,
    bool required = false,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            if (required)
              const Text(' *',
                  style: TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.bold)),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    bool obscureText = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    bool required = false,
    String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      validator: required ? (v) => v == null ? '선택해주세요' : null : null,
    );
  }
}

/// 팀원 입력 필드 묶음
class _TeamMemberFields {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  String? skillLevel;

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
  }
}
