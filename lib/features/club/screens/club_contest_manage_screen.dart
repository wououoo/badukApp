import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/club_contest_service.dart';
import '../widgets/contest_participants_tab.dart';
import '../widgets/contest_pairings_tab.dart';
import '../widgets/contest_rankings_tab.dart';
import '../widgets/contest_section_dialogs.dart';

/// 클럽 대회 운영 핵심 화면
/// 다중 부문 지원: 부문 선택 + 탭 3개(참가자/대진표/순위)
class ClubContestManageScreen extends StatefulWidget {
  final int clubId;
  final int contestId;

  const ClubContestManageScreen({
    super.key,
    required this.clubId,
    required this.contestId,
  });

  @override
  State<ClubContestManageScreen> createState() => _ClubContestManageScreenState();
}

class _ClubContestManageScreenState extends State<ClubContestManageScreen> {
  final ClubContestService _service = ClubContestService();

  // 대회 상세
  Map<String, dynamic>? _contestDetail;
  bool _isLoading = true;
  String? _error;

  // 부문 목록
  List<Map<String, dynamic>> _sections = [];
  int _selectedSectionIndex = 0;

  // 탭 상태
  int _selectedTabIndex = 0;

  // 현재 선택된 부문의 데이터
  List<Map<String, dynamic>> _participants = [];
  List<Map<String, dynamic>> _allPairings = [];
  int _maxRound = 0;
  List<Map<String, dynamic>> _rankings = [];
  String _rankingSortBy = 'wins'; // 맥마흔 순위 정렬 기준

  // 단체전 팀 데이터
  List<Map<String, dynamic>> _teams = [];

  // 대진표: 팀 대진 여부 및 팀 인원수
  bool _isTeamPairings = false;
  int _teamSize = 0;

  // DE 본선 토너먼트
  bool _hasTournament = false;
  List<Map<String, dynamic>> _tournamentPairings = [];
  int _tournamentMaxRound = 0;

  bool get _isFinished => _contestDetail?['isFinished'] == true;
  bool get _isRated => _contestDetail?['rated'] != false;
  int get _currentSortId {
    if (_sections.isEmpty) return 0;
    final v = _sections[_selectedSectionIndex]['sortId'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }
  String get _currentType {
    if (_sections.isEmpty) return '스위스리그';
    return (_sections[_selectedSectionIndex]['type']?.toString()) ?? '스위스리그';
  }
  bool get _isTeamContest => _currentType.contains('단체전');
  int get _currentTeamSize {
    if (_sections.isEmpty) return 0;
    final v = _sections[_selectedSectionIndex]['teamSize'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  List<Map<String, dynamic>> _safeListCast(dynamic list) {
    if (list == null) return [];
    if (list is! List) return [];
    return list.map((e) {
      if (e is Map) return Map<String, dynamic>.from(e);
      return <String, dynamic>{};
    }).toList();
  }

  bool _isRefreshing = false;

  Future<void> _loadAll() async {
    if (!mounted) return;
    if (_isRefreshing) return;
    _isRefreshing = true;

    final showLoading = _contestDetail == null;
    if (showLoading) {
      setState(() { _isLoading = true; _error = null; });
    }

    try {
      final detail = await _service.getContestDetail(widget.clubId, widget.contestId);
      final sections = _safeListCast(detail['sections']);

      _contestDetail = detail;
      _sections = sections;
      if (_selectedSectionIndex >= _sections.length) {
        _selectedSectionIndex = _sections.isEmpty ? 0 : _sections.length - 1;
      }

      if (_sections.isNotEmpty) {
        await _loadSectionDataSilent();
      } else {
        _participants = [];
        _teams = [];
        _allPairings = [];
        _maxRound = 0;
        _rankings = [];
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _loadSectionDataSilent() async {
    if (_sections.isEmpty) {
      _participants = []; _teams = []; _allPairings = [];
      _maxRound = 0; _rankings = [];
      return;
    }

    final sortId = _currentSortId;
    List<Map<String, dynamic>> participants = [];
    List<Map<String, dynamic>> teams = [];
    List<Map<String, dynamic>> pairings = [];
    int maxRound = 0;
    List<Map<String, dynamic>> rankings = [];
    bool isTeamPairings = false;
    int teamSizeFromApi = 0;

    if (_isTeamContest) {
      try { final d = await _service.getTeams(widget.clubId, widget.contestId, sortId); teams = _safeListCast(d['teams']); } catch (_) {}
    } else {
      try { final d = await _service.getParticipants(widget.clubId, widget.contestId, sortId); participants = _safeListCast(d['participants']); } catch (_) {}
    }

    try {
      final d = await _service.getAllPairings(widget.clubId, widget.contestId, sortId);
      pairings = _safeListCast(d['pairings']);
      final mr = d['maxRound'];
      maxRound = (mr is int) ? mr : (mr is num ? mr.toInt() : 0);
      isTeamPairings = d['isTeam'] == true;
      teamSizeFromApi = (d['teamSize'] is num) ? (d['teamSize'] as num).toInt() : 0;
      if (d['hasTournament'] == true) {
        _hasTournament = true;
        _tournamentPairings = _safeListCast(d['tournamentPairings']);
        _tournamentMaxRound = (d['tournamentMaxRound'] is num) ? (d['tournamentMaxRound'] as num).toInt() : 0;
      } else {
        _hasTournament = false; _tournamentPairings = []; _tournamentMaxRound = 0;
      }
    } catch (_) {}

    try { final d = await _service.getRankings(widget.clubId, widget.contestId, sortId, sortBy: _rankingSortBy); rankings = _safeListCast(d['rankings']); } catch (_) {}

    _participants = participants;
    _teams = teams;
    _allPairings = pairings;
    _maxRound = maxRound;
    _rankings = rankings;
    _isTeamPairings = isTeamPairings;
    _teamSize = teamSizeFromApi;
  }

  void _onSectionChanged(int index) {
    if (index == _selectedSectionIndex) return;
    setState(() {
      _selectedSectionIndex = index;
      _isLoading = true;
    });
    _loadSectionDataSilent().then((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  // ==================== Actions ====================

  Future<void> _generateRound() async {
    String matchingType = 'default';
    bool avoidClub = false;

    if (_currentType == '맥마흔') {
      // 맥마흔은 무조건 MWPM (최적 매칭) 방식 사용
      matchingType = 'mwpm';
    }

    try {
      final result = await _service.generateRound(
        widget.clubId, widget.contestId, _currentSortId,
        matchingType: matchingType, avoidClub: avoidClub,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '대진표가 생성되었습니다.')),
        );
        await _loadAll();
      } else {
        // 실패 시 다이얼로그로 명확하게 안내
        _showGenerateFailDialog(result['message']?.toString() ?? '대진 생성에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('[Error] 대진 생성 오류: $e');
      if (mounted) {
        _showGenerateFailDialog('오류가 발생했습니다. 다시 시도해주세요.');
      }
    }
  }

  void _showGenerateFailDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('대진 생성 실패', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRound() async {
    if (_maxRound <= 0) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('라운드 삭제'),
        content: Text('$_maxRound 라운드를 삭제하시겠습니까?'),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('취소'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('삭제', style: TextStyle(color: Colors.white)))),
          ]),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final result = await _service.deleteRound(widget.clubId, widget.contestId, _currentSortId, _maxRound);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? (result['success'] == true ? '라운드가 삭제되었습니다.' : '삭제 실패'))));
      if (result['success'] == true) _loadAll();
    } catch (e) {
      if (mounted) { debugPrint('[Error] 오류: $e'); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.'))); }
    }
  }

  Future<void> _unfinishContest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('대회 종료 취소'),
        content: Text(_isRated ? '대회 종료를 취소하고 레이팅을 이전 상태로 복원하시겠습니까?' : '대회 종료를 취소하시겠습니까?'),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('취소'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('종료 취소', style: TextStyle(color: Colors.white)))),
          ]),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final result = await _service.unfinishContest(widget.clubId, widget.contestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? '대회 종료 취소')));
      _loadAll();
    } catch (e) {
      if (mounted) { debugPrint('[Error] 오류: $e'); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.'))); }
    }
  }

  Future<void> _finishContest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('대회 종료'),
        content: Text(_isRated ? '대회를 종료하고 Elo 레이팅을 반영하시겠습니까?' : '대회를 종료하시겠습니까? (레이팅 변동 없음)'),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('취소'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.clubPrimary, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('종료', style: TextStyle(color: Colors.white)))),
          ]),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final result = await _service.finishContest(widget.clubId, widget.contestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? '대회 종료')));
      _loadAll();
    } catch (e) {
      if (mounted) { debugPrint('[Error] 오류: $e'); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.'))); }
    }
  }

  void _showAddGuestDialog() {
    final nameController = TextEditingController();
    final rankNumberController = TextEditingController();
    bool isDan = true;
    final isMcMahon = _currentType == '맥마흔';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('게스트 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '이름',
                  hintText: '게스트 참가자 이름',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  counterText: '',
                ),
                maxLength: 30,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: rankNumberController,
                      decoration: InputDecoration(
                        labelText: isMcMahon ? '단수 *' : '단수',
                        hintText: isDan ? '1~9' : '1~30',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => setDialogState(() => isDan = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDan ? AppColors.clubPrimary : Colors.transparent,
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                            ),
                            child: Text('단', style: TextStyle(color: isDan ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setDialogState(() => isDan = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: !isDan ? AppColors.clubPrimary : Colors.transparent,
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                            ),
                            child: Text('급', style: TextStyle(color: !isDan ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          actions: [
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    int? level;
                    final rankText = rankNumberController.text.trim();
                    if (rankText.isNotEmpty) {
                      final rankNum = int.tryParse(rankText);
                      if (rankNum == null || rankNum < 1 || (isDan && rankNum > 9) || (!isDan && rankNum > 30)) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(isDan ? '단수는 1~9 사이로 입력해주세요.' : '급수는 1~30 사이로 입력해주세요.')));
                        return;
                      }
                      level = isDan ? (19 - rankNum) : (18 + rankNum);
                    } else if (isMcMahon) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('맥마흔 대회는 단수를 반드시 입력해주세요.')));
                      return;
                    }

                    Navigator.pop(ctx);
                    try {
                      final result = await _service.addGuestParticipant(widget.clubId, widget.contestId, _currentSortId, name, level: level);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['success'] == true ? '${result['name']} 게스트가 추가되었습니다.' : (result['message'] ?? '추가 실패'))));
                      if (result['success'] == true) _loadAll();
                    } catch (e) {
                      if (mounted) { debugPrint('[Error] 오류: $e'); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.'))); }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.clubPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('추가'),
                ),
              ),
            ]),
          ],
        ),
      ),
    ).then((_) {
      nameController.dispose();
      rankNumberController.dispose();
    });
  }

  void _showAddTeamDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('팀 추가'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: '팀 이름', hintText: '예: A팀', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          maxLength: 30,
          autofocus: true,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('취소'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final result = await _service.addTeam(widget.clubId, widget.contestId, _currentSortId, name);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['success'] == true ? '팀이 추가되었습니다.' : (result['message'] ?? '추가 실패'))));
                  if (result['success'] == true) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _loadAll(); });
                } catch (e) {
                  if (mounted) { debugPrint('[Error] 오류: $e'); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.'))); }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.clubPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('추가'),
            )),
          ]),
        ],
      ),
    ).then((_) => nameController.dispose());
  }

  // ==================== 맥마흔 설정 ====================

  Future<void> _showMcMahonConfigSheet() async {
    // 설정 로드
    Map<String, dynamic>? config;
    try {
      config = await _service.getMcMahonConfig(widget.clubId, widget.contestId, _currentSortId);
      if (config['success'] != true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(config['message'] ?? '설정 조회 실패')));
        return;
      }
    } catch (e) {
      if (mounted) { debugPrint('[Error] 오류: $e'); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.'))); }
      return;
    }

    if (!mounted) return;

    int kFactor = (config['kFactor'] is num) ? (config['kFactor'] as num).toInt() : 70;
    bool europeanMode = config['europeanMode'] == true;
    int? upperBarLevel = (config['upperBarLevel'] is num) ? (config['upperBarLevel'] as num).toInt() : null;
    int? lowerBarLevel = (config['lowerBarLevel'] is num) ? (config['lowerBarLevel'] as num).toInt() : null;

    String _levelToLabel(int level) {
      if (level <= 18) return '${19 - level}단';
      return '${level - 18}급';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  const Text('맥마흔 설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),

                  // K팩터
                  Row(
                    children: [
                      const Text('K팩터', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('$kFactor', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.clubPrimary)),
                    ],
                  ),
                  Slider(
                    value: kFactor.toDouble(),
                    min: 20, max: 100,
                    divisions: 8,
                    activeColor: AppColors.clubPrimary,
                    label: '$kFactor',
                    onChanged: (v) => setSheetState(() => kFactor = v.round()),
                  ),
                  const SizedBox(height: 12),

                  // 유럽식 모드
                  Row(
                    children: [
                      const Text('유럽식 모드', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Switch(
                        value: europeanMode,
                        activeColor: AppColors.clubPrimary,
                        onChanged: (v) => setSheetState(() => europeanMode = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 상한 바
                  Row(
                    children: [
                      const Text('상한 바', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      DropdownButton<int?>(
                        value: upperBarLevel,
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('없음', style: TextStyle(fontSize: 14))),
                          for (int i = 10; i <= 18; i++)
                            DropdownMenuItem(value: i, child: Text(_levelToLabel(i), style: const TextStyle(fontSize: 14))),
                        ],
                        onChanged: (v) => setSheetState(() => upperBarLevel = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 하한 바
                  Row(
                    children: [
                      const Text('하한 바', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      DropdownButton<int?>(
                        value: lowerBarLevel,
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('없음', style: TextStyle(fontSize: 14))),
                          for (int i = 10; i <= 48; i++)
                            DropdownMenuItem(value: i, child: Text(_levelToLabel(i), style: const TextStyle(fontSize: 14))),
                        ],
                        onChanged: (v) => setSheetState(() => lowerBarLevel = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 저장 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          final result = await _service.updateMcMahonConfig(widget.clubId, widget.contestId, _currentSortId, {
                            'kFactor': kFactor,
                            'europeanMode': europeanMode,
                            'upperBarLevel': upperBarLevel,
                            'lowerBarLevel': lowerBarLevel,
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? '저장 완료')));
                          }
                        } catch (e) {
                          if (mounted) { debugPrint('[Error] 오류: $e'); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.'))); }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.clubPrimary, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0,
                      ),
                      child: const Text('저장', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_contestDetail?['contestName'] ?? '대회 관리'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'edit': ContestSectionDialogs.showEditContestDialog(context, widget.clubId, widget.contestId, _contestDetail?['contestName'] ?? '', _loadAll); break;
                case 'addSection': ContestSectionDialogs.showAddSectionDialog(context, widget.clubId, widget.contestId, _loadAll); break;
                case 'editSection': if (_sections.isNotEmpty) ContestSectionDialogs.showEditSectionDialog(context, widget.clubId, widget.contestId, _currentSortId, _sections[_selectedSectionIndex], _loadAll); break;
                case 'deleteSection': if (_sections.isNotEmpty) {
                  final deleteSortId = _currentSortId;
                  final deleteName = _sections[_selectedSectionIndex]['name'] ?? '';
                  ContestSectionDialogs.deleteCurrentSection(context, widget.clubId, widget.contestId, deleteSortId, deleteName, () async {
                    await _loadAll();
                    if (mounted) {
                      setState(() {
                        if (_selectedSectionIndex >= _sections.length) {
                          _selectedSectionIndex = _sections.isEmpty ? 0 : _sections.length - 1;
                        }
                      });
                    }
                  });
                } break;
                case 'finish': _finishContest(); break;
                case 'unfinish': _unfinishContest(); break;
              }
            },
            itemBuilder: (_) => [
              if (!_isFinished) ...[
                const PopupMenuItem(value: 'edit', child: Text('대회 수정')),
                const PopupMenuItem(value: 'addSection', child: Text('부문 추가')),
                if (_sections.isNotEmpty) const PopupMenuItem(value: 'editSection', child: Text('현재 부문 수정')),
                if (_sections.length > 1) const PopupMenuItem(value: 'deleteSection', child: Text('현재 부문 삭제')),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'finish', child: Text(_isRated ? '대회 종료 + 레이팅 반영' : '대회 종료')),
              ],
              if (_isFinished)
                const PopupMenuItem(value: 'unfinish', child: Text('대회 종료 취소', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_error!, style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        TextButton(onPressed: _loadAll, child: const Text('다시 시도')),
      ]));
    }
    if (_sections.isEmpty) return _buildEmptySections();

    return Column(
      children: [
        if (_isFinished)
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8),
            color: AppColors.success.withOpacity(0.1),
            child: Text(_isRated ? '대회 종료됨 (레이팅 반영 완료)' : '대회 종료됨 (친선 대회)', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success)),
          ),
        if (_sections.length > 1) _buildSectionSelector(),
        // Info bar
        Container(
          width: double.infinity, padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), color: AppColors.surface,
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _currentType == '풀리그' ? Colors.orange.withOpacity(0.1) : AppColors.clubPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(_currentType, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _currentType == '풀리그' ? Colors.orange : AppColors.clubPrimary)),
            ),
            const SizedBox(width: 8),
            Text(_isTeamContest ? '${_teams.length}팀${_currentTeamSize > 0 ? ' · $_currentTeamSize장제' : ''}' : '참가자 ${_participants.length}명', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (_maxRound > 0) ...[SizedBox(width: 8), Text('$_maxRound R 진행', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))],
            const Spacer(),
            if (_currentType == '맥마흔' && !_isFinished)
              GestureDetector(
                onTap: _showMcMahonConfigSheet,
                child: Icon(Icons.settings, size: 20, color: AppColors.textSecondary),
              ),
          ]),
        ),
        // Tab bar
        Material(
          color: AppColors.surface,
          child: Row(children: [
            _buildTab(0, _isTeamContest ? '팀 (${_teams.length})' : '참가자 (${_participants.length})'),
            _buildTab(1, '대진표 ($_maxRound R)'),
            _buildTab(2, '순위'),
          ]),
        ),
        // Add buttons (fixed area)
        if (_selectedTabIndex == 0 && !_isFinished && _maxRound == 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: _isTeamContest ? _buildAddTeamButton() : _buildAddParticipantButtons(),
          ),
        // Pairing action buttons (fixed area)
        if (_selectedTabIndex == 1 && !_isFinished) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generateRound,
                icon: const Icon(Icons.shuffle, size: 18),
                label: Text(_currentType == '풀리그' ? (_maxRound == 0 ? '전체 라운드 생성' : '라운드 재생성') : (_maxRound == 0 ? '1R 대진 생성' : '${_maxRound + 1}R 대진 생성')),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.clubPrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
              ),
            ),
          ),
          if (_maxRound > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _deleteRound,
                  icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                  label: Text('${_maxRound}R 삭제', style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), minimumSize: const Size(0, 40)),
                ),
              ),
            ),
        ],
        // Tab content with IndexedStack to preserve state
        Expanded(
          child: IndexedStack(
            index: _selectedTabIndex,
            children: [
              ContestParticipantsTab(
                clubId: widget.clubId,
                contestId: widget.contestId,
                sortId: _currentSortId,
                isTeamContest: _isTeamContest,
                isFinished: _isFinished,
                maxRound: _maxRound,
                teamSize: _currentTeamSize,
                gameType: _currentType,
                participants: _participants,
                teams: _teams,
                onReload: _loadAll,
              ),
              ContestPairingsTab(
                key: ValueKey('pairings_${_currentSortId}_$_maxRound'),
                clubId: widget.clubId,
                contestId: widget.contestId,
                sortId: _currentSortId,
                currentType: _currentType,
                isFinished: _isFinished,
                maxRound: _maxRound,
                isTeamPairings: _isTeamPairings,
                teamSize: _currentTeamSize > 0 ? _currentTeamSize : _teamSize,
                allPairings: _allPairings,
                hasTournament: _hasTournament,
                tournamentPairings: _tournamentPairings,
                tournamentMaxRound: _tournamentMaxRound,
                onReload: _loadAll,
              ),
              ContestRankingsTab(
                rankings: _rankings,
                isTeamContest: _isTeamContest,
                currentType: _currentType,
                teamSize: _currentTeamSize > 0 ? _currentTeamSize : _teamSize,
                sortBy: _rankingSortBy,
                onSortByChanged: (value) {
                  setState(() { _rankingSortBy = value; });
                  _loadSectionDataSilent().then((_) { if (mounted) setState(() {}); });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isSelected ? AppColors.clubPrimary : Colors.transparent, width: 2))),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: isSelected ? AppColors.clubPrimary : AppColors.textTertiary)),
        ),
      ),
    );
  }

  Widget _buildEmptySections() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.category_outlined, size: 48, color: AppColors.textTertiary),
      const SizedBox(height: 12),
      Text('부문이 없습니다', style: TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 12),
      if (!_isFinished)
        ElevatedButton.icon(
          onPressed: () => ContestSectionDialogs.showAddSectionDialog(context, widget.clubId, widget.contestId, _loadAll),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('부문 추가'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.clubPrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
        ),
    ]));
  }

  Widget _buildSectionSelector() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _sections.length,
          itemBuilder: (context, index) {
            final section = _sections[index];
            final isSelected = index == _selectedSectionIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(section['name'] as String? ?? ''),
                selected: isSelected,
                selectedColor: AppColors.clubPrimary,
                labelStyle: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: isSelected ? Colors.white : AppColors.textPrimary),
                onSelected: (selected) { if (selected) _onSectionChanged(index); },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAddTeamButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showAddTeamDialog,
        icon: const Icon(Icons.group_add, size: 16),
        label: const Text('팀 추가', style: TextStyle(fontSize: 13)),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.clubPrimary, foregroundColor: Colors.white, minimumSize: const Size(0, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
      ),
    );
  }

  Widget _buildAddParticipantButtons() {
    return Row(children: [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () {
            context.push('/clubs/${widget.clubId}/contests/${widget.contestId}/select-participants?sortId=$_currentSortId&gameType=${Uri.encodeComponent(_currentType)}').then((result) { if (result == true) _loadAll(); });
          },
          icon: const Icon(Icons.person_add, size: 16),
          label: const Text('멤버 추가', style: TextStyle(fontSize: 13)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.clubPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 40), tapTargetSize: MaterialTapTargetSize.shrinkWrap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
        ),
      ),
      const SizedBox(width: 8),
      ElevatedButton.icon(
        onPressed: _showAddGuestDialog,
        icon: const Icon(Icons.person_outline, size: 16),
        label: const Text('게스트', style: TextStyle(fontSize: 13)),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.surface, foregroundColor: AppColors.textPrimary, padding: EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 40), tapTargetSize: MaterialTapTargetSize.shrinkWrap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)), elevation: 0),
      ),
    ]);
  }
}
