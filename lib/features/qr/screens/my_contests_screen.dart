import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/mobile_qr_provider.dart';
import '../../../data/models/qr/my_contest.dart';

/// 내 참가 대회 목록 화면
class MyContestsScreen extends ConsumerWidget {
  const MyContestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mobileQRProvider);
    final notifier = ref.read(mobileQRProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('내 대회'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: state.isLoading ? null : () => notifier.refresh(),
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(context, ref, state, notifier),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    MobileQRState state,
    MobileQRNotifier notifier,
  ) {
    if (state.isLoading && state.contests.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.error != null && state.contests.isEmpty) {
      return _buildError(context, state.error!, notifier);
    }

    if (state.contests.isEmpty) {
      return _buildEmpty(context, notifier);
    }

    // 같은 대회의 여러 부문을 하나의 카드로 그룹핑
    // contestId + contestType으로 그룹핑하여 다른 타입은 별도 카드로 분리
    final grouped = <String, List<MyContest>>{};
    for (final c in state.contests) {
      final key = '${c.contestId}_${c.contestType}';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(c);
    }
    final groupedList = grouped.values.toList();
    debugPrint('[내대회] 전체 ${state.contests.length}건 → 그룹 ${groupedList.length}개: ${grouped.keys.toList()}');

    return RefreshIndicator(
      onRefresh: () => notifier.refresh(),
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupedList.length,
        itemBuilder: (context, index) {
          final contests = groupedList[index];
          if (contests.length == 1) {
            return _buildContestCard(context, ref, contests.first);
          }
          return _buildGroupedContestCard(context, ref, contests);
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, String error, MobileQRNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              error,
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => notifier.refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, MobileQRNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '참가 중인 대회가 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '대회에 등록하면 여기에 표시됩니다',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => notifier.refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('새로고침'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContestCard(BuildContext context, WidgetRef ref, MyContest contest) {
    final dateFormat = DateFormat('MM/dd');
    final notifier = ref.read(mobileQRProvider.notifier);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: contest.checkedIn
              ? AppColors.success.withOpacity(0.3)
              : AppColors.border,
        ),
      ),
      color: AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.push('/qr/contest/${contest.contestId}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 대회명 + 체크인 상태
              Row(
                children: [
                  Expanded(
                    child: Text(
                      contest.contestName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (contest.checkedIn)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: AppColors.success),
                          SizedBox(width: 4),
                          Text(
                            '체크인 완료',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // 부문명 + 대회 타입
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      contest.contestTypeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    contest.sortName,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (contest.teamName != null) ...[
                    Text(' / ', style: TextStyle(color: AppColors.textSecondary)),
                    Text(
                      contest.teamName!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // 날짜 + 현재 라운드 정보
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary.withOpacity(0.7)),
                  const SizedBox(width: 4),
                  Text(
                    contest.startDate != null
                        ? (contest.endDate != null && contest.startDate != contest.endDate
                            ? '${dateFormat.format(contest.startDate!)} ~ ${dateFormat.format(contest.endDate!)}'
                            : dateFormat.format(contest.startDate!))
                        : '-',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withOpacity(0.8),
                    ),
                  ),
                  const Spacer(),
                  if (contest.currentRound > 0) ...[
                    Text(
                      '${contest.currentRound}R',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (contest.opponent != null) ...[
                      Text(' vs ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Flexible(
                        child: Text(
                          contest.opponent!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ],
              ),

              // 동명이인 선택 버튼 (선택 필요한 경우)
              if (contest.needsSelection && contest.candidates.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.help_outline, size: 16, color: AppColors.warning),
                          SizedBox(width: 8),
                          Text(
                            '동명이인이 있습니다',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _showCandidateSelectionDialog(context, ref, contest),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.warning,
                            side: const BorderSide(color: AppColors.warning),
                          ),
                          child: const Text('본인 선택하기'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

            ],
          ),
        ),
      ),
    );
  }

  /// 같은 대회의 여러 부문을 하나의 카드로 표시
  Widget _buildGroupedContestCard(BuildContext context, WidgetRef ref, List<MyContest> contests) {
    final primary = contests.first;
    final dateFormat = DateFormat('MM/dd');

    // 어느 하나라도 체크인 되어있으면
    final anyCheckedIn = contests.any((c) => c.checkedIn);

    // 가장 높은 라운드 정보를 가진 것
    final active = contests.reduce((a, b) => a.currentRound >= b.currentRound ? a : b);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: anyCheckedIn ? AppColors.success.withOpacity(0.3) : AppColors.border,
        ),
      ),
      color: AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.push('/qr/contest/${primary.contestId}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 대회명 + 체크인
              Row(
                children: [
                  Expanded(
                    child: Text(
                      primary.contestName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (anyCheckedIn)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: AppColors.success),
                          SizedBox(width: 4),
                          Text(
                            '체크인 완료',
                            style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // 대회 타입 + 부문 칩들
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      primary.contestTypeLabel,
                      style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                    ),
                  ),
                  for (final c in contests)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        c.sortName,
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // 날짜 + 현재 라운드
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary.withOpacity(0.7)),
                  const SizedBox(width: 4),
                  Text(
                    primary.startDate != null
                        ? (primary.endDate != null && primary.startDate != primary.endDate
                            ? '${dateFormat.format(primary.startDate!)} ~ ${dateFormat.format(primary.endDate!)}'
                            : dateFormat.format(primary.startDate!))
                        : '-',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.8)),
                  ),
                  const Spacer(),
                  if (active.currentRound > 0) ...[
                    Text(
                      '${active.currentRound}R',
                      style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                    ),
                    if (active.opponent != null) ...[
                      Text(' vs ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Flexible(
                        child: Text(
                          active.opponent!,
                          style: TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCandidateSelectionDialog(BuildContext context, WidgetRef ref, MyContest contest) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // 핸들
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 제목
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '본인을 선택하세요',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '동일한 이름의 참가자가 여러 명 있습니다.\n본인 정보를 선택해주세요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 후보 목록
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: contest.candidates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final candidate = contest.candidates[index];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        Navigator.pop(context);
                        final notifier = ref.read(mobileQRProvider.notifier);
                        final result = await notifier.linkParticipant(
                          contest.contestId,
                          candidate.participantId,
                          candidate.gameRoomId,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result.message ?? (result.success ? '연결 완료!' : '연결 실패')),
                              backgroundColor: result.success ? AppColors.success : AppColors.error,
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${candidate.participantNumber ?? index + 1}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    candidate.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    candidate.displayDescription,
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
