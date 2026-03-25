import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/club.dart';
import '../../../data/services/club_service.dart';
import 'club_posts_screen.dart';
import 'club_photos_screen.dart';
import 'club_schedules_screen.dart';
import 'club_contests_screen.dart';
import 'club_rankings_screen.dart';

class ClubDetailScreen extends StatefulWidget {
  final int clubId;

  const ClubDetailScreen({super.key, required this.clubId});

  @override
  State<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends State<ClubDetailScreen> with SingleTickerProviderStateMixin {
  final ClubService _clubService = ClubService();
  final ImagePicker _imagePicker = ImagePicker();
  ClubDetail? _club;
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;
  final GlobalKey<ClubPhotosScreenState> _photosKey = GlobalKey();
  final GlobalKey<ClubSchedulesScreenState> _schedulesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadClubDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClubDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final club = await _clubService.getClubDetail(widget.clubId);
      setState(() {
        _club = club;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadPhotos() async {
    try {
      final images = await _imagePicker.pickMultiImage(imageQuality: 80);
      if (images.isEmpty || !mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${images.length}장 업로드 중...')),
      );

      // XFile.readAsBytes()로 바이트 읽기 (웹 + 모바일 모두 호환)
      final files = <Map<String, dynamic>>[];
      for (final img in images) {
        files.add({
          'bytes': await img.readAsBytes(),
          'name': img.name,
        });
      }
      await _clubService.uploadClubPhotos(widget.clubId, files);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${images.length}장의 사진이 업로드되었습니다.')),
        );
        _photosKey.currentState?.refresh();
      }
    } catch (e) {
      debugPrint('[Error] 사진 업로드 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    }
  }

  Future<void> _requestJoin() async {
    final messageController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('가입 신청'),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(
            hintText: '가입 인사말을 남겨주세요 (선택)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          maxLength: 200,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
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
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.clubPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('신청', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    try {
      final res = await _clubService.requestJoin(
        widget.clubId,
        message: messageController.text.trim().isEmpty ? null : messageController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? '가입 신청 완료')),
        );
      }
    } catch (e) {
      debugPrint('[Error] 가입 신청 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
    }
  }

  Future<void> _leaveClub() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('클럽 탈퇴'),
        content: const Text('정말 이 클럽에서 탈퇴하시겠습니까?'),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
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
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('탈퇴', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final res = await _clubService.leaveClub(widget.clubId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? '탈퇴 완료')),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('[Error] 클럽 탈퇴 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    }
  }

  Future<void> _deleteClub() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('클럽 삭제'),
        content: const Text('정말 이 클럽을 삭제하시겠습니까?\n모든 멤버와 데이터가 삭제됩니다.'),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
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
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('삭제', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final res = await _clubService.deleteClub(widget.clubId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? '삭제 완료')),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('[Error] 클럽 삭제 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    }
  }

  Future<void> _removeMember(ClubMemberInfo member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('멤버 추방'),
        content: Text('${member.name ?? '멤버'}을(를) 추방하시겠습니까?'),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
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
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('추방', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _clubService.removeMember(widget.clubId, member.userId);
      _loadClubDetail();
    } catch (e) {
      debugPrint('[Error] 멤버 추방 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final club = _club;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(club?.name ?? '클럽'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          // MEMBER/ADMIN: leave option in AppBar menu
          if (club?.myRole == 'MEMBER' || club?.myRole == 'ADMIN')
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'leave') _leaveClub();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'leave',
                  child: Text('클럽 탈퇴', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          // Owner: delete option in AppBar menu
          if (club?.myRole == 'OWNER')
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') _deleteClub();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('클럽 삭제', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: AppColors.textSecondary)))
              : _buildBody(),
      // FAB: member only
      floatingActionButton: (club?.isMyClub == true)
          ? AnimatedBuilder(
              animation: _tabController,
              builder: (context, child) {
                final index = _tabController.index;
                // 게시판 탭: 글쓰기
                if (index == 0) {
                  return FloatingActionButton(
                    onPressed: () {
                      context.push(
                        '/clubs/${widget.clubId}/posts/create',
                        extra: {'myRole': club?.myRole},
                      ).then((result) {
                        if (result == true) setState(() {});
                      });
                    },
                    backgroundColor: AppColors.clubPrimary,
                    child: const Icon(Icons.edit, color: Colors.white),
                  );
                }
                // 사진첩 탭: 사진 업로드
                if (index == 1) {
                  return FloatingActionButton(
                    onPressed: _pickAndUploadPhotos,
                    backgroundColor: AppColors.clubPrimary,
                    child: const Icon(Icons.add_photo_alternate, color: Colors.white),
                  );
                }
                // 일정 탭: ADMIN 이상 일정 생성
                if (index == 2 && (club?.myRole == 'OWNER' || club?.myRole == 'ADMIN')) {
                  return FloatingActionButton(
                    onPressed: () {
                      _schedulesKey.currentState?.showScheduleForm();
                    },
                    backgroundColor: AppColors.clubPrimary,
                    child: const Icon(Icons.add, color: Colors.white),
                  );
                }
                return const SizedBox.shrink();
              },
            )
          : null,
      // Non-member: sticky bottom join bar
      bottomNavigationBar: (club != null && !club.isMyClub) ? _buildJoinBottomBar() : null,
    );
  }

  Widget _buildJoinBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _requestJoin,
            icon: const Icon(Icons.person_add, size: 20),
            label: const Text('가입 신청', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.clubPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // 비회원: 정보카드 + 멤버목록을 하나의 스크롤뷰로
    if (_club?.isMyClub != true) {
      return _buildNonMemberBody();
    }

    return Column(
      children: [
        _buildInfoCard(),
        // 관리자 이상 action chips
        if (_club?.myRole == 'OWNER' || _club?.myRole == 'ADMIN') ...[
          const SizedBox(height: 8),
          _buildOwnerActionChips(),
        ],
        const SizedBox(height: 8),
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.clubPrimary,
            unselectedLabelColor: AppColors.textTertiary,
            indicatorColor: AppColors.clubPrimary,
            indicatorWeight: 2,
            tabs: const [
              Tab(text: '게시판'),
              Tab(text: '사진첩'),
              Tab(text: '일정'),
              Tab(text: '대회'),
              Tab(text: '랭킹'),
              Tab(text: '멤버'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              ClubPostsScreen(clubId: widget.clubId, myRole: _club?.myRole),
              ClubPhotosScreen(key: _photosKey, clubId: widget.clubId, myRole: _club?.myRole),
              ClubSchedulesScreen(key: _schedulesKey, clubId: widget.clubId, myRole: _club?.myRole),
              ClubContestsScreen(clubId: widget.clubId, myRole: _club?.myRole),
              ClubRankingsScreen(clubId: widget.clubId),
              _buildMembersTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNonMemberBody() {
    final club = _club!;
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _buildInfoCard(),
        const SizedBox(height: 16),
        // 멤버 목록을 직접 표시
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '멤버',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${club.members.length}',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...club.members.map((member) => _buildMemberTile(member, false, false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    final club = _club!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.clubPrimary, AppColors.clubPrimaryLight],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: club.photoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          '${ApiConstants.baseUrl.replaceAll('/api', '')}${club.photoUrl}',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.groups, color: Colors.white, size: 28),
                        ),
                      )
                    : const Icon(Icons.groups, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    if (club.region != null)
                      Text(
                        '${club.region}${club.city != null ? ' ${club.city}' : ''}',
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // Description - more prominent
          if (club.description != null && club.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                club.description!,
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.95), height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatItem(Icons.people, '멤버 ${club.memberCount}명'),
              const SizedBox(width: 20),
              if (club.ownerName != null) _buildStatItem(Icons.person, '클럽장: ${club.ownerName}'),
            ],
          ),
          // 가입 신청 버튼은 하단 bottomNavigationBar에 표시
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9))),
      ],
    );
  }

  /// 관리자 이상 action chips row
  Widget _buildOwnerActionChips() {
    final isOwner = _club?.myRole == 'OWNER';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildActionChip(
            icon: Icons.how_to_reg,
            label: '가입 관리',
            onTap: () => context.push('/clubs/${widget.clubId}/requests').then((_) => _loadClubDetail()),
          ),
          if (isOwner) ...[
            const SizedBox(width: 8),
            _buildActionChip(
              icon: Icons.edit_outlined,
              label: '정보 수정',
              onTap: () {
                context.push('/clubs/${widget.clubId}/edit').then((result) {
                  if (result == true) _loadClubDetail();
                });
              },
            ),
          ],
          const SizedBox(width: 8),
          _buildActionChip(
            icon: Icons.emoji_events_outlined,
            label: '대회 생성',
            onTap: () => context.push('/clubs/${widget.clubId}/contests/create'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: AppColors.clubPrimary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembersTab() {
    final club = _club!;
    final isOwner = club.myRole == 'OWNER';
    final isAdmin = club.myRole == 'OWNER' || club.myRole == 'ADMIN';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '멤버',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${club.members.length}',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...club.members.map((member) => _buildMemberTile(member, isOwner, isAdmin)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberTile(ClubMemberInfo member, bool isOwner, bool isAdmin) {
    final isMemberOwner = member.role == 'OWNER';
    final isMemberAdmin = member.role == 'ADMIN';

    // 추방 가능 여부: ADMIN+만 가능, ADMIN은 ADMIN/OWNER 추방 불가
    final canRemove = isAdmin && !isMemberOwner && !(
      !isOwner && isMemberAdmin // ADMIN이 다른 ADMIN 추방 불가
    );

    return GestureDetector(
      onLongPress: isAdmin && !isMemberOwner ? () => _showRoleManageDialog(member) : null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: (isMemberOwner || isMemberAdmin)
                  ? AppColors.clubPrimary.withOpacity(0.15)
                  : AppColors.background,
              child: Text(
                (member.name ?? '?')[0],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: (isMemberOwner || isMemberAdmin) ? AppColors.clubPrimary : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        member.name ?? '알 수 없음',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      if (isMemberOwner) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.clubPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '클럽장',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.clubPrimary),
                          ),
                        ),
                      ],
                      if (isMemberAdmin) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '관리자',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (member.rank != null)
                    Text(member.rank!, style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ],
              ),
            ),
            if (canRemove)
              IconButton(
                onPressed: () => _removeMember(member),
                icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppColors.error),
                tooltip: '추방',
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRoleManageDialog(ClubMemberInfo member) async {
    final isCurrentlyAdmin = member.role == 'ADMIN';
    final isOwner = _club?.myRole == 'OWNER';
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${member.name ?? '멤버'} 관리',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            if (isOwner && !isCurrentlyAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.orange),
                title: const Text('관리자로 임명'),
                subtitle: const Text('가입 관리, 대회 운영, 일정 관리 등 가능'),
                onTap: () => Navigator.pop(ctx, 'ADMIN'),
              ),
            if (isOwner && isCurrentlyAdmin)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('관리자 해제'),
                subtitle: const Text('일반 멤버로 변경'),
                onTap: () => Navigator.pop(ctx, 'MEMBER'),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.clubPrimary),
              title: const Text('단수 변경'),
              subtitle: Text(member.rank != null ? '현재: ${member.rank}' : '단수 미설정'),
              onTap: () => Navigator.pop(ctx, 'CHANGE_LEVEL'),
            ),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;

    if (action == 'CHANGE_LEVEL') {
      _showLevelChangeDialog(member);
      return;
    }

    try {
      final result = await _clubService.updateMemberRole(widget.clubId, member.userId, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '역할이 변경되었습니다.')),
        );
        _loadClubDetail();
      }
    } catch (e) {
      debugPrint('[Error] 역할 변경 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    }
  }

  Future<void> _showLevelChangeDialog(ClubMemberInfo member) async {
    // level 값: 10(9단) ~ 48(30급)
    int? selectedLevel = member.level;

    final List<Map<String, dynamic>> levelOptions = [
      for (int i = 10; i <= 18; i++) {'level': i, 'display': '${19 - i}단'},
      for (int i = 19; i <= 48; i++) {'level': i, 'display': '${i - 18}급'},
    ];

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('${member.name ?? '멤버'} 단수 변경'),
              content: DropdownButtonFormField<int>(
                value: selectedLevel,
                decoration: const InputDecoration(
                  labelText: '단수 선택',
                  border: OutlineInputBorder(),
                ),
                items: levelOptions.map((opt) {
                  return DropdownMenuItem<int>(
                    value: opt['level'] as int,
                    child: Text(opt['display'] as String),
                  );
                }).toList(),
                onChanged: (val) {
                  setDialogState(() { selectedLevel = val; });
                },
              ),
              actionsAlignment: MainAxisAlignment.center,
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: selectedLevel != null ? () => Navigator.pop(ctx, selectedLevel) : null,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.clubPrimary),
                  child: const Text('변경', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;

    try {
      final res = await _clubService.updateMemberLevel(widget.clubId, member.userId, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? '단수가 변경되었습니다.')),
        );
        _loadClubDetail();
      }
    } catch (e) {
      debugPrint('[Error] 단수 변경 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    }
  }
}
