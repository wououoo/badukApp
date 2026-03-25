import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/club.dart';
import '../../../data/services/club_service.dart';
import '../../../data/services/club_contest_service.dart';

/// 참가자 탭 (개인 + 팀)
class ContestParticipantsTab extends StatelessWidget {
  final int clubId;
  final int contestId;
  final int sortId;
  final bool isTeamContest;
  final bool isFinished;
  final int maxRound;
  final int teamSize;
  final String gameType;
  final List<Map<String, dynamic>> participants;
  final List<Map<String, dynamic>> teams;
  final VoidCallback onReload;

  const ContestParticipantsTab({
    super.key,
    required this.clubId,
    required this.contestId,
    required this.sortId,
    required this.isTeamContest,
    required this.isFinished,
    required this.maxRound,
    required this.teamSize,
    required this.gameType,
    required this.participants,
    required this.teams,
    required this.onReload,
  });

  ClubContestService get _service => ClubContestService();

  List<Map<String, dynamic>> _safeListCast(dynamic list) {
    if (list == null) return [];
    if (list is! List) return [];
    return list.map((e) {
      if (e is Map) return Map<String, dynamic>.from(e);
      return <String, dynamic>{};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (isTeamContest) return _buildTeamParticipantsTab(context);

    if (participants.isEmpty) {
      return const Center(child: Text('참가자가 없습니다.\n멤버에서 참가자를 추가해주세요.', textAlign: TextAlign.center));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: participants.length,
      itemBuilder: (context, index) => _buildParticipantCard(context, index, participants[index]),
    );
  }

  Widget _buildParticipantCard(BuildContext context, int pIndex, Map<String, dynamic> p) {
    final name = p['name']?.toString() ?? '알 수 없음';
    final number = (p['participantNumber'] is num) ? (p['participantNumber'] as num).toInt() : (pIndex + 1);
    final rating = (p['rating'] is num) ? (p['rating'] as num).toInt() : 1500;
    final participantId = (p['participantId'] is num) ? (p['participantId'] as num).toInt() : 0;
    final isGuest = p['userId'] == null;
    final canEdit = !isFinished && maxRound == 0;

    return GestureDetector(
      onTap: canEdit ? () => _showEditParticipantDialog(context, p) : null,
      child: Card(
        margin: const EdgeInsets.only(bottom: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Text('$number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    if (isGuest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.textTertiary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text('게스트', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                      ),
                    ],
                  ],
                ),
              ),
              Text('$rating', style: const TextStyle(fontSize: 13, color: AppColors.clubPrimary, fontWeight: FontWeight.w600)),
              if (canEdit)
                IconButton(
                  onPressed: () => _removeParticipant(context, participantId, name),
                  icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppColors.error),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditParticipantDialog(BuildContext context, Map<String, dynamic> p) {
    final participantId = (p['participantId'] is num) ? (p['participantId'] as num).toInt() : 0;
    final currentName = p['name']?.toString() ?? '';
    final isMcMahon = gameType == '맥마흔';

    final nameController = TextEditingController(text: currentName);
    final rankNumberController = TextEditingController();
    bool isDan = true;

    // 맥마흔인 경우 현재 레벨에서 단/급 역산 (유효 범위: 10~48)
    if (isMcMahon && p['level'] != null) {
      final level = (p['level'] as num).toInt();
      if (level >= 10 && level <= 48) {
        if (level <= 18) {
          isDan = true;
          rankNumberController.text = '${19 - level}';
        } else {
          isDan = false;
          rankNumberController.text = '${level - 18}';
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('참가자 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '이름',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  counterText: '',
                ),
                maxLength: 30,
                autofocus: true,
              ),
              if (isMcMahon) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: rankNumberController,
                        decoration: InputDecoration(
                          labelText: '단수 *',
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
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          actions: [
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
                    if (isMcMahon) {
                      final rankText = rankNumberController.text.trim();
                      if (rankText.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('단수를 입력해주세요.')));
                        return;
                      }
                      final rankNum = int.tryParse(rankText);
                      if (rankNum == null || rankNum < 1 || (isDan && rankNum > 9) || (!isDan && rankNum > 30)) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(isDan ? '단수는 1~9 사이로 입력해주세요.' : '급수는 1~30 사이로 입력해주세요.')));
                        return;
                      }
                      level = isDan ? (19 - rankNum) : (18 + rankNum);
                    }

                    Navigator.pop(ctx);
                    try {
                      final result = await _service.updateParticipant(clubId, contestId, sortId, participantId, name: name, level: level);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['success'] == true ? '수정되었습니다.' : (result['message'] ?? '수정 실패'))));
                      }
                      if (result['success'] == true) onReload();
                    } catch (e) {
                      debugPrint('[Error] 참가자 수정 오류: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.clubPrimary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('수정'),
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

  Future<void> _removeParticipant(BuildContext context, int participantId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('참가자 제거'),
        content: Text('$name을(를) 참가자에서 제거하시겠습니까?'),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('제거', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.removeParticipant(clubId, contestId, participantId);
      onReload();
    } catch (e) {
      debugPrint('[Error] 참가자 제거 오류: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    }
  }

  // ==================== Team participants ====================

  Widget _buildTeamParticipantsTab(BuildContext context) {
    if (teams.isEmpty) {
      return const Center(child: Text('팀이 없습니다.\n팀을 추가해주세요.', textAlign: TextAlign.center));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: teams.length,
      itemBuilder: (context, index) {
        final team = teams[index];
        final rawTeamId = team['teamId'] ?? team['id'];
        final teamId = (rawTeamId is num) ? rawTeamId.toInt() : 0;
        final teamName = team['teamName']?.toString() ?? '팀 ${index + 1}';
        final members = _safeListCast(team['members']);
        return _buildTeamCard(context, teamId, teamName, members);
      },
    );
  }

  Widget _buildTeamCard(BuildContext context, int teamId, String teamName, List<Map<String, dynamic>> members) {
    return Card(
      key: ValueKey('team_$teamId'),
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          title: Row(
            children: [
              Expanded(
                child: Text(teamName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Text('${members.length}명', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          trailing: (!isFinished && maxRound == 0)
              ? IconButton(
                  onPressed: () => _deleteTeam(context, teamId, teamName),
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32),
                )
              : null,
          children: [
            ...members.asMap().entries.map((entry) {
              final m = entry.value;
              final rawMemberId = m['memberId'] ?? m['id'];
              final memberId = (rawMemberId is num) ? rawMemberId.toInt() : 0;
              final name = (m['name'] ?? m['username'])?.toString() ?? '';
              final position = (m['position'] is num) ? (m['position'] as num).toInt() : (entry.key + 1);
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: AppColors.clubPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  alignment: Alignment.center,
                  child: Text('$position', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.clubPrimary)),
                ),
                title: Text(name, style: const TextStyle(fontSize: 13)),
                subtitle: Text('${position}장', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                trailing: (!isFinished && maxRound == 0)
                    ? IconButton(
                        onPressed: () => _removeTeamMember(context, teamId, memberId, name),
                        icon: const Icon(Icons.close, size: 16, color: AppColors.error),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28),
                      )
                    : null,
              );
            }),
            if (!isFinished && maxRound == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddTeamMemberDialog(context, teamId),
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: const Text('팀원 추가', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTeam(BuildContext context, int teamId, String teamName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('팀 삭제'),
        content: Text('"$teamName" 팀을 삭제하시겠습니까?\n팀원도 모두 삭제됩니다.'),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('삭제', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final result = await _service.deleteTeam(clubId, contestId, sortId, teamId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['success'] == true ? '팀이 삭제되었습니다.' : (result['message'] ?? '삭제 실패'))),
        );
      }
      if (result['success'] == true) onReload();
    } catch (e) {
      debugPrint('[Error] 팀 삭제 오류: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    }
  }

  Future<void> _removeTeamMember(BuildContext context, int teamId, int memberId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('팀원 삭제'),
        content: Text('$name을(를) 팀에서 삭제하시겠습니까?'),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('삭제', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final result = await _service.removeTeamMember(clubId, contestId, sortId, teamId, memberId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['success'] == true ? '팀원이 삭제되었습니다.' : (result['message'] ?? '삭제 실패'))),
        );
      }
      if (result['success'] == true) onReload();
    } catch (e) {
      debugPrint('[Error] 팀원 삭제 오류: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    }
  }

  Future<void> _showAddTeamMemberDialog(BuildContext context, int teamId) async {
    final team = teams.firstWhere((t) {
      final tid = t['teamId'] ?? t['id'];
      return (tid is num) && tid.toInt() == teamId;
    }, orElse: () => {});
    final existingMembers = _safeListCast(team.isNotEmpty ? team['members'] : null);
    final existingNames = existingMembers
        .map((m) => ((m['name'] ?? m['username'])?.toString() ?? '').toLowerCase())
        .where((n) => n.isNotEmpty)
        .toSet();

    final clubService = ClubService();
    List<ClubMemberInfo> clubMembers = [];
    try {
      clubMembers = await clubService.getClubMembers(clubId);
    } catch (_) {}

    if (!context.mounted) return;

    final Set<int> selectedUserIds = {};
    final List<String> guestNames = [];
    final guestNameController = TextEditingController();
    final guestFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final totalSelected = selectedUserIds.length + guestNames.length;

          return AlertDialog(
            title: const Text('팀원 일괄 추가'),
            content: SingleChildScrollView(
              child: ListBody(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.clubPrimary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '총 $totalSelected명 선택 (멤버 ${selectedUserIds.length} + 게스트 ${guestNames.length})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('클럽 멤버', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (clubMembers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('멤버가 없습니다', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ),
                  ...clubMembers.map((m) {
                    final memberName = m.name ?? '알 수 없음';
                    final isAlreadyAdded = existingNames.contains(memberName.toLowerCase());
                    final isSelected = selectedUserIds.contains(m.userId);
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(
                        memberName,
                        style: TextStyle(
                          fontSize: 13,
                          color: isAlreadyAdded ? AppColors.textTertiary : AppColors.textPrimary,
                          decoration: isAlreadyAdded ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: isAlreadyAdded ? const Text('이미 추가됨', style: TextStyle(fontSize: 11)) : null,
                      value: isSelected,
                      activeColor: AppColors.clubPrimary,
                      onChanged: isAlreadyAdded
                          ? null
                          : (v) => setDialogState(() {
                              if (v == true) selectedUserIds.add(m.userId);
                              else selectedUserIds.remove(m.userId);
                            }),
                    );
                  }),
                  const Divider(height: 24),
                  const Text('게스트 추가', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: guestNameController,
                          focusNode: guestFocusNode,
                          decoration: InputDecoration(
                            hintText: '이름 입력 후 + 버튼',
                            hintStyle: const TextStyle(fontSize: 12),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 13),
                          onSubmitted: (value) {
                            final name = value.trim();
                            if (name.isNotEmpty) {
                              setDialogState(() { guestNames.add(name); guestNameController.clear(); });
                              guestFocusNode.requestFocus();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 48, height: 38,
                        child: ElevatedButton(
                          onPressed: () {
                            final name = guestNameController.text.trim();
                            if (name.isNotEmpty) {
                              setDialogState(() { guestNames.add(name); guestNameController.clear(); });
                              guestFocusNode.requestFocus();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.clubPrimary, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: const Icon(Icons.add, size: 20),
                        ),
                      ),
                    ],
                  ),
                  if (guestNames.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6, runSpacing: 4,
                      children: guestNames.asMap().entries.map((entry) {
                        return Chip(
                          label: Text(entry.value, style: const TextStyle(fontSize: 12)),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setDialogState(() => guestNames.removeAt(entry.key)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: totalSelected == 0 ? null : () async {
                        Navigator.pop(ctx);
                        final List<Map<String, dynamic>> membersList = [];
                        for (final uid in selectedUserIds) {
                          final m = clubMembers.firstWhere((cm) => cm.userId == uid);
                          membersList.add({'userId': uid, 'name': m.name ?? ''});
                        }
                        for (final name in guestNames) {
                          membersList.add({'name': name});
                        }
                        try {
                          final result = await _service.addTeamMembers(clubId, contestId, sortId, teamId, membersList);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result['success'] == true
                                  ? '${result['addedCount'] ?? membersList.length}명의 팀원이 추가되었습니다.'
                                  : (result['message'] ?? '추가 실패'))),
                            );
                          }
                          if (result['success'] == true) {
                            WidgetsBinding.instance.addPostFrameCallback((_) => onReload());
                          }
                        } catch (e) {
                          debugPrint('[Error] 팀원 추가 오류: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.clubPrimary, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('추가 ($totalSelected명)'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ).then((_) {
      guestNameController.dispose();
      guestFocusNode.dispose();
    });
  }
}
