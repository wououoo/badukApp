import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/host_operation_provider.dart';
import '../../../data/services/host_operation_service.dart';
import 'host_correction.dart';

/// B — 풀리그(개인) 부문 운영
///
/// 풀리그는 스케줄이 고정 → **전 라운드를 한 화면에** 보여주고, 각 매치 승자를 바로 입력.
/// (라운드 칩·"대진표 생성"·순위 확정 없음 = 웹 동작과 동일. 순위는 실시간 표시)
class HostFullLeagueScreen extends ConsumerStatefulWidget {
  final int homepageId;
  final int gameRoomId;
  final String? sortName;
  const HostFullLeagueScreen({
    super.key,
    required this.homepageId,
    required this.gameRoomId,
    this.sortName,
  });

  @override
  ConsumerState<HostFullLeagueScreen> createState() => _HostFullLeagueScreenState();
}

class _HostFullLeagueScreenState extends ConsumerState<HostFullLeagueScreen> {
  int _tab = 0;
  bool _busy = false;

  ({int homepageId, int gameRoomId}) get _key =>
      (homepageId: widget.homepageId, gameRoomId: widget.gameRoomId);
  HostOperationService get _svc => ref.read(hostOperationServiceProvider);

  Future<void> _reload() async {
    ref.invalidate(fullLeagueSectionProvider(_key));
    await ref.read(fullLeagueSectionProvider(_key).future);
  }

  Future<void> _save(int round, int? p1Id, int? p2Id, int? winnerId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await _svc.saveFullLeagueResult(widget.homepageId, widget.gameRoomId,
          round: round, player1Id: p1Id, player2Id: p2Id, winnerId: winnerId);
      if (res['success'] == false && mounted) {
        _toast(res['message']?.toString() ?? '저장에 실패했습니다.');
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
    final data = ref.read(fullLeagueSectionProvider(_key)).value;
    final maxRound = _asInt(data?['maxRound']) ?? 0;
    if (maxRound < 1) {
      _toast('삭제할(결과 입력된) 라운드가 없습니다.');
      return;
    }
    final done = await HostCorrection.runDelete(
      context,
      title: '마지막 입력 라운드 삭제',
      confirmMessage: '$maxRound라운드 결과를 삭제하시겠습니까? 대진표는 유지되고 결과만 지워집니다.',
      action: (pw) => _svc.deleteRound(widget.homepageId, widget.gameRoomId,
          kind: 'full-league', round: maxRound, password: pw),
    );
    if (done) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(fullLeagueSectionProvider(_key));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.sortName ?? '풀리그 운영'), actions: [_correctionMenu()]),
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
    final totalRounds = _asInt(data['totalRounds']) ?? 0;
    final rounds = (data['rounds'] as List?) ?? const [];
    final rankings = (data['rankings'] as List?) ?? const [];

    if (totalRounds == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.calendar_view_week_outlined, size: 56, color: AppColors.textHint),
            const SizedBox(height: 14),
            Text('아직 대진이 없습니다',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text('참가자가 등록되면 전체 대진표가 자동으로 만들어집니다.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ]),
        ),
      );
    }

    return Column(children: [
      _segments(),
      Expanded(child: _tab == 0 ? _pairingsTab(rounds) : _rankingsTab(rankings)),
    ]);
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
        final matches = (round['results'] as List?) ?? const [];
        final done = matches.where(_isCompleted).length;
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
                padding: const EdgeInsets.only(bottom: 8),
                child: _matchCard(Map<String, dynamic>.from(m), roundNo),
              ),
          ],
        );
      },
    );
  }

  Widget _matchCard(Map<String, dynamic> m, int round) {
    final table = _asInt(m['tableNumber']);
    final p1Id = _asInt(m['player1Id']);
    final p2Id = _asInt(m['player2Id']);
    final p1 = _asStr(m['player1']);
    final p2 = _asStr(m['player2']);
    final winnerId = _asInt(m['winnerId']);
    final completed = _isCompleted(m);
    final isBye = p2Id == null || p2 == '부전승' || p2 == '없음';

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: completed ? const Color(0xFFF6FCF8) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: completed ? const Color(0xFFCDE9D8) : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(6)),
            child: Text(table != null ? '$table번' : '-', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary)),
          ),
          const Spacer(),
          if (isBye)
            _tag('부전승', AppColors.statusOpenText, AppColors.statusOpenBg)
          else if (completed)
            _tag('완료', AppColors.statusOpenText, AppColors.statusOpenBg)
          else
            _tag('미입력', AppColors.primaryDark, AppColors.surfaceVariant),
        ]),
        const SizedBox(height: 10),
        if (isBye)
          Text('$p1 (부전승)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary))
        else
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _winBtn(p1, isWinner: winnerId != null && winnerId == p1Id,
                onTap: _busy ? null : () => _save(round, p1Id, p2Id, p1Id)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Text('vs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textHint))),
            _winBtn(p2, isWinner: winnerId != null && winnerId == p2Id,
                onTap: _busy ? null : () => _save(round, p1Id, p2Id, p2Id)),
          ]),
      ]),
    );
  }

  Widget _winBtn(String name, {required bool isWinner, VoidCallback? onTap}) {
    final bg = isWinner ? AppColors.primary : AppColors.surface;
    final fg = isWinner ? Colors.white : AppColors.textPrimary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9), border: Border.all(color: isWinner ? AppColors.primary : AppColors.border)),
          child: Text(name.isEmpty ? '-' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
        ),
      ),
    );
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
        final pn = _asStr(r['participantName']);
        final name = pn.isNotEmpty ? pn : _asStr(r['name']);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            SizedBox(width: 26, child: Text('${i + 1}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: i < 3 ? AppColors.primary : AppColors.textPrimary))),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('$wins승 $losses패', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ]),
            ),
            Text('$wins', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ]),
        );
      },
    );
  }

  Widget _tag(String text, Color tx, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tx)),
      );

  bool _isCompleted(dynamic m) {
    final map = m is Map ? m : const {};
    return map['end'] == true || map['winnerId'] != null;
  }

  int? _asInt(dynamic v) => v == null ? null : (v is int ? v : int.tryParse(v.toString().split('.').first));
  String _asStr(dynamic v) => v?.toString() ?? '';
}
