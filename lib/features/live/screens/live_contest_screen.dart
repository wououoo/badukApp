import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/live_contest.dart';
import '../../../data/services/live_contest_service.dart';
import '../widgets/live_de_content.dart';

/// 스크롤 속도를 줄이는 커스텀 Physics (고연령층 사용자 배려)
class _SlowScrollPhysics extends ClampingScrollPhysics {
  const _SlowScrollPhysics({super.parent});

  @override
  _SlowScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SlowScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // 관성 스크롤 속도를 40%로 줄임
    return super.createBallisticSimulation(position, velocity * 0.4);
  }
}

/// 라이브 대회 상세 화면
class LiveContestScreen extends StatefulWidget {
  final int contestId;

  const LiveContestScreen({super.key, required this.contestId});

  @override
  State<LiveContestScreen> createState() => _LiveContestScreenState();
}

class _LiveContestScreenState extends State<LiveContestScreen>
    with SingleTickerProviderStateMixin {
  final LiveContestService _service = LiveContestService();

  LiveContestDetail? _contest;
  LiveContestSort? _selectedSort;
  List<LiveStanding> _rankings = [];
  LivePairingsResponse? _pairingsResponse;
  int _selectedRound = 1;

  bool _isLoading = true;
  bool _isLoadingData = false;
  String? _error;

  // 맥마흔 정렬 방식 (score: 점수순, wins: 승수순)
  String _mcmSortBy = 'score';

  // linkedContests의 sorts도 합친 전체 부문 목록
  List<LiveContestSort> _allSorts = [];
  // sortId -> contestId 매핑 (linkedContests의 sort는 해당 대회 ID 사용)
  final Map<int, int> _sortContestIdMap = {};

  // 단체전 대진표 확장 상태 (id 기반)
  final Set<int> _expandedPairings = {};

  // 자동 새로고침
  Timer? _autoRefreshTimer;
  bool _autoRefreshEnabled = true;
  DateTime? _lastUpdated;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadContest();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_autoRefreshEnabled && !_isLoading && !_isLoadingData) {
        _refreshData();
      }
    });
  }

  /// 선택된 sort가 속한 contestId 반환
  int _getContestIdForSort(int sortId) {
    return _sortContestIdMap[sortId] ?? widget.contestId;
  }

  Future<void> _refreshData() async {
    if (_selectedSort == null || _isDEType) return;
    final contestId = _getContestIdForSort(_selectedSort!.id);
    try {
      // 순위표와 대진표를 독립적으로 로드 (하나 실패해도 다른 건 표시)
      List<LiveStanding> rankings = _rankings;
      LivePairingsResponse? pairingsResp = _pairingsResponse;

      try {
        rankings = await _service.getRankings(contestId, _selectedSort!.id);
      } catch (e) {
        debugPrint('순위표 새로고침 실패: $e');
      }

      try {
        pairingsResp = await _service.getPairings(contestId, _selectedSort!.id);
      } catch (e) {
        debugPrint('대진표 새로고침 실패: $e');
      }

      if (!mounted) return;
      setState(() {
        _rankings = rankings;
        _pairingsResponse = pairingsResp;
        // 새 라운드가 생겼는데 _selectedRound가 0이면 최신 라운드로 동기화
        if (pairingsResp != null && pairingsResp.maxRound > 0 && _selectedRound == 0) {
          _selectedRound = pairingsResp.maxRound;
        }
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      debugPrint('데이터 새로고침 실패: $e');
    }
  }

  Future<void> _loadContest() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final contest = await _service.getLiveContestDetail(widget.contestId);

      // linkedContests의 sorts도 합침 (React LiveTVPage.js와 동일)
      final allSorts = <LiveContestSort>[...contest.sorts];
      final sortContestIdMap = <int, int>{};
      for (final sort in contest.sorts) {
        sortContestIdMap[sort.id] = contest.id;
      }
      for (final linked in contest.linkedContests) {
        for (final sort in linked.sorts) {
          sortContestIdMap[sort.id] = linked.id;
          allSorts.add(sort);
        }
      }
      // 참가자 0명인 부문 제외
      allSorts.removeWhere((s) => (s.participantCount ?? 0) == 0);

      setState(() {
        _contest = contest;
        _allSorts = allSorts;
        _sortContestIdMap
          ..clear()
          ..addAll(sortContestIdMap);
        _isLoading = false;
      });

      // 첫 번째 부문 자동 선택
      if (_allSorts.isNotEmpty) {
        _selectSort(_allSorts.first);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectSort(LiveContestSort sort) async {
    final type = sort.contestType?.toUpperCase() ?? '';
    final isDE = type == 'DE' || type == 'TOURNAMENT';

    setState(() {
      _selectedSort = sort;
      // currentRound가 0이면 1로 보정 (아직 라운드가 시작되지 않은 경우)
      final round = sort.currentRound ?? 1;
      _selectedRound = round > 0 ? round : 1;
      // DE/TOURNAMENT는 전용 위젯이 자체 로딩하므로 여기서 로딩하지 않음
      if (!isDE) {
        _isLoadingData = true;
      }
    });

    if (isDE) return;

    final contestId = _getContestIdForSort(sort.id);
    try {
      // 순위표와 대진표를 독립적으로 로드 (하나 실패해도 다른 건 표시)
      List<LiveStanding> rankings = [];
      LivePairingsResponse? pairingsResp;

      try {
        rankings = await _service.getRankings(contestId, sort.id);
      } catch (e) {
        debugPrint('순위표 로드 실패: $e');
      }

      try {
        pairingsResp = await _service.getPairings(contestId, sort.id);
      } catch (e) {
        debugPrint('대진표 로드 실패: $e');
      }

      if (!mounted) return;
      setState(() {
        _rankings = rankings;
        _pairingsResponse = pairingsResp;
        // 대진표 응답의 maxRound로 _selectedRound 동기화
        if (pairingsResp != null && pairingsResp.maxRound > 0 && _selectedRound > pairingsResp.maxRound) {
          _selectedRound = pairingsResp.maxRound;
        } else if (pairingsResp != null && pairingsResp.maxRound > 0 && _selectedRound == 0) {
          _selectedRound = pairingsResp.maxRound;
        }
        _isLoadingData = false;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      debugPrint('데이터 로드 실패: $e');
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_contest?.contestName ?? '실시간 현황'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_autoRefreshEnabled ? Icons.sync : Icons.sync_disabled),
            tooltip: _autoRefreshEnabled ? '자동 새로고침 켜짐' : '자동 새로고침 꺼짐',
            onPressed: () {
              setState(() {
                _autoRefreshEnabled = !_autoRefreshEnabled;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadContest,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadContest,
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

    if (_contest == null) {
      return const Center(child: Text('대회 정보가 없습니다.'));
    }

    return Column(
      children: [
        // 대회 정보 헤더
        _buildContestHeader(),

        // 부문 선택
        if (_allSorts.isNotEmpty) _buildSortSelector(),

        // 탭바 (DE/TOURNAMENT는 자체 탭 사용)
        if (_selectedSort != null && !_isDEType) _buildTabBar(),

        // 내용
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContestHeader() {
    final contest = _contest!;
    final dateFormat = DateFormat('MM/dd');

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (contest.fullLocation.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: AppColors.textSecondary.withOpacity(0.7)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    contest.fullLocation,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (contest.startDate != null)
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary.withOpacity(0.7)),
                const SizedBox(width: 4),
                Text(
                  contest.endDate != null && contest.startDate != contest.endDate
                      ? '${dateFormat.format(contest.startDate!)} ~ ${dateFormat.format(contest.endDate!)}'
                      : dateFormat.format(contest.startDate!),
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary.withOpacity(0.8),
                  ),
                ),
                if (_lastUpdated != null) ...[
                  const Spacer(),
                  Text(
                    '${DateFormat('HH:mm:ss').format(_lastUpdated!)} 업데이트',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSortSelector() {
    return Container(
      height: 48,
      color: AppColors.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _allSorts.length,
        itemBuilder: (context, index) {
          final sort = _allSorts[index];
          final isSelected = _selectedSort?.id == sort.id;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: ChoiceChip(
              label: Text(sort.name),
              selected: isSelected,
              onSelected: (_) => _selectSort(sort),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor: AppColors.background,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.surface,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        tabs: const [
          Tab(text: '순위표'),
          Tab(text: '대진표'),
        ],
      ),
    );
  }

  /// DE/TOURNAMENT 타입인지 확인
  bool get _isDEType {
    final type = _selectedSort?.contestType?.toUpperCase() ?? '';
    return type == 'DE' || type == 'TOURNAMENT';
  }

  Widget _buildContent() {
    if (_selectedSort == null) {
      return const Center(child: Text('부문을 선택하세요'));
    }

    // DE/TOURNAMENT 타입은 전용 위젯 사용
    if (_isDEType) {
      final deContestId = _getContestIdForSort(_selectedSort!.id);
      return LiveDEContent(
        // 부문 변경 시 Flutter가 기존 State를 재사용해 이전 부문 데이터가 남는 문제 방지.
        // sortId 기반 key로 위젯을 강제 재생성 → initState 재실행으로 새 부문 데이터를 즉시 로드.
        key: ValueKey('de-$deContestId-${_selectedSort!.id}'),
        contestId: deContestId,
        sortId: _selectedSort!.id,
      );
    }

    if (_isLoadingData) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildRankingsTab(),
        _buildPairingsTab(),
      ],
    );
  }

  Widget _buildRankingsTab() {
    if (_rankings.isEmpty) {
      return const Center(child: Text('순위표 정보가 없습니다.'));
    }

    final contestType = _selectedSort?.contestType?.toUpperCase() ?? '';
    final isTeamSwiss = contestType == 'TEAM_SWISS';
    final isTeamFullLeague = contestType == 'TEAM_FULL_LEAGUE';
    final isTeamContest = isTeamSwiss || isTeamFullLeague;
    final isMcMahon = contestType == 'MCM';
    final isFullLeague = contestType == 'FULL_LEAGUE';
    final isEuropeanMcMahon = isMcMahon && _rankings.isNotEmpty && _rankings.first.europeanMode;

    // 디버깅: 첫 아이템의 데이터 확인
    if (_rankings.isNotEmpty) {
      final first = _rankings.first;
      debugPrint('순위표 데이터 - contestType: $contestType, name: ${first.name}, '
          'wins: ${first.wins}, losses: ${first.losses}, draws: ${first.draws}, '
          'boardWins: ${first.totalIndividualWins}, teamName: ${first.teamName}, '
          'playerWins: ${first.playerWins}, europeanMode: ${first.europeanMode}');
    }

    // 맥마흔: 정렬 적용 (유럽식은 서버 정렬 유지)
    List<LiveStanding> sortedRankings = _rankings;
    if (isMcMahon && !isEuropeanMcMahon) {
      sortedRankings = _sortMcMahonRankings(_rankings, _mcmSortBy);
    }

    return Column(
      children: [
        // 맥마흔: 정렬 토글 버튼 (유럽식은 서버 정렬 고정이므로 숨김)
        if (isMcMahon && !isEuropeanMcMahon) _buildMcMahonSortToggle(),

        // 순위표 목록
        Expanded(
          child: ListView.builder(
            physics: const _SlowScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: sortedRankings.length,
            itemBuilder: (context, index) {
              final standing = sortedRankings[index];

              if (isTeamContest) {
                return _buildTeamRankingCard(standing, index + 1, isTeamFullLeague);
              } else if (isEuropeanMcMahon) {
                return _buildEuropeanMcMahonRankingCard(standing, standing.rank > 0 ? standing.rank : index + 1);
              } else if (isMcMahon) {
                return _buildMcMahonRankingCard(standing, index + 1);
              } else if (isFullLeague) {
                return _buildFullLeagueRankingCard(standing, index + 1);
              } else {
                return _buildSwissRankingCard(standing, index + 1);
              }
            },
          ),
        ),
      ],
    );
  }

  /// 맥마흔 정렬 토글 버튼
  Widget _buildMcMahonSortToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSortButton('점수순', 'score'),
          const SizedBox(width: 8),
          _buildSortButton('승수순', 'wins'),
        ],
      ),
    );
  }

  Widget _buildSortButton(String label, String value) {
    final isSelected = _mcmSortBy == value;
    return GestureDetector(
      onTap: () => setState(() => _mcmSortBy = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  /// 맥마흔 순위 정렬
  List<LiveStanding> _sortMcMahonRankings(List<LiveStanding> rankings, String sortBy) {
    final sorted = List<LiveStanding>.from(rankings);
    sorted.sort((a, b) {
      // 삭제된 유저는 맨 아래로
      if (a.isDeleted != b.isDeleted) {
        return a.isDeleted ? 1 : -1;
      }

      if (sortBy == 'score') {
        // 점수순: 맥마흔점수 → 승수 → 참가번호
        final scoreCompare = (b.mcMahonScore ?? 0).compareTo(a.mcMahonScore ?? 0);
        if (scoreCompare != 0) return scoreCompare;
        final winsCompare = b.wins.compareTo(a.wins);
        if (winsCompare != 0) return winsCompare;
      } else {
        // 승수순: 승수 → 맥마흔점수 → 참가번호
        final winsCompare = b.wins.compareTo(a.wins);
        if (winsCompare != 0) return winsCompare;
        final scoreCompare = (b.mcMahonScore ?? 0).compareTo(a.mcMahonScore ?? 0);
        if (scoreCompare != 0) return scoreCompare;
      }
      return (a.participantNumber ?? 0).compareTo(b.participantNumber ?? 0);
    });
    return sorted;
  }

  /// 맥마흔 순위 카드
  Widget _buildMcMahonRankingCard(LiveStanding standing, int rank) {
    final isDeleted = standing.isDeleted;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: isDeleted ? AppColors.background : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDeleted ? AppColors.textSecondary.withOpacity(0.2) : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 순위
            _buildRankBadge(rank),
            const SizedBox(width: 12),

            // 이름 + 소속
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          standing.cleanName,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: isDeleted ? AppColors.textSecondary : AppColors.textPrimary,
                            decoration: isDeleted ? TextDecoration.lineThrough : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDeleted)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '없음',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                    ],
                  ),
                  if (standing.club != null && standing.club!.isNotEmpty)
                    Text(
                      standing.club!,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary.withOpacity(0.8),
                      ),
                    ),
                ],
              ),
            ),

            // 맥마흔 점수 + 성적
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${standing.mcMahonScore ?? 0}점',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '${standing.wins}승 ${standing.losses}패',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 유럽식 맥마흔 순위 카드
  Widget _buildEuropeanMcMahonRankingCard(LiveStanding standing, int rank) {
    final isDeleted = standing.isDeleted;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: isDeleted ? AppColors.background : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDeleted ? AppColors.textSecondary.withOpacity(0.2) : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 상단: 순위 + 이름 + 점수
            Row(
              children: [
                _buildRankBadge(rank),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              standing.cleanName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: isDeleted ? AppColors.textSecondary : AppColors.textPrimary,
                                decoration: isDeleted ? TextDecoration.lineThrough : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isDeleted)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.textSecondary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '없음',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ),
                        ],
                      ),
                      if (standing.club != null && standing.club!.isNotEmpty)
                        Text(
                          standing.club!,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary.withOpacity(0.8),
                          ),
                        ),
                    ],
                  ),
                ),
                // 점수 (displayGameScore)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${standing.displayGameScore?.toStringAsFixed(1) ?? '0.0'}점',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '${standing.wins}승 ${standing.losses}패${(standing.jigoes ?? 0) > 0 ? ' ${standing.jigoes}비김' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 하단: SOS / SODOS / SOSOS
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildEuropeanStatItem('SOS', standing.sos),
                  _buildEuropeanStatItem('SODOS', standing.sodos),
                  _buildEuropeanStatItem('SOSOS', standing.sosos),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 유럽식 맥마흔 통계 아이템 (SOS/SODOS/SOSOS - 값을 4로 나누어 표시)
  Widget _buildEuropeanStatItem(String label, double? value) {
    final displayValue = value != null ? (value / 4).toStringAsFixed(1) : '-';
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          displayValue,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  /// 스위스리그 순위 카드
  Widget _buildSwissRankingCard(LiveStanding standing, int rank) {
    final isNone = (standing.none ?? 0) != 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: isNone ? AppColors.background : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isNone ? AppColors.textSecondary.withOpacity(0.2) : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 순위
            _buildRankBadge(rank),
            const SizedBox(width: 12),

            // 이름
            Expanded(
              child: Text(
                standing.cleanName,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: isNone ? AppColors.textSecondary : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // 승수 + 승점 + SOS
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${standing.wins}승',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '승점 ${(standing.useSwissLeague ?? 0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 풀리그 순위 카드
  Widget _buildFullLeagueRankingCard(LiveStanding standing, int rank) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 순위
            _buildRankBadge(rank),
            const SizedBox(width: 12),

            // 이름
            Expanded(
              child: Text(
                standing.cleanName,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // 승/패/승률
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${standing.wins}승 ${standing.losses}패',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (standing.winRate != null)
                  Text(
                    standing.winRate!,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary.withOpacity(0.8),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 단체전 순위 카드
  Widget _buildTeamRankingCard(LiveStanding standing, int rank, bool isFullLeague) {
    final hasPlayerWins = standing.playerWins != null && standing.playerWins!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // 순위
                _buildRankBadge(rank),
                const SizedBox(width: 12),

                // 팀명
                Expanded(
                  child: Text(
                    standing.teamName ?? standing.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // 성적
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isFullLeague)
                      Text(
                        '${standing.wins}승 ${standing.draws ?? 0}무 ${standing.losses}패',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      )
                    else
                      Text(
                        '${standing.wins}승',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    Text(
                      '총 ${standing.totalIndividualWins ?? 0}승',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // 장별 승수
            if (hasPlayerWins) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(standing.playerWins!.length, (i) {
                    return _buildBoardWinBadge(i + 1, standing.playerWins![i]);
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 장별 승수 뱃지
  Widget _buildBoardWinBadge(int boardNumber, int wins) {
    return Column(
      children: [
        Text(
          '${boardNumber}장',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 32,
          height: 26,
          decoration: BoxDecoration(
            color: wins > 0 ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: wins > 0 ? AppColors.primary.withOpacity(0.3) : AppColors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$wins',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: wins > 0 ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  /// 순위 배지
  Widget _buildRankBadge(int rank) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _getRankColor(rank),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: rank <= 3 ? Colors.white : AppColors.textPrimary,
        ),
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

  Widget _buildPairingsTab() {
    if (_pairingsResponse == null || _pairingsResponse!.pairings.isEmpty) {
      return const Center(child: Text('대진표 정보가 없습니다.'));
    }

    final maxRound = _pairingsResponse!.maxRound;
    final pairings = _pairingsResponse!.pairings
        .where((p) => p.round == _selectedRound)
        .toList();
    // 풀리그 홀수 인원: 선택 라운드의 쉬는 선수(부전승)
    final restingPlayer = _pairingsResponse!.restingByRound[_selectedRound];

    return Column(
      children: [
        // 라운드 선택
        if (maxRound > 1)
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: maxRound,
              itemBuilder: (context, index) {
                final round = index + 1;
                final isSelected = round == _selectedRound;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: ChoiceChip(
                    label: Text('$round라운드'),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedRound = round),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    backgroundColor: AppColors.surface,
                  ),
                );
              },
            ),
          ),

        // 대진표 목록 (쉬는 선수가 있으면 마지막 항목으로 카드 추가)
        Expanded(
          child: (pairings.isEmpty && restingPlayer == null)
              ? const Center(child: Text('해당 라운드 대진이 없습니다.'))
              : ListView.builder(
                  physics: const _SlowScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: pairings.length + (restingPlayer != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == pairings.length && restingPlayer != null) {
                      return _buildLiveRestingPlayerCard(restingPlayer);
                    }
                    return _buildPairingCard(pairings[index]);
                  },
                ),
        ),
      ],
    );
  }

  /// 풀리그 쉬는 선수(부전승) 카드
  Widget _buildLiveRestingPlayerCard(String playerName) {
    final cleanName = playerName.replaceAll(RegExp(r'\s+\d+(단|급)$'), '').trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
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
              '쉬는 선수(부전승): $cleanName',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.warning),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairingCard(LivePairing pairing) {
    // winnerId가 있으면 ID로 비교(맥마흔), 없으면 이름으로 비교(스위스리그)
    bool isPlayer1Winner = false;
    bool isPlayer2Winner = false;
    if (pairing.winnerId != null && pairing.player1Id != null) {
      isPlayer1Winner = pairing.winnerId == pairing.player1Id;
      isPlayer2Winner = pairing.winnerId == pairing.player2Id;
    } else if (pairing.winnerName != null && pairing.isCompleted && !pairing.isByeMatch) {
      isPlayer1Winner = pairing.winnerName == pairing.player1Name;
      isPlayer2Winner = pairing.winnerName == pairing.player2Name;
    }

    final hasBoards = pairing.boards.isNotEmpty;
    final isExpanded = pairing.id != null && _expandedPairings.contains(pairing.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: hasBoards && pairing.id != null
            ? () {
                setState(() {
                  if (_expandedPairings.contains(pairing.id)) {
                    _expandedPairings.remove(pairing.id);
                  } else {
                    _expandedPairings.add(pairing.id!);
                  }
                });
              }
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  // 테이블 번호
                  if (pairing.tableNumber != null)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${pairing.tableNumber}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  if (pairing.tableNumber != null) const SizedBox(width: 12),

                  // 선수/팀 1
                  Expanded(
                    child: _buildPlayerInfo(
                      name: pairing.player1Name ?? '-',
                      isWinner: isPlayer1Winner,
                      isBlack: true,
                      score: hasBoards ? pairing.player1Score : null,
                    ),
                  ),

                  // VS (웹과 동일하게 항상 'vs', 부전승 표시는 상대 셀에서)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'vs',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),

                  // 선수/팀 2 (부전승이면 상대 자리에 '부전승' 표시 — 웹과 동일)
                  Expanded(
                    child: _buildPlayerInfo(
                      name: pairing.isByeMatch ? '부전승' : (pairing.player2Name ?? '-'),
                      isWinner: isPlayer2Winner,
                      isBlack: false,
                      isBye: pairing.isByeMatch,
                      score: hasBoards ? pairing.player2Score : null,
                    ),
                  ),

                  // 보드 상세 펼침 아이콘
                  if (hasBoards)
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                ],
              ),

              // 보드별 상세 결과
              if (hasBoards && isExpanded) ...[
                const SizedBox(height: 8),
                Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 8),
                ...pairing.boards.map((board) => _buildBoardResultRow(board)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 보드별 개인 매치 결과 행
  Widget _buildBoardResultRow(BoardResult board) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          // 장 번호
          SizedBox(
            width: 36,
            child: Text(
              '${board.boardNumber}장',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),

          // 팀1 선수
          Expanded(
            child: Text(
              board.team1MemberName ?? '-',
              style: TextStyle(
                fontSize: 15,
                fontWeight: board.isTeam1Winner ? FontWeight.w700 : FontWeight.normal,
                color: board.isCompleted && !board.isTeam1Winner
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // 결과 아이콘
          SizedBox(
            width: 36,
            child: board.isCompleted
                ? Icon(
                    Icons.circle,
                    size: 10,
                    color: board.isTeam1Winner
                        ? AppColors.info
                        : (board.isTeam2Winner ? AppColors.error : AppColors.textSecondary),
                  )
                : Text(
                    'vs',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
          ),

          // 팀2 선수
          Expanded(
            child: Text(
              board.team2MemberName ?? '-',
              style: TextStyle(
                fontSize: 15,
                fontWeight: board.isTeam2Winner ? FontWeight.w700 : FontWeight.normal,
                color: board.isCompleted && !board.isTeam2Winner
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerInfo({
    required String name,
    required bool isWinner,
    required bool isBlack,
    bool isBye = false,
    int? score,
  }) {
    return Row(
      mainAxisAlignment: isBlack ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        if (!isBlack && isWinner)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.emoji_events, size: 16, color: Color(0xFFFFD700)),
          ),
        if (!isBlack && score != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              '($score)',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withOpacity(0.8),
              ),
            ),
          ),
        Flexible(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isWinner ? FontWeight.w600 : FontWeight.normal,
              color: isBye && !isBlack ? AppColors.textSecondary : AppColors.textPrimary,
            ),
            textAlign: isBlack ? TextAlign.left : TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isBlack && score != null)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '($score)',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withOpacity(0.8),
              ),
            ),
          ),
        if (isBlack && isWinner)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.emoji_events, size: 16, color: Color(0xFFFFD700)),
          ),
      ],
    );
  }
}
