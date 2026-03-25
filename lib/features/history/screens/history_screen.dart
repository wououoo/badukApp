import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/user_provider.dart';
import '../../../data/models/contest_history.dart';
import '../../../data/models/mcmahon_history.dart';

/// 기록 화면 (런너블 스타일)
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('나의 기록'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 탭바
          _buildTabBar(),
          // 탭 콘텐츠
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _ContestHistoryTab(),
                _McMahonScoreTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: '참가 이력'),
          Tab(text: '맥마흔 점수'),
        ],
      ),
    );
  }
}

class _ContestHistoryTab extends ConsumerStatefulWidget {
  const _ContestHistoryTab();

  @override
  ConsumerState<_ContestHistoryTab> createState() => _ContestHistoryTabState();
}

class _ContestHistoryTabState extends ConsumerState<_ContestHistoryTab> {
  final _scrollController = ScrollController();

  // 확장된 대회 gameRoomId
  int? _expandedGameRoomId;
  // 라운드 결과 캐시
  final Map<int, List<McMahonRoundResult>> _roundResultsCache = {};
  // 로딩 중인 gameRoomId
  int? _loadingGameRoomId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contestHistoryProvider.notifier).loadHistory(refresh: true);
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(contestHistoryProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _roundResultsCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(contestHistoryProvider);

    if (historyState.isLoading && historyState.history.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (historyState.error != null && historyState.history.isEmpty) {
      return _buildErrorState();
    }

    if (historyState.history.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(contestHistoryProvider.notifier).loadHistory(refresh: true),
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: historyState.history.length + (historyState.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= historyState.history.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }

          final item = historyState.history[index];
          return _buildHistoryItem(item);
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              '데이터를 불러올 수 없습니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => ref
                  .read(contestHistoryProvider.notifier)
                  .loadHistory(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_outlined,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              '참가 이력이 없습니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '대회에 참가하면 이력이 기록됩니다',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 대회 유형별 뱃지 색상
  Color _getContestTypeColor(String? contestType) {
    switch (contestType) {
      case 'MCM':
        return const Color(0xFF3B82F6); // 파란색
      case 'SWISS':
        return const Color(0xFF10B981); // 초록색
      case 'FULL_LEAGUE':
        return const Color(0xFF8B5CF6); // 보라색
      case 'TEAM_SWISS':
        return const Color(0xFFF59E0B); // 주황색
      case 'TEAM_FULL_LEAGUE':
        return const Color(0xFFEF4444); // 빨간색
      case 'DE':
        return const Color(0xFF6366F1); // 인디고
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildContestTypeBadge(ContestHistory item) {
    final typeText = item.contestTypeText;
    if (typeText.isEmpty) return const SizedBox.shrink();

    final color = _getContestTypeColor(item.contestType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        typeText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildHistoryItem(ContestHistory item) {
    final gameRoomId = item.gameRoomId;
    final isExpanded = _expandedGameRoomId == gameRoomId;
    final isLoading = _loadingGameRoomId == gameRoomId;
    final roundResults = gameRoomId != null ? _roundResultsCache[gameRoomId] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 메인 항목 (클릭 가능)
          InkWell(
            onTap: gameRoomId != null ? () => _toggleExpand(item) : null,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 순위 표시
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          item.rankText,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // 대회 정보
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 대회 유형 뱃지 + 대회명
                            Row(
                              children: [
                                _buildContestTypeBadge(item),
                                if (item.contestTypeText.isNotEmpty)
                                  const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.contestName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.dateText} | ${item.sortName}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // 단체전 팀명 표시
                            if (item.teamName != null && item.teamName!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                '팀: ${item.teamName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // 확장 아이콘
                      if (gameRoomId != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 전적: DE는 예선/본선 분리 표시
                  if (item.hasDeStageData) ...[
                    // DE 예선/본선 분리 표시
                    Row(
                      children: [
                        _buildStageStatChip('예선', item.groupWins ?? 0, item.groupLosses ?? 0),
                        const SizedBox(width: 8),
                        if (item.advancedToTournament == true)
                          _buildStageStatChip('본선', item.tournamentWins ?? 0, item.tournamentLosses ?? 0)
                        else
                          _buildStatChip('예선 탈락', AppColors.textSecondary),
                      ],
                    ),
                  ] else ...[
                    // 일반 전적 표시
                    Row(
                      children: [
                        _buildStatChip('${item.wins}승', AppColors.success),
                        const SizedBox(width: 8),
                        _buildStatChip('${item.losses}패', AppColors.error),
                        if (item.scoreChange != null) ...[
                          const SizedBox(width: 8),
                          _buildStatChip(
                            '${item.scoreChange! >= 0 ? '+' : ''}${item.scoreChange}점',
                            item.scoreChange! >= 0
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 확장된 라운드 결과
          if (isExpanded) ...[
            Divider(height: 1, color: AppColors.border),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              )
            else if (roundResults != null && roundResults.isNotEmpty)
              item.isDE
                  ? _buildStageGroupedResults(roundResults)
                  : _buildRoundResultsList(roundResults)
            else
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '상세 전적을 불러올 수 없습니다',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// DE 대회 라운드 결과를 예선/본선으로 그룹화하여 표시
  Widget _buildStageGroupedResults(List<McMahonRoundResult> results) {
    final groupResults = results.where((r) => r.isGroupStage).toList();
    final tournamentResults = results.where((r) => r.isTournamentStage).toList();
    // 스테이지 구분 없는 결과
    final otherResults = results.where((r) => r.stage == null).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (groupResults.isNotEmpty) ...[
            _buildStageHeader('예선 (그룹 스테이지)', AppColors.textSecondary),
            const SizedBox(height: 6),
            ...groupResults.map((r) => _buildRoundResultRow(r)),
          ],
          if (tournamentResults.isNotEmpty) ...[
            if (groupResults.isNotEmpty) const SizedBox(height: 12),
            _buildStageHeader('본선 (토너먼트)', AppColors.primary),
            const SizedBox(height: 6),
            ...tournamentResults.map((r) => _buildRoundResultRow(r)),
          ],
          if (otherResults.isNotEmpty) ...[
            if (groupResults.isNotEmpty || tournamentResults.isNotEmpty)
              const SizedBox(height: 12),
            Text(
              '라운드별 결과',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            ...otherResults.map((r) => _buildRoundResultRow(r)),
          ],
        ],
      ),
    );
  }

  /// 스테이지 헤더 위젯
  Widget _buildStageHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Future<void> _toggleExpand(ContestHistory item) async {
    final gameRoomId = item.gameRoomId;
    if (gameRoomId == null) return;

    if (_expandedGameRoomId == gameRoomId) {
      // 접기
      setState(() {
        _expandedGameRoomId = null;
      });
    } else {
      // 펼치기
      setState(() {
        _expandedGameRoomId = gameRoomId;
      });

      // 캐시에 없으면 로드
      if (!_roundResultsCache.containsKey(gameRoomId)) {
        setState(() {
          _loadingGameRoomId = gameRoomId;
        });

        try {
          final userService = ref.read(userServiceProvider);
          // contestType에 따라 적절한 API 호출
          final List<McMahonRoundResult> results;
          if (item.isMcm) {
            results = await userService.getMcMahonRoundResults(gameRoomId);
          } else {
            results = await userService.getContestRoundResults(gameRoomId);
          }
          if (mounted) {
            setState(() {
              _roundResultsCache[gameRoomId] = results;
              _loadingGameRoomId = null;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _roundResultsCache[gameRoomId] = [];
              _loadingGameRoomId = null;
            });
          }
        }
      }
    }
  }

  Widget _buildRoundResultsList(List<McMahonRoundResult> results) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '라운드별 결과',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...results.map((r) => _buildRoundResultRow(r)),
        ],
      ),
    );
  }

  Widget _buildRoundResultRow(McMahonRoundResult result) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // 라운드 번호
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              '${result.round}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 상대 이름
          Expanded(
            child: Text(
              result.opponentName,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // 결과
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: result.isWin
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              result.resultText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: result.isWin ? AppColors.success : AppColors.error,
              ),
            ),
          ),
          // 점수 변동
          if (result.pointChange != null) ...[
            const SizedBox(width: 8),
            Text(
              result.pointChange! >= 0 ? '+${result.pointChange}' : '${result.pointChange}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: result.pointChange! >= 0 ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  /// DE 예선/본선 전적 칩 (예: "예선 2승1패")
  Widget _buildStageStatChip(String stageName, int wins, int losses) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$stageName ',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          Text(
            '${wins}승',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Text(
            '${losses}패',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _McMahonScoreTab extends ConsumerStatefulWidget {
  const _McMahonScoreTab();

  @override
  ConsumerState<_McMahonScoreTab> createState() => _McMahonScoreTabState();
}

class _McMahonScoreTabState extends ConsumerState<_McMahonScoreTab> {
  // 확장된 대회 gameRoomId
  int? _expandedGameRoomId;
  // 라운드 결과 캐시
  final Map<int, List<McMahonRoundResult>> _roundResultsCache = {};
  // 로딩 중인 gameRoomId
  int? _loadingGameRoomId;

  @override
  Widget build(BuildContext context) {
    final mcmahonHistory = ref.watch(mcmahonHistoryProvider);

    return mcmahonHistory.when(
      data: (data) => _buildContent(context, ref, data),
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (error, _) => _buildErrorState(ref),
    );
  }

  Widget _buildErrorState(WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              '데이터를 불러올 수 없습니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(mcmahonHistoryProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, McMahonScoreSummary data) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(mcmahonHistoryProvider);
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 현재 점수 카드
            _buildScoreCard(data),
            const SizedBox(height: 24),
            // 점수 추이 그래프
            if (data.history.length >= 2) ...[
              _buildScoreChart(data),
              const SizedBox(height: 24),
            ],
            // 점수 변동 이력 섹션
            _buildHistorySection(data),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(McMahonScoreSummary data) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            '현재 맥마흔 점수',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${data.currentScore.toInt()}',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            '점',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          if (data.recentChange != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    data.recentChange! >= 0
                        ? Icons.trending_up
                        : Icons.trending_down,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${data.recentChange! >= 0 ? '+' : ''}${data.recentChange!.toInt()} (최근 대회)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreChart(McMahonScoreSummary data) {
    // 날짜순 정렬 (오래된 순)
    final sortedHistory = List<McMahonHistory>.from(data.history)
      ..sort((a, b) {
        if (a.contestDate == null || b.contestDate == null) return 0;
        return a.contestDate!.compareTo(b.contestDate!);
      });

    // 점수 데이터 추출
    final spots = <FlSpot>[];
    final labels = <String>[];

    for (int i = 0; i < sortedHistory.length; i++) {
      final item = sortedHistory[i];
      if (item.scoreAfter != null) {
        spots.add(FlSpot(i.toDouble(), item.scoreAfter!));
        labels.add(item.shortDateText);
      }
    }

    if (spots.isEmpty) {
      return const SizedBox.shrink();
    }

    // 최소/최대값 계산 (정수 기준, 여백 포함)
    final minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;

    // Y축 범위를 정수로 조정 (최소 50 간격)
    final yInterval = range < 50 ? 10.0 : (range / 4).ceilToDouble();
    final adjustedMinY = (minY - yInterval / 2).floorToDouble();
    final adjustedMaxY = (maxY + yInterval / 2).ceilToDouble();

    // 최근 추세 계산
    final isUpward = spots.length >= 2 && spots.last.y >= spots.first.y;
    final totalChange = spots.length >= 2 ? spots.last.y - spots.first.y : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Icon(
                Icons.show_chart,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                '점수 추이',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              // 총 변동
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isUpward
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUpward ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14,
                      color: isUpward ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${totalChange >= 0 ? '+' : ''}${totalChange.toInt()}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isUpward ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 차트
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: adjustedMinY,
                maxY: adjustedMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.border.withOpacity(0.5),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        // 첫/끝 라벨은 숨김 (경계선 겹침 방지)
                        if (value == meta.min || value == meta.max) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: spots.length > 6 ? (spots.length / 4).ceil().toDouble() : 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[index],
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final isLast = index == spots.length - 1;
                        return FlDotCirclePainter(
                          radius: isLast ? 6 : 4,
                          color: isLast ? AppColors.primary : AppColors.surface,
                          strokeWidth: 2,
                          strokeColor: AppColors.primary,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withOpacity(0.2),
                          AppColors.primary.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => AppColors.primary,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        final contestName = index < sortedHistory.length
                            ? sortedHistory[index].contestName
                            : '';
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(1)}점\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: contestName.length > 15
                                  ? '${contestName.substring(0, 15)}...'
                                  : contestName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 범례
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '총 ${sortedHistory.length}개 대회',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(McMahonScoreSummary data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 20, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text(
              '점수 변동 이력',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (data.history.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '점수 변동 이력이 없습니다',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...data.history.map((item) => _buildHistoryItem(item)),
      ],
    );
  }

  Widget _buildHistoryItem(McMahonHistory item) {
    final gameRoomId = item.gameRoomId;
    final isExpanded = _expandedGameRoomId == gameRoomId;
    final isLoading = _loadingGameRoomId == gameRoomId;
    final roundResults = gameRoomId != null ? _roundResultsCache[gameRoomId] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 메인 항목 (클릭 가능)
          InkWell(
            onTap: gameRoomId != null ? () => _toggleExpand(item) : null,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 아이콘
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.isPositive
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.isPositive ? Icons.trending_up : Icons.trending_down,
                      color: item.isPositive ? AppColors.success : AppColors.error,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // 대회 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.contestName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              item.dateText,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (item.wins > 0 || item.losses > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${item.wins}승 ${item.losses}패',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 점수 변동
                  Text(
                    _formatScoreChange(item.scoreChange),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: item.isPositive ? AppColors.success : AppColors.error,
                    ),
                  ),
                  // 확장 아이콘
                  if (gameRoomId != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 확장된 라운드 결과
          if (isExpanded) ...[
            Divider(height: 1, color: AppColors.border),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              )
            else if (roundResults != null && roundResults.isNotEmpty)
              _buildRoundResultsList(roundResults)
            else
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '상세 전적을 불러올 수 없습니다',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _formatScoreChange(double? change) {
    if (change == null) return '-';
    final intChange = change.toInt();
    if (intChange >= 0) return '+$intChange';
    return '$intChange';
  }

  Future<void> _toggleExpand(McMahonHistory item) async {
    final gameRoomId = item.gameRoomId;
    if (gameRoomId == null) return;

    if (_expandedGameRoomId == gameRoomId) {
      // 접기
      setState(() {
        _expandedGameRoomId = null;
      });
    } else {
      // 펼치기
      setState(() {
        _expandedGameRoomId = gameRoomId;
      });

      // 캐시에 없으면 로드
      if (!_roundResultsCache.containsKey(gameRoomId)) {
        setState(() {
          _loadingGameRoomId = gameRoomId;
        });

        try {
          final userService = ref.read(userServiceProvider);
          final results = await userService.getMcMahonRoundResults(gameRoomId);
          if (mounted) {
            setState(() {
              _roundResultsCache[gameRoomId] = results;
              _loadingGameRoomId = null;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _roundResultsCache[gameRoomId] = [];
              _loadingGameRoomId = null;
            });
          }
        }
      }
    }
  }

  Widget _buildRoundResultsList(List<McMahonRoundResult> results) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '라운드별 결과',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...results.map((r) => _buildRoundResultRow(r)),
        ],
      ),
    );
  }

  Widget _buildRoundResultRow(McMahonRoundResult result) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // 라운드 번호
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              '${result.round}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 상대 이름
          Expanded(
            child: Text(
              result.opponentName,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // 결과
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: result.isWin
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              result.resultText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: result.isWin ? AppColors.success : AppColors.error,
              ),
            ),
          ),
          // 점수 변동
          if (result.pointChange != null) ...[
            const SizedBox(width: 8),
            Text(
              result.pointChange! >= 0 ? '+${result.pointChange}' : '${result.pointChange}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: result.pointChange! >= 0 ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
