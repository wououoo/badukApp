import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/registration.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/services/contest_service.dart';
import '../../../data/services/homepage_service.dart';

/// 단체전 팀 합류 화면
class TeamJoinScreen extends ConsumerStatefulWidget {
  final int homepageId;
  final ContestDetail contest;
  final ContestCategory category;

  const TeamJoinScreen({
    super.key,
    required this.homepageId,
    required this.contest,
    required this.category,
  });

  @override
  ConsumerState<TeamJoinScreen> createState() => _TeamJoinScreenState();
}

class _TeamJoinScreenState extends ConsumerState<TeamJoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _homepageService = HomepageService();

  // 팀 목록
  List<Map<String, dynamic>> _teams = [];
  bool _isLoadingTeams = true;
  String? _teamLoadError;

  // 선택된 팀
  Map<String, dynamic>? _selectedTeam;
  int? _selectedOrder; // 선택한 빈 자리 번호

  // 본인 정보
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedSkillLevel;

  bool _isLoading = false;
  bool _agreedToTerms = false;

  // 검색
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredTeams = [];

  final _skillLevels = [
    '9단', '8단', '7단', '6단', '5단', '4단', '3단', '2단', '1단',
    '1급', '2급', '3급', '4급', '5급', '6급', '7급', '8급', '9급',
    '10급', '11급', '12급', '13급', '14급', '15급', '16급', '17급', '18급',
  ];

  @override
  void initState() {
    super.initState();
    _loadTeams();
    _initFromUserProfile();
    _searchController.addListener(_filterTeams);
  }

  void _initFromUserProfile() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone ?? '';
      if (user.rank != null && _skillLevels.contains(user.rank)) {
        _selectedSkillLevel = user.rank;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    setState(() {
      _isLoadingTeams = true;
      _teamLoadError = null;
    });

    try {
      final teams = await _homepageService.getTeamsForCategory(
        widget.homepageId,
        widget.category.id,
      );
      setState(() {
        _teams = teams;
        _filteredTeams = teams;
        _isLoadingTeams = false;
      });
    } catch (e) {
      setState(() {
        _teamLoadError = '팀 목록을 불러오는데 실패했습니다.';
        _isLoadingTeams = false;
      });
    }
  }

  void _filterTeams() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredTeams = _teams;
      } else {
        _filteredTeams = _teams
            .where((team) =>
                (team['teamName'] as String?)
                    ?.toLowerCase()
                    .contains(query) ??
                false)
            .toList();
      }
    });
  }

  Future<void> _submitJoin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTeam == null || _selectedOrder == null) {
      _showError('팀과 자리를 선택해주세요.');
      return;
    }
    if (!_agreedToTerms) {
      _showError('개인정보 수집 및 이용에 동의해주세요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authProvider);
      final mobileUserId = authState.user?.id;
      final teamName = _selectedTeam!['teamName'] as String;
      final parentRegId = _selectedTeam!['parentRegistrationId'];

      final registration = RegistrationData(
        homepageId: widget.homepageId,
        categoryId: widget.category.id,
        name: _nameController.text.trim(),
        skillLevel: _selectedSkillLevel ?? '',
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        type: 'TEAM',
        teamName: teamName,
        teamMemberOrder: _selectedOrder,
        parentRegistrationId: parentRegId is int ? parentRegId : null,
        mobileUserId: mobileUserId,
      );

      final fee = widget.category.fee ?? 0;

      if (fee > 0) {
        if (mounted) {
          context.push('/payment', extra: {
            'registration': registration,
            'participantName': _nameController.text.trim(),
            'categoryName': widget.category.categoryName,
            'contestName': widget.contest.name,
            'amount': fee,
            'homepageId': widget.homepageId,
          });
        }
        return;
      }

      final response = await _homepageService.submitRegistration(registration);

      if (response.success) {
        if (mounted) {
          _showSuccessDialog(teamName);
        }
      } else {
        _showError(response.message ?? '팀 합류에 실패했습니다.');
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
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _showSuccessDialog(String teamName) {
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
            const Text('합류 완료'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('팀에 성공적으로 합류했습니다.'),
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
                  _buildInfoRow('팀명', teamName),
                  _buildInfoRow('자리', '$_selectedOrder번'),
                  _buildInfoRow('이름', _nameController.text),
                  _buildInfoRow('비밀번호', _passwordController.text),
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
              Navigator.pop(context);
              context.pop(); // team-join
              context.pop(); // registration
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
        title: const Text('팀 합류'),
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

              // 팀 검색 및 선택
              _buildTeamSelection(),
              const SizedBox(height: 24),

              // 팀 선택 후 빈 자리 선택
              if (_selectedTeam != null) ...[
                _buildSlotSelection(),
                const SizedBox(height: 24),
              ],

              // 빈 자리 선택 후 본인 정보 입력
              if (_selectedTeam != null && _selectedOrder != null) ...[
                _buildPersonalInfoSection(),
                const SizedBox(height: 24),

                // 비밀번호
                _buildSection(
                  title: '신청 비밀번호',
                  subtitle: '참가신청 조회/취소 시 사용됩니다',
                  child: _buildTextField(
                    controller: _passwordController,
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

                _buildAgreementSection(),
                const SizedBox(height: 32),

                _buildSubmitButton(),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      ),
    );
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
            child:
                const Icon(Icons.person_add, color: Colors.white, size: 24),
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
                  widget.category.categoryName,
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

  Widget _buildTeamSelection() {
    return _buildSection(
      title: '팀 선택',
      required: true,
      subtitle: '합류할 팀을 선택하세요',
      child: Column(
        children: [
          // 검색바
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '팀명 검색',
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
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
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          // 팀 목록
          if (_isLoadingTeams)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else if (_teamLoadError != null)
            _buildEmptyState(_teamLoadError!, Icons.error_outline)
          else if (_filteredTeams.isEmpty)
            _buildEmptyState(
              _searchController.text.isNotEmpty
                  ? '검색 결과가 없습니다'
                  : '등록된 팀이 없습니다.\n팀 대표로 먼저 등록해주세요.',
              Icons.groups_outlined,
            )
          else
            ..._filteredTeams.map((team) => _buildTeamCard(team)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team) {
    final teamName = team['teamName'] as String? ?? '';
    final currentSize = team['currentSize'] as int? ?? 0;
    final maxSize = team['maxSize'] as int? ?? 5;
    final isSelected = _selectedTeam?['teamName'] == teamName;
    final isFull = currentSize >= maxSize;

    return GestureDetector(
      onTap: isFull
          ? null
          : () {
              setState(() {
                _selectedTeam = team;
                _selectedOrder = null; // 자리 선택 초기화
              });
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isFull
              ? AppColors.surfaceVariant
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : isFull
                    ? AppColors.border
                    : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // 팀 아이콘
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.groups,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // 팀 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teamName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isFull
                          ? AppColors.textSecondary
                          : isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$currentSize/$maxSize명',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // 상태 뱃지
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isFull
                    ? AppColors.error.withOpacity(0.1)
                    : AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isFull ? '정원 마감' : '합류 가능',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isFull ? AppColors.error : AppColors.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotSelection() {
    final members = (_selectedTeam?['members'] as List<dynamic>?) ?? [];
    final teamName = _selectedTeam?['teamName'] ?? '';

    return _buildSection(
      title: '자리 선택',
      required: true,
      subtitle: '$teamName 팀의 빈 자리를 선택하세요',
      child: Column(
        children: members.map<Widget>((member) {
          final order = member['order'] as int? ?? 0;
          final name = member['name'] as String?;
          final skillLevel = member['skillLevel'] as String?;
          final filled = member['filled'] as bool? ?? false;
          final isSelected = _selectedOrder == order;

          return GestureDetector(
            onTap: filled
                ? null
                : () => setState(() => _selectedOrder = order),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: filled
                    ? AppColors.surfaceVariant
                    : isSelected
                        ? AppColors.primary.withOpacity(0.05)
                        : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // 순번
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: filled
                          ? AppColors.textTertiary.withOpacity(0.2)
                          : isSelected
                              ? AppColors.primary
                              : AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$order',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: filled
                        ? Text(
                            '$name${skillLevel != null ? ' ($skillLevel)' : ''}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          )
                        : Text(
                            '비어있음',
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textTertiary,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                  ),
                  if (filled)
                    Icon(Icons.person, color: AppColors.textTertiary, size: 18)
                  else if (isSelected)
                    const Icon(Icons.check_circle,
                        color: AppColors.primary, size: 20)
                  else
                    Icon(Icons.radio_button_unchecked,
                        color: AppColors.border, size: 20),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return _buildSection(
      title: '참가자 정보',
      required: true,
      child: Column(
        children: [
          _buildTextField(
            controller: _nameController,
            label: '이름',
            hint: '실명을 입력하세요',
            required: true,
            validator: (v) => v?.isEmpty ?? true ? '이름을 입력하세요' : null,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _phoneController,
            label: '연락처',
            hint: '010-0000-0000',
            required: true,
            keyboardType: TextInputType.phone,
            validator: (v) => v?.isEmpty ?? true ? '연락처를 입력하세요' : null,
          ),
          const SizedBox(height: 14),
          _buildDropdownField(
            label: '기력',
            required: true,
            value: _selectedSkillLevel,
            items: _skillLevels,
            onChanged: (v) => setState(() => _selectedSkillLevel = v),
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
        onPressed: _isLoading ? null : _submitJoin,
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
                fee > 0 ? '${_formatNumber(fee)}원 결제하고 합류하기' : '합류하기',
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
