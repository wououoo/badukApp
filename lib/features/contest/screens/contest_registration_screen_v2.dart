import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
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
import '../../../core/constants/region_data.dart';
import '../../../data/models/homepage.dart';
import '../widgets/refund_policy_section.dart';
import '../widgets/payment_info_box.dart';
import '../widgets/registration_option_selector.dart';

/// 대회 참가신청 화면
class ContestRegistrationScreenV2 extends ConsumerStatefulWidget {
  final int homepageId;
  final ContestDetail contest;

  const ContestRegistrationScreenV2({
    super.key,
    required this.homepageId,
    required this.contest,
  });

  @override
  ConsumerState<ContestRegistrationScreenV2> createState() =>
      _ContestRegistrationScreenV2State();
}

class _ContestRegistrationScreenV2State
    extends ConsumerState<ContestRegistrationScreenV2> {
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
  String? _selectedGroupName; // 2단계 선택: 먼저 고른 부문(그룹). 부문 많을 때만 사용.

  /// 현재 걸음 (0 부문 · 1 참가자 정보 · 2 확인·결제)
  int _step = 0;
  bool _isForChild = false; // false: 본인 신청, true: 자녀 대리 신청
  String? _selectedRegion;
  String? _selectedSubRegion; // 시/군/구 — 지역(시·도) 선택 후 활성화
  String? _selectedSkillLevel;
  String? _childSkillLevel;
  bool _isLoading = false;
  bool _agreedToTerms = false;         // 기존 호환용
  bool _agreedPersonalInfo = false;    // [필수] 개인정보 수집·이용
  bool _agreedThirdParty = false;      // [필수] 대회 주최측 제3자 제공
  // [필수] 카카오톡·SMS 수신 — 정보통신망법 §50에 따라 개인정보 동의와 분리해 받아야 한다.
  // (콩그레스 웹은 받고 있었는데 앱만 빠져 있어 알림톡 발송 근거가 없었다)
  bool _agreedReceive = false;

  // 결제·환불 정책 표시용 (PaymentInfoBox 입력)
  HomepageDetail? _homepageDetail;

  // 대회별 추가 항목(숙박·식사·기념품 등)
  List<Map<String, dynamic>> _optionDefs = [];
  List<Map<String, dynamic>> _optionPayload = [];
  bool _optionsValid = true;

  // ===== 국제대회(콩그레스) 전용 =====
  // 대회가 켜둔 경우에만 화면에 뜬다. 기존 대회는 플래그가 false라 아무 변화가 없다.
  final _nameEnController = TextEditingController();
  final _nameEnFocus = FocusNode();
  /// 'PLAYER'(선수, 기본) | 'GUEST'(동반 — 대국 없이 숙박·식사만, 참가비 0)
  String _role = 'PLAYER';

  /// 국적 — 국제대회에서만 입력받는다. 기본값 대한민국.
  /// 목록·저장값(한글 국가명)은 콩그레스 웹(placeholder.js NATIONS)과 동일하게 맞춘다.
  String _nationality = '대한민국';
  static const _nations = [
    '대한민국', '중국', '일본', '미국', '대만', '독일', '프랑스', '영국', '러시아',
    '캐나다', '호주', '베트남', '태국', '싱가포르', '네덜란드', '스웨덴',
    '우크라이나', '헝가리', '폴란드', '기타',
  ];
  bool get _isGuest => _role == 'GUEST';

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
    _autoSelectSoleCategory();
    _initFromUserProfile();
    _loadHomepageDetail();
    _loadOptions();
  }

  /// 신청 가능한 부문이 하나뿐이면 미리 선택해 둔다.
  ///
  /// 위저드가 "부문 2개 이상일 때만" 선택 단계를 만들기 때문에, 자동 선택이 없으면
  /// 단일 부문 대회(콩그레스 등)에서 부문을 고를 화면이 없어 영영 미선택 상태가 된다.
  /// 단, 마감·정원초과된 부문은 자동 선택하지 않는다 — 왜 신청이 막히는지 보여줘야 하므로
  /// 선택 단계를 그대로 노출한다(_steps 참조).
  void _autoSelectSoleCategory() {
    final selectable = widget.contest.categories.where((c) => !c.onsiteOnly).toList();
    if (selectable.length == 1 && !selectable.first.isBlocked) {
      _selectedCategory = selectable.first;
    }
  }

  /// 대회별 추가 항목 정의 로드
  /// 추가 항목 정의 로드.
  ///
  /// 옵션은 부문별로 다르게 정의할 수 있다(정의의 categoryId가 null이면 전 부문 공통).
  /// 부문을 안 넘기면 다른 부문 전용 옵션까지 화면에 뜨고 그대로 과금되므로,
  /// 선택된 부문 기준으로 다시 불러온다.
  Future<void> _loadOptions() async {
    try {
      final defs = await _homepageService.getRegistrationOptions(
        widget.homepageId,
        categoryId: _selectedCategory?.id,
      );
      if (!mounted) return;
      setState(() {
        _optionDefs = defs;
        // 부문이 바뀌면 이전 부문에서 고른 응답이 남아 잘못 과금될 수 있어 초기화한다.
        _optionPayload = [];
        _optionsValid = true;
      });
    } catch (e) {
      debugPrint('[옵션 조회 실패] $e');
    }
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

  /// 선택한 유료옵션 추가금액 합 (choice.extraFee × 수량).
  /// 백엔드 calcExtraFeeFromPayload와 동일 공식 — 결제 금액 검증이 1원까지 맞아야 통과된다.
  int _computeOptionFee() {
    int total = 0;
    for (final sel in _optionPayload) {
      final key = sel['key'];
      Map<String, dynamic>? def;
      for (final d in _optionDefs) {
        if (d['key'] == key) {
          def = d;
          break;
        }
      }
      if (def == null) continue;
      final type = (def['type'] ?? 'SINGLE_SELECT').toString();
      if (type == 'TEXT' || type == 'NUMBER') continue; // 텍스트/숫자는 무료
      final choices = (def['choices'] as List?) ?? [];
      final quantities = sel['quantities'] as Map?;
      for (final v in (sel['values'] as List? ?? [])) {
        Map? choice;
        for (final c in choices) {
          if (c['value'].toString() == v.toString()) {
            choice = c;
            break;
          }
        }
        if (choice == null || choice['extraFee'] == null) continue;
        final fee = (choice['extraFee'] as num).toInt();
        int qty = 1;
        if (quantities != null && quantities[v] != null) {
          qty = (quantities[v] as num).toInt();
        }
        if (qty < 1) qty = 1;
        total += fee * qty;
      }
    }
    return total;
  }

  /// 사용자가 실제 결제할 금액 = (참가비 + 유료옵션비) + (정책상 사용자가 부담하는 결제 PG 수수료)
  /// 게스트(동반)는 참가비가 면제된다 — 백엔드 PaymentService가 role=GUEST를 보고
  /// 참가비를 0으로 처리하므로(isGuestRegistration), 앱 표시도 같은 기준이어야
  /// "화면엔 135,000원인데 실제 결제는 60,000원" 같은 불일치가 안 생긴다.
  int get _effectiveBaseFee =>
      _isGuest ? 0 : (_selectedCategory?.fee ?? 0);

  int _computeTotalPayAmount() {
    final baseFee = _effectiveBaseFee;
    final chargeBase = baseFee + _computeOptionFee(); // 참가비 + 옵션비 = 결제 기준액
    if (chargeBase <= 0) return 0;
    // PG수수료도 결제 기준액 위에 계산 (백엔드와 동일). 무료옵션이면 baseFee와 같아 기존과 동일.
    final pgFee = _homepageDetail?.computeUserPaymentPgFee(chargeBase) ?? 0;
    return chargeBase + pgFee;
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
    _nameEnController.dispose();
    _nameEnFocus.dispose();
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
    if (_selectedCategory!.registrationClosed) {
      _showError('선택하신 부문은 접수가 마감되었습니다.');
      return;
    }
    if (_selectedCategory!.isFull) {
      _showError('선택하신 부문은 정원이 마감되었습니다.');
      return;
    }
    if (!_agreedPersonalInfo || !_agreedThirdParty || !_agreedReceive) {
      _showError('필수 동의 항목에 모두 동의해주세요.');
      return;
    }
    if (!_optionsValid) {
      _showError('필수 추가 항목을 선택해주세요.');
      return;
    }
    // 대회별 필수입력 강제(웹과 동일) — requiredFields 지정 시 클라에서도 차단
    if (_req('region') && (_selectedRegion == null || _selectedRegion!.trim().isEmpty)) {
      _showError('지역(시·도)을 선택해주세요.');
      return;
    }
    if (_req('subRegion') && (_selectedSubRegion == null || _selectedSubRegion!.trim().isEmpty)) {
      _showError('시·군·구를 선택해주세요.');
      return;
    }
    if (_req('academy') && _isChildCategory && _childAcademyController.text.trim().isEmpty) {
      _showError('바둑학원을 입력해주세요.');
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
          subRegion: _selectedSubRegion,
          club: _clubController.text.trim(),
          mobileUserId: mobileUserId,
          options: _optionPayload,
          // 국제대회 필드 — 대회가 켠 경우에만 값이 채워진다(아니면 null → payload에서 제외).
          nameEn: widget.contest.requireNameEn ? _nameEnController.text.trim() : null,
          nationality: widget.contest.requireNameEn ? _nationality : null,
          role: widget.contest.guestEnabled ? _role : null,
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
          // 어린이도 시/도+시/군/구 수집 (웹과 동일). 대회 required 지정 시 백엔드 강제.
          region: _selectedRegion,
          subRegion: _selectedSubRegion,
          mobileUserId: mobileUserId,
          options: _optionPayload,
          // 국제대회 필드 — 대회가 켠 경우에만 값이 채워진다(아니면 null → payload에서 제외).
          nameEn: widget.contest.requireNameEn ? _nameEnController.text.trim() : null,
          nationality: widget.contest.requireNameEn ? _nationality : null,
          role: widget.contest.guestEnabled ? _role : null,
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
          // 지역/시군구 — 성인·어린이 본인 신청 모두 수집(웹과 동일). 클럽은 성인만.
          region: _selectedRegion,
          subRegion: _selectedSubRegion,
          club: isChildSelf ? null : _clubController.text.trim(),
          mobileUserId: mobileUserId,
          options: _optionPayload,
          // 국제대회 필드 — 대회가 켠 경우에만 값이 채워진다(아니면 null → payload에서 제외).
          nameEn: widget.contest.requireNameEn ? _nameEnController.text.trim() : null,
          nationality: widget.contest.requireNameEn ? _nationality : null,
          role: widget.contest.guestEnabled ? _role : null,
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
          {
            'consentType': 'CONTEST_REGISTRATION',
            'consentItem': 'MARKETING_RECEIVE',
            'consented': _agreedReceive,
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
                color: AppColors.success.withValues(alpha: 0.1),
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
                  if (_selectedRegion != null)
                    _buildInfoRow('지역',
                        '${_selectedRegion!}${_selectedSubRegion != null ? ' ${_selectedSubRegion!}' : ''}'),
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
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
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
                          color: accent.withValues(alpha: 0.85),
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
                    color: accent.withValues(alpha: 0.18),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // 뒤로가기는 한 걸음씩. 2걸음에서 누르면 화면을 닫지 않고 1걸음으로 돌아간다.
          onPressed: () {
            if (_step > 0) {
              setState(() => _step -= 1);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildStepIndicator(),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentStepKey == '부문 선택') ..._stepCategory(),
                      if (_currentStepKey == '참가자 정보') ..._stepParticipant(),
                      if (_currentStepKey == '추가 항목') ..._stepOptions(),
                      if (_currentStepKey == '확인·결제') ..._stepConfirm(),
                    ],
                  ),
                ),
              ),
            ),
            _buildStepFooter(),
          ],
        ),
      ),
    );
  }

  /// 이 대회에 유료·선택 항목(숙박·식사 등)이 있는가.
  /// 없으면 옵션 걸음을 아예 만들지 않는다 — 빈 걸음을 지나가게 하지 않는다.
  bool get _hasOptionStep => _optionDefs.isNotEmpty;

  /// 걸음 이름. 부문이 폼의 모양을 정하므로(어린이면 학교·보호자, 단체면 팀 구성) 부문이 맨 앞이다.
  /// 참가자 정보와 옵션은 묻는 것의 성격이 달라 따로 세운다.
  List<String> get _stepLabels => [
        '부문 선택',
        '참가자 정보',
        if (_hasOptionStep) '추가 항목',
        '확인·결제',
      ];

  /// 걸음 번호 → 무엇을 그릴지. 옵션 유무에 따라 번호가 밀리므로 이름으로 판단한다.
  String get _currentStepKey {
    final labels = _stepLabels;
    if (_step >= labels.length) return labels.last;
    return labels[_step];
  }

  /// 이 걸음에서 무엇을 묻는지 한 줄로 알린다.
  /// 걸음을 나눈 이유가 "한 번에 하나만 묻는다"이므로, 그 하나를 말해주는 편이 낫다.
  String get _stepHint {
    switch (_currentStepKey) {
      case '부문 선택':
        return '어느 부문에 나가시나요?';
      case '참가자 정보':
        return '누가 참가하시나요?';
      case '추가 항목':
        return '더 필요한 것이 있나요?';
      default:
        return '금액과 규정을 확인해주세요';
    }
  }

  Widget _buildStepIndicator() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepBars(),
          const SizedBox(height: 12),
          Text(
            _stepHint,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBars() {
    return Row(
        children: List.generate(_stepLabels.length, (i) {
          final done = i < _step;
          final cur = i == _step;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == _stepLabels.length - 1 ? 0 : 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: (done || cur) ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _stepLabels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cur
                          ? AppColors.primary
                          : (done ? AppColors.textSecondary : AppColors.textTertiary),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
    );
  }

  /// 1걸음 — 무엇에 나갈지. 부문이 정해져야 다음 걸음의 칸이 정해진다.
  List<Widget> _stepCategory() {
    final notice = _homepageDetail?.registrationNotice;
    return [
      // 신청 화면 최상단 안내(서버 주도 registrationNotice) — 설정된 대회만 표시. 웹과 동일.
      if (notice != null && notice.trim().isNotEmpty) ...[
        _buildRegistrationNotice(notice),
        const SizedBox(height: 16),
      ],
      _buildContestInfo(),
      const SizedBox(height: 24),
      if (widget.contest.groupRegistrationEnabled) ...[
        _buildGroupRegistrationCard(),
        const SizedBox(height: 24),
      ],
      _buildCategorySelection(),
      const SizedBox(height: 24),
      if (_selectedCategory != null) ...[
        _buildSelectedCategoryBanner(),
        const SizedBox(height: 16),
      ],
      if (_selectedCategory != null && _isTeamCategory) _buildTeamModeSelection(),
      if (_selectedCategory != null && _isPairSelfCategory) _buildPairSelfModeSelection(),
    ];
  }

  /// 신청 화면 최상단 안내 배너 (웹 registrationNotice와 동일 스타일: 노란 안내 박스)
  Widget _buildRegistrationNotice(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        border: Border.all(color: const Color(0xFFFFE082)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13.5,
          height: 1.6,
          color: Color(0xFF8A5A00),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 2걸음 — 누가 나가는지. 부문에 따라 뜨는 칸이 달라진다.
  List<Widget> _stepParticipant() {
    return [
      if (widget.contest.guestEnabled) ...[
        _buildRoleSelection(),
        const SizedBox(height: 24),
      ],
      if (_isPairOrganizerCategory) ...[
        _buildPairOrganizerInfo(),
        const SizedBox(height: 16),
      ],
      if (!_isPairCategory && _isChildCategory) ...[
        _buildTypeSelection(),
        const SizedBox(height: 24),
      ],
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
          _buildAdultBirthSection(),
        ],
      ],
      const SizedBox(height: 24),
      _buildPasswordSection(),
    ];
  }

  /// 3걸음(있을 때) — 무엇을 더 사는지. 숙박·식사처럼 돈이 붙는 선택만 모은다.
  List<Widget> _stepOptions() {
    return [
      _buildOptionSection(),
    ];
  }

  /// 3걸음 — 얼마를 어떻게 내는지. 금액·환불 규정·동의를 한자리에서 확인하고 제출한다.
  List<Widget> _stepConfirm() {
    return [
      _buildCostBreakdown(),
      const SizedBox(height: 24),
      if (_selectedCategory != null && _selectedCategory!.hasFee && _homepageDetail != null) ...[
        PaymentInfoBox(
          homepage: _homepageDetail!,
          baseFee: _effectiveBaseFee,
          optionFee: _computeOptionFee(),
        ),
        const SizedBox(height: 24),
      ] else ...[
        RefundPolicySection(homepageId: widget.homepageId),
        const SizedBox(height: 24),
      ],
      _buildAgreementSection(),
    ];
  }

  /// 결제 금액이 어떻게 나왔는지 한 줄씩.
  /// 총액만 보여주면 "왜 이 금액이지"를 확인할 방법이 없다.
  Widget _buildCostBreakdown() {
    final base = _effectiveBaseFee;
    final option = _computeOptionFee();
    final rows = <List<String>>[
      [
        '${_selectedCategory?.categoryName ?? '참가비'}',
        '${_formatWon(base)}원',
      ],
      if (option > 0) ['추가 항목', '${_formatWon(option)}원'],
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r[0],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  Text(
                    r[1],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 9),
          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 11),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '합계',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${_formatWon(base + option)}원',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '결제 수수료는 다음 화면에서 더해집니다.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  /// 하단 고정 버튼. 마지막 걸음에서만 제출 버튼이 된다.
  Widget _buildStepFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: _currentStepKey == '확인·결제'
            ? _buildSubmitButton()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 옵션을 고르는 동안 합계가 따라다녀야 "얼마짜리를 고르는 중인지" 안다.
                  if (_currentStepKey == '추가 항목') ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '합계',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_formatWon(_effectiveBaseFee + _computeOptionFee())}원',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  _buildStepNavRow(),
                ],
              ),
      ),
    );
  }

  /// 천 단위 구분. 금액은 화면 여러 곳에 나오므로 한 곳에서 만든다.
  String _formatWon(int v) => v.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  Widget _buildStepNavRow() {
    return Row(
                children: [
                  if (_step > 0) ...[
                    SizedBox(
                      width: 88,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step -= 1),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          '이전',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _goNextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '다음',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              );
  }

  /// 그 걸음에 필요한 것만 확인하고 넘어간다.
  /// 한 화면에 다 있을 땐 제출을 눌러야 빠진 항목을 알 수 있었고,
  /// 그게 화면 어디인지 다시 찾아 올라가야 했다.
  void _goNextStep() {
    final key = _currentStepKey;
    if (key == '부문 선택') {
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('참가할 부문을 선택해주세요.')),
        );
        return;
      }
    } else if (key == '참가자 정보') {
      // 이 걸음에 그려진 칸만 검사된다. 다른 걸음의 칸은 아직 트리에 없다.
      if (!(_formKey.currentState?.validate() ?? false)) return;
    }
    setState(() => _step += 1);
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
              color: Colors.white.withValues(alpha: 0.2),
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
                      color: Colors.white.withValues(alpha: 0.8),
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
    // 부문 많고(>12) 그룹 2개 이상이면 "부문 → 세부" 2단계, 아니면 기존 flat (다른 대회 영향 없음)
    final groupNames = <String>[];
    for (final c in selectableCategories) {
      final g = (c.groupName ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (g.isNotEmpty && !groupNames.contains(g)) groupNames.add(g);
    }
    final useTwoStep = selectableCategories.length > 12 && groupNames.length >= 2;
    return _buildSection(
      title: '참가 부문',
      required: true,
      child: useTwoStep
          ? _buildTwoStepCategorySelection(selectableCategories, groupNames)
          : Column(children: selectableCategories.map(_buildCategoryTile).toList()),
    );
  }

  /// 2단계 부문 선택 (부문 많은 대회): 부문(그룹) 칩 → 선택 부문의 세부 카드
  /// 부문이 많은 대회의 2단계 선택 — 학년(이름) 먼저, 그 다음 부문(그룹).
  ///
  /// hp19처럼 34개가 "그룹 x 학년"의 조합이면 이름이 겹친다("초등 3학년"이 여섯 군데).
  /// 그룹을 먼저 물으면 소속(학원/방과후)과 급수 구간을 한꺼번에 판단해야 하지만,
  /// 학년을 먼저 물으면 확실히 아는 것부터 짚고 어려운 판단은 뒤로 간다.
  Widget _buildTwoStepCategorySelection(
      List<ContestCategory> cats, List<String> groupNames) {
    // 1단계 후보 = 학년(이름). 표기 흔들림을 줄이려 공백만 정규화한다.
    final names = <String>[];
    for (final c in cats) {
      final n = (c.categoryName ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (n.isNotEmpty && !names.contains(n)) names.add(n);
    }

    final filtered = cats
        .where((c) =>
            (c.categoryName ?? '').replaceAll(RegExp(r'\s+'), ' ').trim() ==
            _selectedGroupName)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1단계: 학년 — 세로 카드로 세운다. 칩으로 가로 나열하면 뒤쪽이 화면 밖으로 밀린다.
        ...names.map((n) {
          final sel = _selectedGroupName == n;
          final count = cats
              .where((c) =>
                  (c.categoryName ?? '').replaceAll(RegExp(r'\s+'), ' ').trim() == n)
              .length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedGroupName = n),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? AppColors.primary : AppColors.border,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        n,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: sel ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    // 그 학년 안에 몇 개가 있는지 — 다음 걸음의 크기를 미리 알려준다
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: sel ? AppColors.primary : AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      sel ? Icons.check_circle : Icons.chevron_right,
                      size: 18,
                      color: sel ? AppColors.primary : AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        // 2단계: 그 학년 안의 부문(그룹). 급수 조건이 함께 보여야 자기 자리를 찾는다.
        if (_selectedGroupName == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('먼저 위에서 학년을 선택해주세요.',
                  style: TextStyle(fontSize: 14, color: AppColors.textTertiary)),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 10),
            child: Row(
              children: [
                Text(
                  _selectedGroupName!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                Icon(Icons.chevron_right, size: 15, color: AppColors.textTertiary),
                Text(
                  '부문 선택',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          ...filtered.map(_buildCategoryTile),
        ],
      ],
    );
  }

  /// 부문 카드 1개 (flat/2단계 공용) — 기존 인라인 타일을 함수화(출력 동일).
  Widget _buildCategoryTile(ContestCategory category) {
          final isSelected = _selectedCategory?.id == category.id;
          // 운영자 강제마감/기간종료(registrationClosed) 또는 정원 마감(isFull) → 선택 불가
          final blocked = category.isBlocked;
          return GestureDetector(
            onTap: blocked
                ? null
                : () {
                    if (_selectedCategory?.id == category.id) return;
                    setState(() => _selectedCategory = category);
                    // 부문마다 추가 항목이 다를 수 있으므로 다시 불러온다(응답도 초기화됨).
                    _loadOptions();
                  },
            child: Opacity(
              opacity: blocked ? 0.5 : 1.0,
              child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                // 고른 것은 테두리만이 아니라 면으로도 드러나야 목록에서 바로 찾는다
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.07)
                    : AppColors.surface,
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
                                  ? AppColors.primary.withValues(alpha: 0.85)
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
                        // 정원/잔여 표시 — showRemaining=false면 숫자 숨기고 문구만.
                        //  실제 정원(maxParticipants) 초과 시엔 항상 '마감' 노출(하드캡 존재 시).
                        Builder(builder: (context) {
                          final max = category.maxParticipants;
                          final current = category.currentParticipants ?? 0;
                          final isFull = max != null && max > 0 && current >= max;
                          final displayText = (category.participantsDisplayText ?? '').trim();

                          IconData icon;
                          String label;
                          Color color;
                          bool bold = false;
                          if (isFull) {
                            icon = Icons.person_off_outlined;
                            label = '마감';
                            color = AppColors.error;
                            bold = true;
                          } else if (!category.showRemaining) {
                            // 잔여 숨김 → 커스텀 문구만. 문구 없으면 표시 안 함.
                            if (displayText.isEmpty) return const SizedBox.shrink();
                            icon = Icons.people_outline;
                            label = displayText;
                            color = AppColors.textTertiary;
                          } else if (max != null && max > 0) {
                            final remaining = max - current;
                            icon = Icons.people_outline;
                            label = '$current/$max명 (잔여 $remaining석)';
                            color = AppColors.textTertiary;
                          } else {
                            // 무제한 + 잔여표시 → 표시 안 함 (기존 동작)
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(icon, size: 14, color: color),
                                const SizedBox(width: 4),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: color,
                                    fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (category.registrationClosed) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.block, size: 14, color: AppColors.error),
                              const SizedBox(width: 4),
                              Text('접수 마감',
                                  style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w700)),
                            ],
                          ),
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
                        color: AppColors.accent.withValues(alpha: 0.1),
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
                        color: AppColors.success.withValues(alpha: 0.1),
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
                        color: AppColors.primary.withValues(alpha: 0.1),
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

  /// 대회별 추가 필수입력 여부(웹 requiredFields와 동일). 설정 안 된 대회는 전부 false.
  bool _req(String key) => _homepageDetail?.requiredFields.contains(key) ?? false;

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
            required: _req('academy'),
            hint: _req('academy') ? '학원명' : '학원명 (선택)',
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

  /// 선수 / 동반(GUEST) 구분 — guestEnabled 대회에서만 노출.
  /// 동반은 대국을 두지 않고 숙박·식사만 이용하며 참가비가 0원이다.
  /// (금액 0 처리·정원 제외는 백엔드 PaymentService가 role='GUEST'로 판단한다)
  Widget _buildRoleSelection() {
    Widget option({
      required String value,
      required String title,
      required String desc,
      required IconData icon,
    }) {
      final selected = _role == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _role = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(icon, size: 22,
                    color: selected ? AppColors.primary : AppColors.textSecondary),
                const SizedBox(height: 6),
                Text(title, style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(desc, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, height: 1.3, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    return _buildSection(
      title: '참가 구분',
      required: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              option(
                value: 'PLAYER',
                title: '선수',
                desc: '대국에 참가합니다',
                icon: Icons.sports_esports_outlined,
              ),
              const SizedBox(width: 10),
              option(
                value: 'GUEST',
                title: '동반',
                desc: '대국 없이 숙박·식사만',
                icon: Icons.person_outline,
              ),
            ],
          ),
          if (_isGuest) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '동반 참가는 참가비가 부과되지 않습니다.\n숙박·식사를 선택한 만큼만 결제됩니다.',
                style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
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
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
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
          // 국제대회: 영문명 (여권 표기 기준 — 명찰·대진표에 그대로 쓰인다)
          if (widget.contest.requireNameEn) ...[
            const SizedBox(height: 14),
            _buildTextField(
              controller: _nameEnController,
              focusNode: _nameEnFocus,
              label: '영문명',
              hint: 'HONG GILDONG',
              required: true,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return '영문명을 입력하세요';
                if (!RegExp(r'^[A-Za-z .\-]+$').hasMatch(t)) return '영문(알파벳)으로 입력하세요';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildDropdownField(
              label: '국적',
              required: true,
              value: _nationality,
              items: _nations,
              onChanged: (v) => setState(() => _nationality = v ?? '대한민국'),
            ),
          ],
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
          // 게스트(동반)는 대국을 두지 않으므로 기력을 받지 않는다 — 웹과 동일 규칙
          // (congress-web Registration.jsx: role==='GUEST'면 skillLevel 검증 skip).
          // 필수로 두면 기력을 못 고르는 동반자가 신청 자체를 못 한다.
          _buildDropdownField(
            label: _isGuest ? '기력 (선택)' : '기력',
            required: !_isGuest,
            value: _selectedSkillLevel,
            items: _skillLevels,
            onChanged: (v) => setState(() => _selectedSkillLevel = v),
          ),
          const SizedBox(height: 14),
          _buildDropdownField(
            label: '지역',
            required: _req('region'),
            value: _selectedRegion,
            items: _regions,
            onChanged: (v) => setState(() {
              _selectedRegion = v;
              _selectedSubRegion = null; // 시·도 바뀌면 시·군·구 초기화(목록 불일치 방지)
            }),
          ),
          // 시/군/구 — 시·도를 고른 뒤에만 노출. 대회가 required로 지정하면 백엔드가 강제한다.
          if (_selectedRegion != null) ...[
            const SizedBox(height: 14),
            _buildDropdownField(
              label: '시/군/구',
              required: _req('subRegion'),
              value: _selectedSubRegion,
              items: RegionData.getCities(_selectedRegion!),
              onChanged: (v) => setState(() => _selectedSubRegion = v),
            ),
          ],
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
            required: _req('academy'),
            hint: '예: OO바둑교실',
          ),
          const SizedBox(height: 14),
          // 지역/시군구 — 웹 어린이 폼과 동일하게 항상 수집. 대회가 required로 지정하면 백엔드가 강제.
          _buildDropdownField(
            label: '지역',
            required: _req('region'),
            value: _selectedRegion,
            items: _regions,
            onChanged: (v) => setState(() {
              _selectedRegion = v;
              _selectedSubRegion = null;
            }),
          ),
          if (_selectedRegion != null) ...[
            const SizedBox(height: 14),
            _buildDropdownField(
              label: '시/군/구',
              required: _req('subRegion'),
              value: _selectedSubRegion,
              items: RegionData.getCities(_selectedRegion!),
              onChanged: (v) => setState(() => _selectedSubRegion = v),
            ),
          ],
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
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.people,
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
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.textTertiary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '본인 정보만 입력하시면 주최측이 팀을 배정합니다.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
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
                      color: AppColors.primary.withValues(alpha: 0.1),
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
                      color: AppColors.accent.withValues(alpha: 0.1),
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

  /// 대회가 정의한 추가 항목(숙박·식사·기념품 등 — 대회마다 다름).
  ///
  /// 제목·설명을 특정 대회 기준으로 박아두면(예: "티셔츠 사이즈") 다른 대회에서 엉뚱해진다.
  /// → 필수 항목 포함 여부만 보고 문구를 고른다.
  Widget _buildOptionSection() {
    final hasRequired = _optionDefs.any((d) =>
        d['required'] == true ||
        ((d['choices'] as List?) ?? []).any((c) => c is Map && c['required'] == true));
    return _buildSection(
      title: hasRequired ? '추가 항목' : '추가 선택 항목',
      subtitle: hasRequired
          ? '필수 항목이 포함되어 있습니다'
          : '필요한 항목을 선택해주세요',
      child: RegistrationOptionSelector(
        definitions: _optionDefs,
        onChanged: (payload, valid) {
          // setState 없이 필드만 바꾸면 화면이 다시 그려지지 않아
          // 유료 옵션(숙박·식사)을 골라도 결제 금액이 그대로 보인다.
          // (옵션이 전부 무료이던 시절엔 금액이 안 변해서 드러나지 않던 버그)
          if (!mounted) return;
          setState(() {
            _optionPayload = payload;
            _optionsValid = valid;
          });
        },
      ),
    );
  }

  /// 단체 접수는 엑셀 명단 업로드가 핵심이라 앱에서 받지 않고 웹으로 보낸다.
  /// 링크는 서버가 내려준 externalSiteUrl(별도 도메인 대회) 우선, 없으면 기본 홈페이지 경로.
  String get _groupRegistrationUrl {
    final ext = widget.contest.externalSiteUrl;
    if (ext != null && ext.isNotEmpty) return ext;
    return 'https://swissbaduk.org/homepage/${widget.homepageId}';
  }

  Widget _buildGroupRegistrationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏫', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                '학원·단체로 여러 명 신청',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '엑셀로 명단을 한 번에 올리고 합산 결제합니다.\n'
            '방 배정 요청도 명단에서 함께 작성할 수 있습니다.\n'
            '화면이 넓은 PC를 권장합니다.',
            style: TextStyle(fontSize: 13, height: 1.55, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(_groupRegistrationUrl);
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('웹에서 진행'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  // PC에서 이어서 하려는 경우 — 카카오톡 '나에게 보내기' 등으로 링크를 옮긴다.
                  // 앱이 직접 문자·알림톡을 쏘지 않는 이유: 발송비·번호입력·수신실패가 붙는데
                  // 도착지(카톡)는 동일하기 때문.
                  onPressed: () async {
                    await Share.share(
                      '[단체 접수] ${widget.contest.name}\n$_groupRegistrationUrl',
                      subject: '단체 접수 링크',
                    );
                  },
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('링크 공유'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "카카오톡 → '나에게 보내기'를 선택하면 PC 카카오톡에서 열 수 있습니다.",
            style: TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textSecondary),
          ),
        ],
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

  Widget _buildAgreementSection() {
    final allAgreed = _agreedPersonalInfo && _agreedThirdParty && _agreedReceive;
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
              _agreedReceive = v ?? false;
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
            _agreedToTerms = _agreedPersonalInfo && _agreedThirdParty && _agreedReceive;
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
            _agreedToTerms = _agreedPersonalInfo && _agreedThirdParty && _agreedReceive;
          }),
          title: '[필수] 대회 주최측 제3자 제공 동의',
          subtitle: '대회 운영을 위해 참가자 정보를 주최측에 제공합니다.',
        ),
        const SizedBox(height: 8),
        // [필수] 카카오톡·SMS 수신 (정보통신망법 §50 — 개인정보 동의와 별도로 받아야 함)
        _buildConsentCheckbox(
          value: _agreedReceive,
          onChanged: (v) => setState(() {
            _agreedReceive = v ?? false;
            _agreedToTerms = _agreedPersonalInfo && _agreedThirdParty && _agreedReceive;
          }),
          title: '[필수] 카카오톡·SMS 수신 동의',
          subtitle: '접수·결제·환불·일정 변경 안내를 알림톡 및 문자로 발송합니다.',
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
        color: value ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
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
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
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

  /// 입력 칸 — 라벨을 칸 위쪽에 작게 얹고 값은 굵게.
  ///
  /// Material 기본(테두리 안에 라벨이 떠다니는 형태)은 칸이 여럿 쌓이면
  /// 무엇을 적는 칸인지 훑기 어렵다. 라벨을 고정 위치에 두면 위에서 아래로 읽힌다.
  /// 컨트롤러·검증기는 그대로 넘겨 동작은 바뀌지 않는다.
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
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 9, 13, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: AppColors.textTertiary,
                ),
              ),
              if (required)
                Text(
                  ' *',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
              // 테두리는 바깥 Container가 그린다. 안쪽 선이 겹치면 두 겹으로 보인다.
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.only(top: 2, bottom: 6),
              errorStyle: const TextStyle(fontSize: 11.5, height: 1.2),
            ),
          ),
        ],
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
