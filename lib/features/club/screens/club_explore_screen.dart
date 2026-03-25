import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/club.dart';
import '../../../data/services/club_service.dart';

/// 클럽 탐색 화면
class ClubExploreScreen extends StatefulWidget {
  const ClubExploreScreen({super.key});

  @override
  State<ClubExploreScreen> createState() => _ClubExploreScreenState();
}

class _ClubExploreScreenState extends State<ClubExploreScreen> {
  final ClubService _clubService = ClubService();
  final TextEditingController _searchController = TextEditingController();

  static const _regions = [
    '서울특별시', '부산광역시', '대구광역시', '인천광역시', '광주광역시',
    '대전광역시', '울산광역시', '세종특별자치시',
    '경기도', '강원특별자치도', '충청북도', '충청남도',
    '전북특별자치도', '전라남도', '경상북도', '경상남도', '제주특별자치도',
  ];

  String? _selectedRegion; // null = 전체
  bool _sortByMembers = true; // true = 인원순, false = 최신순
  List<ClubSummary> _clubs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClubs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClubs() async {
    setState(() => _isLoading = true);
    try {
      final keyword = _searchController.text.trim().isEmpty ? null : _searchController.text.trim();
      final clubs = await _clubService.searchClubs(region: _selectedRegion, keyword: keyword);
      // Client-side sort
      if (_sortByMembers) {
        clubs.sort((a, b) => b.memberCount.compareTo(a.memberCount));
      }
      setState(() {
        _clubs = clubs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showRegionPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('지역 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      title: const Text('전체'),
                      trailing: _selectedRegion == null
                          ? const Icon(Icons.check, color: AppColors.clubPrimary)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedRegion = null);
                        _loadClubs();
                      },
                    ),
                    ..._regions.map((r) => ListTile(
                      title: Text(r),
                      trailing: _selectedRegion == r
                          ? const Icon(Icons.check, color: AppColors.clubPrimary)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedRegion = r);
                        _loadClubs();
                      },
                    )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('클럽 탐색'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search & filter area
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '클럽 이름 검색',
                    hintStyle: TextStyle(color: AppColors.textHint),
                    prefixIcon: Icon(Icons.search, color: AppColors.textTertiary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _loadClubs();
                            },
                            icon: const Icon(Icons.clear, size: 18),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (_) => _loadClubs(),
                ),
                const SizedBox(height: 10),
                // Region dropdown chip + sort toggle
                Row(
                  children: [
                    // Region dropdown chip
                    InkWell(
                      onTap: _showRegionPicker,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _selectedRegion != null
                              ? AppColors.clubPrimary.withOpacity(0.1)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectedRegion != null
                                ? AppColors.clubPrimary
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: _selectedRegion != null
                                  ? AppColors.clubPrimary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _selectedRegion ?? '전체 지역',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _selectedRegion != null
                                    ? AppColors.clubPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: _selectedRegion != null
                                  ? AppColors.clubPrimary
                                  : AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sort toggle chips
                    _buildSortChip('인원순', _sortByMembers, () {
                      setState(() => _sortByMembers = true);
                      _loadClubs();
                    }),
                    const SizedBox(width: 6),
                    _buildSortChip('최신순', !_sortByMembers, () {
                      setState(() => _sortByMembers = false);
                      _loadClubs();
                    }),
                  ],
                ),
              ],
            ),
          ),
          // Results
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadClubs,
              color: AppColors.clubPrimary,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _clubs.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _clubs.length,
                          itemBuilder: (context, index) => _buildClubCard(_clubs[index]),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.clubPrimary : AppColors.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            '검색 결과가 없습니다',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildClubCard(ClubSummary club) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: AppColors.surface,
      child: InkWell(
        onTap: () async {
          await context.push('/clubs/${club.id}');
          _loadClubs();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.clubPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups_outlined, color: AppColors.clubPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (club.region != null) ...[
                          Text(
                            '${club.region}${club.city != null ? ' ${club.city}' : ''}',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Icon(Icons.people_outline, size: 13, color: AppColors.textTertiary),
                        const SizedBox(width: 2),
                        Text(
                          '${club.memberCount}명',
                          style: TextStyle(
                            fontSize: 12,
                            color: club.isMyClub ? AppColors.textTertiary : AppColors.clubPrimary,
                            fontWeight: club.isMyClub ? FontWeight.normal : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (club.isMyClub)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.statusOpenBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '가입됨',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.statusOpenText,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
