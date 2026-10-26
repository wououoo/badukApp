import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/host_operation_provider.dart';
import '../../../data/services/host_operation_service.dart';
import 'host_correction.dart';

/// B — 단체 스위스리그 부문 운영 (팀매치 → 장별 승자 입력 → 라운드 저장)
///
/// 개인전과 달리 팀 vs 팀, 각 장(board)에서 team1/team2 개인 승자를 고른다.
/// 저장은 라운드 전체를 보낸다(백엔드가 team명·playerIndex로 upsert → 충돌/누락 없음).
class HostTeamSwissScreen extends ConsumerStatefulWidget {
  final int homepageId;
  final int gameRoomId;
  final String? sortName;
  const HostTeamSwissScreen({
    super.key,
    required this.homepageId,
    required this.gameRoomId,
    this.sortName,
  });

  @override
  ConsumerState<HostTeamSwissScreen> createState() => _HostTeamSwissScreenState();
}

class _HostTeamSwissScreenState extends ConsumerState<HostTeamSwissScreen> {
  int _tab = 0;
  int? _selectedRound;
  bool _busy = false;
  // 로컬 미저장 선택: "matchIndex:playerIndex" -> "team1"/"team2"
  final Map<String, String> _local = {};

  /// 보고 있는 라운드를 키에 포함(과거 라운드 조회용). null=서버가 현재 라운드 반환.
  ({int homepageId, int gameRoomId, int? round}) get _key => (
        homepageId: widget.homepageId,
        gameRoomId: widget.gameRoomId,
        round: _selectedRound,
      );
  HostOperationService get _svc => ref.read(hostOperationServiceProvider);

  Future<void> _reload() async {
    ref.invalidate(teamSwissSectionProvider(_key));
    await ref.read(teamSwissSectionProvider(_key).future);
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action, {bool clearLocal = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await action();
      if (res['success'] == false && mounted) {
        _toast(res['message']?.toString() ?? '처리에 실패했습니다.');
      } else if (clearLocal) {
        _local.clear();
      }
      await _reload();
    } catch (e) {
      if (mounted) _toast('오류가 발생했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Widget _correctionMenu() => PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (v) {
          if (v == 'delLast') _deleteLastRound();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'delLast', child: Text('마지막 라운드 삭제')),
        ],
      );

  Future<void> _deleteLastRound() async {
    final data = ref.read(teamSwissSectionProvider(_key)).value;
    final maxRound = _asInt(data?['maxRound']) ?? 0;
    if (maxRound < 1) {
      _toast('삭제할 라운드가 없습니다.');
      return;
    }
    final done = await HostCorrection.runDelete(
      context,
      title: '마지막 라운드 삭제',
      confirmMessage: '$maxRound라운드를 삭제하시겠습니까? 해당 라운드 대진·결과가 모두 지워집니다.',
      action: (pw) => _svc.deleteRound(widget.homepageId, widget.gameRoomId,
          kind: 'team-swiss', round: maxRound, password: pw),
    );
    if (done) {
      setState(() => _selectedRound = null);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(teamSwissSectionProvider(_key));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.sortName ?? '단체 스위스 운영'), actions: [_correctionMenu()]),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('불러오지 못했습니다', style: TextStyle(color: AppColors.textSecondary)),
            TextButton(onPressed: _reload, child: const Text('다시 시도')),
          ]),
        ),
        data: (data) => _content(data),
      ),
    );
  }

  Widget _content(Map<String, dynamic> data) {
    final maxRound = _asInt(data['maxRound']) ?? 0;
    final rankings = (data['rankings'] as List?) ?? const [];
    if (maxRound == 0) {
      return _notStarted();
    }
    final round = _selectedRound ?? (_asInt(data['round']) ?? maxRound);
    final roundResult = (data['roundResult'] as Map?) ?? const {};
    final matches = (roundResult['results'] as List?) ?? const [];
    final isCurrent = round == maxRound;

    return Column(children: [
      _stateBar(round, matches, isCurrent),
      _segments(),
      Expanded(
        child: _tab == 0 ? _pairingsTab(maxRound, round, matches, isCurrent) : _rankingsTab(rankings),
      ),
    ]);
  }

  Widget _notStarted() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.groups_outlined, size: 56, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('아직 시작하지 않은 부문입니다',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('팀 편성으로 1라운드를 시작하세요.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : () => _run(() => _svc.generateTeamSwiss(widget.homepageId, widget.gameRoomId)),
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('1라운드 편성 시작'),
            ),
          ),
        ]),
      ),
    );
  }

  // displayRound = 지금 보고 있는 라운드(과거일 수 있음)
  Widget _stateBar(int displayRound, List matches, bool isCurrent) {
    final done = matches.where((m) => (m as Map)['isCompleted'] == true).length;
    final total = matches.length;
    final allDone = total > 0 && done == total;
    final hasLocal = _local.isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.board, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$displayRound라운드',
            style: const TextStyle(color: Color(0xFF8FA0B4), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
        const SizedBox(height: 5),
        Text('팀매치 $done/$total 완료${hasLocal ? " · 미저장 있음" : ""}',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 11),
        if (allDone && isCurrent && !hasLocal)
          Row(children: [
            Expanded(child: _darkBtn('다음 라운드 편성', _busy ? null : () => _run(() => _svc.generateTeamSwiss(widget.homepageId, widget.gameRoomId)))),
            const SizedBox(width: 8),
            Expanded(child: _darkBtn('순위 확정', _busy ? null : _confirmFinalize, outline: true)),
          ])
        else
          Text(hasLocal ? '아래 "라운드 저장"으로 입력한 결과를 저장하세요.' : '각 장의 승자를 고른 뒤 저장하세요.',
              style: TextStyle(color: const Color(0xFF8FA0B4), fontSize: 12)),
      ]),
    );
  }

  Widget _darkBtn(String label, VoidCallback? onTap, {bool outline = false}) {
    return Material(
      color: outline ? Colors.transparent : AppColors.primary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: outline
              ? BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF3A4553)))
              : null,
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _segments() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [_seg('대진', 0), _seg('순위', 1)]),
    );
  }

  Widget _seg(String label, int i) {
    final on = _tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? AppColors.surface : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? AppColors.primary : AppColors.textSecondary)),
        ),
      ),
    );
  }

  Widget _pairingsTab(int maxRound, int round, List matches, bool isCurrent) {
    return Column(children: [
      if (maxRound > 1) _roundChips(maxRound, round),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: matches.length + (isCurrent ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= matches.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton(
                  onPressed: (_busy || !isCurrent) ? null : () => _saveRound(round, matches),
                  child: Text(_local.isEmpty ? '라운드 저장' : '라운드 저장 (미저장 ${_local.length})'),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _matchCard(i, Map<String, dynamic>.from(matches[i]), isCurrent),
            );
          },
        ),
      ),
    ]);
  }

  Widget _roundChips(int maxRound, int round) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (int r = 1; r <= maxRound; r++)
            GestureDetector(
              onTap: () => setState(() { _selectedRound = r; _local.clear(); }),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(
                  color: r == round ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: r == round ? AppColors.primary : AppColors.border),
                ),
                child: Text('${r}R', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: r == round ? Colors.white : AppColors.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _matchCard(int mi, Map<String, dynamic> match, bool editable) {
    final t1 = _asStr(match['team1Name']);
    final t2 = _asStr(match['team2Name']);
    final w1 = _asInt(match['team1IndividualWins']) ?? 0;
    final w2 = _asInt(match['team2IndividualWins']) ?? 0;
    final teamWinner = _asStr(match['teamWinner']); // TEAM1/TEAM2/TIE
    final isBye = t2 == '부전승';
    final boards = (match['results'] as List?) ?? const [];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        // 팀 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Expanded(child: Text(t1, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                    color: teamWinner == 'TEAM1' ? AppColors.primaryDark : AppColors.textPrimary))),
            Text('$w1 : $w2', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            Expanded(child: Text(t2, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                    color: teamWinner == 'TEAM2' ? AppColors.primaryDark : AppColors.textPrimary))),
          ]),
        ),
        if (isBye)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text('$t1 부전승', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          )
        else
          ...List.generate(boards.length, (bi) => _boardRow(mi, Map<String, dynamic>.from(boards[bi]), editable)),
      ]),
    );
  }

  Widget _boardRow(int mi, Map<String, dynamic> board, bool editable) {
    final pi = _asInt(board['playerIndex']) ?? 0;
    final m1 = _asStr(board['team1MemberName']);
    final m2 = _asStr(board['team2MemberName']);
    final serverWinner = _asStr(board['winner']);
    final winner = _local['$mi:$pi'] ?? (serverWinner.isEmpty ? null : serverWinner);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(children: [
        SizedBox(width: 26, child: Text('${pi}장', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary))),
        _boardBtn(m1, winner == 'team1', editable ? () => _pick(mi, pi, 'team1') : null),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Text('vs', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textHint)),
        ),
        _boardBtn(m2, winner == 'team2', editable ? () => _pick(mi, pi, 'team2') : null),
      ]),
    );
  }

  Widget _boardBtn(String name, bool win, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: win ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: win ? AppColors.primary : AppColors.border),
          ),
          child: Text(name.isEmpty ? '-' : name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: win ? Colors.white : AppColors.textPrimary)),
        ),
      ),
    );
  }

  void _pick(int mi, int pi, String team) {
    setState(() => _local['$mi:$pi'] = team);
  }

  Future<void> _saveRound(int round, List matches) async {
    final results = <Map<String, dynamic>>[];
    for (int mi = 0; mi < matches.length; mi++) {
      final match = Map<String, dynamic>.from(matches[mi]);
      final boards = (match['results'] as List?) ?? const [];
      final boardOut = <Map<String, dynamic>>[];
      for (final b in boards) {
        final board = Map<String, dynamic>.from(b);
        final pi = _asInt(board['playerIndex']) ?? 0;
        final w = _local['$mi:$pi'] ?? _asStr(board['winner']);
        boardOut.add({'playerIndex': pi, 'winner': w});
      }
      results.add({
        'team1Name': match['team1Name'],
        'team2Name': match['team2Name'],
        'results': boardOut,
      });
    }
    await _run(() => _svc.saveTeamSwissResults(widget.homepageId, widget.gameRoomId,
        round: round, results: results), clearLocal: true);
  }

  Widget _rankingsTab(List rankings) {
    if (rankings.isEmpty) {
      return Center(child: Text('순위 데이터가 없습니다', style: TextStyle(color: AppColors.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: rankings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 7),
      itemBuilder: (_, i) {
        final r = Map<String, dynamic>.from(rankings[i]);
        final wins = _asInt(r['totalWins']) ?? 0;
        final losses = _asInt(r['totalLosses']) ?? 0;
        final indiv = _asInt(r['totalIndividualWins']);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            SizedBox(width: 26, child: Text('${i + 1}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: i < 3 ? AppColors.primary : AppColors.textPrimary))),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_asStr(r['teamName']), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('$wins승 $losses패', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$wins', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              if (indiv != null) Text('개인 $indiv승', style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary)),
            ]),
          ]),
        );
      },
    );
  }

  Future<void> _confirmFinalize() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('순위 확정'),
        content: const Text('확정하면 참가자에게 순위가 공개되고 레이팅에 반영됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('확정')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => _svc.finalizeTeamSwiss(widget.homepageId, widget.gameRoomId));
  }

  int? _asInt(dynamic v) => v == null ? null : (v is int ? v : int.tryParse(v.toString().split('.').first));
  String _asStr(dynamic v) => v?.toString() ?? '';
}
