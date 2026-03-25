import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/club_contest_service.dart';

/// 대진표 탭 (개인/팀/DE 토너먼트)
class ContestPairingsTab extends StatefulWidget {
  final int clubId;
  final int contestId;
  final int sortId;
  final String currentType;
  final bool isFinished;
  final int maxRound;
  final bool isTeamPairings;
  final int teamSize;
  final List<Map<String, dynamic>> allPairings;
  final bool hasTournament;
  final List<Map<String, dynamic>> tournamentPairings;
  final int tournamentMaxRound;
  final VoidCallback onReload;

  const ContestPairingsTab({
    super.key,
    required this.clubId,
    required this.contestId,
    required this.sortId,
    required this.currentType,
    required this.isFinished,
    required this.maxRound,
    required this.isTeamPairings,
    required this.teamSize,
    required this.allPairings,
    required this.hasTournament,
    required this.tournamentPairings,
    required this.tournamentMaxRound,
    required this.onReload,
  });

  @override
  State<ContestPairingsTab> createState() => _ContestPairingsTabState();
}

class _ContestPairingsTabState extends State<ContestPairingsTab> with AutomaticKeepAliveClientMixin {
  final ClubContestService _service = ClubContestService();
  final Set<int> _expandedRounds = {};
  bool _isSaving = false;

  // Swap mode
  bool _swapMode = false;
  final List<Map<String, dynamic>> _swapSelected = []; // [{playerId, playerName, matchId}]

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Auto-expand latest round
    if (widget.maxRound > 0) _expandedRounds.add(widget.maxRound);
    if (widget.hasTournament && widget.tournamentMaxRound > 0) {
      _expandedRounds.add(-1000 - widget.tournamentMaxRound);
    }
  }

  @override
  void didUpdateWidget(ContestPairingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-expand new rounds
    if (widget.maxRound > 0 && widget.maxRound != oldWidget.maxRound) {
      _expandedRounds.add(widget.maxRound);
    }
    if (widget.hasTournament && widget.tournamentMaxRound > 0 && widget.tournamentMaxRound != oldWidget.tournamentMaxRound) {
      _expandedRounds.add(-1000 - widget.tournamentMaxRound);
    }
  }

  List<Map<String, dynamic>> _safeListCast(dynamic list) {
    if (list == null) return [];
    if (list is! List) return [];
    return list.map((e) {
      if (e is Map) return Map<String, dynamic>.from(e);
      return <String, dynamic>{};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.maxRound == 0 && !(widget.hasTournament && widget.tournamentPairings.isNotEmpty)) {
      return const Center(child: Text('대진표를 생성해주세요', textAlign: TextAlign.center));
    }
    if (widget.isTeamPairings) return _buildTeamPairingsTabContent();
    return _buildIndividualPairingsTabContent();
  }

  Widget _buildIndividualPairingsTabContent() {
    final hasTourn = widget.hasTournament && widget.tournamentPairings.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        if (_swapMode)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.warning.withOpacity(0.4))),
            child: Row(children: [
              Icon(Icons.swap_horiz, size: 20, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(child: Text(
                _swapSelected.isEmpty ? '교체할 첫 번째 선수를 선택하세요' : (_swapSelected.length == 1 ? '교체할 두 번째 선수를 선택하세요 (다른 매치)' : '교체 중...'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.warning),
              )),
              Text('${_swapSelected.length}/2', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.warning)),
            ]),
          ),
        if (hasTourn) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.clubPrimary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.emoji_events, size: 20, color: AppColors.clubPrimary),
              const SizedBox(width: 8),
              const Text('본선 토너먼트', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
          ),
          for (int i = 0; i < widget.tournamentMaxRound; i++)
            _buildTournamentRoundSection(widget.tournamentMaxRound - i),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.textTertiary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.group, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              const Text('예선', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
        for (int i = 0; i < widget.maxRound; i++)
          _buildRoundSection(widget.maxRound - i),
      ],
    );
  }

  // ==================== Individual rounds ====================

  Widget _buildRoundSection(int round) {
    final isExpanded = _expandedRounds.contains(round);
    final roundPairings = widget.allPairings.where((p) {
      final r = p['round'];
      return ((r is num) ? r.toInt() : r) == round;
    }).toList();
    final matches = _groupPairingsIntoMatches(roundPairings);

    final finishedCount = matches.where((m) => m['end'] == true || m['isBye'] == true).length;
    final totalCount = matches.length;
    final allFinished = finishedCount == totalCount && totalCount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          _buildRoundHeader(round, isExpanded, allFinished, finishedCount, totalCount),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: matches.isEmpty
                  ? Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('매치가 없습니다', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)))
                  : Column(children: matches.map((match) => _buildMatchCard(match, round)).toList()),
            ),
        ],
      ),
    );
  }

  Widget _buildRoundHeader(int round, bool isExpanded, bool allFinished, int finishedCount, int totalCount, {String? label}) {
    final isMcMahon = widget.currentType == '맥마흔';
    final isLatestRound = round == widget.maxRound;
    final showSwapIcon = isMcMahon && isLatestRound && !widget.isFinished && !allFinished && finishedCount < totalCount;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) _expandedRounds.remove(round);
          else _expandedRounds.add(round);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _swapMode ? AppColors.warning.withOpacity(0.1) : (allFinished ? AppColors.success.withOpacity(0.08) : AppColors.clubPrimary.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, size: 22, color: AppColors.textPrimary),
            const SizedBox(width: 6),
            Text(label ?? '${round}R', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: allFinished ? AppColors.success.withOpacity(0.15) : AppColors.textTertiary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(allFinished ? '완료' : '$finishedCount/$totalCount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: allFinished ? AppColors.success : AppColors.textSecondary)),
            ),
            if (round < widget.maxRound) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.textTertiary.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text('확정', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary)),
              ),
            ],
            if (showSwapIcon) ...[
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _swapMode = !_swapMode;
                    _swapSelected.clear();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _swapMode ? AppColors.warning : AppColors.textTertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz, size: 16, color: _swapMode ? Colors.white : AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(_swapMode ? '취소' : '교체', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _swapMode ? Colors.white : AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _groupPairingsIntoMatches(List<Map<String, dynamic>> roundPairings) {
    return roundPairings.map((p) {
      final player2Id = (p['player2Id'] is num) ? (p['player2Id'] as num).toInt() : null;
      return {
        'player1': p['player1']?.toString() ?? '',
        'player2': p['player2']?.toString() ?? '부전승',
        'player1Id': (p['player1Id'] is num) ? (p['player1Id'] as num).toInt() : 0,
        'player2Id': player2Id,
        'player1Number': p['player1Number'],
        'player2Number': p['player2Number'],
        'matchId': p['matchId'],
        'matchNumber': p['matchNumber'],
        'winnerId': p['winnerId'],
        'winner': p['winner']?.toString() ?? '',
        'end': p['end'] ?? false,
        'win': p['win'] ?? false,
        'isBye': player2Id == null || p['player2'] == '부전승',
        'none': p['none'] ?? false,
      };
    }).toList();
  }

  Widget _buildMatchCard(Map<String, dynamic> match, [int? round]) {
    final player1 = match['player1'] as String;
    final player2 = match['player2'] as String;
    final winner = match['winner'] as String;
    final isEnded = match['end'] == true;
    final isBye = match['isBye'] == true;
    final p1Won = isEnded && winner == player1;
    final p2Won = isEnded && !isBye && winner == player2;

    final effectiveRound = round ?? widget.maxRound;
    final isLatestRound = effectiveRound == widget.maxRound;
    final canInput = !isBye && !widget.isFinished && isLatestRound;

    final p1Id = (match['player1Id'] is num) ? (match['player1Id'] as num).toInt() : 0;
    final p2IdRaw = (match['player2Id'] is num) ? (match['player2Id'] as num).toInt() : null;
    final matchId = match['matchId'];
    final isP1Selected = _swapMode && _swapSelected.any((s) => s['playerId'] == p1Id);
    final isP2Selected = _swapMode && p2IdRaw != null && _swapSelected.any((s) => s['playerId'] == p2IdRaw);

    if (_swapMode && isLatestRound && !isBye && !isEnded) {
      // Swap mode: show tappable player names
      return Card(
        margin: const EdgeInsets.only(bottom: 6),
        elevation: 0,
        color: (isP1Selected || isP2Selected) ? AppColors.warning.withOpacity(0.08) : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: (isP1Selected || isP2Selected) ? AppColors.warning.withOpacity(0.5) : AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(child: GestureDetector(
                onTap: () => _onSwapPlayerTap(p1Id, player1, matchId),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isP1Selected ? AppColors.warning.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: isP1Selected ? Border.all(color: AppColors.warning) : null,
                  ),
                  child: Text(player1, style: TextStyle(fontSize: 14, fontWeight: isP1Selected ? FontWeight.bold : FontWeight.w500, color: isP1Selected ? AppColors.warning : AppColors.textPrimary), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                ),
              )),
              Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('vs', style: TextStyle(fontSize: 12, color: AppColors.textTertiary))),
              Expanded(child: GestureDetector(
                onTap: p2IdRaw != null ? () => _onSwapPlayerTap(p2IdRaw, player2, matchId) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isP2Selected ? AppColors.warning.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: isP2Selected ? Border.all(color: AppColors.warning) : null,
                  ),
                  child: Text(player2, style: TextStyle(fontSize: 14, fontWeight: isP2Selected ? FontWeight.bold : FontWeight.w500, color: isP2Selected ? AppColors.warning : AppColors.textPrimary), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                ),
              )),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: isEnded ? AppColors.success.withOpacity(0.06) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isEnded ? AppColors.success.withOpacity(0.3) : AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Player 1
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(player1, style: TextStyle(fontSize: 14, fontWeight: p1Won ? FontWeight.bold : FontWeight.w500, color: p1Won ? AppColors.success : AppColors.textPrimary), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                  if (canInput) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : () => _inlineSaveResult(match, effectiveRound, isP1Winner: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: p1Won ? AppColors.success : AppColors.surface,
                          foregroundColor: p1Won ? Colors.white : AppColors.textPrimary,
                          elevation: 0, padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: p1Won ? AppColors.success : AppColors.border)),
                        ),
                        child: Text('승', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ] else if (p1Won)
                    _buildWinBadge(),
                ],
              ),
            ),
            // VS
            Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text(isBye ? '부전승' : 'vs', style: TextStyle(fontSize: 12, color: AppColors.textTertiary))),
            // Player 2
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(player2, style: TextStyle(fontSize: 14, fontWeight: p2Won ? FontWeight.bold : FontWeight.w500, color: p2Won ? AppColors.success : isBye ? AppColors.textTertiary : AppColors.textPrimary), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                  if (canInput) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : () => _inlineSaveResult(match, effectiveRound, isP1Winner: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: p2Won ? AppColors.success : AppColors.surface,
                          foregroundColor: p2Won ? Colors.white : AppColors.textPrimary,
                          elevation: 0, padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: p2Won ? AppColors.success : AppColors.border)),
                        ),
                        child: Text('승', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ] else if (p2Won)
                    _buildWinBadge(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _inlineSaveResult(Map<String, dynamic> match, int round, {required bool isP1Winner}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final p1Id = (match['player1Id'] is num) ? (match['player1Id'] as num).toInt() : 0;
    final p2Id = (match['player2Id'] is num) ? (match['player2Id'] as num).toInt() : null;
    final player1 = match['player1']?.toString() ?? '';
    final player2 = match['player2']?.toString() ?? '';
    try {
      await _saveSingleMatchResult(match, round, p1Id, player1, p2Id, player2, isP1Winner: isP1Winner);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildWinBadge() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: const Text('승', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
    );
  }

  // ==================== Swap logic ====================

  void _onSwapPlayerTap(int playerId, String playerName, dynamic matchId) {
    setState(() {
      // 이미 선택된 선수 → 선택 해제
      final existingIdx = _swapSelected.indexWhere((s) => s['playerId'] == playerId);
      if (existingIdx >= 0) {
        _swapSelected.removeAt(existingIdx);
        return;
      }

      // 2명 이상이면 리셋
      if (_swapSelected.length >= 2) {
        _swapSelected.clear();
      }

      // 같은 매치의 선수는 선택 금지
      if (_swapSelected.length == 1 && _swapSelected.first['matchId'] == matchId) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('같은 매치의 선수는 교체할 수 없습니다. 다른 매치의 선수를 선택하세요.')));
        return;
      }

      _swapSelected.add({'playerId': playerId, 'playerName': playerName, 'matchId': matchId});
    });

    // 2명 선택 완료 → 확인 다이얼로그
    if (_swapSelected.length == 2) {
      _confirmSwap();
    }
  }

  Future<void> _confirmSwap() async {
    final p1 = _swapSelected[0];
    final p2 = _swapSelected[1];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('선수 교체'),
        content: Text('${p1['playerName']}과(와) ${p2['playerName']}의 대진을 교체하시겠습니까?'),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('취소'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.clubPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
              child: const Text('교체'),
            )),
          ]),
        ],
      ),
    );

    if (confirmed != true) {
      setState(() => _swapSelected.clear());
      return;
    }

    try {
      final result = await _service.swapPairingPlayers(
        widget.clubId, widget.contestId, widget.sortId,
        widget.maxRound, p1['playerId'] as int, p2['playerId'] as int,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? '교체 완료')));
        setState(() { _swapMode = false; _swapSelected.clear(); });
        if (result['success'] == true) widget.onReload();
      }
    } catch (e) {
      debugPrint('[Error] 선수 교체 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
        setState(() => _swapSelected.clear());
      }
    }
  }

  // ==================== Match result logic ====================

  Future<void> _saveSingleMatchResult(
    Map<String, dynamic> targetMatch, int round,
    int p1Id, String player1, int? p2Id, String player2, {
    required bool isP1Winner,
  }) async {
    final type = widget.currentType;

    if (type == '맥마흔' && targetMatch['matchId'] != null) {
      final winnerId = isP1Winner ? p1Id : p2Id;
      try {
        final result = await _service.saveResults(widget.clubId, widget.contestId, widget.sortId, [{'matchId': targetMatch['matchId'], 'winnerId': winnerId}]);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? '저장 완료')));
          widget.onReload();
        }
      } catch (e) {
        debugPrint('[Error] 맥마흔 결과 저장 오류: $e');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
      return;
    }

    if (type == '더블엘리미네이션') {
      final winnerName = isP1Winner ? player1 : player2;
      final winnerNumber = isP1Winner ? targetMatch['player1Number'] : targetMatch['player2Number'];
      try {
        final result = await _service.saveResults(widget.clubId, widget.contestId, widget.sortId, [
          {'player1': player1, 'player2': player2, 'player1Number': targetMatch['player1Number'], 'player2Number': targetMatch['player2Number'], 'winner': winnerName, 'winnerNumber': winnerNumber, 'round': round}
        ]);
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? '저장 완료'))); widget.onReload(); }
      } catch (e) { debugPrint('[Error] DE 결과 저장 오류: $e'); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.'))); }
      return;
    }

    if (type == '토너먼트' && targetMatch['matchNumber'] != null) {
      final winnerId = isP1Winner ? p1Id : p2Id;
      try {
        final result = await _service.saveResults(widget.clubId, widget.contestId, widget.sortId, [
          {'round': round, 'matchNumber': targetMatch['matchNumber'], 'player1Id': p1Id, 'player1Name': player1, 'player2Id': p2Id, 'player2Name': player2, 'winnerId': winnerId}
        ]);
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? '저장 완료'))); widget.onReload(); }
      } catch (e) { debugPrint('[Error] 토너먼트 결과 저장 오류: $e'); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.'))); }
      return;
    }

    // Swiss/Full league: save all round results
    final roundPairings = widget.allPairings.where((p) {
      final r = p['round'];
      return ((r is num) ? r.toInt() : r) == round;
    }).toList();
    final allMatches = _groupPairingsIntoMatches(roundPairings);

    final results = <Map<String, dynamic>>[];
    for (final m in allMatches) {
      final mP1 = m['player1']?.toString() ?? '';
      final mP1Id = (m['player1Id'] is num) ? (m['player1Id'] as num).toInt() : 0;
      final mP2Id = (m['player2Id'] is num) ? (m['player2Id'] as num).toInt() : null;
      final mIsBye = m['isBye'] == true;
      if (mP1Id == p1Id) {
        // 현재 클릭한 경기
        results.add({'player1': m['player1'], 'player2': m['player2'], 'player1Id': mP1Id, 'player2Id': mP2Id, 'winner': isP1Winner ? m['player1'] : m['player2'], 'end': true, 'none': false});
      } else if (mIsBye) {
        results.add({'player1': m['player1'], 'player2': m['player2'], 'player1Id': mP1Id, 'player2Id': mP2Id, 'winner': mP1, 'end': true, 'none': false});
      } else if (m['end'] == true) {
        // 이미 완료된 경기 (기존 결과 유지)
        results.add({'player1': m['player1'], 'player2': m['player2'], 'player1Id': mP1Id, 'player2Id': mP2Id, 'winner': m['winner']?.toString() ?? '', 'end': true, 'none': false});
      }
      // 미입력 경기는 포함하지 않음 (기존 데이터 보존)
    }

    try {
      final result = await _service.saveResults(widget.clubId, widget.contestId, widget.sortId, results);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? '저장 완료'))); widget.onReload(); }
    } catch (e) { debugPrint('[Error] 결과 저장 오류: $e'); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.'))); }
  }

  // ==================== Tournament rounds ====================

  Widget _buildTournamentRoundSection(int round) {
    final expandKey = -1000 - round;
    final isExpanded = _expandedRounds.contains(expandKey);
    final roundMatches = widget.tournamentPairings.where((p) {
      final r = p['round'];
      return ((r is num) ? r.toInt() : r) == round;
    }).toList();

    String roundLabel;
    if (round == widget.tournamentMaxRound) roundLabel = '결승';
    else if (round == widget.tournamentMaxRound - 1) roundLabel = '준결승';
    else { final players = 1 << (widget.tournamentMaxRound - round + 1); roundLabel = '${players}강'; }

    final finishedCount = roundMatches.where((m) => m['end'] == true).length;
    final totalCount = roundMatches.length;
    final allFinished = finishedCount == totalCount && totalCount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() { if (isExpanded) _expandedRounds.remove(expandKey); else _expandedRounds.add(expandKey); }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: allFinished ? AppColors.success.withOpacity(0.08) : AppColors.clubPrimary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, size: 22, color: AppColors.textPrimary),
                  const SizedBox(width: 6),
                  Text(roundLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: allFinished ? AppColors.success.withOpacity(0.15) : AppColors.textTertiary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(allFinished ? '완료' : '$finishedCount/$totalCount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: allFinished ? AppColors.success : AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: roundMatches.isEmpty
                  ? Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('매치가 없습니다', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)))
                  : Column(children: roundMatches.map((match) => _buildTournamentMatchCard(match, round)).toList()),
            ),
        ],
      ),
    );
  }

  Widget _buildTournamentMatchCard(Map<String, dynamic> match, int round) {
    final player1 = match['player1']?.toString() ?? '';
    final player2 = match['player2']?.toString() ?? '';
    final winner = match['winner']?.toString() ?? '';
    final isEnded = match['end'] == true;
    final isBye = player2 == '부전승' || match['player2Id'] == null;
    final p1Won = isEnded && winner == player1;
    final p2Won = isEnded && !isBye && winner == player2;

    final card = Card(
      margin: const EdgeInsets.only(bottom: 6), elevation: 0,
      color: isEnded ? AppColors.success.withOpacity(0.06) : AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isEnded ? AppColors.success.withOpacity(0.3) : AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text(player1, style: TextStyle(fontSize: 14, fontWeight: p1Won ? FontWeight.bold : FontWeight.w500, color: p1Won ? AppColors.success : AppColors.textPrimary), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
              if (p1Won) _buildWinBadge(),
            ])),
            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text(isBye ? '부전승' : 'vs', style: TextStyle(fontSize: 12, color: AppColors.textTertiary))),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text(player2, style: TextStyle(fontSize: 14, fontWeight: p2Won ? FontWeight.bold : FontWeight.w500, color: p2Won ? AppColors.success : isBye ? AppColors.textTertiary : AppColors.textPrimary), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
              if (p2Won) _buildWinBadge(),
            ])),
          ],
        ),
      ),
    );

    if (isBye || widget.isFinished || player1.isEmpty || player2.isEmpty) return card;
    return GestureDetector(onTap: () => _showTournamentMatchResultDialog(match, round), child: card);
  }

  void _showTournamentMatchResultDialog(Map<String, dynamic> match, int round) {
    final player1 = match['player1']?.toString() ?? '';
    final player2 = match['player2']?.toString() ?? '';
    final p1Id = (match['player1Id'] is num) ? (match['player1Id'] as num).toInt() : 0;
    final p2Id = (match['player2Id'] is num) ? (match['player2Id'] as num).toInt() : null;
    final matchNumber = (match['matchNumber'] is num) ? (match['matchNumber'] as num).toInt() : 0;

    String roundLabel;
    if (round == widget.tournamentMaxRound) roundLabel = '결승';
    else if (round == widget.tournamentMaxRound - 1) roundLabel = '준결승';
    else { final players = 1 << (widget.tournamentMaxRound - round + 1); roundLabel = '${players}강'; }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$roundLabel 결과 입력', style: const TextStyle(fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$player1  vs  $player2', style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _saveTournamentResult(match, round, matchNumber, p1Id, player1, p2Id, player2, isP1Winner: true); },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.clubPrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
              child: Text('$player1 승', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
            )),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _saveTournamentResult(match, round, matchNumber, p1Id, player1, p2Id, player2, isP1Winner: false); },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
              child: Text('$player2 승', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
            )),
          ]),
        ]),
      ),
    );
  }

  Future<void> _saveTournamentResult(Map<String, dynamic> match, int round, int matchNumber, int p1Id, String player1, int? p2Id, String player2, {required bool isP1Winner}) async {
    final winnerId = isP1Winner ? p1Id : p2Id;
    try {
      final result = await _service.saveResults(widget.clubId, widget.contestId, widget.sortId, [
        {'isTournament': true, 'round': round, 'matchNumber': matchNumber, 'player1': player1, 'player2': player2, 'player1Id': p1Id, 'player2Id': p2Id, 'winnerId': winnerId}
      ]);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? '저장 완료'))); widget.onReload(); }
    } catch (e) { debugPrint('[Error] 본선 토너먼트 결과 저장 오류: $e'); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.'))); }
  }

  // ==================== Team rounds ====================

  Widget _buildTeamPairingsTabContent() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: widget.maxRound,
      itemBuilder: (context, index) => _buildTeamRoundSection(widget.maxRound - index),
    );
  }

  Widget _buildTeamRoundSection(int round) {
    final isExpanded = _expandedRounds.contains(round);
    final roundMatches = widget.allPairings.where((p) {
      final r = p['round'];
      return ((r is num) ? r.toInt() : r) == round;
    }).toList();

    final finishedCount = roundMatches.where((m) => m['isCompleted'] == true || m['teamWinner'] != null).length;
    final totalCount = roundMatches.length;
    final allFinished = finishedCount == totalCount && totalCount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          _buildRoundHeader(round, isExpanded, allFinished, finishedCount, totalCount),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: roundMatches.isEmpty
                  ? Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('매치가 없습니다', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)))
                  : Column(children: roundMatches.map((match) => _buildTeamMatchCard(match, round)).toList()),
            ),
        ],
      ),
    );
  }

  Widget _buildTeamMatchCard(Map<String, dynamic> match, int round) {
    final team1Name = match['team1Name']?.toString() ?? '';
    final team2Name = match['team2Name']?.toString() ?? '';
    final results = _safeListCast(match['results']);
    final isBye = team2Name == '부전승' || team2Name.isEmpty;

    int team1Wins = 0, team2Wins = 0, decidedCount = 0;
    for (final r in results) {
      final w = r['winner']?.toString() ?? '';
      if (w == 'team1') { team1Wins++; decidedCount++; }
      else if (w == 'team2') { team2Wins++; decidedCount++; }
    }
    final totalBoards = results.isNotEmpty ? results.length : (widget.teamSize > 0 ? widget.teamSize : 0);
    final isCompleted = isBye || (totalBoards > 0 && decidedCount == totalBoards);
    final team1Won = isCompleted && team1Wins > team2Wins;
    final team2Won = isCompleted && team2Wins > team1Wins;
    final isLatestRound = round == widget.maxRound;
    final canEdit = !widget.isFinished && !isBye && isLatestRound;

    return GestureDetector(
      onTap: canEdit ? () => _showTeamMatchDetailModal(match, round) : null,
      child: Card(
        margin: const EdgeInsets.only(bottom: 6), elevation: 0,
        color: isCompleted ? AppColors.success.withOpacity(0.06) : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isCompleted ? AppColors.success.withOpacity(0.3) : AppColors.border)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(child: Text(team1Name, style: TextStyle(fontSize: 14, fontWeight: team1Won ? FontWeight.bold : FontWeight.w500, color: team1Won ? AppColors.success : AppColors.textPrimary), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
              Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text(isBye ? '부전승' : '$team1Wins : $team2Wins', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isCompleted ? AppColors.success : AppColors.textSecondary))),
              Expanded(child: Text(team2Name, style: TextStyle(fontSize: 14, fontWeight: team2Won ? FontWeight.bold : FontWeight.w500, color: isBye ? AppColors.textTertiary : (team2Won ? AppColors.success : AppColors.textPrimary)), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
              if (!isBye && !widget.isFinished) Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  void _showTeamMatchDetailModal(Map<String, dynamic> match, int round) {
    final team1Name = match['team1Name']?.toString() ?? '';
    final team2Name = match['team2Name']?.toString() ?? '';
    final rawResults = match['results'] as List? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            int t1Wins = 0, t2Wins = 0;
            for (final r in rawResults) {
              if (r is! Map) continue;
              final w = r['winner']?.toString() ?? '';
              if (w == 'team1') t1Wins++;
              else if (w == 'team2') t2Wins++;
            }

            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(margin: const EdgeInsets.only(top: 10, bottom: 6), width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(children: [
                      Expanded(child: Text(team1Name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
                      Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)), child: Text('$t1Wins : $t2Wins', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                      Expanded(child: Text(team2Name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: rawResults.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (_, i) {
                        final r = rawResults[i];
                        if (r is! Map) return const SizedBox.shrink();
                        final pi = (r['playerIndex'] is num) ? (r['playerIndex'] as num).toInt() : (i + 1);
                        final winner = r['winner']?.toString() ?? '';
                        final team1Player = r['team1Player']?.toString() ?? '';
                        final team2Player = r['team2Player']?.toString() ?? '';
                        final isTeam1Win = winner == 'team1';
                        final isTeam2Win = winner == 'team2';

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            SizedBox(width: 32, child: Text('$pi장', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary), textAlign: TextAlign.center)),
                            const SizedBox(width: 4),
                            Expanded(child: GestureDetector(
                              onTap: () => _confirmAndSaveBoardResult(match, round, pi, 'team1', team1Player.isNotEmpty ? team1Player : team1Name, setModalState),
                              child: Container(
                                height: 40, alignment: Alignment.center,
                                decoration: BoxDecoration(color: isTeam1Win ? AppColors.success : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: isTeam1Win ? AppColors.success : AppColors.border)),
                                child: Text(team1Player.isNotEmpty ? team1Player : team1Name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isTeam1Win ? Colors.white : AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                              ),
                            )),
                            const SizedBox(width: 6),
                            Expanded(child: GestureDetector(
                              onTap: () => _confirmAndSaveBoardResult(match, round, pi, 'team2', team2Player.isNotEmpty ? team2Player : team2Name, setModalState),
                              child: Container(
                                height: 40, alignment: Alignment.center,
                                decoration: BoxDecoration(color: isTeam2Win ? AppColors.success : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: isTeam2Win ? AppColors.success : AppColors.border)),
                                child: Text(team2Player.isNotEmpty ? team2Player : team2Name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isTeam2Win ? Colors.white : AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                              ),
                            )),
                          ]),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () { Navigator.pop(ctx); widget.onReload(); },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.textSecondary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: EdgeInsets.symmetric(vertical: 14), elevation: 0),
                          child: const Text('닫기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmAndSaveBoardResult(Map<String, dynamic> match, int round, int boardIndex, String winnerSide, String winnerName, void Function(void Function()) setModalState) async {
    String currentWinner = '';
    final rawResults = match['results'];
    if (rawResults is List) {
      for (final r in rawResults) {
        if (r is Map) {
          final pi = (r['playerIndex'] is num) ? (r['playerIndex'] as num).toInt() : 0;
          if (pi == boardIndex) { currentWinner = r['winner']?.toString() ?? ''; break; }
        }
      }
    }
    final isCancel = currentWinner == winnerSide;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCancel ? '결과 해제' : '결과 확인', style: const TextStyle(fontSize: 16)),
        content: Text(isCancel ? '$boardIndex장: $winnerName 승을 해제하시겠습니까?' : '$boardIndex장: $winnerName 승으로 처리하시겠습니까?', style: const TextStyle(fontSize: 14)),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary, side: BorderSide(color: AppColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: EdgeInsets.symmetric(vertical: 12)), child: Text('취소', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: isCancel ? AppColors.error : AppColors.success, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0), child: Text(isCancel ? '해제' : '저장', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))),
          ]),
        ],
      ),
    );
    if (confirmed != true) return;

    final newWinner = isCancel ? '' : winnerSide;
    if (rawResults is List) {
      for (final r in rawResults) {
        if (r is Map) {
          final pi = (r['playerIndex'] is num) ? (r['playerIndex'] as num).toInt() : 0;
          if (pi == boardIndex) { r['winner'] = newWinner; break; }
        }
      }
    }
    setModalState(() {});
    await _saveTeamRoundResults(round);
  }

  Future<void> _saveTeamRoundResults(int round) async {
    final roundMatches = widget.allPairings.where((p) {
      final r = p['round'];
      return ((r is num) ? r.toInt() : r) == round;
    }).toList();

    if (widget.currentType == '단체전 풀리그') {
      final List<Map<String, dynamic>> bulkResults = [];
      for (final m in roundMatches) {
        final rawResults = m['results'];
        if (rawResults is! List) continue;
        for (final r in rawResults) {
          if (r is! Map) continue;
          final winner = r['winner']?.toString() ?? '';
          if (winner.isEmpty) continue;
          final boardResultId = r['boardResultId'];
          if (boardResultId == null) continue;
          final winnerMemberId = winner == 'team1' ? r['team1MemberId'] : r['team2MemberId'];
          if (winnerMemberId == null) continue;
          bulkResults.add({'boardResultId': boardResultId, 'winnerMemberId': winnerMemberId});
        }
      }
      try {
        await _service.saveResults(widget.clubId, widget.contestId, widget.sortId, bulkResults);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장 완료')));
      } catch (e) { debugPrint('[Error] 팀 결과 저장 오류: $e'); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.'))); }
      return;
    }

    final results = roundMatches.map((m) {
      final rawResults = m['results'];
      final boardList = <Map<String, dynamic>>[];
      if (rawResults is List) {
        for (final r in rawResults) {
          if (r is Map) boardList.add({'playerIndex': r['playerIndex'], 'winner': r['winner'] ?? ''});
        }
      }
      return <String, dynamic>{'team1Name': m['team1Name'], 'team2Name': m['team2Name'], 'round': round, 'none': (m['isNone'] ?? false).toString(), 'results': boardList};
    }).toList();

    try {
      await _service.saveResults(widget.clubId, widget.contestId, widget.sortId, results);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장 완료')));
    } catch (e) { debugPrint('[Error] 팀 라운드 결과 저장 오류: $e'); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.'))); }
  }
}
