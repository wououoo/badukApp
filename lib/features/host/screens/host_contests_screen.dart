import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/host_operation.dart';
import '../../../data/providers/host_operation_provider.dart';

/// A1 — 주최자 대회 운영 진입: 내가 운영할 대회 목록
class HostContestsScreen extends ConsumerWidget {
  const HostContestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contestsAsync = ref.watch(hostContestsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('대회 운영')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.refresh(hostContestsProvider.future),
        child: contestsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => _error(context, ref),
          data: (contests) {
            if (contests.isEmpty) {
              return _empty();
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: contests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _ContestCard(contest: contests[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _empty() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.emoji_events_outlined, size: 56, color: AppColors.textHint),
        const SizedBox(height: 16),
        Center(
          child: Text('운영할 대회가 없습니다',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _error(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.error_outline, size: 56, color: AppColors.textHint),
        const SizedBox(height: 12),
        Center(child: Text('불러오지 못했습니다', style: TextStyle(color: AppColors.textSecondary))),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => ref.refresh(hostContestsProvider),
            child: const Text('다시 시도'),
          ),
        ),
      ],
    );
  }
}

class _ContestCard extends StatelessWidget {
  final HostContest contest;
  const _ContestCard({required this.contest});

  @override
  Widget build(BuildContext context) {
    final disabled = !contest.operable;
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: disabled
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('아직 대회 엔진에 연결되지 않아 운영할 수 없습니다. 관리자에게 문의하세요.')),
                  )
              : () => context.push('/host/operation/${contest.homepageId}',
                  extra: contest.title),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _statusBadge(contest.contestStatus),
                    if (!contest.operable) ...[
                      const SizedBox(width: 6),
                      _pill('엔진 미연결', AppColors.statusClosedText, AppColors.statusClosedBg),
                    ],
                    const Spacer(),
                    if (contest.contestStartDate != null)
                      Text(_fmtDate(contest.contestStartDate!),
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  ],
                ),
                const SizedBox(height: 9),
                Text(contest.title,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('${contest.categoryCount}개 부문 · 신청 ${contest.registrationCount}명',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg = AppColors.statusClosedBg, tx = AppColors.statusClosedText;
    String label = status.isEmpty ? '대회' : status;
    if (status.contains('진행') || status.toUpperCase().contains('LIVE') || status.toUpperCase().contains('ONGOING')) {
      bg = AppColors.statusLiveBg; tx = AppColors.statusLiveText; label = '진행 중';
    } else if (status.contains('접수') || status.toUpperCase().contains('OPEN')) {
      bg = AppColors.statusOpenBg; tx = AppColors.statusOpenText; label = '접수 중';
    } else if (status.contains('예정') || status.toUpperCase().contains('UPCOMING')) {
      bg = AppColors.statusSoonBg; tx = AppColors.statusSoonText; label = '예정';
    }
    return _pill(label, tx, bg);
  }

  Widget _pill(String text, Color tx, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tx)),
      );

  String _fmtDate(DateTime d) => '${d.month}.${d.day}';
}
