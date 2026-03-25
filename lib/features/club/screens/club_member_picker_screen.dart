import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/club.dart';
import '../../../data/services/club_service.dart';

/// 클럽 멤버 선택 화면 (단체전 팀 등록 시 사용)
class ClubMemberPickerScreen extends StatefulWidget {
  final int? teamSize;

  const ClubMemberPickerScreen({super.key, this.teamSize});

  @override
  State<ClubMemberPickerScreen> createState() => _ClubMemberPickerScreenState();
}

class _ClubMemberPickerScreenState extends State<ClubMemberPickerScreen> {
  final ClubService _clubService = ClubService();

  List<ClubSummary> _myClubs = [];
  ClubSummary? _selectedClub;
  List<ClubMemberInfo> _members = [];
  final Set<int> _selectedUserIds = {};
  bool _isLoadingClubs = true;
  bool _isLoadingMembers = false;

  @override
  void initState() {
    super.initState();
    _loadMyClubs();
  }

  Future<void> _loadMyClubs() async {
    setState(() => _isLoadingClubs = true);
    try {
      final clubs = await _clubService.getMyClubs();
      setState(() {
        _myClubs = clubs;
        _selectedClub = null;
        _members = [];
        _selectedUserIds.clear();
        _isLoadingClubs = false;
      });
    } catch (e) {
      setState(() => _isLoadingClubs = false);
    }
  }

  Future<void> _loadMembers(int clubId) async {
    setState(() => _isLoadingMembers = true);
    try {
      final members = await _clubService.getClubMembers(clubId);
      setState(() {
        _members = members;
        _selectedUserIds.clear();
        _isLoadingMembers = false;
      });
    } catch (e) {
      setState(() => _isLoadingMembers = false);
    }
  }

  void _toggleMember(int userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        if (widget.teamSize != null && _selectedUserIds.length >= widget.teamSize!) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('최대 ${widget.teamSize}명까지 선택할 수 있습니다.')),
          );
          return;
        }
        _selectedUserIds.add(userId);
      }
    });
  }

  void _confirmSelection() {
    final selectedMembers = _members
        .where((m) => _selectedUserIds.contains(m.userId))
        .map((m) => {
              'userId': m.userId,
              'name': m.name,
              'rank': m.rank,
              'level': m.level,
              'clubName': _selectedClub?.name,
            })
        .toList();

    context.pop(selectedMembers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('클럽에서 팀원 선택'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (_selectedUserIds.isNotEmpty)
            TextButton(
              onPressed: _confirmSelection,
              child: Text(
                '선택 완료 (${_selectedUserIds.length})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: _isLoadingClubs
          ? const Center(child: CircularProgressIndicator())
          : _myClubs.isEmpty
              ? _buildNoClubState()
              : Column(
                  children: [
                    // 클럽 선택 드롭다운
                    Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: DropdownButtonFormField<ClubSummary>(
                        value: _selectedClub,
                        decoration: InputDecoration(
                          labelText: '클럽 선택',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: _myClubs.map((club) {
                          return DropdownMenuItem(
                            value: club,
                            child: Text('${club.name} (${club.memberCount}명)', style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (club) {
                          setState(() => _selectedClub = club);
                          if (club != null) _loadMembers(club.id);
                        },
                      ),
                    ),
                    if (widget.teamSize != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Text(
                          '${_selectedUserIds.length} / ${widget.teamSize}명 선택됨',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    // 멤버 리스트
                    Expanded(
                      child: _selectedClub == null
                          ? Center(
                              child: Text(
                                '클럽을 선택해주세요',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            )
                          : _isLoadingMembers
                              ? const Center(child: CircularProgressIndicator())
                              : _members.isEmpty
                                  ? Center(
                                      child: Text(
                                        '멤버가 없습니다',
                                        style: TextStyle(color: AppColors.textSecondary),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: _members.length,
                                      itemBuilder: (context, index) => _buildMemberTile(_members[index]),
                                    ),
                    ),
                  ],
                ),
      bottomNavigationBar: _selectedUserIds.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _confirmSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.clubPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      '${_selectedUserIds.length}명 선택 완료',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildNoClubState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            '가입한 클럽이 없습니다',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            '먼저 클럽에 가입해주세요',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(ClubMemberInfo member) {
    final isSelected = _selectedUserIds.contains(member.userId);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isSelected
            ? const BorderSide(color: AppColors.clubPrimary, width: 1.5)
            : BorderSide.none,
      ),
      elevation: 0,
      color: isSelected ? AppColors.clubPrimary.withOpacity(0.05) : AppColors.surface,
      child: InkWell(
        onTap: () => _toggleMember(member.userId),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleMember(member.userId),
                activeColor: AppColors.clubPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name ?? '알 수 없음',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    if (member.rank != null)
                      Text(member.rank!, style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  ],
                ),
              ),
              if (member.role == 'OWNER')
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
          ),
        ),
      ),
    );
  }
}
