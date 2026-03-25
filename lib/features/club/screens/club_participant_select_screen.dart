import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/club.dart';
import '../../../data/services/club_service.dart';
import '../../../data/services/club_contest_service.dart';

/// 클럽 멤버에서 대회 참가자 선택 화면
class ClubParticipantSelectScreen extends StatefulWidget {
  final int clubId;
  final int contestId;
  final int sortId;
  final String gameType;

  const ClubParticipantSelectScreen({
    super.key,
    required this.clubId,
    required this.contestId,
    required this.sortId,
    this.gameType = '',
  });

  @override
  State<ClubParticipantSelectScreen> createState() => _ClubParticipantSelectScreenState();
}

class _ClubParticipantSelectScreenState extends State<ClubParticipantSelectScreen> {
  final ClubService _clubService = ClubService();
  final ClubContestService _contestService = ClubContestService();

  List<ClubMemberInfo> _members = [];
  List<Map<String, dynamic>> _existingParticipants = [];
  final Set<int> _selectedUserIds = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  bool get _isMcMahon => widget.gameType == '맥마흔';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final members = await _clubService.getClubMembers(widget.clubId);
      final participantsData = await _contestService.getParticipants(widget.clubId, widget.contestId, widget.sortId);
      final existing = participantsData['participants'] as List? ?? [];

      setState(() {
        _members = members;
        _existingParticipants = existing.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Set<int> get _existingUserIds {
    return _existingParticipants
        .map((p) => p['userId'] as int?)
        .whereType<int>()
        .toSet();
  }

  bool _hasNoLevel(ClubMemberInfo member) {
    return _isMcMahon && member.level == null;
  }

  void _toggleMember(int userId) {
    if (_existingUserIds.contains(userId)) return;
    final member = _members.firstWhere((m) => m.userId == userId);
    if (_hasNoLevel(member)) return;
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _submitSelection() async {
    if (_selectedUserIds.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final result = await _contestService.addParticipants(
        widget.clubId,
        widget.contestId,
        widget.sortId,
        _selectedUserIds.toList(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final addedCount = result['addedCount'] ?? 0;
        final message = result['message'] as String?;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message ?? '$addedCount명이 추가되었습니다.'),
            duration: Duration(seconds: message != null ? 4 : 2),
          ),
        );
        context.pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '추가 실패')),
        );
      }
    } catch (e) {
      debugPrint('[Error] 참가자 추가 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('참가자 선택'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: AppColors.textSecondary)))
              : _buildBody(),
      bottomNavigationBar: _selectedUserIds.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2)),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.clubPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            '${_selectedUserIds.length}명 추가',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_members.isEmpty) {
      return const Center(child: Text('멤버가 없습니다.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _members.length,
      itemBuilder: (context, index) => _buildMemberTile(_members[index]),
    );
  }

  Widget _buildMemberTile(ClubMemberInfo member) {
    final isAlreadyParticipant = _existingUserIds.contains(member.userId);
    final isSelected = _selectedUserIds.contains(member.userId);
    final noLevel = _hasNoLevel(member);
    final isDisabled = isAlreadyParticipant || noLevel;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isSelected
            ? const BorderSide(color: AppColors.clubPrimary, width: 1.5)
            : BorderSide.none,
      ),
      color: isDisabled
          ? AppColors.background.withOpacity(0.5)
          : isSelected
              ? AppColors.clubPrimary.withOpacity(0.05)
              : AppColors.surface,
      child: InkWell(
        onTap: isDisabled ? null : () => _toggleMember(member.userId),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Checkbox(
                value: isSelected || isAlreadyParticipant,
                onChanged: isDisabled ? null : (_) => _toggleMember(member.userId),
                activeColor: isAlreadyParticipant ? AppColors.textTertiary : AppColors.clubPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          member.name ?? '알 수 없음',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDisabled ? AppColors.textTertiary : AppColors.textPrimary,
                          ),
                        ),
                        if (isAlreadyParticipant) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.textTertiary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '참가 중',
                              style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                            ),
                          ),
                        ],
                        if (noLevel) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '단수 미설정',
                              style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (member.rank != null)
                      Text(
                        member.rank!,
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
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
