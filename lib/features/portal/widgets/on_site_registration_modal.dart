import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/portal_provider.dart';
import '../../../data/models/portal/on_site_registration.dart';
import '../utils/portal_translations.dart';

/// 현장 등록 모달
class OnSiteRegistrationModal extends ConsumerStatefulWidget {
  final int contestId;
  final String language;

  const OnSiteRegistrationModal({
    super.key,
    required this.contestId,
    required this.language,
  });

  @override
  ConsumerState<OnSiteRegistrationModal> createState() => _OnSiteRegistrationModalState();
}

class _OnSiteRegistrationModalState extends ConsumerState<OnSiteRegistrationModal> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _memoController = TextEditingController();
  String? _selectedRank;
  String? _selectedProvince;
  String? _selectedCity;
  bool _isSubmitting = false;

  String t(String key) => PortalTranslations.get(widget.language, key);

  // 기력 목록
  static const List<String> _ranks = [
    '9단', '8단', '7단', '6단', '5단', '4단', '3단', '2단', '1단',
    '1급', '2급', '3급', '4급', '5급', '6급', '7급', '8급', '9급',
    '10급', '11급', '12급', '13급', '14급', '15급', '16급', '17급', '18급',
    '19급', '20급', '21급', '22급', '23급', '24급', '25급', '26급', '27급',
    '28급', '29급', '30급'
  ];

  // 시/도 목록
  static const List<String> _provinces = [
    '서울특별시', '부산광역시', '대구광역시', '인천광역시', '광주광역시',
    '대전광역시', '울산광역시', '세종특별자치시', '경기도', '강원도',
    '충청북도', '충청남도', '전라북도', '전라남도', '경상북도', '경상남도', '제주특별자치도'
  ];

  // 시/군/구 목록 (간략화)
  Map<String, List<String>> get _cities => {
    '서울특별시': ['강남구', '강동구', '강북구', '강서구', '관악구', '광진구', '구로구', '금천구',
      '노원구', '도봉구', '동대문구', '동작구', '마포구', '서대문구', '서초구', '성동구',
      '성북구', '송파구', '양천구', '영등포구', '용산구', '은평구', '종로구', '중구', '중랑구'],
    '경기도': ['수원시', '성남시', '고양시', '용인시', '부천시', '안산시', '안양시', '남양주시',
      '화성시', '평택시', '의정부시', '시흥시', '파주시', '김포시', '광명시', '광주시',
      '군포시', '하남시', '오산시', '이천시', '안성시', '의왕시', '양주시', '포천시', '여주시'],
  };

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String value) {
    final numbers = value.replaceAll(RegExp(r'[^\d]'), '');
    if (numbers.length <= 3) return numbers;
    if (numbers.length <= 7) return '${numbers.substring(0, 3)}-${numbers.substring(3)}';
    return '${numbers.substring(0, 3)}-${numbers.substring(3, 7)}-${numbers.substring(7, numbers.length.clamp(7, 11))}';
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      _showError(t('onSiteRegNameRequired'));
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showError(t('onSiteRegPhoneRequired'));
      return;
    }

    setState(() => _isSubmitting = true);

    final request = OnSiteRegistrationRequest(
      participantName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      playerRank: _selectedRank,
      province: _selectedProvince,
      city: _selectedCity,
      memo: _memoController.text.trim().isNotEmpty ? _memoController.text.trim() : null,
    );

    final notifier = ref.read(portalProvider(widget.contestId).notifier);
    final result = await notifier.registerOnSite(request);

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (result.success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('onSiteRegSuccess')),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        _showError(result.message ?? t('onSiteRegFailed'));
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 40,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들바
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 헤더
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('onSiteRegTitle'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // 폼
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이름
                  _buildLabel(t('onSiteRegName'), required: true),
                  TextField(
                    controller: _nameController,
                    decoration: _inputDecoration(t('onSiteRegNamePlaceholder')),
                  ),
                  const SizedBox(height: 16),

                  // 전화번호
                  _buildLabel(t('onSiteRegPhone'), required: true),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    decoration: _inputDecoration(t('onSiteRegPhonePlaceholder')),
                    onChanged: (value) {
                      final formatted = _formatPhoneNumber(value);
                      if (formatted != value) {
                        _phoneController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // 기력
                  _buildLabel(t('onSiteRegRank')),
                  _buildDropdown(
                    value: _selectedRank,
                    hint: t('onSiteRegRankPlaceholder'),
                    items: _ranks,
                    onChanged: (value) => setState(() => _selectedRank = value),
                  ),
                  const SizedBox(height: 16),

                  // 시/도 & 시/군/구
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel(t('onSiteRegProvince')),
                            _buildDropdown(
                              value: _selectedProvince,
                              hint: t('onSiteRegProvincePlaceholder'),
                              items: _provinces,
                              onChanged: (value) {
                                setState(() {
                                  _selectedProvince = value;
                                  _selectedCity = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel(t('onSiteRegCity')),
                            _buildDropdown(
                              value: _selectedCity,
                              hint: t('onSiteRegCityPlaceholder'),
                              items: _cities[_selectedProvince] ?? [],
                              onChanged: (value) => setState(() => _selectedCity = value),
                              enabled: _selectedProvince != null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 메모
                  _buildLabel(t('onSiteRegMemo')),
                  TextField(
                    controller: _memoController,
                    maxLines: 3,
                    decoration: _inputDecoration(t('onSiteRegMemoPlaceholder')),
                  ),
                  const SizedBox(height: 24),

                  // 제출 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isSubmitting ? t('processing') : t('onSiteRegSubmit'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // 키보드 여백
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          if (required)
            const Text(
              ' *',
              style: TextStyle(color: AppColors.error),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textHint),
      filled: true,
      fillColor: AppColors.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: enabled ? AppColors.surfaceVariant : AppColors.border.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: TextStyle(color: AppColors.textHint)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item),
          )).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}
