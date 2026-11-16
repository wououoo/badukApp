import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/api_client.dart';
import '../../../data/services/homepage_service.dart';
import '../../contest/widgets/registration_option_selector.dart';
import 'my_registrations_screen.dart';

/// 참가신청 수정 화면 (부문, 지역, 소속 수정 가능)
class RegistrationEditScreenV2 extends ConsumerStatefulWidget {
  final int registrationId;
  final Map<String, dynamic>? currentData;

  const RegistrationEditScreenV2({
    super.key,
    required this.registrationId,
    this.currentData,
  });

  @override
  ConsumerState<RegistrationEditScreenV2> createState() => _RegistrationEditScreenV2State();
}

class _RegistrationEditScreenV2State extends ConsumerState<RegistrationEditScreenV2> {
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

  // 추가 옵션(숙박·셔틀·단급증 번호·서약서 등) — 신청 때와 같은 위젯 재사용
  final HomepageService _homepageService = HomepageService();
  List<Map<String, dynamic>> _optionDefs = [];
  Map<String, dynamic> _optionInitial = {}; // key -> {values, text, quantities}
  List<Map<String, dynamic>> _optionPayload = [];
  bool _optionsValid = true;
  // 사용자가 옵션을 실제로 건드렸을 때만 서버로 보낸다(안 건드리면 생략 → 유료옵션/수량/서약서 무손상).
  bool _optionsTouched = false;
  int _optionReportCount = 0;

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
    _buildOptionInitial();
    _loadCategories();
    _loadOptions();
  }

  /// 현재 저장된 옵션 답변을 위젯 프리필 형태(key -> {values, text, quantities})로 변환.
  /// 서버 답변 행: {optionKey, textValue, choiceValue, quantity, ...}.
  ///  - 무료 텍스트(단급증 번호 등): textValue → text
  ///  - 선택형(숙박 등): choiceValue → values, quantity → quantities
  ///  - 서약서(AGREEMENT): choiceValue=처분이력, textValue=작성내용(JSON) 둘 다 보존해야
  ///    재전송 시 서버가 서약 증빙을 무손실 복원(resolveAgreementForm 폴백). decl 없으면 'AGREED'로 동의 표시.
  void _buildOptionInitial() {
    final raw = widget.currentData?['options'];
    if (raw is! List) return;
    final map = <String, Map<String, dynamic>>{};
    for (final o in raw) {
      if (o is! Map) continue;
      final key = (o['optionKey'] ?? '').toString();
      if (key.isEmpty) continue;
      final entry = map.putIfAbsent(
          key, () => {'values': <String>[], 'text': '', 'quantities': <String, int>{}});
      final text = (o['textValue'] ?? '').toString();
      final choiceValue = (o['choiceValue'] ?? '').toString();
      if (choiceValue.isNotEmpty) {
        (entry['values'] as List<String>).add(choiceValue);
        final qty = (o['quantity'] as num?)?.toInt() ?? 1;
        if (qty > 1) (entry['quantities'] as Map<String, int>)[choiceValue] = qty;
      }
      if (text.isNotEmpty) {
        entry['text'] = text;
      }
    }
    // 서약서(처분이력 없이 동의만 한 경우) — choiceValue가 비고 text가 JSON이면 동의로 표시.
    map.forEach((k, e) {
      final vals = e['values'] as List<String>;
      final t = (e['text'] ?? '').toString().trimLeft();
      if (vals.isEmpty && t.startsWith('{')) {
        vals.add('AGREED');
      }
    });
    _optionInitial = map;
  }

  Future<void> _loadOptions() async {
    final homepageId = widget.currentData?['homepageId'];
    if (homepageId == null) return;
    try {
      final defs = await _homepageService.getRegistrationOptions(
        homepageId is int ? homepageId : int.tryParse(homepageId.toString()) ?? 0,
        categoryId: _selectedCategoryId,
      );
      if (!mounted) return;
      setState(() => _optionDefs = defs);
    } catch (e) {
      debugPrint('[옵션 정의 조회 실패] $e');
    }
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

    // 옵션을 건드렸는데 필수 항목이 비면 저장 막기(신청 화면과 동일 규칙)
    if (_optionsTouched && !_optionsValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 추가 항목을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiClient = ApiClient();
      final body = <String, dynamic>{
        'categoryId': _selectedCategoryId?.toString(),
        'region': _selectedRegion,
        'club': _clubController.text.trim(),
        'participantName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'rank': _selectedRank,
      };
      // 사용자가 옵션을 실제로 수정한 경우에만 전송(미수정 시 생략 → 유료옵션/서약서/수량 무손상).
      if (_optionsTouched) {
        body['options'] = _optionPayload;
      }
      final response = await apiClient.put(
        '${ApiConstants.myRegistrationUpdate}/${widget.registrationId}',
        data: body,
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
        title: const Text('참가신청 수정',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
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
              _fieldLabel('이름'),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('이름을 입력하세요'),
                validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력하세요' : null,
              ),
              const SizedBox(height: 20),

              // 연락처
              _fieldLabel('연락처'),
              TextFormField(
                controller: _phoneController,
                decoration: _inputDecoration('연락처를 입력하세요'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),

              // 기력
              _fieldLabel('기력'),
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
              _fieldLabel('부문'),
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
                      decoration: _inputDecoration('부문은 직접 변경 불가'),
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
                      // 부문 변경은 정원 race / 결제 정합성 문제로 항상 차단. 취소 후 재신청만 가능.
                      onChanged: null,
                    ),
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '부문은 직접 변경할 수 없습니다. 취소 후 원하시는 부문으로 재신청해주세요.',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ),
              const SizedBox(height: 20),

              // 지역
              _fieldLabel('지역'),
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
              _fieldLabel('소속/클럽'),
              TextFormField(
                controller: _clubController,
                decoration: _inputDecoration('소속 또는 클럽명을 입력하세요'),
              ),
              const SizedBox(height: 32),

              // 추가 항목(숙박·셔틀·단급증 번호·서약서 등) — 신청 때와 동일 위젯.
              //  건드리지 않으면 전송하지 않는다(유료옵션/수량/서약서 보존). 유료옵션 금액을
              //  바꾸려 하면 서버가 '추가결제/환불로' 안내하며 막는다.
              if (_optionDefs.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 12),
                _fieldLabel('추가 항목'),
                const SizedBox(height: 8),
                RegistrationOptionSelector(
                  definitions: _optionDefs,
                  initial: _optionInitial,
                  onChanged: (payload, valid) {
                    _optionPayload = payload;
                    _optionsValid = valid;
                    _optionReportCount++;
                    // 첫 보고는 프리필(초기값) → 그 다음 보고부터 사용자가 수정한 것으로 본다.
                    if (_optionReportCount > 1) _optionsTouched = true;
                  },
                ),
                const SizedBox(height: 24),
              ],

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
                      : const Text('수정하기',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// 칸 위에 붙는 작은 라벨. 참가신청 화면과 같은 크기·무게라야
  /// 같은 정보를 적는 자리로 읽힌다.
  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: AppColors.textSecondary,
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
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
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
