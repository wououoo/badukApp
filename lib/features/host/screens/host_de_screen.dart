import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/host_operation.dart';
import '../../../data/providers/host_operation_provider.dart';
import '../../../data/services/host_operation_service.dart';
import 'host_correction.dart';

/// B — 더블 엘리미네이션(DE) 부문 운영
///
/// 2단계: 예선(조별 리그) + 본선(토너먼트 브래킷). 웹 MobileDEReferee 와 동일 구조/흐름.
/// 조 자동편성은 웹 준비 단계 → 앱은 편성·시작된 예선을 진행만 한다.
/// 승자 전파는 서버가 처리하고 앱은 저장/해제 후 재조회.
class HostDeScreen extends ConsumerStatefulWidget {
  final int homepageId;
  final int gameRoomId;
  final String? sortName;
  const HostDeScreen({
    super.key,
    required this.homepageId,
    required this.gameRoomId,
    this.sortName,
  });

  @override
  ConsumerState<HostDeScreen> createState() => _HostDeScreenState();
}

class _HostDeScreenState extends ConsumerState<HostDeScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(widget.sortName ?? '더블 엘리미네이션 운영'),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: '예선 (조별)'),
              Tab(text: '본선 (토너먼트)'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DePrelimTab(
                homepageId: widget.homepageId, gameRoomId: widget.gameRoomId),
            _DeBracketTab(
                homepageId: widget.homepageId, gameRoomId: widget.gameRoomId),
          ],
        ),
      ),
    );
  }
}

// ======================= 예선 탭 =======================

class _DePrelimTab extends ConsumerStatefulWidget {
  final int homepageId;
  final int gameRoomId;
  const _DePrelimTab({required this.homepageId, required this.gameRoomId});

  @override
  ConsumerState<_DePrelimTab> createState() => _DePrelimTabState();
}

class _DePrelimTabState extends ConsumerState<_DePrelimTab>
    with AutomaticKeepAliveClientMixin {
  int? _selectedGroup;
  int? _selectedRound;
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  ({int homepageId, int gameRoomId}) get _key =>
      (homepageId: widget.homepageId, gameRoomId: widget.gameRoomId);

  HostOperationService get _svc => ref.read(hostOperationServiceProvider);

  Future<void> _reload() async {
    ref.invalidate(dePrelimProvider(_key));
    await ref.read(dePrelimProvider(_key).future);
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Widget _correctionMenu(DeGroup group) => PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        onSelected: (v) {
          if (v == 'delLast') _deleteGroupLastRound(group);
          if (v == 'delAll') _deleteGroupAllRounds(group);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'delLast', child: Text('이 조 마지막 라운드 삭제')),
          PopupMenuItem(value: 'delAll', child: Text('이 조 전체 삭제')),
        ],
      );

  Future<void> _deleteGroupLastRound(DeGroup group) async {
    final maxRound = group.maxRound;
    if (maxRound < 1) {
      _toast('삭제할 라운드가 없습니다.');
      return;
    }
    final done = await HostCorrection.runDelete(
      context,
      title: '라운드 삭제',
      confirmMessage: '${group.groupNumber}조 $maxRound라운드를 삭제하시겠습니까?',
      action: (pw) => _svc.deleteDePrelimRound(
          widget.homepageId, widget.gameRoomId,
          group: group.groupNumber, round: maxRound, password: pw),
    );
    if (done) {
      setState(() => _selectedRound = null);
      await _reload();
    }
  }

  Future<void> _deleteGroupAllRounds(DeGroup group) async {
    final done = await HostCorrection.runDelete(
      context,
      title: '조 전체 삭제',
      confirmMessage: '${group.groupNumber}조의 모든 라운드를 삭제하시겠습니까?',
      action: (pw) => _svc.deleteDePrelimAllRounds(
          widget.homepageId, widget.gameRoomId,
          group: group.groupNumber, password: pw),
    );
    if (done) {
      setState(() => _selectedRound = null);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(dePrelimProvider(_key));
    return async.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('불러오지 못했습니다',
              style: TextStyle(color: AppColors.textSecondary)),
          TextButton(onPressed: _reload, child: const Text('다시 시도')),
        ]),
      ),
      data: (s) => _content(s),
    );
  }

  Widget _content(DePrelimSection s) {
    if (!s.started || s.groups.isEmpty) {
      return _notReady();
    }
    final groupNum = _selectedGroup ?? s.groups.first.groupNumber;
    DeGroup group = s.groups.firstWhere(
      (g) => g.groupNumber == groupNum,
      orElse: () => s.groups.first,
    );
    final roundNums = group.roundNumbers;
    final round = (_selectedRound != null && roundNums.contains(_selectedRound))
        ? _selectedRound!
        : (roundNums.isNotEmpty ? roundNums.first : 1);
    final matches = group.rounds[round] ?? const [];

    return Column(children: [
      Row(children: [
        Expanded(child: _groupChips(s.groups, group.groupNumber)),
        _correctionMenu(group),
      ]),
      if (roundNums.length > 1) _roundTabs(roundNums, round),
      Expanded(
        child: matches.isEmpty
            ? Center(
                child: Text('해당 라운드에 매치가 없습니다',
                    style: TextStyle(color: AppColors.textSecondary)))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                itemCount: matches.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (_, i) {
                  if (i == matches.length) {
                    return _nextRoundButton(group, round, matches);
                  }
                  return _prelimCard(group.groupNumber, matches[i]);
                },
              ),
      ),
    ]);
  }

  Widget _notReady() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.groups_outlined, size: 56, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('예선이 아직 편성되지 않았습니다',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('조 편성·예선 시작은 웹 관리에서 진행한 뒤\n이 화면에서 경기 결과를 입력하세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: _reload, child: const Text('새로고침')),
        ]),
      ),
    );
  }

  Widget _groupChips(List<DeGroup> groups, int selected) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        children: [
          for (final g in groups)
            GestureDetector(
              onTap: () => setState(() {
                _selectedGroup = g.groupNumber;
                _selectedRound = null;
              }),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(
                  color: g.groupNumber == selected
                      ? AppColors.primary
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: g.completed && g.groupNumber != selected
                          ? AppColors.statusOpenText
                          : (g.groupNumber == selected
                              ? AppColors.primary
                              : AppColors.border)),
                ),
                child: Text(
                    '${g.groupNumber}조(${g.memberCount})${g.completed ? ' ✓' : ''}',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: g.groupNumber == selected
                            ? Colors.white
                            : (g.completed
                                ? AppColors.statusOpenText
                                : AppColors.textSecondary))),
              ),
            ),
        ],
      ),
    );
  }

  Widget _roundTabs(List<int> roundNums, int round) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        children: [
          for (final r in roundNums)
            GestureDetector(
              onTap: () => setState(() => _selectedRound = r),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(
                  color: r == round ? AppColors.board : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: r == round ? AppColors.board : AppColors.border),
                ),
                child: Text('${r}R',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color:
                            r == round ? Colors.white : AppColors.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _prelimCard(int groupNumber, DePrelimMatch m) {
    final done = m.hasWinner;
    final isBye = m.isBye;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFF6FCF8) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: done
                ? const Color(0xFFCDE9D8)
                : AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(6)),
            child: Text('$groupNumber조 · ${m.round}R',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary)),
          ),
          const Spacer(),
          if (done)
            _tag('완료', AppColors.statusOpenText, AppColors.statusOpenBg)
          else
            _tag('대기', AppColors.primaryDark, AppColors.surfaceVariant),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _winBtn(
            m.player1,
            // 동명이인 오동작 방지: 이름이 아니라 번호(id)로 승자 판정
            selected: m.winnerNumber > 0 && m.winnerNumber == m.player1Number,
            onTap: (_busy || isBye)
                ? null
                : () => _onWinnerTap(groupNumber, m, m.player1, m.player1Number),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('vs',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHint)),
          ),
          _winBtn(
            m.player2,
            selected: m.winnerNumber > 0 && m.winnerNumber == m.player2Number,
            onTap: (_busy || isBye)
                ? null
                : () => _onWinnerTap(groupNumber, m, m.player2, m.player2Number),
          ),
        ]),
      ]),
    );
  }

  Widget _nextRoundButton(DeGroup group, int round, List<DePrelimMatch> curr) {
    final maxRound = group.maxRound;
    // 최종 라운드를 보고 있을 때만 "다음 라운드 생성" 노출(앞 라운드 화면엔 숨김)
    if (round != maxRound) return const SizedBox.shrink();
    final maxMatches = group.rounds[maxRound] ?? const [];
    final allDone =
        maxMatches.isNotEmpty && maxMatches.every((m) => m.hasWinner);
    // 웹과 동일: 최대 3라운드까지, 현재 최종 라운드가 전부 완료일 때만
    final canCreate = maxRound > 0 && maxRound < 3 && allDone;
    if (!canCreate) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _busy ? null : () => _createNextRound(group, maxRound),
          child: Text('${maxRound + 1}라운드 생성'),
        ),
      ),
    );
  }

  Widget _winBtn(String name,
      {required bool selected, VoidCallback? onTap}) {
    final bg = selected ? AppColors.primary : AppColors.surface;
    final fg = selected ? Colors.white : AppColors.textPrimary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border)),
          child: Text(name.isEmpty ? '-' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
        ),
      ),
    );
  }

  /// 승자 탭 — 같은 승자 재탭 시 해제. 판정은 번호(id)로(동명이인 안전).
  Future<void> _onWinnerTap(
      int groupNumber, DePrelimMatch m, String winnerName, int winnerNumber) async {
    if (winnerName.isEmpty) return;
    final isClear = m.winnerNumber > 0 && m.winnerNumber == winnerNumber;
    final ok = await _confirm(isClear
        ? '$winnerName 승을 해제하시겠습니까?'
        : '$winnerName 승으로 저장하시겠습니까?');
    if (ok != true) return;
    await _save(
      groupNumber,
      m,
      winner: isClear ? '' : winnerName,
      winnerNumber: isClear ? 0 : winnerNumber,
    );
  }

  Future<void> _save(int groupNumber, DePrelimMatch m,
      {required String winner, required int winnerNumber}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await _svc.saveDePrelimResult(
        widget.homepageId,
        widget.gameRoomId,
        round: m.round,
        group: groupNumber,
        player1: m.player1,
        player2: m.player2,
        player1Number: m.player1Number,
        player2Number: m.player2Number,
        winner: winner,
        winnerNumber: winnerNumber,
      );
      if (res['success'] == false && mounted) {
        _toast(res['message']?.toString() ?? '저장에 실패했습니다.');
      }
      await _reload();
    } catch (_) {
      if (mounted) _toast('오류가 발생했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createNextRound(DeGroup group, int maxRound) async {
    final maxMatches = group.rounds[maxRound] ?? const [];
    final incomplete = maxMatches.where((m) => !m.hasWinner).length;
    if (incomplete > 0) {
      _toast('$incomplete개 매치에 승자가 없습니다. 모든 결과를 입력해주세요.');
      return;
    }
    final ok = await _confirm('${maxRound + 1}라운드를 생성하시겠습니까?');
    if (ok != true) return;
    // 현재 라운드 참가자 추출 (웹 handleCreateNextRound 동일)
    final participants = <Map<String, dynamic>>[];
    for (final m in maxMatches) {
      participants.add({'name': m.player1, 'id': m.player1Number});
      participants.add({'name': m.player2, 'id': m.player2Number});
    }
    setState(() => _busy = true);
    try {
      final res = await _svc.makeDeNextRound(
        widget.homepageId,
        widget.gameRoomId,
        round: maxRound,
        group: group.groupNumber,
        participants: participants,
      );
      final status = res['status']?.toString();
      if (status != null && status != 'SUCCESS' && mounted) {
        _toast('라운드 생성 실패: ${res['message'] ?? ''}');
      } else {
        setState(() => _selectedRound = maxRound + 1);
      }
      await _reload();
    } catch (_) {
      if (mounted) _toast('다음 라운드 생성 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm(String msg) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(msg),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('확인')),
          ],
        ),
      );

  Widget _tag(String text, Color tx, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: tx)),
      );
}

// ======================= 본선 탭 =======================

class _DeBracketTab extends ConsumerStatefulWidget {
  final int homepageId;
  final int gameRoomId;
  const _DeBracketTab({required this.homepageId, required this.gameRoomId});

  @override
  ConsumerState<_DeBracketTab> createState() => _DeBracketTabState();
}

class _DeBracketTabState extends ConsumerState<_DeBracketTab>
    with AutomaticKeepAliveClientMixin {
  int? _selectedRound;
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  ({int homepageId, int gameRoomId}) get _key =>
      (homepageId: widget.homepageId, gameRoomId: widget.gameRoomId);

  HostOperationService get _svc => ref.read(hostOperationServiceProvider);

  Future<void> _reload() async {
    ref.invalidate(deBracketProvider(_key));
    await ref.read(deBracketProvider(_key).future);
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Widget _correctionMenu() => PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        onSelected: (v) {
          if (v == 'reset') _resetBracket();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'reset', child: Text('본선 초기화')),
        ],
      );

  Future<void> _resetBracket() async {
    final done = await HostCorrection.runDelete(
      context,
      title: '본선 초기화',
      confirmMessage: '본선 토너먼트의 모든 결과가 삭제됩니다. 계속하시겠습니까?',
      action: (_) => _svc.resetDeBracket(widget.homepageId, widget.gameRoomId),
    );
    if (done) {
      setState(() => _selectedRound = null);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(deBracketProvider(_key));
    return async.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('불러오지 못했습니다',
              style: TextStyle(color: AppColors.textSecondary)),
          TextButton(onPressed: _reload, child: const Text('다시 시도')),
        ]),
      ),
      data: (s) => _content(s),
    );
  }

  Widget _content(DeBracketSection s) {
    if (!s.started || s.matches.isEmpty) {
      return _notReady();
    }
    final roundNums = s.roundNumbers;
    final round = (_selectedRound != null && roundNums.contains(_selectedRound))
        ? _selectedRound!
        : (roundNums.isNotEmpty ? roundNums.first : 1);
    final matches = s.matchesOfRound(round);

    return Column(children: [
      Row(children: [
        Expanded(
          child: roundNums.length > 1
              ? _roundTabs(s, roundNums, round)
              : const SizedBox(height: 44),
        ),
        _correctionMenu(),
      ]),
      Expanded(
        child: matches.isEmpty
            ? Center(
                child: Text('해당 라운드에 매치가 없습니다',
                    style: TextStyle(color: AppColors.textSecondary)))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                itemCount: matches.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (_, i) => _bracketCard(s, matches[i]),
              ),
      ),
    ]);
  }

  Widget _notReady() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.account_tree_outlined, size: 56, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('본선이 아직 시작되지 않았습니다',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('예선 종료 후 웹에서 본선 대진표를 생성하면\n이 화면에서 경기 결과를 입력할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: _reload, child: const Text('새로고침')),
        ]),
      ),
    );
  }

  Widget _roundTabs(DeBracketSection s, List<int> roundNums, int round) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final r in roundNums)
            GestureDetector(
              onTap: () => setState(() => _selectedRound = r),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(
                  color: r == round ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: r == round ? AppColors.primary : AppColors.border),
                ),
                child: Text(_roundLabel(s, r),
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: r == round
                            ? Colors.white
                            : AppColors.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bracketCard(DeBracketSection s, DeBracketMatch m) {
    final done = m.hasWinner;
    final both = m.hasBothPlayers;
    final p1Name = m.player1Name.isEmpty ? 'TBD' : m.player1Name;
    final p2Name = m.player2Name.isEmpty ? 'TBD' : m.player2Name;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFF6FCF8) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: done
                ? const Color(0xFFCDE9D8)
                : (both
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.border)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(6)),
            child: Text('${_roundLabel(s, m.round)} · M${m.matchNumber}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary)),
          ),
          const Spacer(),
          if (done)
            _tag('완료', AppColors.statusOpenText, AppColors.statusOpenBg)
          else if (both)
            _tag('대기', AppColors.primaryDark, AppColors.surfaceVariant)
          else
            _tag('대진 미확정', AppColors.textTertiary, AppColors.surfaceVariant),
        ]),
        const SizedBox(height: 10),
        if (!both)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Expanded(
              child: Text('$p1Name  vs  $p2Name',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHint)),
            ),
          ])
        else
          Row(children: [
            _winBtn(p1Name,
                selected: m.winnerId != null && m.winnerId == m.player1Id,
                onTap: _busy
                    ? null
                    : () => _onWinnerTap(m, m.player1Id!, p1Name)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('vs',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint)),
            ),
            _winBtn(p2Name,
                selected: m.winnerId != null && m.winnerId == m.player2Id,
                onTap: _busy
                    ? null
                    : () => _onWinnerTap(m, m.player2Id!, p2Name)),
          ]),
      ]),
    );
  }

  Widget _winBtn(String name,
      {required bool selected, VoidCallback? onTap}) {
    final bg = selected ? AppColors.primary : AppColors.surface;
    final fg = selected ? Colors.white : AppColors.textPrimary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border)),
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
        ),
      ),
    );
  }

  /// 승자 탭 — 같은 승자 재탭 시 해제(winnerId=null)
  Future<void> _onWinnerTap(
      DeBracketMatch m, int winnerId, String winnerName) async {
    final isClear = m.winnerId == winnerId;
    final ok = await _confirm(isClear
        ? '$winnerName 승을 해제하시겠습니까?'
        : '$winnerName 승으로 저장하시겠습니까?');
    if (ok != true) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await _svc.saveDeBracketResult(
        widget.homepageId,
        widget.gameRoomId,
        round: m.round,
        matchNumber: m.matchNumber,
        player1Id: m.player1Id,
        player1Name: m.player1Name,
        player2Id: m.player2Id,
        player2Name: m.player2Name,
        winnerId: isClear ? null : winnerId,
      );
      if (res['status'] == 'ERROR' && mounted) {
        _toast(res['message']?.toString() ?? '저장에 실패했습니다.');
      }
      await _reload();
    } catch (_) {
      if (mounted) _toast('오류가 발생했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 라운드 라벨 (웹 MobileDETournamentMatches.getRoundLabel 동일)
  String _roundLabel(DeBracketSection s, int round) {
    if (round == 0) return '예선';
    final bracketSize = s.round1Count > 0 ? s.round1Count * 2 : 0;
    if (bracketSize <= 0) return '${round}R';
    var divisor = 1;
    for (var i = 1; i < round; i++) {
      divisor *= 2;
    }
    final stageSize = bracketSize ~/ divisor;
    if (stageSize <= 2) return '결승';
    return '$stageSize강';
  }

  Future<bool?> _confirm(String msg) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(msg),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('확인')),
          ],
        ),
      );

  Widget _tag(String text, Color tx, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: tx)),
      );
}
