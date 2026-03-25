import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/portal_provider.dart';
import '../../../data/models/portal/portal_participant.dart';
import '../../../data/models/portal/round_result.dart';
import '../../../data/models/portal/ranking.dart';
import '../utils/portal_translations.dart';

/// 포털 상세 화면
class PortalDetailScreen extends ConsumerStatefulWidget {
  final int contestId;
  final PortalParticipant participant;

  const PortalDetailScreen({
    super.key,
    required this.contestId,
    required this.participant,
  });

  @override
  ConsumerState<PortalDetailScreen> createState() => _PortalDetailScreenState();
}

class _PortalDetailScreenState extends ConsumerState<PortalDetailScreen> {
  String _language = 'ko';
  int? _selectedRound;
  bool _showRankings = false;
  String _rankingSortBy = 'wins';  // wins: 승수순, score: 점수순 (MCM 전용)

  String t(String key) => PortalTranslations.get(_language, key);

  @override
  Widget build(BuildContext context) {
    final maxRoundAsync = ref.watch(maxRoundProvider(MaxRoundParams(
      contestId: widget.contestId,
      gameRoomId: widget.participant.gameRoomId,
    )));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 네비게이션
            _buildNavBar(),

            // 콘텐츠
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 참가자 헤더
                    _buildParticipantHeader(),
                    const SizedBox(height: 20),

                    // 현재 경기 정보
                    _buildCurrentMatchCard(),
                    const SizedBox(height: 20),

                    // 라운드 선택
                    maxRoundAsync.when(
                      data: (maxRound) => maxRound > 0
                          ? _buildRoundSelector(maxRound)
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    // 선택된 라운드 결과
                    if (_selectedRound != null) ...[
                      const SizedBox(height: 16),
                      _buildRoundResults(),
                    ],
                    const SizedBox(height: 20),

                    // 순위표 버튼
                    _buildRankingsButton(),

                    // 순위표
                    if (_showRankings) ...[
                      const SizedBox(height: 16),
                      _buildRankingsTable(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, size: 20),
            label: Text(t('back')),
            style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
          ),
          Row(
            children: [
              _buildLanguageButton('ko', '한국어'),
              const SizedBox(width: 8),
              _buildLanguageButton('en', 'EN'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageButton(String code, String label) {
    final isSelected = _language == code;
    return InkWell(
      onTap: () => setState(() => _language = code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantHeader() {
    final p = widget.participant;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildBadge(p.sortName ?? '', AppColors.statusLiveBg, AppColors.statusLiveText),
                    if (p.contestType != null)
                      _buildBadge(
                        t('contestType_${p.contestType}'),
                        AppColors.primaryLight.withOpacity(0.1),
                        AppColors.primaryLight,
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // TODO: Refresh participant
            },
            icon: Icon(Icons.refresh, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildCurrentMatchCard() {
    final p = widget.participant;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${t('currentRound')}: ${p.currentRound}R',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          if (p.opponent != null) ...[
            _buildMatchInfoRow(t('opponent'), p.opponent!),
            if (p.matchNumber != null && p.matchNumber! > 0)
              _buildMatchInfoRow(t('matchNumber'), '${p.matchNumber}'),
            _buildMatchInfoRow(
              '',
              p.matchStatusLabel,
              isStatus: true,
              status: p.matchStatus,
            ),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  t('noOpponent'),
                  style: TextStyle(color: AppColors.textTertiary),
                ),
              ),
            ),

          // 맥마흔 전용 정보
          if (p.contestType == 'MCM') ...[
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (p.mcmahonRank != null)
                  _buildStatItem(p.mcmahonRank!, '기력'),
                _buildStatItem(
                  '${p.wins ?? 0}${t('mcmWins')} ${p.losses ?? 0}${t('mcmLosses')}',
                  '전적',
                ),
                if (p.mcmahonScore != null)
                  _buildStatItem('${p.mcmahonScore}', t('mcmScore')),
              ],
            ),
          ],

          // 팀 스위스 팀원 정보
          if (p.contestType == 'TEAM_SWISS' && p.teamMembers != null) ...[
            const Divider(height: 32),
            Text(
              t('teamMembers'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: p.teamMembers!.map((m) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: m.isNone ? AppColors.border : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${m.boardNumber}. ${m.memberName}',
                  style: TextStyle(
                    fontSize: 13,
                    color: m.isNone ? AppColors.textTertiary : AppColors.textPrimary,
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchInfoRow(String label, String value, {bool isStatus = false, String? status}) {
    Color? statusColor;
    if (isStatus) {
      switch (status) {
        case 'waiting':
          statusColor = AppColors.statusSoon;
          break;
        case 'in_progress':
          statusColor = AppColors.statusLive;
          break;
        case 'completed':
          statusColor = AppColors.statusOpen;
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (label.isNotEmpty)
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          if (isStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor?.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            )
          else
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildRoundSelector(int maxRound) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('roundResults'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(maxRound, (i) {
              final round = i + 1;
              final isSelected = _selectedRound == round;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedRound = isSelected ? null : round;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${round}R',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundResults() {
    final resultsAsync = ref.watch(roundResultsProvider(RoundResultParams(
      contestId: widget.contestId,
      participantId: widget.participant.participantId,
      gameRoomId: widget.participant.gameRoomId,
      round: _selectedRound!,
    )));

    return resultsAsync.when(
      data: (result) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_selectedRound R ${t('roundResults')}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (result.matches.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('결과 없음', style: TextStyle(color: AppColors.textTertiary)),
                ),
              )
            else
              ...result.matches.map((match) => _buildMatchResultItem(match)),
          ],
        ),
      ),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('결과를 불러올 수 없습니다', style: TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }

  Widget _buildMatchResultItem(MatchResult match) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              match.player1 ?? '-',
              style: TextStyle(
                fontSize: 14,
                fontWeight: match.isPlayer1Winner ? FontWeight.bold : FontWeight.normal,
                color: match.isPlayer1Winner ? AppColors.statusOpen : AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            ' vs ',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          Expanded(
            child: Text(
              match.isBye ? t('byeMatch') : (match.player2 ?? '-'),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: match.isPlayer2Winner ? FontWeight.bold : FontWeight.normal,
                color: match.isBye
                    ? AppColors.textTertiary
                    : (match.isPlayer2Winner ? AppColors.statusOpen : AppColors.textPrimary),
              ),
            ),
          ),
          if (match.tableNumber != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${match.tableNumber}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRankingsButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => setState(() => _showRankings = !_showRankings),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(
            color: _showRankings ? AppColors.primary : AppColors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _showRankings ? t('close') : t('viewRankings'),
          style: TextStyle(
            color: _showRankings ? AppColors.primary : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildRankingsTable() {
    // sortId 사용 (없으면 gameRoomId 폴백)
    final sortId = widget.participant.sortId ?? widget.participant.gameRoomId;
    final isMcMahon = widget.participant.contestType == 'MCM';

    final rankingsAsync = ref.watch(rankingsProvider(RankingsParams(
      contestId: widget.contestId,
      sortId: sortId,
      sortBy: _rankingSortBy,
    )));

    return rankingsAsync.when(
      data: (rankings) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목 및 정렬 옵션
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('viewRankings'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                // MCM인 경우에만 정렬 옵션 표시
                if (isMcMahon) _buildSortToggle(),
              ],
            ),
            const SizedBox(height: 16),
            _buildRankingsHeader(),
            const Divider(),
            ...rankings.map((r) => _buildRankingRow(r)),
          ],
        ),
      ),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('순위표를 불러올 수 없습니다', style: TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }

  /// MCM 순위 정렬 토글 버튼
  Widget _buildSortToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSortButton('wins', '승수순'),
          _buildSortButton('score', '점수순'),
        ],
      ),
    );
  }

  Widget _buildSortButton(String value, String label) {
    final isSelected = _rankingSortBy == value;
    return InkWell(
      onTap: () {
        if (_rankingSortBy != value) {
          setState(() => _rankingSortBy = value);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildRankingsHeader() {
    final isTeam = widget.participant.contestType == 'TEAM_SWISS';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(t('rank'), style: _headerStyle),
          ),
          Expanded(
            flex: 3,
            child: Text(t('name'), style: _headerStyle),
          ),
          SizedBox(
            width: 40,
            child: Text(t('wins'), style: _headerStyle, textAlign: TextAlign.center),
          ),
          if (!isTeam) ...[
            SizedBox(
              width: 50,
              child: Text(t('points'), style: _headerStyle, textAlign: TextAlign.center),
            ),
            SizedBox(
              width: 50,
              child: Text(t('sos'), style: _headerStyle, textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRankingRow(Ranking r) {
    final isMe = r.name == widget.participant.name ||
        r.teamName == widget.participant.name;
    final isTeam = widget.participant.contestType == 'TEAM_SWISS';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.statusLiveBg : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${r.rank}',
              style: TextStyle(
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              r.teamName ?? r.name,
              style: TextStyle(
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                color: isMe ? AppColors.statusLiveText : AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${r.wins}',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
          if (!isTeam) ...[
            SizedBox(
              width: 50,
              child: Text(
                '${r.points ?? 0}',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(
                '${r.sos ?? 0}',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  TextStyle get _headerStyle => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textTertiary,
  );
}
