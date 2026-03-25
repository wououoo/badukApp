import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/club_service.dart';
import '../../../data/services/club_contest_service.dart';

/// 클럽 대회 목록 화면 (탭 내부 위젯)
class ClubContestsScreen extends StatefulWidget {
  final int clubId;
  final String? myRole;

  const ClubContestsScreen({super.key, required this.clubId, this.myRole});

  @override
  State<ClubContestsScreen> createState() => _ClubContestsScreenState();
}

class _ClubContestsScreenState extends State<ClubContestsScreen> {
  final ClubService _clubService = ClubService();
  final ClubContestService _contestService = ClubContestService();
  List<Map<String, dynamic>> _contests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContests();
  }

  Future<void> _loadContests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final contests = await _clubService.getClubContests(widget.clubId);
      setState(() {
        _contests = contests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  String _getTypeLabel(String? type) {
    switch (type) {
      case 'SWISS': return '스위스리그';
      case 'MCM': return '맥마흔';
      case 'FULL_LEAGUE': return '풀리그';
      case 'TEAM_SWISS': return '단체전';
      case 'TEAM_FULL_LEAGUE': return '단체 풀리그';
      case 'DE': return '더블엘리미네이션';
      case 'TOURNAMENT': return '토너먼트';
      default: return type ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadContests, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    if (_contests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text('아직 클럽 대회가 없습니다', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            if (widget.myRole == 'OWNER' || widget.myRole == 'ADMIN')
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/clubs/${widget.clubId}/contests/create').then((_) => _loadContests());
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('대회 생성'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.clubPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadContests,
          color: AppColors.clubPrimary,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _contests.length,
            itemBuilder: (context, index) => _buildContestCard(_contests[index]),
          ),
        ),
        if (widget.myRole == 'OWNER' || widget.myRole == 'ADMIN')
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'clubContestFab',
              onPressed: () {
                context.push('/clubs/${widget.clubId}/contests/create').then((result) {
                  if (result == true) _loadContests();
                });
              },
              backgroundColor: AppColors.clubPrimary,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Future<void> _deleteContest(int contestId, String contestName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('대회 삭제'),
        content: Text('"$contestName" 대회를 삭제하시겠습니까?\n모든 부문, 참가자, 대진 결과가 삭제됩니다.'),
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
      final result = await _contestService.deleteContest(widget.clubId, contestId);
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('대회가 삭제되었습니다.')),
        );
        _loadContests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '삭제 실패')),
        );
      }
    } catch (e) {
      debugPrint('[Error] 대회 삭제 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    }
  }

  Widget _buildContestCard(Map<String, dynamic> contest) {
    final contestId = (contest['contestId'] is num) ? (contest['contestId'] as num).toInt() : 0;
    final contestName = contest['contestName'] as String? ?? '';
    final type = contest['type'] as String?;
    final startDate = contest['startDate'] as String?;
    final endDate = contest['endDate'] as String?;
    final location = contest['contestLocation'] as String?;
    final isFinished = contest['isFinished'] == true;
    final isOwner = widget.myRole == 'OWNER' || widget.myRole == 'ADMIN';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: AppColors.surface,
      child: InkWell(
        onTap: () {
          // Members can manage, non-members read-only (just view the list)
          if (widget.myRole != null) {
            context.push('/clubs/${widget.clubId}/contests/$contestId/manage').then((_) => _loadContests());
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (type != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.clubPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getTypeLabel(type),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.clubPrimary),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isFinished ? Colors.grey.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isFinished ? '종료' : '진행중',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isFinished ? Colors.grey : Colors.blue,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isOwner) ...[
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'manage') {
                            context.push('/clubs/${widget.clubId}/contests/$contestId/manage').then((_) => _loadContests());
                          } else if (value == 'delete') {
                            _deleteContest(contestId, contestName);
                          }
                        },
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'manage',
                            child: Row(
                              children: [
                                Icon(Icons.settings_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('대회 관리'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                const SizedBox(width: 8),
                                const Text('삭제', style: TextStyle(color: AppColors.error)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (widget.myRole != null) ...[
                    Icon(Icons.chevron_right, size: 20, color: AppColors.textTertiary),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                contestName,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (startDate != null) ...[
                    Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatDate(startDate)}${endDate != null ? ' ~ ${_formatDate(endDate)}' : ''}',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
              if (location != null && location.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
