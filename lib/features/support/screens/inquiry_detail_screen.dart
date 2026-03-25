import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/support_provider.dart';

/// 문의 상세 화면
class InquiryDetailScreen extends ConsumerWidget {
  final int inquiryId;

  const InquiryDetailScreen({super.key, required this.inquiryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inquiryAsync = ref.watch(inquiryDetailProvider(inquiryId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('문의 상세'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          inquiryAsync.whenOrNull(
            data: (inquiry) => inquiry.isPending
                ? IconButton(
                    onPressed: () => _showDeleteDialog(context, ref),
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.error,
                  )
                : null,
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: inquiryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              Text(
                '문의를 불러올 수 없습니다.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        data: (inquiry) {
          final dateFormat = DateFormat('yyyy년 MM월 dd일 HH:mm');

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 문의 내용
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: AppColors.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildStatusBadge(inquiry.status),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              inquiry.category,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        inquiry.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dateFormat.format(inquiry.createdAt),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        inquiry.content ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                // 답변
                if (inquiry.isAnswered && inquiry.answer != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.support_agent, size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              '답변',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            const Spacer(),
                            if (inquiry.answeredAt != null)
                              Text(
                                dateFormat.format(inquiry.answeredAt!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          inquiry.answer!,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 답변 대기 안내
                if (inquiry.isPending) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_empty, color: AppColors.textTertiary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '답변을 준비 중입니다. 빠른 시일 내에 답변 드리겠습니다.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String text;

    switch (status) {
      case 'PENDING':
        bgColor = AppColors.warning.withOpacity(0.1);
        textColor = AppColors.warning;
        text = '답변 대기';
        break;
      case 'ANSWERED':
        bgColor = AppColors.success.withOpacity(0.1);
        textColor = AppColors.success;
        text = '답변 완료';
        break;
      default:
        bgColor = AppColors.textTertiary.withOpacity(0.1);
        textColor = AppColors.textTertiary;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('문의 삭제'),
        content: const Text('이 문의를 삭제하시겠습니까?\n삭제된 문의는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final service = ref.read(supportServiceProvider);
        await service.deleteInquiry(inquiryId);
        ref.invalidate(myInquiriesProvider);
        if (context.mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('문의가 삭제되었습니다.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          debugPrint('[Error] 삭제 실패: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('삭제에 실패했습니다. 다시 시도해주세요.')),
          );
        }
      }
    }
  }
}
