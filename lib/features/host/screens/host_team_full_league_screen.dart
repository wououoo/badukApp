import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/host_operation_provider.dart';
import '../../../data/services/host_operation_service.dart';
import 'host_correction.dart';

/// B — 단체 풀리그 부문 운영
///
/// 스케줄 고정 → 시작(대진표 생성/materialize) 후 **전 라운드를 한 화면에** 표시.
/// 각 장(board) 승자를 boardResultId 로 즉시 저장. 팀 승패는 자동 집계(동수=무승부).
/// 순위 확정 없음(웹과 동일, 실시간).
class HostTeamFullLeagueScreen extends ConsumerStatefulWidget {
  final int homepageId;
  final int gameRoomId;
  final String? sortName;
  final int teamSize;
  const HostTeamFullLeagueScreen({
    super.key,
    required this.homepageId,
    required this.gameRoomId,
    this.sortName,
    required this.teamSize,
  });

  @override
  ConsumerState<HostTeamFullLeagueScreen> createState() => _State();
}

class _State extends ConsumerState<HostTeamFullLeagueScreen> {
  int _tab = 0;
  bool _busy = false;

  ({int homepageId, int gameRoomId}) get _key =>
      (homepageId: widget.homepageId, gameRoomId: widget.gameRoomId);
  HostOperationService get _svc => ref.read(hostOperationServiceProvider);

  Future<void> _reload() async {
    ref.invalidate(teamFullLeagueSectionProvider(_key));
    await ref.read(teamFullLeagueSectionProvider(_key).future);
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await action();
      if (res['success'] == false && mounted) {
        _toast(res['message']?.toString() ?? '처리에 실패했습니다.');
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
          PopupMenuItem(value: 'delLast', child: Text('마지막 입력 라운드 삭제')),
        ],
      );

  Future<void> _deleteLastRound() async {
    final data = ref.read(teamFullLeagueSectionProvider(_key)).value;
    final round = _asInt(data?['currentRound']) ?? 0;
    if (round < 1) {
      _toast('삭제할(결과 입력된) 라운드가 없습니다.');
      return;
    }
    final done = await HostCorrection.runDelete(
      context,
      title: '마지막 입력 라운드 삭제',
      confirmMessage: '$round라운드 결과를 삭제하시겠습니까? 대진표는 유지되고 결과만 지워집니다.',
      action: (pw) => _svc.deleteRound(widget.homepageId, widget.gameRoomId,
          kind: 'team-full-league', round: round, password: pw),
    );
    if (done) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(teamFullLeagueSectionProvider(_key));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.sortName ?? '단체 풀리그 운영'), actions: [_correctionMenu()]),
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
    // 시작(materialize) 여부는 currentRound 로 판단한다.
    // totalRounds 는 "팀이 2개 이상"이기만 하면(teamCount-1) 양수가 되어
    // 아직 startLeague 전인데도 _pairingsTab 으로 넘어가 버린다 → 보드는 미materialize
    // (boardResultId=null) 라 모든 장 버튼이 비활성 → 시작 버튼도 없는 막다른 길이 됐었다.
    final currentRound = _asInt(data['currentRound']) ?? 0;
    final rounds = (data['rounds'] as List?) ?? const [];
    final rankings = (data['rankings'] as List?) ?? const [];
    if (currentRound == 0) {
      return _notStarted();
    }
    return Column(children: [
      _segments(),
      Expanded(child: _tab == 0 ? _pairingsTab(rounds) : _rankingsTab(rankings)),
    ]);
  }

  Widget _notStarted() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.groups_outlined, size: 56, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('대진표가 아직 없습니다',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('전체 대진표(팀 라운드로빈)를 생성·시작하세요.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : () => _run(() => _svc.startTeamFullLeague(widget.homepageId, widget.gameRoomId, widget.teamSize)),
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('대진표 생성 및 시작'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _segments() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [_seg('전체 대진', 0), _seg('순위', 1)]),
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

  // ── 전 라운드 한 화면 ──
  Widget _pairingsTab(List rounds) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: rounds.length,
      itemBuilder: (_, ri) {
        final round = Map<String, dynamic>.from(rounds[ri]);
        final roundNo = _asInt(round['round']) ?? (ri + 1);
        final matches = (round['matches'] as List?) ?? const [];
        final done = matches.where((m) => (m as Map)['isCompleted'] == true).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
              child: Row(children: [
                Text('$roundNo라운드',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(width: 8),
                Text('$done/${matches.length}',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary, fontWeight: FontWeight.w600)),
              ]),
            ),
            for (final m in matches)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _matchCard(Map<String, dynamic>.from(m)),
              ),
          ],
        );
      },
    );
  }

  Widget _matchCard(Map<String, dynamic> match) {
    final t1 = _asStr(match['team1Name']);
    final t2 = _asStr(match['team2Name']);
    final w1 = _asInt(match['team1Wins']) ?? 0;
    final w2 = _asInt(match['team2Wins']) ?? 0;
    final winnerTeamId = _asInt(match['winnerTeamId']);
    final t1Id = _asInt(match['team1Id']);
    final t2Id = _asInt(match['team2Id']);
    final completed = match['isCompleted'] == true;
    final isBye = t2 == '부전승' || t2 == '없음' || t2Id == null;
    final boards = (match['boards'] as List?) ?? const [];

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: [
            Expanded(child: Text(t1, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                    color: (winnerTeamId != null && winnerTeamId == t1Id) ? AppColors.primaryDark : AppColors.textPrimary))),
            Column(children: [
              Text('$w1 : $w2', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              if (completed && winnerTeamId == null)
                Text('무승부', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
            ]),
            Expanded(child: Text(t2, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                    color: (winnerTeamId != null && winnerTeamId == t2Id) ? AppColors.primaryDark : AppColors.textPrimary))),
          ]),
        ),
        if (isBye)
          Padding(padding: const EdgeInsets.all(14), child: Text('$t1 부전승', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)))
        else
          ...boards.map((b) => _boardRow(Map<String, dynamic>.from(b))),
      ]),
    );
  }

  Widget _boardRow(Map<String, dynamic> board) {
    final boardResultId = _asInt(board['id']);
    final bn = _asInt(board['boardNumber']) ?? 0;
    final m1Id = _asInt(board['team1MemberId']);
    final m2Id = _asInt(board['team2MemberId']);
    final m1 = _asStr(board['team1MemberName']);
    final m2 = _asStr(board['team2MemberName']);
    final winnerMemberId = _asInt(board['winnerMemberId']);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(children: [
        SizedBox(width: 26, child: Text('${bn}장', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary))),
        _boardBtn(m1, winnerMemberId != null && winnerMemberId == m1Id,
            (!_busy && boardResultId != null && m1Id != null) ? () => _saveBoard(boardResultId, m1Id) : null),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text('vs', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textHint))),
        _boardBtn(m2, winnerMemberId != null && winnerMemberId == m2Id,
            (!_busy && boardResultId != null && m2Id != null) ? () => _saveBoard(boardResultId, m2Id) : null),
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

  Future<void> _saveBoard(int boardResultId, int winnerMemberId) async {
    await _run(() => _svc.saveTeamFullLeagueBoard(widget.homepageId, widget.gameRoomId,
        boardResultId: boardResultId, winnerMemberId: winnerMemberId));
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
        final wins = _asInt(r['totalWins']) ?? _asInt(r['wins']) ?? 0;
        final losses = _asInt(r['totalLosses']) ?? _asInt(r['losses']) ?? 0;
        final draws = _asInt(r['draws']) ?? 0;
        final boardWins = _asInt(r['boardWins']);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            SizedBox(width: 26, child: Text('${i + 1}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: i < 3 ? AppColors.primary : AppColors.textPrimary))),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_asStr(r['teamName']), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('$wins승 $draws무 $losses패', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$wins', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              if (boardWins != null) Text('개인 $boardWins승', style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary)),
            ]),
          ]),
        );
      },
    );
  }

  int? _asInt(dynamic v) => v == null ? null : (v is int ? v : int.tryParse(v.toString().split('.').first));
  String _asStr(dynamic v) => v?.toString() ?? '';
}
