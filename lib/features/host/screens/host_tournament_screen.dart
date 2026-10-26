import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/host_operation.dart';
import '../../../data/providers/host_operation_provider.dart';
import '../../../data/services/host_operation_service.dart';
import 'host_correction.dart';

/// B — 싱글 토너먼트 부문 운영 (브래킷 + 매치 결과입력 + 순위)
///
/// 서버 SSOT: 저장 후 항상 bracket 재조회. 승자 전파·패자 탈락·다음라운드 수정거부(400)는
/// 서버가 처리하고 앱은 재조회만 한다(웹 TournamentMobile.js 동일 흐름).
/// 추첨/대진 생성은 웹에서 하는 준비 단계 → 앱은 대진이 없으면 안내만.
class HostTournamentScreen extends ConsumerStatefulWidget {
  final int homepageId;
  final int gameRoomId;
  final String? sortName;
  const HostTournamentScreen({
    super.key,
    required this.homepageId,
    required this.gameRoomId,
    this.sortName,
  });

  @override
  ConsumerState<HostTournamentScreen> createState() =>
      _HostTournamentScreenState();
}

class _HostTournamentScreenState extends ConsumerState<HostTournamentScreen> {
  int _tab = 0; // 0=대진, 1=순위
  int? _selectedRound;
  bool _busy = false;

  ({int homepageId, int gameRoomId}) get _key =>
      (homepageId: widget.homepageId, gameRoomId: widget.gameRoomId);

  HostOperationService get _svc => ref.read(hostOperationServiceProvider);

  Future<void> _reload() async {
    ref.invalidate(tournamentSectionProvider(_key));
    await ref.read(tournamentSectionProvider(_key).future);
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Widget _correctionMenu() => PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (v) {
          if (v == 'resetBracket') _resetBracket();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'resetBracket', child: Text('대진표 초기화')),
        ],
      );

  Future<void> _resetBracket() async {
    final s = ref.read(tournamentSectionProvider(_key)).value;
    if (s == null || !s.exists) {
      _toast('초기화할 대진표가 없습니다.');
      return;
    }
    final done = await HostCorrection.runDelete(
      context,
      title: '대진표 초기화',
      confirmMessage: '전체 대진표와 모든 경기 결과가 삭제됩니다. 계속하시겠습니까?',
      action: (pw) => _svc.deleteTournamentBracket(
          widget.homepageId, widget.gameRoomId, password: pw),
    );
    if (done) {
      setState(() => _selectedRound = null);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tournamentSectionProvider(_key));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.sortName ?? '토너먼트 운영'), actions: [_correctionMenu()]),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('불러오지 못했습니다',
                style: TextStyle(color: AppColors.textSecondary)),
            TextButton(onPressed: _reload, child: const Text('다시 시도')),
          ]),
        ),
        data: (data) => _content(data),
      ),
    );
  }

  Widget _content(TournamentSection s) {
    if (!s.exists || s.bracket.isEmpty) {
      return _notReady();
    }
    // stale _selectedRound(초기화/재조회로 maxRound 축소 시) 범위 보정
    final round = (_selectedRound != null &&
            _selectedRound! >= 1 &&
            _selectedRound! <= s.maxRound)
        ? _selectedRound!
        : s.maxRound;
    return Column(children: [
      _stateBar(s, round),
      _segments(),
      Expanded(
        child: _tab == 0 ? _bracketTab(s, round) : _rankingsTab(s.rankings),
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
          Text('대진표가 아직 없습니다',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('토너먼트 추첨·대진표 생성은 웹 관리에서 진행한 뒤\n이 화면에서 경기 결과를 입력하세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: _reload, child: const Text('새로고침')),
        ]),
      ),
    );
  }

  Widget _stateBar(TournamentSection s, int round) {
    final roundMatches = _sortedRound(s, round);
    // 실제 경기(부전승 제외) 중 완료 수
    final real = roundMatches.where((m) => !_isByeMatch(m)).toList();
    final done = real.where((m) => m.isDone).length;
    final total = real.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.board, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_roundLabel(s, round).toUpperCase(),
            style: const TextStyle(
                color: Color(0xFF8FA0B4),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1)),
        const SizedBox(height: 5),
        Text('결과 $done/$total 입력됨',
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('경기를 눌러 승자를 선택하세요. 다음 라운드는 자동으로 채워집니다.',
            style: TextStyle(color: const Color(0xFF8FA0B4), fontSize: 12)),
      ]),
    );
  }

  Widget _segments() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10)),
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
          decoration: BoxDecoration(
              color: on ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(8)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: on ? AppColors.primary : AppColors.textSecondary)),
        ),
      ),
    );
  }

  Widget _bracketTab(TournamentSection s, int round) {
    final matches = _sortedRound(s, round);
    return Column(children: [
      if (s.maxRound > 1) _roundChips(s, round),
      Expanded(
        child: matches.isEmpty
            ? Center(
                child: Text('이 라운드에 경기가 없습니다',
                    style: TextStyle(color: AppColors.textSecondary)))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: matches.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (_, i) => _matchCard(matches[i], i + 1),
              ),
      ),
    ]);
  }

  Widget _roundChips(TournamentSection s, int round) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (int r = 1; r <= s.maxRound; r++)
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

  Widget _matchCard(TournamentMatch m, int displayNo) {
    final p1 = m.p1;
    final p2 = m.p2;
    final isBye = _isByeMatch(m);
    final done = m.isDone;

    return GestureDetector(
      onTap: () => _onMatchTap(m),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: done
              ? const Color(0xFFF6FCF8)
              : (isBye ? AppColors.surfaceVariant : AppColors.surface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: done
                  ? const Color(0xFFCDE9D8)
                  : (isBye
                      ? AppColors.border
                      : AppColors.primary.withValues(alpha: 0.35))),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(6)),
              child: Text('경기 $displayNo',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary)),
            ),
            const Spacer(),
            if (isBye)
              _tag('부전', AppColors.statusOpenText, AppColors.statusOpenBg)
            else if (done)
              _tag('완료', AppColors.statusOpenText, AppColors.statusOpenBg)
            else
              _tag('대기', AppColors.primaryDark, AppColors.surfaceVariant),
          ]),
          const SizedBox(height: 10),
          _playerRow(p1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('vs',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHint)),
          ),
          _playerRow(p2),
        ]),
      ),
    );
  }

  Widget _playerRow(TournamentPlayer? p) {
    final name = p?.name ?? 'TBD';
    final isWinner = p?.isWinner == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: isWinner ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
            color: isWinner ? AppColors.primary : AppColors.border),
      ),
      child: Row(children: [
        Expanded(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isWinner ? Colors.white : AppColors.textPrimary)),
        ),
        if (isWinner)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999)),
            child: const Text('승',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
      ]),
    );
  }

  /// 매치 탭 — 웹 TournamentMobile.js handleMatchClick 규칙과 동일
  void _onMatchTap(TournamentMatch m) {
    if (m.isWalkOver) return; // 부전 매치 무시
    final p1 = m.p1;
    final p2 = m.p2;
    final p1Tbd = p1 == null || p1.isTbd;
    final p2Tbd = p2 == null || p2.isTbd;
    if (p1Tbd && p2Tbd) {
      _toast('대진이 아직 확정되지 않았습니다.');
      return;
    }
    // 부전 상대(한쪽이라도 TBD/BYE)면 승자 선택 불필요
    if (p1 == null || p1.isTbd || p1.isByeSlot ||
        p2 == null || p2.isTbd || p2.isByeSlot) {
      return;
    }
    _openWinnerSheet(m);
  }

  void _openWinnerSheet(TournamentMatch m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final p1 = m.p1!;
        final p2 = m.p2!;
        final currentWinner = m.isDone
            ? (p1.isWinner ? p1.name : (p2.isWinner ? p2.name : null))
            : null;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(m.isDone ? '결과 수정' : '승자 선택',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('${p1.name}  vs  ${p2.name}',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              if (currentWinner != null) ...[
                const SizedBox(height: 6),
                Text('현재 승자: $currentWinner',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ],
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: _winnerChoice(m, p1, selected: p1.isWinner, ctx: ctx)),
                const SizedBox(width: 10),
                Expanded(
                    child: _winnerChoice(m, p2, selected: p2.isWinner, ctx: ctx)),
              ]),
              if (m.isDone) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _confirmReset(m);
                          },
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary),
                    child: const Text('결과 초기화'),
                  ),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }

  Widget _winnerChoice(TournamentMatch m, TournamentPlayer p,
      {required bool selected, required BuildContext ctx}) {
    return GestureDetector(
      onTap: _busy || p.id == null
          ? null
          : () {
              Navigator.pop(ctx);
              _saveWinner(m, p.id!);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1),
        ),
        child: Text('${p.name} 승',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : AppColors.textPrimary)),
      ),
    );
  }

  Future<void> _saveWinner(TournamentMatch m, int winnerId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _svc.setTournamentResult(widget.homepageId, widget.gameRoomId,
          matchDbId: m.matchDbId, winnerId: winnerId);
      await _reload();
    } on DioException catch (e) {
      if (mounted) _toast(_errText(e, '결과 저장에 실패했습니다.'));
    } catch (_) {
      if (mounted) _toast('결과 저장에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReset(TournamentMatch m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('결과 초기화'),
        content: const Text('이 경기 결과를 초기화하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('초기화')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _svc.resetTournamentResult(widget.homepageId, widget.gameRoomId,
          matchDbId: m.matchDbId);
      await _reload();
    } on DioException catch (e) {
      if (mounted) _toast(_errText(e, '초기화에 실패했습니다.'));
    } catch (_) {
      if (mounted) _toast('초기화에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _rankingsTab(List<Map<String, dynamic>> rankings) {
    if (rankings.isEmpty) {
      return Center(
          child: Text('순위 데이터가 없습니다 (경기 진행 후 표시)',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: rankings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 7),
      itemBuilder: (_, i) {
        final r = rankings[i];
        final rank = _asInt(r['rank']) ?? (i + 1);
        final elim = r['eliminatedRound']?.toString();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border)),
          child: Row(children: [
            SizedBox(
                width: 26,
                child: Text('$rank',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color:
                            rank <= 3 ? AppColors.primary : AppColors.textPrimary))),
            Expanded(
              child: Text(r['playerName']?.toString() ?? '-',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ),
            Text(
                rank == 1 && (elim == null || elim.isEmpty)
                    ? '우승'
                    : (elim == null || elim.isEmpty ? '진행 중' : '$elim 탈락'),
                style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
          ]),
        );
      },
    );
  }

  // ── helpers ──

  List<TournamentMatch> _sortedRound(TournamentSection s, int round) {
    final list = s.matchesOfRound(round);
    list.sort((a, b) => a.matchDbId.compareTo(b.matchDbId));
    return list;
  }

  bool _isByeMatch(TournamentMatch m) {
    if (m.isWalkOver) return true;
    final p2 = m.p2;
    return p2 != null && p2.isByeSlot;
  }

  /// 라운드 라벨 — 서버가 준 roundText(16강/결승 등) 우선, 없으면 nR
  String _roundLabel(TournamentSection s, int round) {
    for (final m in s.bracket) {
      if (m.roundNumber == round &&
          m.roundText.isNotEmpty) {
        return m.roundText;
      }
    }
    return '${round}R';
  }

  String _errText(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['error'] ?? data['message'];
      if (msg != null) return msg.toString();
    }
    if (e.response?.statusCode == 400) {
      return '다음 라운드에 이미 결과가 있어 변경할 수 없습니다.';
    }
    return fallback;
  }

  int? _asInt(dynamic v) => v == null
      ? null
      : (v is int ? v : int.tryParse(v.toString().split('.').first));

  Widget _tag(String text, Color tx, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: tx)),
      );
}
