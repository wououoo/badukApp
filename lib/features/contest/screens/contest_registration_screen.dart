import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/registration.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/services/contest_service.dart';
import '../../../data/services/homepage_service.dart';
import '../../../data/services/notification_service_stub.dart'
    if (dart.library.io) '../../../data/services/notification_service.dart';
import '../../../data/api/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/homepage.dart';
import '../widgets/refund_policy_section.dart';
import '../widgets/payment_info_box.dart';

/// 대회 참가신청 화면
class ContestRegistrationScreen extends ConsumerStatefulWidget {
  final int homepageId;
  final ContestDetail contest;

  const ContestRegistrationScreen({
    super.key,
    required this.homepageId,
    required this.contest,
  });

  @override
  ConsumerState<ContestRegistrationScreen> createState() =>
      _ContestRegistrationScreenState();
}

class _ContestRegistrationScreenState
    extends ConsumerState<ContestRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _homepageService = HomepageService();

  // Controllers (본인용)
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _clubController = TextEditingController();

  // Controllers (자녀용)
  final _childNameController = TextEditingController();
  final _childSchoolController = TextEditingController();
  final _childAcademyController = TextEditingController();
  final _childBirthYearController = TextEditingController();

  // FocusNodes — 검증 실패 시 첫 invalid 필드로 자동 focus + 스크롤
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _childNameFocus = FocusNode();
  final _childBirthYearFocus = FocusNode();

  // State
  ContestCategory? _selectedCategory;
  bool _isForChild = false; // false: 본인 신청, true: 자녀 대리 신청
  String? _selectedRegion;
  String? _selectedSkillLevel;
  String? _childSkillLevel;
  bool _isLoading = false;
  bool _agreedToTerms = false;         // 기존 호환용
  bool _agreedPersonalInfo = false;    // [필수] 개인정보 수집·이용
  bool _agreedThirdParty = false;      // [필수] 대회 주최측 제3자 제공

  // 결제·환불 정책 표시용 (PaymentInfoBox 입력)
  HomepageDetail? _homepageDetail;

  // 기력 옵션
  final _skillLevels = [
    '9단', '8단', '7단', '6단', '5단', '4단', '3단', '2단', '1단',
    '1급', '2급', '3급', '4급', '5급', '6급', '7급', '8급', '9급',
    '10급', '11급', '12급', '13급', '14급', '15급', '16급', '17급', '18급',
    '19급', '20급', '21급', '22급', '23급', '24급', '25급', '26급', '27급',
    '28급', '29급', '30급',
  ];

  // 지역 옵션 (공식 명칭)
  final _regions = [
    '서울특별시', '부산광역시', '대구광역시', '인천광역시', '광주광역시',
    '대전광역시', '울산광역시', '세종특별자치시',
    '경기도', '강원특별자치도', '충청북도', '충청남도',
    '전북특별자치도', '전라남도', '경상북도', '경상남도', '제주특별자치도',
  ];

  @override
  void initState() {
    super.initState();
    _initFromUserProfile();
    _loadHomepageDetail();
  }

  Future<void> _loadHomepageDetail() async {
    try {
      final detail = await _homepageService.getHomepageDetail(widget.homepageId);
      if (mounted) {
        setState(() => _homepageDetail = detail);
      }
    } catch (e) {
      debugPrint('[홈페이지 정책 조회 실패] $e');
    }
  }

  /// 사용자가 실제 결제할 금액 = 참가비 + (정책상 사용자가 부담하는 결제 PG 수수료)
  int _computeTotalPayAmount() {
    final baseFee = _selectedCategory?.fee ?? 0;
    if (baseFee <= 0) return 0;
    final pgFee = _homepageDetail?.computeUserPaymentPgFee(baseFee) ?? 0;
    return baseFee + pgFee;
  }

  void _initFromUserProfile() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone ?? '';
      // 드롭다운 값이 목록에 있는지 확인 후 설정
      if (user.rank != null && _skillLevels.contains(user.rank)) {
        _selectedSkillLevel = user.rank;
      }
      if (user.region != null && _regions.contains(user.region)) {
        _selectedRegion = user.region;
      }
      _clubController.text = user.club ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _clubController.dispose();
    _childNameController.dispose();
    _childSchoolController.dispose();
    _childAcademyController.dispose();
    _childBirthYearController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _childNameFocus.dispose();
    _childBirthYearFocus.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) {
      // 검증 실패 시 첫 invalid 필드로 자동 focus + 스크롤
      // (validator만으로는 화면 밖 필드에서 사용자가 인지하지 못함)
      _focusFirstInvalidField();
      return;
    }
    if (_selectedCategory == null) {
      _showError('참가 부문을 선택해주세요.');
      return;
    }
    if (!_agreedPersonalInfo || !_agreedThirdParty) {
      _showError('필수 동의 항목에 모두 동의해주세요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 현재 로그인한 사용자 ID (푸시 알림용)
      final authState = ref.read(authProvider);
      final mobileUserId = authState.user?.id;

      final RegistrationData registration;

      if (_isPairOrganizerCategory) {
        // 페어 랜덤조편성 - 개인 신청
        registration = RegistrationData(
          homepageId: widget.homepageId,
          categoryId: _selectedCategory!.id,
          name: _nameController.text.trim(),
          skillLevel: _selectedSkillLevel ?? '',
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          type: 'PAIR',
          region: _selectedRegion,
          club: _clubController.text.trim(),
          mobileUserId: mobileUserId,
        );
      } else if (_isForChild) {
        // 자녀 대리 신청
        registration = RegistrationData(
          homepageId: widget.homepageId,
          categoryId: _selectedCategory!.id,
          name: _childNameController.text.trim(),
          skillLevel: _childSkillLevel ?? '',
          phone: _phoneController.text.trim(), // 보호자 연락처
          password: _passwordController.text,
          type: 'CHILD',
          school: _childSchoolController.text.trim(),
          academy: _childAcademyController.text.trim(),
          birthYear: _childBirthYearController.text.trim(),
          parentPhone: _phoneController.text.trim(),
          mobileUserId: mobileUserId,
        );
      } else {
        // 본인 신청 — type은 선택한 부문의 contestType을 그대로 따름
        // (어린이 부문에 본인이 직접 신청하면 type='CHILD'로 저장 → 데이터 일관성)
        final selfRegType = (_selectedCategory?.contestType?.toUpperCase() ?? 'ADULT');
        final isChildSelf = selfRegType == 'CHILD';
        // 부문 birthInputType 결정 (CHILD 기본 YEAR_ONLY, 그 외 NONE)
        final birthInputType = _selectedCategory?.birthInputType ??
            (isChildSelf ? 'YEAR_ONLY' : 'NONE');
        final sendBirth = birthInputType != 'NONE';
        registration = RegistrationData(
          homepageId: widget.homepageId,
          categoryId: _selectedCategory!.id,
          name: _nameController.text.trim(),
          skillLevel: _selectedSkillLevel ?? '',
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          type: selfRegType,
          // 어린이 부문 본인 신청 — 학교/학원/출생년도 + 본인 연락처를 보호자 연락처로도 사용
          school: isChildSelf ? _childSchoolController.text.trim() : null,
          academy: isChildSelf ? _childAcademyController.text.trim() : null,
          // 부문에 출생 정보 설정이 있으면 전송 (YEAR_ONLY="YYYY" / FULL_DATE="YYYY-MM-DD")
          birthYear: sendBirth ? _childBirthYearController.text.trim() : null,
          parentPhone: isChildSelf ? _phoneController.text.trim() : null,
          // 성인 부문 — 지역/클럽
          region: isChildSelf ? null : _selectedRegion,
          club: isChildSelf ? null : _clubController.text.trim(),
          mobileUserId: mobileUserId,
        );
      }

      final fee = _selectedCategory?.fee ?? 0;

      // 참가비가 있으면 결제 화면으로 먼저 이동 (참가신청은 결제 완료 후 저장)
      if (fee > 0) {
        if (mounted) {
          _navigateToPayment(registration);
        }
        return;
      }

      // 무료인 경우에만 바로 참가신청 저장
      final response = await _homepageService.submitRegistration(registration);

      if (response.success) {
        // 동의 기록 API 전송 (증빙용)
        _recordRegistrationConsent(response.registrationId);

        if (widget.contest.contestStartDate != null && response.registrationId != null) {
          NotificationService().scheduleContestReminders(
            registrationId: response.registrationId!,
            homepageId: widget.homepageId,
            contestName: widget.contest.name,
            contestStartDate: widget.contest.contestStartDate!,
          );
        }
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

  /// 참가신청 동의 기록 API 전송 (증빙용, 실패해도 참가신청 자체에는 영향 없음)
  Future<void> _recordRegistrationConsent(int? registrationId) async {
    try {
      final apiClient = ApiClient();
      final endpoint = registrationId != null
          ? '${ApiConstants.privacyConsent}/registration/$registrationId'
          : ApiConstants.privacyConsent;

      await apiClient.dio.post(endpoint, data: {
        'consents': [
          {
            'consentType': 'CONTEST_REGISTRATION',
            'consentItem': 'REQUIRED_PERSONAL_INFO',
            'consented': _agreedPersonalInfo,
          },
          {
            'consentType': 'CONTEST_REGISTRATION',
            'consentItem': 'THIRD_PARTY_PROVISION',
            'consented': _agreedThirdParty,
          },
        ],
        'deviceInfo': 'Flutter App',
      });
      debugPrint('참가신청 동의 기록 완료: registrationId=$registrationId');
    } catch (e) {
      debugPrint('참가신청 동의 기록 실패 (무시): $e');
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

  /// 결제 화면으로 이동 (참가신청 데이터를 함께 전달)
  void _navigateToPayment(RegistrationData registration) {
    final participantName = _isForChild
        ? _childNameController.text.trim()
        : _nameController.text.trim();

    context.push('/payment', extra: {
      'registration': registration,  // 참가신청 데이터
      'participantName': participantName,
      'categoryName': _selectedCategory!.categoryName,
      'contestName': widget.contest.name,
      'amount': _computeTotalPayAmount(),  // 참가비 + 정책 PG 수수료
      'homepageId': widget.homepageId,
      'contestStartDate': widget.contest.contestStartDate,
    });
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
            const Text('신청 완료'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('참가신청이 완료되었습니다.'),
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
                  _buildInfoRow('부문', _selectedCategory?.categoryName ?? ''),
                  _buildInfoRow('이름', _isForChild ? _childNameController.text : _nameController.text),
                  if (_isForChild) _buildInfoRow('구분', '자녀 대리 신청'),
                  _buildInfoRow('비밀번호', _passwordController.text),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '* 비밀번호는 참가신청 조회/취소 시 필요합니다.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 다이얼로그 닫기
              context.pop(true); // 상세 페이지로 돌아가면서 성공 결과 전달
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 선택된 부문 안내 배너 — 부문명/참가비를 폼 상단에서 부각해 헷갈림 방지
  Widget _buildSelectedCategoryBanner() {
    final cat = _selectedCategory!;
    final isPair = _isPairCategory;
    final accent = isPair ? AppColors.warning : AppColors.success;
    final fee = cat.fee ?? 0;

    String desc;
    if (_isPairSelfCategory) {
      desc = '자유조편성 - 팀원 ${cat.teamSize ?? 2}명의 정보를 모두 입력해주세요.';
    } else if (_isPairOrganizerCategory) {
      desc = '랜덤조편성 - 본인 정보만 입력하시면 주최측이 팀을 배정합니다.';
    } else if (_isTeamCategory) {
      desc = '단체전 - 팀원 ${cat.teamSize ?? 3}명의 정보를 모두 입력해주세요.';
    } else if (_isChildCategory) {
      desc = '어린이/청소년 - 참가자와 보호자 정보를 입력해주세요.';
    } else {
      desc = '성인 개인전 - 참가자 정보를 입력해주세요.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        border: Border.all(color: accent.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.push_pin, size: 18, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cat.groupName != null && cat.groupName!.isNotEmpty)
                      Text(
                        cat.groupName!.replaceAll(RegExp(r'\s+'), ' ').trim(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: accent.withOpacity(0.85),
                        ),
                      ),
                    Text(
                      cat.categoryName ?? '',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (fee > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '참가비 ${_formatPrice(fee)}원',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              desc,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    final s = price.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
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
        title: const Text('참가신청'),
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
              // 대회 정보
              _buildContestInfo(),
              const SizedBox(height: 24),

              // 참가 부문 선택
              _buildCategorySelection(),
              const SizedBox(height: 24),

              // 선택된 부문 안내 배너 (헷갈림 방지)
              if (_selectedCategory != null) ...[
                _buildSelectedCategoryBanner(),
                const SizedBox(height: 16),
              ],

              // 단체전 부문 선택 시: 모드 선택 카드 표시
              if (_isTeamCategory) ...[
                _buildTeamModeSelection(),
              ] else if (_isPairSelfCategory) ...[
                // 페어 자유조편성: 팀 신청 모드
                _buildPairSelfModeSelection(),
              ] else ...[
                // 개인전 / 페어 랜덤조편성
                if (_isPairOrganizerCategory) ...[
                  _buildPairOrganizerInfo(),
                  const SizedBox(height: 16),
                ],
                // 신청 구분 토글: CHILD 부문일 때만 의미 있음 (페어는 본인 신청 강제)
                // ADULT 부문엔 토글 숨기고 본인 신청만
                if (!_isPairCategory && _isChildCategory) _buildTypeSelection(),
                if (!_isPairCategory && _isChildCategory) const SizedBox(height: 24),

                // 폼 분기 (부문 contestType 우선):
                //  - CHILD 부문 + 자녀 대리 → 보호자 연락처 + 자녀 정보 (학교/학원/출생년도)
                //  - CHILD 부문 + 본인 신청 → 본인 정보 + 학교/학원/출생년도
                //  - ADULT 부문 → 본인 정보 (지역/클럽)
                if (_isChildCategory && _isForChild) ...[
                  _buildParentContactSection(),
                  const SizedBox(height: 24),
                  _buildChildInfoSection(),
                ] else ...[
                  _buildSelfInfoSection(),
                  if (_isChildCategory) ...[
                    const SizedBox(height: 24),
                    _buildSelfChildExtraSection(),
                  ] else ...[
                    // 성인/페어/단체 부문 — 부문에 birthInputType 설정이 있으면 출생 정보 입력 (기본 NONE = 안 받음)
                    _buildAdultBirthSection(),
                  ],
                ],
                const SizedBox(height: 24),

                // 비밀번호
                _buildPasswordSection(),
                const SizedBox(height: 24),

                // 결제 안내 + 환불 정책 (부문 선택 후 + 유료 부문일 때만 PaymentInfoBox)
                if (_selectedCategory != null
                    && _selectedCategory!.hasFee
                    && _homepageDetail != null) ...[
                  PaymentInfoBox(
                    homepage: _homepageDetail!,
                    baseFee: _selectedCategory!.fee ?? 0,
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  // 부문 미선택 또는 무료 부문 — 환불 규정만 표시
                  RefundPolicySection(
                    homepageId: widget.homepageId,
                  ),
                  const SizedBox(height: 24),
                ],

                // 동의 체크박스
                _buildAgreementSection(),
                const SizedBox(height: 32),

                // 주최자에게 문의(채팅) - 일단 비활성
                // if (widget.contest.hasChatManager)
                //   _buildInquiryButton(),

                // 제출 버튼
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
            child: const Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: 24,
            ),
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
                if (widget.contest.schedule != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.contest.schedule!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelection() {
    // 현장 접수 전용(onsiteOnly) 부문은 앱 신청 목록에서 제외
    // (요강 페이지에는 표시되지만 신청 자체는 차단됨)
    final selectableCategories = widget.contest.categories
        .where((c) => !c.onsiteOnly)
        .toList();
    return _buildSection(
      title: '참가 부문',
      required: true,
      child: Column(
        children: selectableCategories.map((category) {
          final isSelected = _selectedCategory?.id == category.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (category.groupName != null && category.groupName!.isNotEmpty)
                          Text(
                            category.groupName!.replaceAll(RegExp(r'\s+'), ' ').trim(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.85)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        Text(
                          category.categoryName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (category.skillRequirement != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            category.skillRequirement!,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        // 정원 및 현재 신청자 수 표시
                        if (category.maxParticipants != null && category.maxParticipants! > 0) ...[
                          const SizedBox(height: 4),
                          Builder(builder: (context) {
                            final current = category.currentParticipants ?? 0;
                            final max = category.maxParticipants!;
                            final remaining = max - current;
                            final isFull = remaining <= 0;
                            return Row(
                              children: [
                                Icon(
                                  isFull ? Icons.person_off_outlined : Icons.people_outline,
                                  size: 14,
                                  color: isFull ? AppColors.error : AppColors.textTertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isFull
                                      ? '마감 ($current/$max)'
                                      : '$current/$max명 (잔여 $remaining석)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isFull ? AppColors.error : AppColors.textTertiary,
                                    fontWeight: isFull ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  // 참가비 표시
                  if (category.hasFee) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_formatNumber(category.fee!)}원',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else if (category.fee == 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '무료',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (category.contestType != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getContestTypeLabel(category.contestType!),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 선택된 부문이 단체전인지 확인
  bool get _isTeamCategory =>
      _selectedCategory?.contestType?.toUpperCase() == 'TEAM';

  /// 선택된 부문이 페어 자유조편성인지 (팀 일괄 신청)
  /// teamFormationType이 null이어도 teamSize가 있으면 자유조편성으로 판단
  bool get _isPairSelfCategory {
    final cat = _selectedCategory;
    if (cat == null || cat.contestType?.toUpperCase() != 'PAIR') return false;
    if (cat.teamFormationType == 'SELF') return true;
    if (cat.teamFormationType == null && cat.teamSize != null && cat.teamSize! > 0) return true;
    return false;
  }

  /// 선택된 부문이 페어 랜덤조편성인지 (개인 신청)
  bool get _isPairOrganizerCategory {
    final cat = _selectedCategory;
    if (cat == null || cat.contestType?.toUpperCase() != 'PAIR') return false;
    if (cat.teamFormationType == 'ORGANIZER') return true;
    if (cat.teamFormationType == null && (cat.teamSize == null || cat.teamSize == 0)) return true;
    return false;
  }

  /// 선택된 부문이 페어인지
  bool get _isPairCategory =>
      _selectedCategory?.contestType?.toUpperCase() == 'PAIR';

  /// 선택된 부문이 어린이부(CHILD)인지 — 폼 분기 기준
  bool get _isChildCategory =>
      _selectedCategory?.contestType?.toUpperCase() == 'CHILD';

  /// 본인 신청 + 어린이 부문일 때 학교/학원/출생년도 추가 입력 섹션
  /// (자녀 대리 폼의 _buildChildInfoSection과 동일 컨트롤러 재사용 — 본인이 직접 입력)
  Widget _buildSelfChildExtraSection() {
    return _buildSection(
      title: '학교 / 출생년도 정보',
      subtitle: '어린이 부문 신청 시 필요한 정보입니다',
      child: Column(
        children: [
          _buildTextField(
            controller: _childSchoolController,
            label: '학교',
            hint: '학교명',
            required: true,
            validator: (v) => v?.isEmpty ?? true ? '학교를 입력하세요' : null,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _childAcademyController,
            label: '학원/도장',
            hint: '학원명 (선택)',
          ),
          _buildBirthInputField(defaultType: 'YEAR_ONLY'),
        ],
      ),
    );
  }

  /// 출생 정보 입력 위젯 — 부문 birthInputType 따라 분기
  /// defaultType: 명시값 없을 때 기본 (어린이=YEAR_ONLY, 성인/페어/단체=NONE)
  Widget _buildBirthInputField({required String defaultType}) {
    final type = _selectedCategory?.birthInputType ?? defaultType;
    if (type == 'NONE') return const SizedBox.shrink();
    if (type == 'FULL_DATE') {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: _buildBirthDatePicker(),
      );
    }
    // YEAR_ONLY (기존 동작)
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _buildTextField(
        controller: _childBirthYearController,
        focusNode: _childBirthYearFocus,
        label: '출생년도',
        hint: '예: 2015',
        required: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        validator: (v) {
          if (v?.isEmpty ?? true) return '출생년도를 입력하세요';
          if (v!.length != 4) return '4자리 연도를 입력하세요';
          return null;
        },
      ),
    );
  }

  /// 생년월일 년/월/일 dropdown 3개 (FULL_DATE 전용 — 6자리 year, 잘못된 일 원천 차단)
  Widget _buildBirthDatePicker() {
    final raw = _childBirthYearController.text;
    final parts = raw.split('-');
    final y = parts.isNotEmpty ? parts[0] : '';
    final m = parts.length > 1 && parts[1].isNotEmpty
        ? int.parse(parts[1]).toString()
        : '';
    final d = parts.length > 2 && parts[2].isNotEmpty
        ? int.parse(parts[2]).toString()
        : '';

    int daysInMonth(String year, String month) {
      if (year.isEmpty || month.isEmpty) return 31;
      final yy = int.tryParse(year) ?? 0;
      final mm = int.tryParse(month) ?? 0;
      if (yy == 0 || mm == 0) return 31;
      return DateTime(yy, mm + 1, 0).day;
    }

    void update(String ny, String nm, String nd) {
      String fd = nd;
      if (ny.isNotEmpty && nm.isNotEmpty && nd.isNotEmpty) {
        final max = daysInMonth(ny, nm);
        if (int.parse(nd) > max) fd = max.toString();
      }
      String v;
      if (ny.isNotEmpty && nm.isNotEmpty && fd.isNotEmpty) {
        v = '${ny.padLeft(4, '0')}-${nm.padLeft(2, '0')}-${fd.padLeft(2, '0')}';
      } else if (ny.isNotEmpty || nm.isNotEmpty || fd.isNotEmpty) {
        v = '$ny-$nm-$fd';
      } else {
        v = '';
      }
      setState(() {
        _childBirthYearController.text = v;
      });
    }

    final currentYear = DateTime.now().year;
    final maxDay = daysInMonth(y, m);

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: DropdownButtonFormField<String>(
            value: y.isEmpty ? null : y,
            isExpanded: true,
            // 검증 실패 시 스크롤/포커스 타겟 (YEAR_ONLY 텍스트필드와 동일 노드 —
            // 두 모드는 동시에 렌더되지 않으므로 충돌 없음)
            focusNode: _childBirthYearFocus,
            decoration: const InputDecoration(
              labelText: '생년월일 *',
              hintText: '년도',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: List.generate(100, (i) {
              final yr = (currentYear - i).toString();
              return DropdownMenuItem(value: yr, child: Text('$yr년'));
            }),
            onChanged: (v) => update(v ?? '', m, d),
            validator: (v) => (v == null || v.isEmpty) ? '필수' : null,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            value: m.isEmpty ? null : m,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '월',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: List.generate(12, (i) {
              return DropdownMenuItem(
                value: (i + 1).toString(),
                child: Text('${i + 1}월'),
              );
            }),
            onChanged: (v) => update(y, v ?? '', d),
            validator: (v) => (v == null || v.isEmpty) ? '필수' : null,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            value: d.isEmpty ? null : d,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '일',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: List.generate(maxDay, (i) {
              return DropdownMenuItem(
                value: (i + 1).toString(),
                child: Text('${i + 1}일'),
              );
            }),
            onChanged: (v) => update(y, m, v ?? ''),
            validator: (v) => (v == null || v.isEmpty) ? '필수' : null,
          ),
        ),
      ],
    );
  }

  /// 성인/페어/단체 본인 신청 — 부문 birthInputType 설정 시 별도 섹션 노출
  /// (CHILD 본인 신청은 _buildSelfChildExtraSection이 이미 처리)
  Widget _buildAdultBirthSection() {
    final type = _selectedCategory?.birthInputType ?? 'NONE';
    if (type == 'NONE') return const SizedBox.shrink();
    final isFullDate = type == 'FULL_DATE';
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: _buildSection(
        title: isFullDate ? '생년월일' : '출생년도',
        subtitle: '대회 참가 자격 확인용',
        child: isFullDate
            ? _buildBirthDatePicker()
            : _buildTextField(
                controller: _childBirthYearController,
                focusNode: _childBirthYearFocus,
                label: '출생년도',
                hint: '예: 1990',
                required: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                validator: (v) {
                  if (v?.isEmpty ?? true) return '출생년도를 입력하세요';
                  if (v!.length != 4) return '4자리 연도를 입력하세요';
                  return null;
                },
              ),
      ),
    );
  }

  String _getContestTypeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'MCMAHON':
        return '맥마흔';
      case 'FULLLEAGUE':
        return '풀리그';
      case 'TOURNAMENT':
        return '토너먼트';
      case 'SWISS':
        return '스위스리그';
      case 'TEAM':
        return '단체전';
      case 'PAIR':
        return '페어';
      default:
        return type;
    }
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Widget _buildTypeSelection() {
    return _buildSection(
      title: '신청 구분',
      child: Row(
        children: [
          Expanded(
            child: _buildTypeOption(
              label: '본인 신청',
              isSelected: !_isForChild,
              icon: Icons.person,
              onTap: () => setState(() => _isForChild = false),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTypeOption(
              label: '자녀 대리 신청',
              isSelected: _isForChild,
              icon: Icons.family_restroom,
              onTap: () => setState(() => _isForChild = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption({
    required String label,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 본인 신청 - 본인 정보 섹션
  Widget _buildSelfInfoSection() {
    return _buildSection(
      title: '참가자 정보',
      child: Column(
        children: [
          _buildTextField(
            controller: _nameController,
            focusNode: _nameFocus,
            label: '이름',
            hint: '실명을 입력하세요',
            required: true,
            validator: (v) => v?.isEmpty ?? true ? '이름을 입력하세요' : null,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _phoneController,
            focusNode: _phoneFocus,
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
          const SizedBox(height: 14),
          _buildDropdownField(
            label: '지역',
            value: _selectedRegion,
            items: _regions,
            onChanged: (v) => setState(() => _selectedRegion = v),
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _clubController,
            label: '소속/클럽',
            hint: '예: OO바둑클럽',
          ),
        ],
      ),
    );
  }

  /// 자녀 대리 신청 - 보호자 연락처
  Widget _buildParentContactSection() {
    return _buildSection(
      title: '보호자 연락처',
      subtitle: '대회 관련 연락을 받을 번호입니다',
      child: _buildTextField(
        controller: _phoneController,
        focusNode: _phoneFocus,
        label: '보호자 휴대폰',
        hint: '010-0000-0000',
        required: true,
        keyboardType: TextInputType.phone,
        validator: (v) => v?.isEmpty ?? true ? '연락처를 입력하세요' : null,
      ),
    );
  }

  /// 자녀 대리 신청 - 자녀 정보
  Widget _buildChildInfoSection() {
    return _buildSection(
      title: '자녀 정보',
      child: Column(
        children: [
          _buildTextField(
            controller: _childNameController,
            focusNode: _childNameFocus,
            label: '자녀 이름',
            hint: '실명을 입력하세요',
            required: true,
            validator: (v) => v?.isEmpty ?? true ? '이름을 입력하세요' : null,
          ),
          const SizedBox(height: 14),
          _buildDropdownField(
            label: '기력',
            required: true,
            value: _childSkillLevel,
            items: _skillLevels,
            onChanged: (v) => setState(() => _childSkillLevel = v),
          ),
          _buildBirthInputField(defaultType: 'YEAR_ONLY'),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _childSchoolController,
            label: '학교명',
            hint: '예: OO초등학교',
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _childAcademyController,
            label: '바둑학원',
            hint: '예: OO바둑교실',
          ),
        ],
      ),
    );
  }

  /// 페어 자유조편성 모드 선택 (팀 신청으로 이동)
  Widget _buildPairSelfModeSelection() {
    return _buildSection(
      title: '페어 신청 (자유조편성)',
      subtitle: '팀원 ${_selectedCategory?.teamSize ?? 2}명의 정보를 한번에 등록합니다',
      child: GestureDetector(
        onTap: () {
          context.push(
            '/contest/${widget.homepageId}/team-register',
            extra: {
              'contest': widget.contest,
              'category': _selectedCategory!,
              'registrationType': 'PAIR', // PAIR 타입으로 전달
            },
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.people,
                  color: Colors.orange.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '팀 신청하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '팀명과 팀원 ${_selectedCategory?.teamSize ?? 2}명의 정보를 입력합니다',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  /// 페어 랜덤조편성 안내
  Widget _buildPairOrganizerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '본인 정보만 입력하시면 주최측이 팀을 배정합니다.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 단체전 모드 선택 카드
  Widget _buildTeamModeSelection() {
    return _buildSection(
      title: '단체전 신청 방법',
      subtitle: '팀을 새로 만들거나 기존 팀에 합류할 수 있습니다',
      child: Column(
        children: [
          // 팀 대표로 신청
          GestureDetector(
            onTap: () {
              context.push(
                '/contest/${widget.homepageId}/team-register',
                extra: {
                  'contest': widget.contest,
                  'category': _selectedCategory!,
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.group_add,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '팀 대표로 신청',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '팀명과 모든 팀원 정보를 한번에 등록합니다',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 기존 팀에 합류
          GestureDetector(
            onTap: () {
              context.push(
                '/contest/${widget.homepageId}/team-join',
                extra: {
                  'contest': widget.contest,
                  'category': _selectedCategory!,
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_add,
                      color: AppColors.accent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '기존 팀에 합류',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '이미 등록된 팀을 찾아 빈 자리에 합류합니다',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return _buildSection(
      title: '신청 비밀번호',
      subtitle: '참가신청 조회/취소 시 사용됩니다',
      child: _buildTextField(
        controller: _passwordController,
        focusNode: _passwordFocus,
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
    );
  }

  Widget _buildAgreementSection() {
    final allAgreed = _agreedPersonalInfo && _agreedThirdParty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 전체 동의
        _buildConsentCheckbox(
          value: allAgreed,
          onChanged: (v) {
            setState(() {
              _agreedPersonalInfo = v ?? false;
              _agreedThirdParty = v ?? false;
              _agreedToTerms = v ?? false;
            });
          },
          title: '전체 동의',
          isBold: true,
        ),
        const SizedBox(height: 8),
        // [필수] 개인정보 수집·이용 동의
        _buildConsentCheckbox(
          value: _agreedPersonalInfo,
          onChanged: (v) => setState(() {
            _agreedPersonalInfo = v ?? false;
            _agreedToTerms = _agreedPersonalInfo && _agreedThirdParty;
          }),
          title: '[필수] 개인정보 수집·이용 동의',
          subtitle: '이름, 연락처, 기력 등을 대회 운영 목적으로 수집합니다.',
        ),
        const SizedBox(height: 8),
        // [필수] 제3자 제공 동의
        _buildConsentCheckbox(
          value: _agreedThirdParty,
          onChanged: (v) => setState(() {
            _agreedThirdParty = v ?? false;
            _agreedToTerms = _agreedPersonalInfo && _agreedThirdParty;
          }),
          title: '[필수] 대회 주최측 제3자 제공 동의',
          subtitle: '대회 운영을 위해 참가자 정보를 주최측에 제공합니다.',
        ),
      ],
    );
  }

  Widget _buildConsentCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String title,
    String? subtitle,
    bool isBold = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: value ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? AppColors.primary.withOpacity(0.3) : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(!value),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInquiryButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton.icon(
        onPressed: () async {
          try {
            final chatService = ChatService();
            final room = await chatService.getOrCreateRoom(homepageId: widget.homepageId);
            if (mounted) {
              context.push('/chat/${room['roomId']}', extra: {
                'contestTitle': room['contestTitle'] ?? widget.contest.name,
              });
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('채팅방 생성에 실패했습니다.')),
              );
            }
          }
        },
        icon: const Icon(Icons.chat_bubble_outline, size: 18),
        label: const Text('주최자에게 문의하기'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitRegistration,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                _selectedCategory?.hasFee == true
                    ? '${_formatNumber(_computeTotalPayAmount())}원 결제하기'
                    : '참가신청',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
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
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  /// 생년월일 필드가 표시되는 부문(birthInputType != NONE)에서 값이 비었거나
  /// 형식이 틀리면 해당 포커스 노드를, 아니면 null을 반환.
  /// 표시 형식: 자녀 부문 기본 YEAR_ONLY("YYYY", 4자리), 그 외 기본 NONE, FULL_DATE("YYYY-MM-DD").
  /// 웹과 동일하게 "표시되는 경우 필수" 정책. (검증 자체는 각 필드 validator가 수행하고,
  ///  이 헬퍼는 미입력 시 화면 밖 에러를 사용자가 인지하도록 스크롤/포커스 대상을 잡는 용도)
  FocusNode? _invalidBirthFocus() {
    final birthType = _selectedCategory?.birthInputType ??
        (_isChildCategory ? 'YEAR_ONLY' : 'NONE');
    if (birthType == 'NONE') return null; // 부문이 생년월일을 받지 않음
    final by = _childBirthYearController.text.trim();
    final invalid = birthType == 'FULL_DATE'
        ? !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(by)
        : by.length != 4;
    return invalid ? _childBirthYearFocus : null;
  }

  /// 폼 검증 실패 시 첫 번째 invalid 필드로 focus + 자동 스크롤.
  /// 사용자가 화면 아래 비밀번호 등을 못 보고 "참가신청 안 됨" 으로 인식하는 문제 방지.
  void _focusFirstInvalidField() {
    // 폼 위에서 아래 순서대로 검증 — 가장 위쪽 invalid 필드를 우선 focus
    FocusNode? target;
    if (_isForChild) {
      if (_phoneController.text.trim().isEmpty) {
        target = _phoneFocus;
      } else if (_childNameController.text.trim().isEmpty) {
        target = _childNameFocus;
      } else {
        target = _invalidBirthFocus();
      }
    } else {
      if (_nameController.text.trim().isEmpty) {
        target = _nameFocus;
      } else if (_phoneController.text.trim().isEmpty) {
        target = _phoneFocus;
      } else {
        target = _invalidBirthFocus();
      }
    }
    // 비밀번호 — 본인/자녀 공통, 보통 화면 아래쪽이라 가장 자주 놓침
    if (target == null) {
      final pw = _passwordController.text;
      if (pw.isEmpty || pw.length != 4) target = _passwordFocus;
    }
    if (target == null) return;

    // focus 요청 + 다음 프레임에서 해당 위젯이 화면에 보이도록 스크롤
    FocusScope.of(context).requestFocus(target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = target!.context;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.3, // 화면 위쪽 30% 지점에 위치
        );
      }
    });
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
    FocusNode? focusNode,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              ))
          .toList(),
      onChanged: onChanged,
      validator: required ? (v) => v == null ? '선택해주세요' : null : null,
    );
  }
}
