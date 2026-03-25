import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/contest.dart';
import '../../../data/providers/contest_provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/services/location_service.dart';
import '../widgets/contest_card.dart';
import '../widgets/contest_poster_card.dart';
import '../widgets/contest_filter_chips.dart';
import '../../../core/widgets/shimmer_loading.dart';

/// 대회 목록 화면 (런너블 스타일)
class ContestListScreen extends ConsumerStatefulWidget {
  const ContestListScreen({super.key});

  @override
  ConsumerState<ContestListScreen> createState() => _ContestListScreenState();
}

class _ContestListScreenState extends ConsumerState<ContestListScreen> {
  String _selectedFilter = 'ALL';
  String _searchQuery = '';
  bool _posterMode = true;
  final _searchController = TextEditingController();

  // 내 근처 필터 상태
  List<Map<String, dynamic>> _nearbyContests = [];
  bool _nearbyLoading = false;
  String? _nearbyError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contestListProvider.notifier).loadContests(type: 'ALL', refresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userName = authState.user?.name ?? '회원';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            _buildHeader(userName),
            // 검색바
            _buildSearchBar(),
            // 필터 칩 + 뷰 모드 토글
            const SizedBox(height: 12),
            _buildFilterRow(),
            const SizedBox(height: 16),
            // 대회 목록
            Expanded(
              child: _buildContestGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String userName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '안녕하세요, $userName님',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '오늘의 대회 소식을 확인하세요',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          // 알림 버튼
          Semantics(
            label: '알림',
            button: true,
            child: IconButton(
              onPressed: () => context.push('/notifications'),
              tooltip: '알림',
              icon: Icon(
                Icons.notifications_outlined,
                color: AppColors.textPrimary,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: '대회명으로 검색',
          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: AppColors.textTertiary, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: AppColors.textTertiary, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }

  /// 필터 칩 + 뷰모드 토글 버튼
  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        children: [
          // 필터 칩 (가로 스크롤)
          Expanded(
            child: ContestFilterChips(
              selectedFilter: _selectedFilter,
              onFilterChanged: (filter) {
                setState(() => _selectedFilter = filter);
                if (filter == 'NEARBY') {
                  _loadNearbyContests();
                } else {
                  ref.read(contestListProvider.notifier).loadContests(
                    type: filter,
                    refresh: true,
                  );
                }
              },
            ),
          ),
          // 뷰 모드 토글
          Semantics(
            label: _posterMode ? '리스트 보기로 전환' : '포스터 보기로 전환',
            button: true,
            child: GestureDetector(
              onTap: () => setState(() => _posterMode = !_posterMode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _posterMode
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _posterMode ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Icon(
                  _posterMode ? Icons.view_agenda_outlined : Icons.photo_library_outlined,
                  size: 20,
                  color: _posterMode ? AppColors.primary : AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadNearbyContests() async {
    setState(() {
      _nearbyLoading = true;
      _nearbyError = null;
    });
    try {
      final position = await LocationService.instance.getCurrentPosition();
      if (position == null) {
        setState(() {
          _nearbyError = '위치 권한을 허용해주세요';
          _nearbyLoading = false;
        });
        return;
      }
      final results = await LocationService.instance.getNearbyContests(
        lat: position.latitude,
        lng: position.longitude,
      );
      setState(() {
        _nearbyContests = results;
        _nearbyLoading = false;
      });
    } catch (e) {
      setState(() {
        _nearbyError = '근처 대회를 불러오지 못했습니다';
        _nearbyLoading = false;
      });
    }
  }

  Widget _buildNearbyList() {
    if (_nearbyLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_nearbyError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(_nearbyError!, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadNearbyContests,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    if (_nearbyContests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_searching, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text('반경 50km 이내 대회가 없습니다', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadNearbyContests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _nearbyContests.length,
        itemBuilder: (context, index) {
          final c = _nearbyContests[index];
          final distance = c['distance'] as num?;
          final distanceText = distance != null
              ? LocationService.instance.formatDistance(distance.toDouble())
              : '';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/contest/${c['homepageId']}'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['title'] ?? '',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (c['venue'] != null)
                            Text(
                              c['venue'],
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (c['contestStatus'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                c['contestStatus'],
                                style: TextStyle(fontSize: 12, color: AppColors.primary),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        Icon(Icons.near_me, size: 20, color: AppColors.primary),
                        const SizedBox(height: 4),
                        Text(
                          distanceText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContestGrid() {
    // 내 근처 필터는 별도 처리
    if (_selectedFilter == 'NEARBY') {
      return _buildNearbyList();
    }

    final state = ref.watch(contestListProvider);

    if (state.isLoading && state.contests.isEmpty) {
      return SkeletonBuilders.contestGrid();
    }

    if (state.error != null && state.contests.isEmpty) {
      return _buildErrorState();
    }

    if (state.contests.isEmpty) {
      return _buildEmptyState();
    }

    // 검색어로 필터링
    final filtered = _searchQuery.isEmpty
        ? state.contests
        : state.contests.where((c) =>
            c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              "'$_searchQuery' 검색 결과가 없습니다",
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(contestListProvider.notifier).refresh(),
      color: AppColors.primary,
      child: _posterMode
          ? _buildPosterGrid(filtered)
          : _buildInfoGrid(filtered),
    );
  }

  /// 기본 정보 모드 (기존 2열 카드)
  Widget _buildInfoGrid(List<Contest> contests) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: contests.length,
      itemBuilder: (context, index) {
        final contest = contests[index];
        return ContestCard(
          contest: contest,
          onTap: () => context.push('/contest/${contest.id}'),
        );
      },
    );
  }

  /// 포스터 모드 (2열 포스터 카드)
  Widget _buildPosterGrid(List<Contest> contests) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.65,
      ),
      itemCount: contests.length,
      itemBuilder: (context, index) {
        final contest = contests[index];
        return ContestPosterCard(
          contest: contest,
          onTap: () => context.push('/contest/${contest.id}'),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              '데이터를 불러올 수 없습니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '네트워크 연결을 확인해주세요',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => ref.read(contestListProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              '등록된 대회가 없습니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '새로운 대회가 곧 등록될 예정입니다',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
