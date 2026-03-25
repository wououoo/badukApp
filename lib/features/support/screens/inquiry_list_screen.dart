import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/support_provider.dart';
import '../../../data/services/support_service.dart';

/// 1:1 문의 목록 화면
class InquiryListScreen extends ConsumerWidget {
  const InquiryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inquiriesAsync = ref.watch(myInquiriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('1:1 문의'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: inquiriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              Text(
                '문의 내역을 불러올 수 없습니다.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(myInquiriesProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (inquiries) {
          if (inquiries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    '문의 내역이 없습니다.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '궁금한 점이 있으시면 문의해주세요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myInquiriesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: inquiries.length,
              itemBuilder: (context, index) {
                final inquiry = inquiries[index];
                return _InquiryTile(
                  inquiry: inquiry,
                  onTap: () => context.push('/support/inquiries/${inquiry.id}'),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/support/inquiries/create'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.edit, color: Colors.white),
        label: const Text('문의하기', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _InquiryTile extends StatelessWidget {
  final Inquiry inquiry;
  final VoidCallback onTap;

  const _InquiryTile({required this.inquiry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy.MM.dd');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                  const Spacer(),
                  Text(
                    dateFormat.format(inquiry.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                inquiry.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (inquiry.isAnswered && inquiry.answeredAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.reply, size: 14, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      '답변 완료 ${dateFormat.format(inquiry.answeredAt!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
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
}
