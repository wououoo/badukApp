import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/club.dart';
import '../../../data/services/club_service.dart';
import '../../../core/widgets/shimmer_loading.dart';

/// 내 클럽 목록 화면
class MyClubsScreen extends StatefulWidget {
  const MyClubsScreen({super.key});

  @override
  State<MyClubsScreen> createState() => _MyClubsScreenState();
}

class _MyClubsScreenState extends State<MyClubsScreen> {
  final ClubService _clubService = ClubService();
  List<ClubSummary> _clubs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyClubs();
  }

  Future<void> _loadMyClubs() async {
    setState(() => _isLoading = true);
    try {
      final clubs = await _clubService.getMyClubs();
      setState(() {
        _clubs = clubs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        debugPrint('[Error] 클럽 목록 로드 오류: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('클럽 목록을 불러올 수 없습니다. 다시 시도해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('내 클럽'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadMyClubs,
        color: AppColors.clubPrimary,
        child: _isLoading
            ? SkeletonBuilders.clubList()
            : _clubs.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _clubs.length + 1, // +1 for search banner
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildSearchBanner();
                      return _buildClubCard(_clubs[index - 1]);
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push('/clubs/create');
          if (result == true) _loadMyClubs();
        },
        backgroundColor: AppColors.clubPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('클럽 만들기'),
      ),
    );
  }

  /// Search banner at top of list
  Widget _buildSearchBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/clubs/explore'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.clubBgTint,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.clubPrimary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: AppColors.clubPrimary),
              const SizedBox(width: 10),
              Text(
                '클럽 탐색...',
                style: TextStyle(fontSize: 15, color: AppColors.clubPrimary, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.clubPrimary.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.clubBgTint,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.groups_outlined, size: 52, color: AppColors.clubPrimary.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              '클럽에 가입하고\n함께 대국하세요',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '가까운 바둑 클럽을 찾아 가입하거나\n새 클럽을 만들어보세요',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/clubs/explore'),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('클럽 탐색'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.clubPrimary,
                      side: BorderSide(color: AppColors.clubPrimary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await context.push('/clubs/create');
                      if (result == true) _loadMyClubs();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('클럽 만들기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.clubPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClubCard(ClubSummary club) {
    final isOwner = club.myRole == 'OWNER';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await context.push('/clubs/${club.id}');
          _loadMyClubs();
        },
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left color strip (role-based)
              Container(
                width: 4,
                color: isOwner ? AppColors.clubPrimaryDark : AppColors.clubPrimaryLight,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: icon + name + badge
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.clubPrimary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.groups, color: AppColors.clubPrimary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              club.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          _buildRoleBadge(club.myRole),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Row 2: region + member count
                      Row(
                        children: [
                          if (club.region != null) ...[
                            Icon(Icons.location_on_outlined, size: 14, color: AppColors.textTertiary),
                            const SizedBox(width: 2),
                            Text(
                              '${club.region}${club.city != null ? ' ${club.city}' : ''}',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Icon(Icons.people_outline, size: 14, color: AppColors.textTertiary),
                          const SizedBox(width: 2),
                          Text(
                            '${club.memberCount}명',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.chevron_right, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String? role) {
    if (role == null) return const SizedBox.shrink();

    final isOwner = role == 'OWNER';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isOwner ? AppColors.clubPrimary.withOpacity(0.1) : AppColors.statusOpenBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isOwner ? '클럽장' : '멤버',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isOwner ? AppColors.clubPrimary : AppColors.statusOpenText,
        ),
      ),
    );
  }
}
