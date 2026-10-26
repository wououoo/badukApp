import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 결제 시점 필수 동의 — 결제·환불 규정 / 전자금융거래 이용·결제대행.
///  결제 화면(PaymentScreenV2)과 추가결제 화면(AddonPaymentScreen)이 함께 쓴다.
///  법적 문구가 두 화면에서 갈라지지 않도록 '한 곳'에서만 정의한다.
///  onChanged(allAgreed): 두 필수 항목이 모두 체크됐는지(버튼 게이트용).
class PaymentTermsConsent extends StatefulWidget {
  final ValueChanged<bool> onChanged;

  const PaymentTermsConsent({super.key, required this.onChanged});

  // 결제·환불 규정 전문. 가상계좌 30분 자동취소는 va-expiry 정책과 동일.
  static const String kPayRefundTerms =
      '[결제 방식]\n'
      '- 가상계좌(계좌이체) 입금 방식으로 진행됩니다.\n'
      '- 버튼을 누르면 입금용 계좌가 발급되며, 이 시점에는 돈이 빠져나가지 않습니다.\n'
      '- 발급 후 30분 이내에 해당 계좌로 입금해야 하며, 기한을 넘기면 신청이 자동으로 취소됩니다.\n'
      '- 입금자명이 신청 정보와 다르면 입금 확인이 지연·반려될 수 있습니다.\n\n'
      '[환불 규정]\n'
      '- 환불은 대회가 정한 환불 규정 및 마감 기준에 따릅니다.\n'
      '- 접수 마감 또는 대회가 정한 환불 가능 기간이 지나면 환불이 제한될 수 있습니다.\n'
      '- 환불 시 결제대행 수수료 등 실비가 공제될 수 있습니다.\n'
      '- 자세한 환불 금액·기준은 대회 홈페이지의 환불 안내를 따릅니다.';

  // 전자금융거래/결제대행(PG) 이용 동의 전문.
  static const String kEftTerms =
      '- 본 결제는 토스페이먼츠(주)의 결제대행 서비스를 통해 처리됩니다.\n'
      '- 결제 진행을 위해 주문정보·결제수단 정보가 결제대행사에 제공됩니다.\n'
      '- 전자금융거래 이용약관 및 결제대행 서비스 이용에 동의합니다.\n'
      '- 결제 및 정산 과정은 관련 법령과 결제대행사의 약관에 따릅니다.';

  @override
  State<PaymentTermsConsent> createState() => _PaymentTermsConsentState();
}

class _PaymentTermsConsentState extends State<PaymentTermsConsent> {
  bool _agreedPayRefund = false;
  bool _agreedEft = false;
  final Set<String> _open = {};

  void _emit() => widget.onChanged(_agreedPayRefund && _agreedEft);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '결제 전 동의',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _item(
            keyId: 'refund',
            value: _agreedPayRefund,
            onChanged: (v) => setState(() {
              _agreedPayRefund = v;
              _emit();
            }),
            title: '[필수] 결제·환불 규정 동의',
            summary: '가상계좌 30분 입금기한·자동취소 및 환불 규정을 확인했습니다.',
            fullText: PaymentTermsConsent.kPayRefundTerms,
          ),
          const SizedBox(height: 8),
          _item(
            keyId: 'eft',
            value: _agreedEft,
            onChanged: (v) => setState(() {
              _agreedEft = v;
              _emit();
            }),
            title: '[필수] 전자금융거래 이용·결제대행 동의',
            summary: '토스페이먼츠(주)를 통한 결제 처리 및 정보 제공에 동의합니다.',
            fullText: PaymentTermsConsent.kEftTerms,
          ),
        ],
      ),
    );
  }

  Widget _item({
    required String keyId,
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    required String summary,
    required String fullText,
  }) {
    final open = _open.contains(keyId);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value ? AppColors.primary.withValues(alpha: 0.05) : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: value,
                  onChanged: (v) => onChanged(v ?? false),
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(!value),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(summary,
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary, height: 1.35)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 6),
            child: GestureDetector(
              onTap: () => setState(() {
                if (open) {
                  _open.remove(keyId);
                } else {
                  _open.add(keyId);
                }
              }),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(open ? '약관 전문 닫기' : '약관 전문 보기',
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline)),
                  Icon(open ? Icons.expand_less : Icons.expand_more, size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ),
          if (open)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(left: 34, top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: SelectableText(fullText,
                  style: TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }
}
