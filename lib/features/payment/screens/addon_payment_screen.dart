import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/homepage_service.dart';
import '../../../data/services/payment_service.dart';
import '../../contest/widgets/registration_option_selector.dart';
import '../widgets/payment_terms_consent.dart';

/// 추가결제 화면 — 이미 신청을 마친 건에 유료 항목(숙박 등)을 더 산다.
///
/// 신청 자체는 건드리지 않고 별도 결제(isAddon)만 만든다. 그래서 참가비·정원·신청 상태는 그대로다.
/// 금액은 서버(prepare)가 확정하며, 이 화면은 옵션값만 미리 보여준다 — 결제수수료는 대회 설정값이라
/// 앱이 하드코딩하지 않고 다음 결제 화면에서 실제 청구액으로 표시된다.
class AddonPaymentScreen extends StatefulWidget {
  final int registrationId;
  final int homepageId;
  final int? categoryId;
  final String contestName;

  const AddonPaymentScreen({
    super.key,
    required this.registrationId,
    required this.homepageId,
    required this.contestName,
    this.categoryId,
  });

  @override
  State<AddonPaymentScreen> createState() => _AddonPaymentScreenState();
}

class _AddonPaymentScreenState extends State<AddonPaymentScreen> {
  final _homepageService = HomepageService();
  final _paymentService = PaymentService();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  bool _payTermsAgreed = false; // 결제 전 필수 동의(결제·환불/전자금융)

  /// 유료 선택지가 하나라도 있는 옵션 정의만 남긴 목록
  List<Map<String, dynamic>> _paidDefs = [];
  List<Map<String, dynamic>> _payload = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final defs = await _homepageService.getRegistrationOptions(
        widget.homepageId,
        categoryId: widget.categoryId,
      );

      // 추가로 "살 수 있는" 것만 남긴다 = 유료 선택지가 있는 옵션.
      // required는 신청 때 이미 받은 값이므로 추가결제에서는 강제하지 않는다(false로 덮어씀).
      final paid = <Map<String, dynamic>>[];
      for (final d in defs) {
        final choices = (d['choices'] as List?) ?? [];
        final hasPaid = choices.any((c) =>
            c is Map && c['extraFee'] != null && (c['extraFee'] as num) > 0);
        if (!hasPaid) continue;
        paid.add({...d, 'required': false});
      }

      if (!mounted) return;
      setState(() {
        _paidDefs = paid;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '추가 가능한 항목을 불러오지 못했습니다.';
        _loading = false;
      });
    }
  }

  /// 선택한 옵션의 금액 합 (choice.extraFee × 수량).
  /// 백엔드 calcExtraFeeFromPayload와 같은 공식이어야 표시액과 청구액이 어긋나지 않는다.
  int _computeOptionFee() {
    int total = 0;
    for (final sel in _payload) {
      final key = sel['key'];
      Map<String, dynamic>? def;
      for (final d in _paidDefs) {
        if (d['key'] == key) {
          def = d;
          break;
        }
      }
      if (def == null) continue;

      final type = (def['type'] ?? 'SINGLE_SELECT').toString();
      if (type == 'TEXT' || type == 'NUMBER') continue; // 텍스트/숫자는 무과금

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

  String _formatNumber(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  Future<void> _submit() async {
    final optionFee = _computeOptionFee();
    if (optionFee <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('추가할 항목을 선택해주세요.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final payment = await _paymentService.prepareAddonPayment(
        registrationId: widget.registrationId,
        options: _payload,
        addonReason: '옵션 추가',
      );

      if (!mounted) return;
      final ok = await context.push<bool>(
        '/payment/toss-checkout',
        extra: {
          'orderId': payment.orderId,
          'amount': payment.amount,
          'orderName': '${widget.contestName} - 옵션 추가결제',
          'registrationId': widget.registrationId,
        },
      );

      if (!mounted) return;
      if (ok == true) {
        // 결제(가상계좌 발급 포함)까지 끝났으면 호출한 화면이 목록을 새로고침하도록 true로 닫는다.
        context.pop(true);
      } else {
        setState(() => _submitting = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final optionFee = _computeOptionFee();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('항목 추가결제'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: TextStyle(color: AppColors.textSecondary)))
              : _paidDefs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          '이 대회에는 추가로 신청할 수 있는 유료 항목이 없습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.contestName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '이미 신청한 건에 항목만 더 결제합니다. 참가비는 다시 청구되지 않습니다.',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 20),
                          RegistrationOptionSelector(
                            definitions: _paidDefs,
                            onChanged: (payload, _) {
                              setState(() => _payload = payload);
                            },
                          ),
                          const SizedBox(height: 16),
                          PaymentTermsConsent(
                            onChanged: (v) => setState(() => _payTermsAgreed = v),
                          ),
                        ],
                      ),
                    ),
      bottomNavigationBar: (_loading || _paidDefs.isEmpty)
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text('추가 항목 금액',
                            style: TextStyle(
                                fontSize: 14, color: AppColors.textSecondary)),
                        const Spacer(),
                        Text(
                          '₩${_formatNumber(optionFee)}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '결제 수수료가 더해진 최종 금액은 다음 화면에서 확인됩니다.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed:
                            (_submitting || optionFee <= 0 || !_payTermsAgreed) ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                (optionFee > 0 && !_payTermsAgreed) ? '필수 약관에 동의해 주세요' : '결제하기',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
