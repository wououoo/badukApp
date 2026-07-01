import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/live_contest.dart';
import '../../../data/services/live_contest_service.dart';
import '../widgets/live_de_content.dart';
import '../widgets/live_sort_content.dart';

/// 라이브 대회 상세 화면
///
/// 대회 정보 헤더 + 부문 선택 UI만 담당하고,
/// 실제 순위표/대진표 렌더링은 부문 유형에 따라
/// [LiveSortContent](비-DE) 또는 [LiveDEContent](DE/TOURNAMENT)에 위임한다.
class LiveContestScreen extends StatefulWidget {
  final int contestId;

  const LiveContestScreen({super.key, required this.contestId});

  @override
  State<LiveContestScreen> createState() => _LiveContestScreenState();
}

class _LiveContestScreenState extends State<LiveContestScreen> {
  final LiveContestService _service = LiveContestService();

  LiveContestDetail? _contest;
  LiveContestSort? _selectedSort;

  bool _isLoading = true;
  String? _error;

  // linkedContests의 sorts도 합친 전체 부문 목록
  List<LiveContestSort> _allSorts = [];
  // sortId -> contestId 매핑 (linkedContests의 sort는 해당 대회 ID 사용)
  final Map<int, int> _sortContestIdMap = {};

  // 자동 새로고침 (콘텐츠 위젯에 전달)
  bool _autoRefreshEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadContest();
  }

  /// 선택된 sort가 속한 contestId 반환
  int _getContestIdForSort(int sortId) {
    return _sortContestIdMap[sortId] ?? widget.contestId;
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

  /// 부문 선택 — 데이터 로딩은 콘텐츠 위젯이 자체 담당하므로 선택 상태만 변경
  void _selectSort(LiveContestSort sort) {
    setState(() {
      _selectedSort = sort;
    });
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

        // 내용 (순위표/대진표 탭은 콘텐츠 위젯 내부로 이동)
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

  /// DE/TOURNAMENT 타입인지 확인
  bool get _isDEType {
    final type = _selectedSort?.contestType?.toUpperCase() ?? '';
    return type == 'DE' || type == 'TOURNAMENT';
  }

  Widget _buildContent() {
    if (_selectedSort == null) {
      return const Center(child: Text('부문을 선택하세요'));
    }

    final contestId = _getContestIdForSort(_selectedSort!.id);

    // DE/TOURNAMENT 타입은 전용 위젯 사용
    if (_isDEType) {
      return LiveDEContent(
        // 부문 변경 시 Flutter가 기존 State를 재사용해 이전 부문 데이터가 남는 문제 방지.
        // sortId 기반 key로 위젯을 강제 재생성 → initState 재실행으로 새 부문 데이터를 즉시 로드.
        key: ValueKey('de-$contestId-${_selectedSort!.id}'),
        contestId: contestId,
        sortId: _selectedSort!.id,
      );
    }

    // 비-DE 부문: 순위표/대진표 콘텐츠 위젯에 위임
    return LiveSortContent(
      key: ValueKey('sort-$contestId-${_selectedSort!.id}'),
      contestId: contestId,
      sortId: _selectedSort!.id,
      contestType: _selectedSort!.contestType,
      autoRefresh: _autoRefreshEnabled,
    );
  }
}
