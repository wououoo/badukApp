import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/host_operation.dart';
import '../../../data/providers/host_operation_provider.dart';

/// A2 — 대회 운영 홈: 부문(운영 단위) 목록
class HostContestDetailScreen extends ConsumerWidget {
  final int homepageId;
  final String? title;
  const HostContestDetailScreen({super.key, required this.homepageId, this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(contestSectionsProvider(homepageId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title ?? '대회 운영')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.refresh(contestSectionsProvider(homepageId).future),
        child: sectionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            Center(child: Text('불러오지 못했습니다', style: TextStyle(color: AppColors.textSecondary))),
          ]),
          data: (sections) {
            if (sections.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 120),
                Icon(Icons.grid_view_outlined, size: 52, color: AppColors.textHint),
                const SizedBox(height: 14),
                Center(child: Text('부문이 없습니다', style: TextStyle(color: AppColors.textSecondary))),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _SectionCard(homepageId: homepageId, section: sections[i]),
            );
          },
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final int homepageId;
  final ContestSection section;
  const _SectionCard({required this.homepageId, required this.section});

  @override
  Widget build(BuildContext context) {
    final operable = section.appOperable;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: operable
            ? () {
                // 단체 풀리그는 시작에 teamSize(=장 수)가 필요 → Map extra 로 전달
                if (section.isTeamFullLeague) {
                  context.push(
                    '/host/operation/$homepageId/team-full-league/${section.gameRoomId}',
                    extra: {'sortName': section.sortName, 'teamSize': section.teamSize ?? 0},
                  );
                  return;
                }
                final kind = section.isMcMahon
                    ? 'mcmahon'
                    : section.isTeamSwiss
                        ? 'team-swiss'
                        : section.isFullLeague
                            ? 'full-league'
                            : section.isTournament
                                ? 'tournament'
                                : section.isDoubleElimination
                                    ? 'de'
                                    : 'swiss';
                context.push(
                  '/host/operation/$homepageId/$kind/${section.gameRoomId}',
                  extra: section.sortName,
                );
              }
            : () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${section.type} 부문은 아직 앱 운영을 지원하지 않습니다.')),
                ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(section.sortName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        ),
                        const SizedBox(width: 8),
                        _typePill(section.type),
                      ],
                    ),
                    const SizedBox(height: 7),
                    _stateLine(section),
                  ],
                ),
              ),
              Icon(
                operable ? Icons.chevron_right : Icons.lock_outline,
                color: operable ? AppColors.textTertiary : AppColors.textHint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typePill(String type) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(999)),
        child: Text(type.isEmpty ? '부문' : type,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
      );

  Widget _stateLine(ContestSection s) {
    String label;
    Color color;
    if (s.gameStarted) {
      label = '진행 중';
      color = AppColors.statusLive;
    } else {
      label = '편성 대기';
      color = AppColors.statusSoon;
    }
    return Row(
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        if (s.teamSize != null && s.teamSize! > 0) ...[
          Text('  ·  ${s.teamSize}장제', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
        ],
      ],
    );
  }
}
