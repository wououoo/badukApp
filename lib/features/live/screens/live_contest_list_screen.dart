import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/live_contest.dart';
import '../../../data/services/live_contest_service.dart';

/// 라이브 대회 목록 (네이티브 내장)
/// - 웹 /live(LiveContestList)와 동일한 백엔드(/live/contests/paged)·동일 타입필터
/// - 표시(상태/유형/카운트)는 백엔드 계산값을 그대로 렌더, 프론트는 보여주기만
/// - 카드 탭 → 기존 LiveContestScreen(/live/:id)
class LiveContestListScreen extends StatefulWidget {
  const LiveContestListScreen({super.key});

  @override
  State<LiveContestListScreen> createState() => _LiveContestListScreenState();
}

class _LiveContestListScreenState extends State<LiveContestListScreen> {
  final LiveContestService _service = LiveContestService();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;  // 60초 자동 갱신 (웹 목록과 동일)

  static const int _pageSize = 10;
  final List<LiveContest> _contests = [];
  String _typeFilter = 'ALL';
  int _page = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  // 타입 필터 (웹 LiveContestList와 동일 목록)
  static const List<List<String>> _filters = [
    ['ALL', '전체'],
    ['SWISS', '스위스리그'],
    ['MCM', '맥마흔'],
    ['DE', '더블엘리'],
    ['TEAM_SWISS', '단체 스위스'],
    ['FULL_LEAGUE', '풀리그'],
    ['TEAM_FULL_LEAGUE', '단체 풀리그'],
    ['TOURNAMENT', '토너먼트'],
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 60), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 60초 자동 갱신 — 첫 페이지를 조용히(스피너 없이) 갱신.
  /// 깊게 스크롤한 상태면 위치가 튀지 않게 스킵.
  Future<void> _silentRefresh() async {
    if (!mounted || _isLoading || _isLoadingMore) return;
    // 첫 페이지로 리셋하므로, 살짝이라도 스크롤한 상태면 위치 점프 방지를 위해 스킵.
    if (_scrollController.hasClients &&
        _scrollController.position.pixels > 50) return;
    final requested = _typeFilter;
    try {
      final res = await _service.getLiveContestsPaged(
          type: requested, page: 0, size: _pageSize);
      if (!mounted || requested != _typeFilter) return;
      setState(() {
        _contests
          ..clear()
          ..addAll(res.content);
        _page = 0;
        _hasMore = !res.last;
      });
    } catch (_) {
      // 자동 갱신 실패는 조용히 무시
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    final requested = _typeFilter; // 응답 도착 시점에 필터가 바뀌었는지 검증용
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _error = null;
      _page = 0;
      _contests.clear();
      _hasMore = true;
    });
    try {
      final res = await _service.getLiveContestsPaged(
          type: requested, page: 0, size: _pageSize);
      // 늦게 도착한 응답이 더 최신 필터 목록을 덮어쓰지 않도록 가드
      if (!mounted || requested != _typeFilter) return;
      setState(() {
        _contests.addAll(res.content);
        _hasMore = !res.last;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || requested != _typeFilter) return;
      setState(() {
        _error = '대회 목록을 불러올 수 없습니다';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final requested = _typeFilter;
    setState(() => _isLoadingMore = true);
    try {
      final next = _page + 1;
      final res = await _service.getLiveContestsPaged(
          type: requested, page: next, size: _pageSize);
      if (!mounted || requested != _typeFilter) return;
      setState(() {
        _page = next;
        _contests.addAll(res.content);
        _hasMore = !res.last;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || requested != _typeFilter) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _onFilterChanged(String type) {
    if (type == _typeFilter) return;
    setState(() => _typeFilter = type);
    _loadInitial();
  }

  String _typeLabel(String? type) {
    switch (type?.toUpperCase()) {
      case 'SWISS':
        return '스위스리그';
      case 'MCM':
        return '맥마흔';
      case 'DE':
        return '더블엘리미네이션';
      case 'TEAM_SWISS':
        return '단체전 스위스';
      case 'FULL_LEAGUE':
        return '풀리그';
      case 'TEAM_FULL_LEAGUE':
        return '단체전 풀리그';
      case 'TOURNAMENT':
        return '토너먼트';
      default:
        return type ?? '스위스리그';
    }
  }

  String _fmt(DateTime? d) => d == null ? '-' : DateFormat('yyyy.MM.dd').format(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        title: const Text('라이브', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: _filters.map((f) {
            final selected = _typeFilter == f[0];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _onFilterChanged(f[0]),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    f[1],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.textOnPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadInitial, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (_contests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadInitial,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(Icons.live_tv_outlined,
                size: 56, color: AppColors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 12),
            Center(
              child: Text('진행 중인 라이브 대회가 없습니다',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: _contests.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _contests.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            );
          }
          return _buildContestCard(_contests[index]);
        },
      ),
    );
  }

  Widget _buildContestCard(LiveContest c) {
    // 상태 색 (백엔드 status: 진행중/예정/종료)
    Color stBg, stText;
    switch (c.status) {
      case '진행중':
        stBg = AppColors.statusLiveBg;
        stText = AppColors.statusLiveText;
        break;
      case '예정':
        stBg = AppColors.statusSoonBg;
        stText = AppColors.statusSoonText;
        break;
      default:
        stBg = AppColors.statusClosedBg;
        stText = AppColors.statusClosedText;
    }

    final typeList = c.types.isNotEmpty
        ? c.types
        : (c.type != null ? [c.type!] : <String>[]);

    return GestureDetector(
      onTap: () => context.push('/live/${c.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상태 + 유형 배지
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    c.status ?? '-',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: stText),
                  ),
                ),
                ...typeList.map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _typeLabel(t),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary),
                      ),
                    )),
              ],
            ),
            const SizedBox(height: 10),
            // 대회명
            Text(
              c.name,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            // 정보
            _infoRow('장소', _locationText(c)),
            _infoRow('일시', _dateText(c)),
            _infoRow('부문', '${c.sortCount ?? c.sorts.length}개'),
            _infoRow('참가자', '${c.totalParticipants ?? 0}명'),
            // 연결된(묶은) 대회 — 웹 목록과 동일
            if (c.linkedContests.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('연결된 대회',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    ...c.linkedContests.map((lc) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            lc.types.isNotEmpty
                                ? '${lc.contestName} (${lc.types.map(_typeLabel).join(', ')})'
                                : lc.contestName,
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textPrimary),
                          ),
                        )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _locationText(LiveContest c) {
    final parts = <String>[];
    if (c.contestProv != null && c.contestProv!.isNotEmpty) {
      parts.add(c.contestProv!);
    }
    if (c.location != null && c.location!.isNotEmpty) parts.add(c.location!);
    if (c.contestDetailLocation != null &&
        c.contestDetailLocation!.isNotEmpty) {
      parts.add(c.contestDetailLocation!);
    }
    return parts.isEmpty ? '-' : parts.join(' ');
  }

  String _dateText(LiveContest c) {
    if (c.startDate == null) return '-';
    final s = _fmt(c.startDate);
    if (c.endDate != null && c.endDate != c.startDate) {
      return '$s ~ ${_fmt(c.endDate)}';
    }
    return s;
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(label,
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
