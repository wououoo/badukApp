import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/host_operation_provider.dart';
import '../../../data/services/host_operation_service.dart';
import 'host_correction.dart';

/// B — 맥마흔 부문 운영 (대진 + 결과입력 + 순위, 편성/확정 액션)
class HostMcmahonScreen extends ConsumerStatefulWidget {
  final int homepageId;
  final int gameRoomId;
  final String? sortName;
  const HostMcmahonScreen({
    super.key,
    required this.homepageId,
    required this.gameRoomId,
    this.sortName,
  });

  @override
  ConsumerState<HostMcmahonScreen> createState() => _HostMcmahonScreenState();
}

class _HostMcmahonScreenState extends ConsumerState<HostMcmahonScreen> {
  int _tab = 0; // 0=대진, 1=순위
  int? _selectedRound;
  bool _busy = false;

  /// 현재 보고 있는 라운드를 키에 포함한다(과거 라운드 조회용).
  /// _selectedRound=null 이면 서버가 현재 라운드를 반환.
  ({int homepageId, int gameRoomId, int? round}) get _key => (
        homepageId: widget.homepageId,
        gameRoomId: widget.gameRoomId,
        round: _selectedRound,
      );

  HostOperationService get _svc => ref.read(hostOperationServiceProvider);

  Future<void> _reload() async {
    ref.invalidate(mcmahonSectionProvider(_key));
    await ref.read(mcmahonSectionProvider(_key).future);
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

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

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
    final data = ref.read(mcmahonSectionProvider(_key)).value;
    final currentRound = _asInt(data?['currentRound']) ?? 0;
    if (currentRound < 1) {
      _toast('삭제할 라운드가 없습니다.');
      return;
    }
    final done = await HostCorrection.runDelete(
      context,
      title: '마지막 라운드 삭제',
      confirmMessage: '$currentRound라운드를 삭제하시겠습니까? 해당 라운드 대진·결과가 모두 지워집니다.',
      action: (pw) => _svc.deleteRound(widget.homepageId, widget.gameRoomId,
          kind: 'mcmahon', round: currentRound, password: pw),
    );
    if (done) {
      setState(() => _selectedRound = null);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(mcmahonSectionProvider(_key));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.sortName ?? '맥마흔 운영'),
        actions: [_correctionMenu()],
      ),
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
    final exists = data['exists'] == true;
    final currentRound = _asInt(data['currentRound']) ?? 0;
    final matches = (data['matches'] as List?) ?? const [];
    final rankings = (data['rankings'] as List?) ?? const [];

    if (!exists) {
      return _notStarted();
    }

    final round = _selectedRound ?? currentRound;
    final isCurrent = round == currentRound;
    final roundMatches = matches; // 서버가 요청 라운드(_key.round) 매치를 반환

    return Column(
      children: [
        _stateBar(round, roundMatches, isCurrent),
        _segments(),
        Expanded(
          child: _tab == 0
              ? _pairingsTab(currentRound, round, roundMatches)
              : _rankingsTab(rankings),
        ),
      ],
    );
  }

  // ── 시작 전 ──
  Widget _notStarted() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.flag_outlined, size: 56, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('아직 시작하지 않은 부문입니다',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('참가자 편성으로 1라운드를 시작하세요.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : () => _run(() => _svc.startMcmahon(widget.homepageId, widget.gameRoomId)),
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('1라운드 편성 시작'),
            ),
          ),
        ]),
      ),
    );
  }

  // ── 상태 바 (반상) ── displayRound = 지금 보고 있는 라운드(과거일 수 있음)
  Widget _stateBar(int displayRound, List roundMatches, bool isCurrent) {
    final done = roundMatches.where(_isCompleted).length;
    final total = roundMatches.length;
    final allDone = total > 0 && done == total;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.board, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$displayRound라운드',
              style: const TextStyle(color: Color(0xFF8FA0B4), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 5),
          Text('결과 $done/$total 입력됨',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 11),
          if (allDone && isCurrent)
            Row(children: [
              Expanded(
                child: _darkBtn('다음 라운드 편성', _busy ? null : () => _run(() => _svc.nextRoundMcmahon(widget.homepageId, widget.gameRoomId))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _darkBtn('순위 확정', _busy ? null : _confirmFinalize, outline: true),
              ),
            ])
          else
            Text('모든 탁자 결과를 입력하면 다음 라운드를 편성할 수 있어요.',
                style: TextStyle(color: const Color(0xFF8FA0B4), fontSize: 12)),
        ],
      ),
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
          child: Text(label,
              style: TextStyle(color: outline ? Colors.white : Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _segments() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        _seg('대진', 0),
        _seg('순위', 1),
      ]),
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
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: on ? AppColors.primary : AppColors.textSecondary)),
        ),
      ),
    );
  }

  // ── 대진 + 결과입력 탭 ──
  Widget _pairingsTab(int currentRound, int round, List roundMatches) {
    return Column(
      children: [
        if (currentRound > 1) _roundChips(currentRound, round),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: roundMatches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (_, i) => _matchCard(Map<String, dynamic>.from(roundMatches[i]), round == currentRound),
          ),
        ),
      ],
    );
  }

  Widget _roundChips(int currentRound, int round) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (int r = 1; r <= currentRound; r++) ...[
            GestureDetector(
              onTap: () => setState(() => _selectedRound = r),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(
                  color: r == round ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: r == round ? AppColors.primary : AppColors.border),
                ),
                child: Text('${r}R',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: r == round ? Colors.white : AppColors.textSecondary)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _matchCard(Map<String, dynamic> m, bool editable) {
    final matchId = _asInt(m['id']) ?? 0;
    final table = _asInt(m['tableNumber']);
    final p1Id = _asInt(m['player1Id']);
    final p2Id = _asInt(m['player2Id']);
    final p1 = _asStr(m['player1Name']);
    final p2 = _asStr(m['player2Name']);
    final winnerId = _asInt(m['winnerId']);
    final completed = _isCompleted(m);
    final isBye = p2Id == null;
    final isJigo = m['isJigo'] == true;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: completed ? const Color(0xFFF6FCF8) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: completed ? const Color(0xFFCDE9D8) : (editable ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(6)),
              child: Text(table != null ? '$table번' : '-',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary)),
            ),
            const Spacer(),
            if (isBye)
              _tag('부전승', AppColors.statusOpenText, AppColors.statusOpenBg)
            else if (completed)
              _tag(isJigo ? '비김' : '완료', AppColors.statusOpenText, AppColors.statusOpenBg)
            else
              _tag('미입력', AppColors.primaryDark, AppColors.surfaceVariant),
          ]),
          const SizedBox(height: 10),
          if (isBye)
            Row(children: [
              Expanded(child: Text('$p1 (부전승)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            ])
          else ...[
            // 완료된 매치도 현재 라운드(editable)면 승자를 다시 탭해 정정 가능.
            // (서버 updateMatchResult 가 기존 결과 롤백 후 재적용 → 덮어쓰기 지원)
            // 이미 승자인 버튼만 비활성(불필요한 재기록 방지), 상대/무는 눌러서 정정.
            Builder(builder: (_) {
              final w1 = winnerId != null && winnerId == p1Id;
              final w2 = winnerId != null && winnerId == p2Id;
              return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _winBtn(p1, isWinner: w1, completed: completed,
                    onTap: (editable && p1Id != null && !w1) ? () => _saveWinner(matchId, p1Id) : null),
                _vsMid(completed: completed, editable: editable, matchId: matchId, isJigo: isJigo),
                _winBtn(p2, isWinner: w2, completed: completed,
                    onTap: (editable && !w2) ? () => _saveWinner(matchId, p2Id) : null),
              ]);
            }),
            if (editable && completed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('승자(또는 무)를 다시 탭하면 결과가 정정됩니다.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _vsMid({required bool completed, required bool editable, required int matchId, bool isJigo = false}) {
    // 편집 가능하면(미입력/완료 무관) '무(비김)' 버튼. 이미 무로 기록됐으면 강조.
    // 과거 라운드(비편집)는 vs 표기.
    if (editable) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: GestureDetector(
          onTap: isJigo ? null : () => _saveWinner(matchId, null, jigo: true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isJigo ? AppColors.primary : null,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isJigo ? AppColors.primary : AppColors.border),
            ),
            child: Text('무', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isJigo ? Colors.white : AppColors.textTertiary)),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text('vs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textHint)),
    );
  }

  Widget _winBtn(String name, {required bool isWinner, required bool completed, VoidCallback? onTap}) {
    final Color bg = isWinner ? AppColors.primary : AppColors.surface;
    final Color fg = isWinner ? Colors.white : (completed ? AppColors.textHint : AppColors.textPrimary);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: isWinner ? AppColors.primary : AppColors.border),
          ),
          child: Text(name.isEmpty ? '-' : name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
        ),
      ),
    );
  }

  Future<void> _saveWinner(int matchId, int? winnerId, {bool jigo = false}) async {
    await _run(() => _svc.saveResult(widget.homepageId, widget.gameRoomId, matchId,
        winnerId: winnerId, isJigo: jigo));
  }

  // ── 순위 탭 ──
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
        final euro = r['europeanMode'] == true;
        final wins = _asInt(r['wins']) ?? 0;
        final losses = _asInt(r['losses']) ?? 0;
        final score = euro ? _asStr(r['displayGameScore']) : (_asInt(r['mcMahonScore'])?.toString() ?? '-');
        final sos = _fmtNum(r['sos']); // double 절삭 방지
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            SizedBox(
              width: 26,
              child: Text('${i + 1}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: i < 3 ? AppColors.primary : AppColors.textPrimary)),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_asStr(r['name']), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('$wins승 $losses패', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(score, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              if (sos != null) Text('SOS $sos', style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary)),
            ]),
          ]),
        );
      },
    );
  }

  // ── 순위 확정 ──
  Future<void> _confirmFinalize() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('순위 확정'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('확정하면 참가자에게 순위가 공개되고 레이팅에 반영됩니다.'),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '대회 비밀번호 (설정된 경우)'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('확정')),
        ],
      ),
    );
    if (ok != true) return;
    final pw = controller.text.trim();
    await _run(() => _svc.finalizeMcmahon(widget.homepageId, widget.gameRoomId,
        password: pw.isEmpty ? null : pw));
  }

  // ── helpers ──
  Widget _tag(String text, Color tx, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tx)),
      );

  bool _isCompleted(dynamic m) {
    final map = m is Map ? m : const {};
    final status = map['status']?.toString().toUpperCase() ?? '';
    return status == 'COMPLETED' || map['winnerId'] != null;
  }

  int? _asInt(dynamic v) => v == null ? null : (v is int ? v : int.tryParse(v.toString().split('.').first));
  String _asStr(dynamic v) => v?.toString() ?? '';

  /// 정수면 그대로, 소수면 소수 1자리로. SOS 등 double 값 절삭 방지.
  String? _fmtNum(dynamic v) {
    if (v == null) return null;
    final d = v is num ? v.toDouble() : double.tryParse(v.toString());
    if (d == null) return null;
    return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);
  }
}
