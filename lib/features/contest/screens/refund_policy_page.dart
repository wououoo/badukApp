import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/refund_policy_section.dart';

/// 환불 규정 전용 페이지.
/// 정책/문구/계산식은 RefundPolicySection(백엔드 /api/refund/registration-notice 단일소스)이 담당.
class RefundPolicyPage extends ConsumerWidget {
  final int homepageId;
  final String contestName;

  const RefundPolicyPage({
    super.key,
    required this.homepageId,
    required this.contestName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('환불 규정'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 대회명 헤더
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      contestName,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 환불 규정 (배너·정책표·안내문구 전부 백엔드 생성)
            RefundPolicySection(homepageId: homepageId, compact: false),
          ],
        ),
      ),
    );
  }
}
