import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/live_de.dart';
import '../../../data/services/live_contest_service.dart';

/// 스크롤 속도를 줄이는 커스텀 Physics (고연령층 사용자 배려)
class _SlowScrollPhysics extends ClampingScrollPhysics {
  const _SlowScrollPhysics({super.parent});

  @override
  _SlowScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SlowScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    return super.createBallisticSimulation(position, velocity * 0.4);
  }
}

/// DE(더블엘리미네이션) 전용 라이브 콘텐츠 위젯
/// 예선(조별 리그) + 본선(토너먼트) 2단계 구조
class LiveDEContent extends StatefulWidget {
  final int contestId;
  final int sortId;

  const LiveDEContent({
    super.key,
    required this.contestId,
    required this.sortId,
  });

  @override
  State<LiveDEContent> createState() => _LiveDEContentState();
}

class _LiveDEContentState extends State<LiveDEContent>
    with SingleTickerProviderStateMixin {
  final LiveContestService _service = LiveContestService();

  late TabController _stageTabController;

  // 예선 데이터
  List<int> _groups = [];
  int _selectedGroup = 1;
  List<DEPreliminaryRanking> _prelimRankings = [];
  DEPreliminaryPairingsResponse? _prelimPairings;
  int _selectedPrelimRound = 1;

  // 본선 데이터
  List<DETournamentRanking> _tournamentRankings = [];
  DETournamentPairingsResponse? _tournamentPairings;
  int _selectedTournamentRound = 1;

  bool _isLoading = true;
  bool _isLoadingData = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _stageTabController = TabController(length: 2, vsync: this);
    _stageTabController.addListener(_onStageTabChanged);
    _loadGroups();
  }

  @override
  void dispose() {
    _stageTabController.removeListener(_onStageTabChanged);
    _stageTabController.dispose();
    super.dispose();
  }

  void _onStageTabChanged() {
    if (!_stageTabController.indexIsChanging) return;
    if (_stageTabController.index == 1) {
      _loadTournamentData();
    }
  }

  /// 그룹 목록 로드
  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final groups = await _service.getDEGroups(
        widget.contestId,
        widget.sortId,
      );
      debugPrint('DE 그룹 로드 성공: $groups');
      setState(() {
        _groups = groups;
        _isLoading = false;
        if (groups.isNotEmpty) {
          _selectedGroup = groups.first;
        }
      });
      if (groups.isNotEmpty) {
        _loadPreliminaryData();
      }
    } catch (e) {
      debugPrint('DE 그룹 로드 실패: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '그룹 데이터 로드 실패: $e';
      });
    }
  }

  /// 예선 데이터 로드 (순위 + 대진)
  Future<void> _loadPreliminaryData() async {
    setState(() {
      _isLoadingData = true;
      _hasError = false;
    });
    try {
      // 순위표와 대진표를 독립적으로 로드 (하나 실패해도 다른 건 표시)
      List<DEPreliminaryRanking> rankings = [];
      DEPreliminaryPairingsResponse? pairings;

      try {
        rankings = await _service.getDEPreliminaryRankings(
          widget.contestId,
          widget.sortId,
          _selectedGroup,
        );
        debugPrint('DE 예선 순위표 로드 성공: ${rankings.length}건');
      } catch (e) {
        debugPrint('DE 예선 순위표 로드 실패: $e');
      }

      try {
        pairings = await _service.getDEPreliminaryPairings(
          widget.contestId,
          widget.sortId,
          _selectedGroup,
        );
        debugPrint('DE 예선 대진표 로드 성공: ${pairings.pairings.length}건, maxRound: ${pairings.maxRound}');
      } catch (e) {
        debugPrint('DE 예선 대진표 로드 실패: $e');
      }

      if (!mounted) return;
      setState(() {
        _prelimRankings = rankings;
        _prelimPairings = pairings;
        // 최신 라운드를 기본 선택
        if (pairings != null && pairings.maxRound > 0) {
          _selectedPrelimRound = pairings.maxRound;
        }
        _isLoadingData = false;
      });
    } catch (e) {
      debugPrint('DE 예선 데이터 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _hasError = true;
          _errorMessage = '예선 데이터 로드 실패: $e';
        });
      }
    }
  }

  /// 본선 데이터 로드
  Future<void> _loadTournamentData() async {
    setState(() {
      _isLoadingData = true;
      _hasError = false;
    });
    try {
      // 순위표와 대진표를 독립적으로 로드
      List<DETournamentRanking> rankings = [];
      DETournamentPairingsResponse? pairings;

      try {
        rankings = await _service.getDETournamentRankings(
          widget.contestId,
          widget.sortId,
        );
        debugPrint('DE 본선 순위표 로드 성공: ${rankings.length}건');
      } catch (e) {
        debugPrint('DE 본선 순위표 로드 실패: $e');
      }

      try {
        pairings = await _service.getDETournamentPairings(
          widget.contestId,
          widget.sortId,
        );
        debugPrint('DE 본선 대진표 로드 성공: ${pairings.pairings.length}건');
      } catch (e) {
        debugPrint('DE 본선 대진표 로드 실패: $e');
      }

      if (!mounted) return;
      setState(() {
        _tournamentRankings = rankings;
        _tournamentPairings = pairings;
        // 최신 라운드를 기본 선택
        if (pairings != null) {
          final rounds = pairings.pairings
              .map((p) => p.round)
              .toSet()
              .toList()
            ..sort();
          if (rounds.isNotEmpty) {
            _selectedTournamentRound = rounds.last;
          }
        }
        _isLoadingData = false;
      });
    } catch (e) {
      debugPrint('DE 본선 데이터 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _hasError = true;
          _errorMessage = '본선 데이터 로드 실패: $e';
        });
      }
    }
  }

  /// 이름에서 급수/단수 제거
  String _cleanName(String name) {
    return name.replaceAll(RegExp(r'\s+\d+(단|급)$'), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_hasError && _groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? '데이터를 불러올 수 없습니다.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadGroups,
                icon: const Icon(Icons.refresh, size: 18),
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

    return Column(
      children: [
        // 예선/본선 탭
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _stageTabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: '예선전'),
              Tab(text: '토너먼트'),
            ],
          ),
        ),

        // 내용
        Expanded(
          child: _isLoadingData
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _hasError && _prelimRankings.isEmpty && _tournamentRankings.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage ?? '데이터를 불러올 수 없습니다.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                if (_stageTabController.index == 0) {
                                  _loadPreliminaryData();
                                } else {
                                  _loadTournamentData();
                                }
                              },
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('다시 시도'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : TabBarView(
                      controller: _stageTabController,
                      children: [
                        _buildPreliminaryTab(),
                        _buildTournamentTab(),
                      ],
                    ),
        ),
      ],
    );
  }

  // ==================== 예선 탭 ====================

  Widget _buildPreliminaryTab() {
    if (_groups.isEmpty) {
      return const Center(child: Text('예선 그룹 정보가 없습니다.'));
    }

    return SingleChildScrollView(
      physics: const _SlowScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 그룹 선택
          _buildGroupSelector(),
          const SizedBox(height: 16),

          // 그룹 순위표
          _buildSectionTitle('${_selectedGroup}조 순위표'),
          const SizedBox(height: 8),
          _buildPrelimRankingTable(),
          const SizedBox(height: 24),

          // 그룹 대진표
          _buildSectionTitle('${_selectedGroup}조 대진표'),
          const SizedBox(height: 8),
          _buildPrelimRoundSelector(),
          const SizedBox(height: 8),
          _buildPrelimPairingsTable(),
        ],
      ),
    );
  }

  Widget _buildGroupSelector() {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _groups.length,
        itemBuilder: (context, index) {
          final group = _groups[index];
          final isSelected = group == _selectedGroup;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${group}조'),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedGroup = group);
                _loadPreliminaryData();
              },
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor: AppColors.surface,
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrelimRankingTable() {
    if (_prelimRankings.isEmpty) {
      return _buildEmptyState('순위표 정보가 없습니다.');
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                SizedBox(width: 40, child: Text('순위', style: _headerStyle)),
                Expanded(child: Text('이름', style: _headerStyle)),
                SizedBox(width: 36, child: Text('승', style: _headerStyle, textAlign: TextAlign.center)),
                SizedBox(width: 36, child: Text('패', style: _headerStyle, textAlign: TextAlign.center)),
                SizedBox(width: 64, child: Text('상태', style: _headerStyle, textAlign: TextAlign.center)),
              ],
            ),
          ),
          // 데이터 행
          ...List.generate(_prelimRankings.length, (index) {
            final r = _prelimRankings[index];
            final isEliminated = r.isEliminated;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: index < _prelimRankings.length - 1
                    ? Border(bottom: BorderSide(color: AppColors.border, width: 0.5))
                    : null,
                color: isEliminated ? AppColors.background : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${r.rank}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isEliminated ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _cleanName(r.participantName),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isEliminated ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${r.wins}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.info),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${r.losses}',
                      style: const TextStyle(fontSize: 15, color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: _buildStatusBadge(r.status),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPrelimRoundSelector() {
    if (_prelimPairings == null || _prelimPairings!.maxRound <= 0) {
      return const SizedBox.shrink();
    }

    final rounds = _prelimPairings!.pairings
        .map((p) => p.round)
        .toSet()
        .toList()
      ..sort();

    if (rounds.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: rounds.length,
        itemBuilder: (context, index) {
          final round = rounds[index];
          final isSelected = round == _selectedPrelimRound;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${round}R'),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedPrelimRound = round),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontSize: 15,
              ),
              backgroundColor: AppColors.surface,
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrelimPairingsTable() {
    if (_prelimPairings == null || _prelimPairings!.pairings.isEmpty) {
      return _buildEmptyState('대진표 정보가 없습니다.');
    }

    final pairings = _prelimPairings!.pairings
        .where((p) => p.round == _selectedPrelimRound)
        .toList();

    if (pairings.isEmpty) {
      return _buildEmptyState('해당 라운드 대진이 없습니다.');
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(pairings.length, (index) {
          final match = pairings[index];
          return _buildPrelimPairingRow(match, index, pairings.length);
        }),
      ),
    );
  }

  Widget _buildPrelimPairingRow(
      DEPreliminaryPairing match, int index, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: index < total - 1
            ? Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5))
            : null,
      ),
      child: Row(
        children: [
          // 번호
          SizedBox(
            width: 28,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          // 선수1
          Expanded(
            child: Text(
              _cleanName(match.player1),
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    match.isPlayer1Winner ? FontWeight.w700 : FontWeight.w400,
                color: match.isEnd && !match.isPlayer1Winner
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // vs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'vs',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          // 선수2
          Expanded(
            child: Text(
              _cleanName(match.player2),
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    match.isPlayer2Winner ? FontWeight.w700 : FontWeight.w400,
                color: match.isEnd && !match.isPlayer2Winner
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 승리 아이콘
          SizedBox(
            width: 20,
            child: match.isEnd
                ? Icon(
                    Icons.emoji_events,
                    size: 16,
                    color: match.isPlayer2Winner
                        ? const Color(0xFFFFD700)
                        : Colors.transparent,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  // ==================== 토너먼트(본선) 탭 ====================

  Widget _buildTournamentTab() {
    return SingleChildScrollView(
      physics: const _SlowScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 토너먼트 현황
          _buildSectionTitle('토너먼트 현황'),
          const SizedBox(height: 8),
          _buildTournamentRankingTable(),
          const SizedBox(height: 24),

          // 토너먼트 대진표
          _buildSectionTitle('토너먼트 대진표'),
          const SizedBox(height: 8),
          _buildTournamentRoundSelector(),
          const SizedBox(height: 8),
          _buildTournamentPairingsTable(),
        ],
      ),
    );
  }

  Widget _buildTournamentRankingTable() {
    if (_tournamentRankings.isEmpty) {
      return _buildEmptyState('토너먼트가 아직 시작되지 않았습니다.');
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Expanded(child: Text('이름', style: _headerStyle)),
                SizedBox(width: 72, child: Text('상태', style: _headerStyle, textAlign: TextAlign.center)),
                SizedBox(width: 48, child: Text('원조', style: _headerStyle, textAlign: TextAlign.center)),
              ],
            ),
          ),
          // 데이터 행
          ...List.generate(_tournamentRankings.length, (index) {
            final r = _tournamentRankings[index];
            final isEliminated = r.isEliminated;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: index < _tournamentRankings.length - 1
                    ? Border(bottom: BorderSide(color: AppColors.border, width: 0.5))
                    : null,
                color: isEliminated ? AppColors.background : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (r.isChampion)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.emoji_events, size: 18, color: Color(0xFFFFD700)),
                          ),
                        if (r.isRunnerUp)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.emoji_events, size: 18, color: Color(0xFFC0C0C0)),
                          ),
                        Flexible(
                          child: Text(
                            _cleanName(r.playerName),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: r.isChampion || r.isRunnerUp ? FontWeight.w700 : FontWeight.w500,
                              color: isEliminated ? AppColors.textSecondary : AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: _buildTournamentStatusBadge(r.status),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      r.originalGroup != null ? '${r.originalGroup}조' : '-',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTournamentRoundSelector() {
    if (_tournamentPairings == null || _tournamentPairings!.pairings.isEmpty) {
      return const SizedBox.shrink();
    }

    final rounds = _tournamentPairings!.pairings
        .map((p) => p.round)
        .toSet()
        .toList()
      ..sort();

    if (rounds.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: rounds.length,
        itemBuilder: (context, index) {
          final round = rounds[index];
          final isSelected = round == _selectedTournamentRound;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(round == 0 ? '예선' : '${round}R'),
              selected: isSelected,
              onSelected: (_) =>
                  setState(() => _selectedTournamentRound = round),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontSize: 15,
              ),
              backgroundColor: AppColors.surface,
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTournamentPairingsTable() {
    if (_tournamentPairings == null || _tournamentPairings!.pairings.isEmpty) {
      return _buildEmptyState('토너먼트 대진표가 없습니다.');
    }

    final pairings = _tournamentPairings!.pairings
        .where((p) => p.round == _selectedTournamentRound)
        .toList();

    if (pairings.isEmpty) {
      return _buildEmptyState('해당 라운드 대진이 없습니다.');
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(pairings.length, (index) {
          final match = pairings[index];
          return _buildTournamentPairingRow(match, index, pairings.length);
        }),
      ),
    );
  }

  Widget _buildTournamentPairingRow(
      DETournamentPairing match, int index, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: index < total - 1
            ? Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5))
            : null,
      ),
      child: Row(
        children: [
          // 번호
          SizedBox(
            width: 28,
            child: Text(
              '${match.matchNumber ?? (index + 1)}',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          // 선수1
          Expanded(
            child: Text(
              match.player1 != null ? _cleanName(match.player1!) : '대기중',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    match.isPlayer1Winner ? FontWeight.w700 : FontWeight.w400,
                color: match.player1 == null
                    ? AppColors.textTertiary
                    : (match.isEnd && !match.isPlayer1Winner
                        ? AppColors.textSecondary
                        : AppColors.textPrimary),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // vs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'vs',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          // 선수2
          Expanded(
            child: Text(
              match.player2 != null ? _cleanName(match.player2!) : '대기중',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    match.isPlayer2Winner ? FontWeight.w700 : FontWeight.w400,
                color: match.player2 == null
                    ? AppColors.textTertiary
                    : (match.isEnd && !match.isPlayer2Winner
                        ? AppColors.textSecondary
                        : AppColors.textPrimary),
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 결과 아이콘
          SizedBox(
            width: 20,
            child: match.isEnd
                ? const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppColors.success,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  // ==================== 공통 위젯 ====================

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Text(
        message,
        style: TextStyle(
          fontSize: 16,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  /// 예선 상태 뱃지 (본선진출/탈락/진행중)
  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    if (status == '본선진출') {
      bgColor = AppColors.statusOpenBg;
      textColor = AppColors.statusOpenText;
    } else if (status == '탈락') {
      bgColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFF991B1B);
    } else {
      bgColor = AppColors.statusLiveBg;
      textColor = AppColors.statusLiveText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 토너먼트 상태 뱃지 (우승/준우승/4강/8강/진행중/탈락)
  Widget _buildTournamentStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    if (status == '우승') {
      bgColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFF92400E);
    } else if (status == '준우승') {
      bgColor = const Color(0xFFE0E7FF);
      textColor = const Color(0xFF3730A3);
    } else if (status.contains('탈락')) {
      bgColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFF991B1B);
    } else if (status.contains('진행중')) {
      bgColor = AppColors.statusLiveBg;
      textColor = AppColors.statusLiveText;
    } else {
      // 4강, 8강 등
      bgColor = AppColors.statusOpenBg;
      textColor = AppColors.statusOpenText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  static TextStyle _headerStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );
}
