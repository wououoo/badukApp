import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/mobile_qr_provider.dart';
import '../../../data/models/qr/my_contest_detail.dart';
import '../../../data/services/mobile_qr_service.dart';

/// 내 대회 상세 화면
class MyContestDetailScreen extends ConsumerStatefulWidget {
  final int contestId;

  const MyContestDetailScreen({
    super.key,
    required this.contestId,
  });

  @override
  ConsumerState<MyContestDetailScreen> createState() => _MyContestDetailScreenState();
}

class _MyContestDetailScreenState extends ConsumerState<MyContestDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedRound = 1;
  int? _selectedParticipationIndex; // null = 리스트 모드, 값 있으면 상세 모드
  String _rankingSortBy = 'wins';  // wins: 승수순, score: 점수순 (MCM 전용)
  String _divisionFilter = '';  // MCM 조별 필터 (빈 문자열 = 전체)
  bool _showTournament = false;  // DE 예선/본선 토글
  int _selectedTournamentRound = -1;  // 본선 선택 라운드 (-1이면 아직 미선택)
  Timer? _autoRefreshTimer;
  static const _autoRefreshInterval = Duration(seconds: 30);
  static const _seoulOffset = Duration(hours: 9);
  DateTime? _lastRefresh;

  /// 서울 시간 기준 오늘 날짜
  DateTime get _todaySeoul {
    final now = DateTime.now().toUtc().add(_seoulOffset);
    return DateTime(now.year, now.month, now.day);
  }

  /// 서울 시간 기준 오늘 체크인 여부
  bool _isCheckedInToday(MyParticipation participation) {
    final today = _todaySeoul;
    return participation.checkedInDates.any((d) =>
        d.year == today.year && d.month == today.month && d.day == today.day);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // 대회 상세 정보 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mobileQRProvider.notifier).loadContestDetail(widget.contestId);
      _lastRefresh = DateTime.now();
      _startAutoRefresh();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// 자동 새로고침 시작
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (mounted) {
        ref.read(mobileQRProvider.notifier).loadContestDetail(widget.contestId);
        // 순위표/대진표 등 별도 프로바이더도 캐시 무효화
        ref.invalidate(qrRankingsProvider);
        ref.invalidate(qrRoundResultsProvider);
        ref.invalidate(fullLeagueScheduleProvider);
        ref.invalidate(teamFullLeagueScheduleProvider);
        ref.invalidate(tournamentBracketProvider);
        _lastRefresh = DateTime.now();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mobileQRProvider);
    final detail = state.selectedContestDetail;

    // 상세 모드에서 시스템 뒤로가기 시 리스트로 복귀
    return PopScope(
      canPop: _selectedParticipationIndex == null,
      onPopInvoked: (didPop) {
        if (!didPop && _selectedParticipationIndex != null) {
          setState(() => _selectedParticipationIndex = null);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _selectedParticipationIndex == null
            ? _buildListAppBar(state, detail)
            : _buildDetailAppBar(state, detail),
        body: state.isLoading && detail == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : state.error != null && detail == null
                ? _buildError(state.error!)
                : detail == null
                    ? _buildNotFound()
                    : _selectedParticipationIndex == null
                        ? _buildGameRoomList(detail)
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildMyInfoTab(detail),
                              _buildMatchesTab(detail),
                              _buildRankingsTab(detail),
                            ],
                          ),
      ),
    );
  }

  /// 리스트 모드 AppBar (대회명, 탭바 없음)
  PreferredSizeWidget _buildListAppBar(dynamic state, MyContestDetail? detail) {
    return AppBar(
      title: Text(detail?.contestName ?? '대회 상세'),
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      actions: [
        _buildRefreshButton(state),
      ],
    );
  }

  /// 상세 모드 AppBar (부문명 + 뒤로가기 + 탭바)
  PreferredSizeWidget _buildDetailAppBar(dynamic state, MyContestDetail? detail) {
    final participation = detail != null &&
            _selectedParticipationIndex != null &&
            _selectedParticipationIndex! < detail.participations.length
        ? detail.participations[_selectedParticipationIndex!]
        : null;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => setState(() => _selectedParticipationIndex = null),
      ),
      title: Text(participation?.sortName ?? '부문 상세'),
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      actions: [
        _buildRefreshButton(state),
      ],
      bottom: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        tabs: const [
          Tab(text: '내 정보'),
          Tab(text: '대진표'),
          Tab(text: '순위표'),
        ],
      ),
    );
  }

  /// 새로고침 버튼 (공통)
  Widget _buildRefreshButton(dynamic state) {
    return IconButton(
      onPressed: state.isLoading
          ? null
          : () {
              ref.read(mobileQRProvider.notifier).loadContestDetail(widget.contestId);
              // 순위표/대진표 등 별도 프로바이더도 캐시 무효화
              ref.invalidate(qrRankingsProvider);
              ref.invalidate(qrRoundResultsProvider);
              ref.invalidate(fullLeagueScheduleProvider);
              ref.invalidate(teamFullLeagueScheduleProvider);
              ref.invalidate(tournamentBracketProvider);
              setState(() => _lastRefresh = DateTime.now());
            },
      icon: state.isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : const Icon(Icons.refresh),
      tooltip: '새로고침',
    );
  }

  Widget _buildError(String error) {
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
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('뒤로 가기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '참가 정보를 찾을 수 없습니다',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 게임룸 리스트 화면 ====================
  Widget _buildGameRoomList(MyContestDetail detail) {
    final notifier = ref.read(mobileQRProvider.notifier);

    return RefreshIndicator(
      onRefresh: () => notifier.loadContestDetail(widget.contestId),
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(detail),
          const SizedBox(height: 16),
          for (int i = 0; i < detail.participations.length; i++) ...[
            _buildGameRoomListItem(detail.participations[i], i),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  /// 게임룸 리스트 아이템 카드
  Widget _buildGameRoomListItem(MyParticipation participation, int index) {
    final isCheckedInToday = _isCheckedInToday(participation);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCheckedInToday
              ? AppColors.success.withOpacity(0.3)
              : AppColors.border,
        ),
      ),
      color: AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedParticipationIndex = index;
            _selectedRound = 1;
            _divisionFilter = '';
            _tabController.index = 0;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 부문명 + 체크인 상태
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      participation.sortName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (participation.teamName != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      participation.teamName!,
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                  const Spacer(),
                  if (isCheckedInToday)
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
                            '체크인',
                            style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  else if (participation.checkInEnabled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '미체크인',
                        style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // 라운드 + 상대 미리보기
              Row(
                children: [
                  Icon(Icons.sports_esports, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  if (participation.currentRound > 0)
                    Text(
                      '${participation.currentRound}라운드',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    )
                  else
                    Text(
                      '대기 중',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  if (participation.opponent != null) ...[
                    const SizedBox(width: 12),
                    Text('vs ', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                    Flexible(
                      child: Text(
                        participation.opponent!,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (participation.matchNumber != null) ...[
                    const Spacer(),
                    Text(
                      '${participation.matchNumber}번',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
              // 전적 요약
              if (participation.wins > 0 || participation.losses > 0) ...[
                const SizedBox(height: 8),
                Text(
                  participation.record,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
              // 진입 화살표 안내
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.chevron_right, size: 20, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 내 정보 탭 ====================
  Widget _buildMyInfoTab(MyContestDetail detail) {
    final notifier = ref.read(mobileQRProvider.notifier);
    final participation = _selectedParticipationIndex != null &&
            _selectedParticipationIndex! < detail.participations.length
        ? detail.participations[_selectedParticipationIndex!]
        : null;

    if (participation == null) {
      return const Center(child: Text('참가 정보가 없습니다'));
    }

    return RefreshIndicator(
      onRefresh: () => notifier.loadContestDetail(widget.contestId),
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(detail),
          const SizedBox(height: 16),
          _buildParticipationCard(participation),
        ],
      ),
    );
  }

  Widget _buildInfoCard(MyContestDetail detail) {
    final dateFormat = DateFormat('yyyy.MM.dd');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail.contestName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  detail.startDate != null
                      ? (detail.endDate != null && detail.startDate != detail.endDate
                          ? '${dateFormat.format(detail.startDate!)} ~ ${dateFormat.format(detail.endDate!)}'
                          : dateFormat.format(detail.startDate!))
                      : '-',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
            if (detail.maxRound > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.repeat, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    '총 ${detail.maxRound}라운드',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParticipationCard(MyParticipation participation) {
    final notifier = ref.read(mobileQRProvider.notifier);
    final isCheckedInToday = _isCheckedInToday(participation);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCheckedInToday
              ? AppColors.success.withOpacity(0.3)
              : AppColors.border,
        ),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 부문명
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    participation.sortName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (participation.teamName != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    participation.teamName!,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const Spacer(),
                if (isCheckedInToday)
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
                          '체크인',
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

            // 맥마흔 전적 정보
            if (participation.mcmahonRank != null || participation.wins > 0 || participation.losses > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (participation.mcmahonRank != null) ...[
                    Text(
                      participation.mcmahonRank!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    participation.record,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (participation.mcmahonScore != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      '점수: ${participation.mcmahonScore!.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],

            // 라운드 진행 정보 (순위는 순위표 탭에서 확인)
            if (participation.currentRanking != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatItem('라운드', participation.roundProgressText, AppColors.textPrimary),
                  ],
                ),
              ),
            ],

            // 현재 경기 정보 - 토너먼트 상태에 따라 분기
            if (participation.tournamentStarted && participation.advancedToTournament == true) ...[
              // DE 토너먼트 진출
              const SizedBox(height: 12),
              _buildTournamentCard(participation),
            ] else if (participation.tournamentStarted && participation.advancedToTournament == false) ...[
              // DE 토너먼트 탈락
              const SizedBox(height: 12),
              _buildEliminatedCard(),
            ] else if (participation.currentRound > 0) ...[
              // 예선 진행 중 (기존 로직)
              const SizedBox(height: 12),
              _buildCurrentMatchCard(participation),
            ],

            // 토너먼트 매치 이력
            if (participation.tournamentMatches.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildTournamentMatchHistory(participation),
            ],

            // 팀원 목록 (단체전)
            if (participation.teamMembers.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildTeamMembersSection(participation),
            ],

            // 체크인 버튼
            if (participation.checkInEnabled && !isCheckedInToday) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final result = await notifier.checkIn(
                          widget.contestId,
                          sortId: participation.gameRoomId,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result.message ?? (result.success ? '체크인 완료!' : '체크인 실패')),
                              backgroundColor: result.success ? AppColors.success : AppColors.error,
                            ),
                          );
                          if (result.success) {
                            notifier.loadContestDetail(widget.contestId);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '체크인',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // 체크인 취소 버튼
            if (participation.checkInEnabled && isCheckedInToday) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => _showCancelCheckInDialog(participation.gameRoomId),
                  child: Text(
                    '체크인 취소',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// 단체전 팀원 목록 섹션
  Widget _buildTeamMembersSection(MyParticipation participation) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '팀원 정보',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          // 헤더
          Row(
            children: [
              SizedBox(width: 30, child: Text('기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.center)),
              const SizedBox(width: 8),
              Expanded(child: Text('이름', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
              SizedBox(width: 60, child: Text('전적', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.center)),
            ],
          ),
          const Divider(height: 12),
          ...participation.teamMembers.map((member) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '${member.boardNumber}',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    member.isNone ? '(부전)' : member.memberName,
                    style: TextStyle(
                      fontSize: 13,
                      color: member.isNone ? AppColors.textTertiary : AppColors.textPrimary,
                      fontWeight: member.memberName == participation.myName ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: member.isNone
                      ? Text('-', style: TextStyle(fontSize: 13, color: AppColors.textTertiary), textAlign: TextAlign.center)
                      : Text(
                          '${member.wins}승 ${member.losses}패',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  /// 예선 현재 대국 카드 (기존 로직 분리)
  Widget _buildCurrentMatchCard(MyParticipation participation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primaryLight.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${participation.currentRound}라운드',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (participation.deGroup != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFD7E14).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFD7E14).withOpacity(0.3)),
                  ),
                  child: Text(
                    '${participation.deGroup}조',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFFD7E14),
                    ),
                  ),
                ),
              ],
              if (participation.matchNumber != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '${participation.matchNumber}번 테이블',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (participation.opponent == '없음')
            // 부전승
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events_outlined, color: AppColors.warning, size: 20),
                  SizedBox(width: 8),
                  Text('부전승', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.warning)),
                ],
              ),
            )
          else if (participation.opponent != null)
            _buildVsWidget(participation.myName ?? '나', participation.opponent!, participation.opponentLevel)
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_empty, color: AppColors.textSecondary, size: 20),
                SizedBox(width: 8),
                Text('대진 대기 중', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              ],
            ),
        ],
      ),
    );
  }

  /// VS 대진 위젯 (재사용)
  Widget _buildVsWidget(String myName, String opponentName, String? opponentLevel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: const Icon(Icons.person, color: AppColors.primary, size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                myName,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Text('VS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        Expanded(
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.textSecondary, width: 2),
                ),
                child: Icon(Icons.person_outline, color: AppColors.textSecondary, size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                opponentName,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (opponentLevel != null)
                Text(opponentLevel, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  /// DE 토너먼트 진출 카드
  Widget _buildTournamentCard(MyParticipation participation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFD7E14).withOpacity(0.1),
            const Color(0xFFFD7E14).withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFD7E14).withOpacity(0.4), width: 2),
      ),
      child: Column(
        children: [
          // 본선 토너먼트 뱃지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFD7E14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '본선 토너먼트',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          // 현재 단계
          if (participation.tournamentStage != null)
            Text(
              participation.tournamentStage!,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          const SizedBox(height: 12),
          // VS 정보
          if (participation.tournamentOpponent != null)
            _buildVsWidget(participation.myName ?? '나', participation.tournamentOpponent!, null)
          else
            Text('상대 배정 대기 중', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          // 매치 상태
          if (participation.tournamentMatchStatus != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getTournamentStatusText(participation.tournamentMatchStatus!),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.info),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 토너먼트 탈락 카드
  Widget _buildEliminatedCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: const Center(
        child: Text(
          '예선에서 탈락하였습니다',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.error),
        ),
      ),
    );
  }

  /// 토너먼트 매치 이력 위젯
  Widget _buildTournamentMatchHistory(MyParticipation participation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '토너먼트 이력',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ),
        ...participation.tournamentMatches.map((match) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // 단계 뱃지
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFD7E14).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  match.stageName ?? '${match.round}R',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFD7E14)),
                ),
              ),
              const SizedBox(width: 12),
              // 상대
              Expanded(
                child: Text(
                  'vs ${match.opponent ?? "?"}',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 승패 결과
              if (match.won != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: match.won! ? AppColors.info.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    match.won! ? '승' : '패',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: match.won! ? AppColors.info : AppColors.error,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '진행 중',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.info),
                  ),
                ),
            ],
          ),
        )),
      ],
    );
  }

  String _getTournamentStatusText(String status) {
    switch (status) {
      case 'COMPLETED': return '종료';
      case 'IN_PROGRESS': return '진행 중';
      case 'PENDING': return '대기 중';
      default: return '진행 중';
    }
  }

  void _showCancelCheckInDialog(int sortId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('체크인 취소'),
        content: const Text('체크인을 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final notifier = ref.read(mobileQRProvider.notifier);
              final result = await notifier.cancelCheckIn(
                widget.contestId,
                sortId: sortId,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message ?? (result.success ? '체크인 취소 완료' : '취소 실패')),
                    backgroundColor: result.success ? AppColors.success : AppColors.error,
                  ),
                );
                if (result.success) {
                  notifier.loadContestDetail(widget.contestId);
                }
              }
            },
            child: const Text('예', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // 상세 모드에서는 부문 선택 칩이 불필요 (리스트에서 이미 선택했으므로)
  // 대진표/순위표 탭에서의 부문 선택은 제거
  Widget _buildParticipationSelector(MyContestDetail detail) {
    return const SizedBox.shrink();
  }

  // ==================== 대진표 탭 ====================
  Widget _buildMatchesTab(MyContestDetail detail) {
    final participation = _selectedParticipationIndex != null &&
            _selectedParticipationIndex! < detail.participations.length
        ? detail.participations[_selectedParticipationIndex!]
        : null;
    final sortId = participation?.gameRoomId;

    if (sortId == null) {
      return const Center(child: Text('대진표 정보가 없습니다'));
    }

    // 선택된 participation의 contestType 우선 사용 (그룹핑 시 자식 대회 타입)
    final effectiveType = participation?.contestType ?? detail.contestType;

    // 풀리그는 전체 스케줄 API 사용
    final isFullLeague = effectiveType == 'FULL_LEAGUE';
    if (isFullLeague) {
      return _buildFullLeagueMatchesTab(detail, sortId);
    }

    // 단체 풀리그는 팀 매치 + 기별 상세 표시
    final isTeamFullLeague = effectiveType == 'TEAM_FULL_LEAGUE';
    if (isTeamFullLeague) {
      return _buildTeamFullLeagueMatchesTab(detail, sortId);
    }

    // DE 대회 + 토너먼트 시작 여부 확인
    final isDE = effectiveType == 'DE';
    final hasTournament = isDE && participation != null && participation.tournamentStarted;

    return Column(
      children: [
        // 부문 선택 (다중 부문 시)
        _buildParticipationSelector(detail),

        // DE 토너먼트 시작 시 예선/본선 세그먼트 토글
        if (hasTournament)
          _buildDESegmentToggle(),

        // 본선 선택 시 토너먼트 대진표
        if (hasTournament && _showTournament)
          Expanded(
            child: _buildTournamentRounds(participation!.gameRoomId),
          )
        else ...[
          // 예선 라운드 선택 (participation별 라운드 수 사용)
          Builder(builder: (context) {
            // 우선순위: totalRounds > currentRound > detail.maxRound
            int roundCount;
            if (participation != null && participation.totalRounds != null && participation.totalRounds! > 0) {
              roundCount = participation.totalRounds!;
            } else if (participation != null && participation.currentRound > 0) {
              roundCount = participation.currentRound;
            } else {
              roundCount = detail.maxRound;
            }
            if (roundCount <= 0) roundCount = 1;
            return Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: roundCount,
                itemBuilder: (context, index) {
                  final round = index + 1;
                  final isSelected = round == _selectedRound;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$round라운드'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedRound = round);
                        }
                      },
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  );
                },
              ),
            );
          }),

          // 대진표 내용
          Expanded(
            child: _buildRoundMatches(sortId, deGroup: participation?.deGroup, contestType: effectiveType),
          ),
        ],
      ],
    );
  }

  /// DE 예선/본선 세그먼트 토글
  Widget _buildDESegmentToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_showTournament) {
                    setState(() => _showTournament = false);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !_showTournament ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '예선',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: !_showTournament ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!_showTournament) {
                    setState(() => _showTournament = true);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _showTournament ? const Color(0xFFFD7E14) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '본선',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _showTournament ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 토너먼트 본선 라운드 표시
  Widget _buildTournamentRounds(int gameRoomId) {
    final asyncBracket = ref.watch(tournamentBracketProvider(gameRoomId));

    return asyncBracket.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (err, stack) => Center(
        child: Text('본선 대진표를 불러올 수 없습니다', style: TextStyle(color: AppColors.textSecondary)),
      ),
      data: (bracket) {
        final rounds = bracket.rounds;
        if (rounds.isEmpty) {
          return Center(
            child: Text('본선 대진표가 아직 없습니다', style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        // 첫 진입 시 첫 번째 라운드 자동 선택
        if (_selectedTournamentRound == -1 || !rounds.contains(_selectedTournamentRound)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _selectedTournamentRound = rounds.first);
            }
          });
          if (_selectedTournamentRound == -1) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
        }

        return Column(
          children: [
            // 라운드 칩: [16강] [8강] [4강] [결승]
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: rounds.length,
                itemBuilder: (context, index) {
                  final round = rounds[index];
                  final isSelected = round == _selectedTournamentRound;
                  final stageName = bracket.getStageName(round);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(stageName),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedTournamentRound = round);
                        }
                      },
                      selectedColor: const Color(0xFFFD7E14),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  );
                },
              ),
            ),

            // 매치 목록
            Expanded(
              child: _buildTournamentMatchList(bracket),
            ),
          ],
        );
      },
    );
  }

  /// 토너먼트 본선 매치 리스트
  Widget _buildTournamentMatchList(TournamentBracketResponse bracket) {
    final matches = bracket.matchesForRound(_selectedTournamentRound);

    if (matches.isEmpty) {
      return Center(
        child: Text('해당 라운드 매치가 없습니다', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        // 양쪽 선수 모두 미정인 대기 매치
        if (match.isWaiting && match.player1Id == null && match.player2Id == null) {
          return _buildWaitingMatchCard(match);
        }
        return _buildMatchCard(match.toMatchResult());
      },
    );
  }

  /// 대기 중 매치 카드 (양쪽 선수 미정)
  Widget _buildWaitingMatchCard(TournamentBracketMatch match) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.textTertiary.withOpacity(0.3)),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 16, color: AppColors.textTertiary),
            SizedBox(width: 6),
            Text(
              '대기',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 단체 풀리그 대진표 ====================

  /// 단체 풀리그 대진표 탭 (전체 스케줄 기반 - 웹과 동일)
  Widget _buildTeamFullLeagueMatchesTab(MyContestDetail detail, int gameRoomId) {
    final asyncSchedule = ref.watch(teamFullLeagueScheduleProvider(gameRoomId));

    return asyncSchedule.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (err, stack) => Center(
        child: Text('대진표를 불러올 수 없습니다', style: TextStyle(color: AppColors.textSecondary)),
      ),
      data: (schedule) {
        if (schedule.rounds.isEmpty) {
          return Center(
            child: Text('대진표가 아직 생성되지 않았습니다', style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        final totalRounds = schedule.totalRounds;

        return Column(
          children: [
            _buildParticipationSelector(detail),

            // 라운드 선택 (전체 라운드 표시)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: totalRounds,
                itemBuilder: (context, index) {
                  final round = index + 1;
                  final isSelected = round == _selectedRound;
                  final roundData = schedule.rounds.length > index ? schedule.rounds[index] : null;
                  final hasResults = roundData?.started ?? false;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$round라운드'),
                          if (hasResults) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.check_circle, size: 14, color: Colors.white70),
                          ],
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedRound = round);
                        }
                      },
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  );
                },
              ),
            ),

            // 선택된 라운드의 매치 표시
            Expanded(
              child: _buildTeamFullLeagueRoundContent(schedule),
            ),
          ],
        );
      },
    );
  }

  /// 단체 풀리그 선택된 라운드 내용
  Widget _buildTeamFullLeagueRoundContent(TeamFullLeagueScheduleResponse schedule) {
    if (_selectedRound > schedule.rounds.length || _selectedRound < 1) {
      return Center(
        child: Text(
          '$_selectedRound라운드 대진표가 없습니다',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final roundData = schedule.rounds[_selectedRound - 1];
    final matches = roundData.matches;

    if (matches.isEmpty) {
      return Center(
        child: Text(
          '$_selectedRound라운드 대진표가 없습니다',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length + (roundData.restingTeamName != null ? 1 : 0),
      itemBuilder: (context, index) {
        // 쉬는 팀 표시
        if (index == matches.length && roundData.restingTeamName != null) {
          return _buildRestingPlayerCard(roundData.restingTeamName!);
        }

        final match = matches[index];
        return _buildTeamMatchCard(match);
      },
    );
  }

  /// 단체전 팀 매치 카드 (팀 스코어 + 기별 상세)
  Widget _buildTeamMatchCard(TeamFullLeagueMatch match) {
    final team1 = match.team1Name;
    final team2 = match.team2Name;
    final t1Wins = match.team1Wins;
    final t2Wins = match.team2Wins;
    final isTeam1Winner = match.isCompleted && match.winnerTeamId != null && match.winnerTeamId == match.team1Id;
    final isTeam2Winner = match.isCompleted && match.winnerTeamId != null && match.winnerTeamId == match.team2Id;

    // BYE 매치
    if (match.isBye) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.border),
        ),
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  team1,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '부전승',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.warning),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: match.isCompleted ? AppColors.border : AppColors.info.withOpacity(0.3),
        ),
      ),
      color: AppColors.surface,
      child: Column(
        children: [
          // 팀 매치 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                // 팀1
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        team1,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isTeam1Winner ? FontWeight.bold : FontWeight.w500,
                          color: isTeam1Winner ? AppColors.primary : (isTeam2Winner ? AppColors.textTertiary : AppColors.textPrimary),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (match.isCompleted && isTeam1Winner)
                        _buildResultBadge('승', AppColors.info),
                      if (match.isCompleted && isTeam2Winner)
                        _buildResultBadge('패', AppColors.error),
                    ],
                  ),
                ),
                // 스코어
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: match.isCompleted
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$t1Wins : $t2Wins',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: match.isCompleted ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
                // 팀2
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        team2,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isTeam2Winner ? FontWeight.bold : FontWeight.w500,
                          color: isTeam2Winner ? AppColors.primary : (isTeam1Winner ? AppColors.textTertiary : AppColors.textPrimary),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (match.isCompleted && isTeam2Winner)
                        _buildResultBadge('승', AppColors.info),
                      if (match.isCompleted && isTeam1Winner)
                        _buildResultBadge('패', AppColors.error),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 상태 표시
          if (match.isCompleted)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '종료',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.success),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '진행중',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.info),
                ),
              ),
            ),

          // 기별 상세 결과
          if (match.boards.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: match.boards.map((board) => _buildBoardResultRow(board)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 기별 결과 행
  Widget _buildBoardResultRow(BoardResult board) {
    final p1 = board.team1MemberName ?? '-';
    final p2 = board.team2MemberName ?? '-';
    final isP1Winner = board.isCompleted && board.winnerMemberId != null && board.winnerMemberId == board.team1MemberId;
    final isP2Winner = board.isCompleted && board.winnerMemberId != null && board.winnerMemberId == board.team2MemberId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          // 기 번호
          Container(
            width: 30,
            alignment: Alignment.center,
            child: Text(
              '${board.boardNumber}장',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 4),
          // 선수1
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isP1Winner)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _buildSmallResultBadge('승', AppColors.info),
                  ),
                if (isP2Winner)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _buildSmallResultBadge('패', AppColors.error),
                  ),
                Flexible(
                  child: Text(
                    p1,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isP1Winner ? FontWeight.w600 : FontWeight.normal,
                      color: isP1Winner ? AppColors.primary : (isP2Winner ? AppColors.textTertiary : AppColors.textPrimary),
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // vs
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'vs',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
          ),
          // 선수2
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    p2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isP2Winner ? FontWeight.w600 : FontWeight.normal,
                      color: isP2Winner ? AppColors.primary : (isP1Winner ? AppColors.textTertiary : AppColors.textPrimary),
                    ),
                    textAlign: TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isP2Winner)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _buildSmallResultBadge('승', AppColors.info),
                  ),
                if (isP1Winner)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _buildSmallResultBadge('패', AppColors.error),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 작은 승/패 뱃지 (기별 결과용)
  Widget _buildSmallResultBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  /// 풀리그 전체 스케줄 기반 대진표 탭
  Widget _buildFullLeagueMatchesTab(MyContestDetail detail, int gameRoomId) {
    final asyncSchedule = ref.watch(fullLeagueScheduleProvider(gameRoomId));

    return asyncSchedule.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (err, stack) => Center(
        child: Text('대진표를 불러올 수 없습니다', style: TextStyle(color: AppColors.textSecondary)),
      ),
      data: (schedule) {
        if (schedule.rounds.isEmpty) {
          return Center(
            child: Text('대진표가 아직 생성되지 않았습니다', style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        final totalRounds = schedule.totalRounds;

        return Column(
          children: [
            // 부문 선택 (다중 부문 시)
            _buildParticipationSelector(detail),

            // 라운드 선택 (전체 라운드 표시)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: totalRounds,
                itemBuilder: (context, index) {
                  final round = index + 1;
                  final isSelected = round == _selectedRound;
                  final roundData = schedule.rounds.length > index ? schedule.rounds[index] : null;
                  final hasResults = roundData?.hasResults ?? false;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$round라운드'),
                          if (hasResults) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.check_circle, size: 14, color: Colors.white70),
                          ],
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedRound = round);
                        }
                      },
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  );
                },
              ),
            ),

            // 선택된 라운드의 매치 표시
            Expanded(
              child: _buildFullLeagueRoundContent(schedule),
            ),
          ],
        );
      },
    );
  }

  /// 풀리그 선택된 라운드 매치 내용
  Widget _buildFullLeagueRoundContent(FullLeagueScheduleResponse schedule) {
    if (_selectedRound > schedule.rounds.length || _selectedRound < 1) {
      return Center(
        child: Text(
          '$_selectedRound라운드 대진표가 없습니다',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final roundData = schedule.rounds[_selectedRound - 1];
    final matches = roundData.matches;

    if (matches.isEmpty) {
      return Center(
        child: Text(
          '$_selectedRound라운드 대진표가 없습니다',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length + (roundData.restingPlayer != null ? 1 : 0),
      itemBuilder: (context, index) {
        // 쉬는 선수 표시
        if (index == matches.length && roundData.restingPlayer != null) {
          return _buildRestingPlayerCard(roundData.restingPlayer!);
        }

        final match = matches[index];
        return _buildFullLeagueMatchCard(match, index + 1);
      },
    );
  }

  /// 풀리그 매치 카드 (스케줄 기반)
  Widget _buildFullLeagueMatchCard(FullLeagueMatch match, int tableNumber) {
    if (match.isBye) {
      // 부전승 카드
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.border),
        ),
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _buildTableNumber(tableNumber),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  match.player1,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '부전승',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.warning),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isPlayer1Winner = match.isCompleted && match.winner == match.player1;
    final isPlayer2Winner = match.isCompleted && match.winner == match.player2;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: match.isCompleted ? AppColors.border : AppColors.info.withOpacity(0.3),
        ),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _buildTableNumber(tableNumber),
            const SizedBox(width: 10),
            // Player 1
            Expanded(
              child: _buildPlayerCell(
                name: match.player1,
                isWinner: isPlayer1Winner,
                isLoser: isPlayer2Winner,
                isCompleted: match.isCompleted,
                align: TextAlign.right,
              ),
            ),
            // 중앙 VS / 상태
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: match.isCompleted
                  ? Container(
                      width: 44,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('vs', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '종료',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.success),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      width: 44,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('vs', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.textTertiary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '예정',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textTertiary),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            // Player 2
            Expanded(
              child: _buildPlayerCell(
                name: match.player2,
                isWinner: isPlayer2Winner,
                isLoser: isPlayer1Winner,
                isCompleted: match.isCompleted,
                align: TextAlign.left,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 쉬는 선수 카드 (풀리그 홀수 인원)
  Widget _buildRestingPlayerCard(String playerName) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.warning.withOpacity(0.3)),
      ),
      color: AppColors.warning.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pause_circle_outline, size: 18, color: AppColors.warning),
            const SizedBox(width: 8),
            Text(
              '$playerName - 이번 라운드 쉼',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.warning),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundMatches(int sortId, {int? deGroup, String? contestType}) {
    final params = QRRoundResultParams(
      contestId: widget.contestId,
      round: _selectedRound,
      sortId: sortId,
      contestType: contestType,
    );
    final asyncValue = ref.watch(qrRoundResultsProvider(params));

    return asyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (err, stack) => Center(
        child: Text('대진표를 불러올 수 없습니다', style: TextStyle(color: AppColors.textSecondary)),
      ),
      data: (result) {
        if (!result.success || result.matches.isEmpty) {
          return Center(
            child: Text(
              '$_selectedRound라운드 대진표가 없습니다',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        // DE일 때 자기 조의 매치만 필터링
        final matches = deGroup != null
            ? result.matches.where((m) => m.group == deGroup).toList()
            : result.matches;

        if (matches.isEmpty) {
          return Center(
            child: Text(
              '$_selectedRound라운드 대진표가 없습니다',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final match = matches[index];
            return _buildMatchCard(match);
          },
        );
      },
    );
  }

  Widget _buildMatchCard(MatchResult match) {
    // 양패: 둘 다 패배 처리. 부전승보다 우선 판정 (isNone과 isByeMatch가 동시에 true이면 양패로 표시)
    final bool isNoneMatch = match.isNone;
    final bool isPlayer1Winner = !isNoneMatch && match.isCompleted && match.winnerId != null && match.winnerId == match.player1Id;
    final bool isPlayer2Winner = !isNoneMatch && match.isCompleted && match.winnerId != null && match.player2Id != null && match.winnerId == match.player2Id;
    final bool hasBoards = match.boards.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isNoneMatch
              ? AppColors.error.withOpacity(0.3)
              : (match.isCompleted ? AppColors.border : AppColors.info.withOpacity(0.3)),
        ),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: isNoneMatch
            ? _buildNoneMatchContent(match)
            : match.isByeMatch
                ? _buildByeMatchContent(match)
                : Column(
                    children: [
                      _buildNormalMatchContent(match, isPlayer1Winner, isPlayer2Winner),
                      // 단체전 기별 대진 표시
                      if (hasBoards) ...[
                        const Divider(height: 16),
                        _buildBoardMatchesContent(match),
                      ],
                    ],
                  ),
      ),
    );
  }

  /// 양패 카드 (둘 다 패배 처리)
  Widget _buildNoneMatchContent(MatchResult match) {
    return Row(
      children: [
        Expanded(
          child: Text(
            match.player1,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              decoration: TextDecoration.lineThrough,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            '양패',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error),
          ),
        ),
        Expanded(
          child: Text(
            match.player2 ?? '',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              decoration: TextDecoration.lineThrough,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// 단체전 기별 대진 표시
  Widget _buildBoardMatchesContent(MatchResult match) {
    return Column(
      children: match.boards.map((board) {
        final bool isTeam1Winner = board.winnerMemberId != null && board.team1MemberId != null
            && board.winnerMemberId == board.team1MemberId;
        final bool isTeam2Winner = board.winnerMemberId != null && board.team2MemberId != null
            && board.winnerMemberId == board.team2MemberId;
        final String team1Name = board.team1MemberName ?? '-';
        final String team2Name = board.team2MemberName ?? '-';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              // 기 번호
              SizedBox(
                width: 32,
                child: Text(
                  '${board.boardNumber}장',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 4),
              // 팀1 선수
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isTeam1Winner)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _buildResultBadge('승', AppColors.info),
                      ),
                    Flexible(
                      child: Text(
                        team1Name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isTeam1Winner ? FontWeight.w600 : FontWeight.normal,
                          color: isTeam1Winner ? AppColors.primary : isTeam2Winner ? AppColors.textTertiary : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // vs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('vs', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
              ),
              // 팀2 선수
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        team2Name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isTeam2Winner ? FontWeight.w600 : FontWeight.normal,
                          color: isTeam2Winner ? AppColors.primary : isTeam1Winner ? AppColors.textTertiary : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isTeam2Winner)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: _buildResultBadge('승', AppColors.info),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 부전승 카드
  Widget _buildByeMatchContent(MatchResult match) {
    return Row(
      children: [
        if (match.tableNumber != null) ...[
          _buildTableNumber(match.tableNumber!),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Row(
            children: [
              Text(
                match.player1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '부전승',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildResultBadge('승', AppColors.info),
      ],
    );
  }

  /// 일반 대국 카드
  Widget _buildNormalMatchContent(MatchResult match, bool isPlayer1Winner, bool isPlayer2Winner) {
    return Row(
      children: [
        if (match.tableNumber != null) ...[
          _buildTableNumber(match.tableNumber!),
          const SizedBox(width: 10),
        ],
        // Player 1 영역
        Expanded(
          child: _buildPlayerCell(
            name: match.player1,
            isWinner: isPlayer1Winner,
            isLoser: isPlayer2Winner,  // 상대가 이겼으면 이 선수는 진 것
            isCompleted: match.isCompleted,
            align: TextAlign.right,
          ),
        ),
        // 중앙 VS / 결과 영역
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: match.isCompleted
              ? Container(
                  width: 50,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 단체전 스코어 표시
                      if (match.team1Wins != null && match.team2Wins != null)
                        Text(
                          '${match.team1Wins}:${match.team2Wins}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        )
                      else
                        Text(
                          'vs',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '종료',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  width: 50,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'vs',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '진행중',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        // Player 2 영역
        Expanded(
          child: _buildPlayerCell(
            name: match.player2 ?? '-',
            isWinner: isPlayer2Winner,
            isLoser: isPlayer1Winner,  // 상대가 이겼으면 이 선수는 진 것
            isCompleted: match.isCompleted,
            align: TextAlign.left,
          ),
        ),
      ],
    );
  }

  /// 테이블 번호 위젯
  Widget _buildTableNumber(int number) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  /// 선수 이름 + 승/패 뱃지
  Widget _buildPlayerCell({
    required String name,
    required bool isWinner,
    required bool isLoser,
    required bool isCompleted,
    required TextAlign align,
  }) {
    final isLeft = align == TextAlign.left;

    return Row(
      mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        // 오른쪽 정렬일 때 뱃지가 이름 앞에
        if (!isLeft && isCompleted) ...[
          if (isWinner) _buildResultBadge('승', AppColors.info),
          if (isLoser) _buildResultBadge('패', AppColors.error),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
              color: isWinner
                  ? AppColors.primary
                  : isLoser
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
            ),
            textAlign: align,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // 왼쪽 정렬일 때 뱃지가 이름 뒤에
        if (isLeft && isCompleted) ...[
          const SizedBox(width: 6),
          if (isWinner) _buildResultBadge('승', AppColors.info),
          if (isLoser) _buildResultBadge('패', AppColors.error),
        ],
      ],
    );
  }

  /// 승/패 결과 뱃지
  Widget _buildResultBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ==================== 순위표 탭 ====================
  Widget _buildRankingsTab(MyContestDetail detail) {
    final participation = _selectedParticipationIndex != null &&
            _selectedParticipationIndex! < detail.participations.length
        ? detail.participations[_selectedParticipationIndex!]
        : null;
    final sortId = participation?.gameRoomId;

    // 선택된 participation의 contestType 우선 사용 (그룹핑 시 자식 대회 타입)
    final effectiveType = participation?.contestType ?? detail.contestType;

    // 대회 타입 확인 (MCM인 경우에만 정렬 토글 표시)
    final isMcMahon = effectiveType == 'MCM';

    if (sortId == null) {
      return const Center(child: Text('순위표 정보가 없습니다'));
    }

    final params = QRRankingsParams(
      contestId: widget.contestId,
      sortId: sortId,
      sortBy: _rankingSortBy,
      contestType: effectiveType,
    );
    final asyncValue = ref.watch(qrRankingsProvider(params));

    return Column(
      children: [
        // 부문 선택 (다중 부문 시)
        _buildParticipationSelector(detail),

        // MCM인 경우 정렬 토글 + 조별 필터 표시 (유럽식이면 숨김)
        if (isMcMahon)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Builder(builder: (_) {
              // 데이터 로드 완료 시 조 목록 추출
              final rankingsData = asyncValue.valueOrNull;
              // 유럽식 맥마흔 감지
              final isEuropean = rankingsData != null &&
                  rankingsData.rankings.isNotEmpty &&
                  rankingsData.rankings.first.europeanMode;
              final divisions = rankingsData != null
                  ? (rankingsData.rankings
                      .map((r) => r.division)
                      .where((d) => d != null && d.isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort())
                  : <String?>[];

              // 유럽식이면 정렬 토글/조별 필터 숨김 (서버 정렬 고정)
              if (isEuropean) return const SizedBox.shrink();

              return Row(
                children: [
                  // 조별 필터 드롭다운
                  if (divisions.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _divisionFilter,
                          isDense: true,
                          style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                          items: [
                            const DropdownMenuItem(value: '', child: Text('전체')),
                            ...divisions.map((d) => DropdownMenuItem(
                              value: d!,
                              child: Text('$d조'),
                            )),
                          ],
                          onChanged: (v) => setState(() => _divisionFilter = v ?? ''),
                        ),
                      ),
                    ),
                  const Spacer(),
                  _buildSortToggle(),
                ],
              );
            }),
          ),

        // 순위표 리스트
        Expanded(
          child: asyncValue.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (err, stack) => Center(
              child: Text('순위표를 불러올 수 없습니다', style: TextStyle(color: AppColors.textSecondary)),
            ),
            data: (result) {
              if (!result.success || result.rankings.isEmpty) {
                return Center(
                  child: Text(
                    '순위표가 없습니다',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              // DE일 때 조별 분리
              final isDE = effectiveType == 'DE';
              final hasGroups = isDE && result.rankings.any((r) => r.group != null);

              if (hasGroups) {
                return _buildGroupedRankings(result.rankings);
              }

              // MCM 조별 필터 적용
              var displayRankings = result.rankings;
              if (isMcMahon && _divisionFilter.isNotEmpty) {
                displayRankings = result.rankings
                    .where((r) => r.division == _divisionFilter)
                    .toList();
              }

              // 조별 필터 적용 시 순위 재계산
              final reRank = isMcMahon && _divisionFilter.isNotEmpty;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: displayRankings.length,
                itemBuilder: (context, index) {
                  final ranking = displayRankings[index];
                  return _buildRankingRow(ranking, index,
                      overrideRank: reRank ? index + 1 : null,
                      contestType: effectiveType);
                },
              );
            },
          ),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// DE 조별 분리 순위표
  Widget _buildGroupedRankings(List<RankingEntry> rankings) {
    // 그룹별로 분류
    final grouped = <int, List<RankingEntry>>{};
    for (final r in rankings) {
      final g = r.group ?? 1;
      grouped.putIfAbsent(g, () => []);
      grouped[g]!.add(r);
    }

    final sortedGroups = grouped.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final group in sortedGroups) ...[
          // 조 제목
          Container(
            margin: EdgeInsets.only(bottom: 8, top: group == sortedGroups.first ? 0 : 12),
            padding: const EdgeInsets.only(left: 8),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Color(0xFFFD7E14), width: 3)),
            ),
            child: Text(
              '$group조',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFD7E14)),
            ),
          ),
          // 해당 조의 순위 목록
          ...grouped[group]!.asMap().entries.map((entry) =>
            _buildRankingRow(entry.value, entry.key),
          ),
        ],
      ],
    );
  }

  Widget _buildRankingRow(RankingEntry ranking, int index, {int? overrideRank, String? contestType}) {
    final displayRank = overrideRank ?? ranking.rank;
    final isTop3 = displayRank <= 3;
    final isFullLeague = contestType == 'FULL_LEAGUE';
    final isTeamFullLeague = contestType == 'TEAM_FULL_LEAGUE';
    final isTeamSwiss = contestType == 'TEAM_SWISS';
    final isTeamContest = isTeamFullLeague || isTeamSwiss;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isTop3 ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isTop3 ? AppColors.primary.withOpacity(0.2) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // 순위
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _getRankColor(displayRank),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              '$displayRank',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: displayRank <= 3 ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 이름
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ranking.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isTop3 ? FontWeight.w600 : FontWeight.normal,
                    color: AppColors.textPrimary,
                  ),
                ),
                // 유럽식 맥마흔: 소속 표시
                if (ranking.europeanMode && ranking.club != null && ranking.club!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      ranking.club!,
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                // 단체전: 선수별 승수 표시
                if (isTeamContest && ranking.playerWins != null && ranking.playerWins!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      ranking.playerWins!.asMap().entries.map((e) => '${e.key + 1}장:${e.value}').join(' '),
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          // 풀리그: 승, 패, 승률
          if (isFullLeague) ...[
            Text(
              '${ranking.wins}승 ${ranking.losses}패',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            if (ranking.winRate != null) ...[
              const SizedBox(width: 8),
              Text(
                ranking.winRate!,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary),
              ),
            ],
          ]
          // 단체전 풀리그: 승, 무, 패, 득실, 총승수
          else if (isTeamFullLeague) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${ranking.wins}승${ranking.draws != null && ranking.draws! > 0 ? ' ${ranking.draws}무' : ''} ${ranking.losses}패',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ranking.pointDiff != null)
                      Text(
                        '득실:${ranking.pointDiff! > 0 ? '+${ranking.pointDiff}' : '${ranking.pointDiff}'}',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    if (ranking.boardWins != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '총${ranking.boardWins}승',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ]
          // 단체전 스위스: 승패 + 전체승수
          else if (isTeamSwiss) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${ranking.wins}승 ${ranking.losses}패',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                if (ranking.boardWins != null)
                  Text(
                    '총${ranking.boardWins}승',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary),
                  ),
              ],
            ),
          ]
          // 유럽식 맥마흔: 점수 + SOS/SODOS/SOSOS
          else if (ranking.europeanMode) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 1행: 점수(gameScore/4) + 승/패/비김
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ranking.displayGameScore?.toStringAsFixed(1) ?? '-',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${ranking.wins}승${ranking.losses}패${ranking.jigoes != null && ranking.jigoes! > 0 ? ' ${ranking.jigoes}무' : ''}',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // 2행: SOS / SODOS / SOSOS (4로 나누어 표시)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ranking.sos != null)
                      Text(
                        'SOS:${(ranking.sos! / 4).toStringAsFixed(1)}',
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    if (ranking.sodos != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        'SODOS:${(ranking.sodos! / 4).toStringAsFixed(1)}',
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                    if (ranking.sosos != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        'SOSOS:${(ranking.sosos! / 4).toStringAsFixed(1)}',
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ]
          // 기본: 전적 + SOS/SOSOS (스위스리그)
          else ...[
            // SOS, SOSOS가 있으면 스위스리그 포맷
            if (ranking.sos != null || ranking.sosos != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ranking.record,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (ranking.sos != null)
                        Text(
                          'SOS:${ranking.sos!.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary),
                        ),
                      if (ranking.sosos != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          'SOSOS:${ranking.sosos!.toStringAsFixed(1)}',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ],
              )
            else ...[
              Text(
                ranking.record,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              if (ranking.score != null) ...[
                const SizedBox(width: 12),
                Text(
                  ranking.score!.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppColors.background;
    }
  }
}
