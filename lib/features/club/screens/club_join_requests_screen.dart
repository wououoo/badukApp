import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/club.dart';
import '../../../data/services/club_service.dart';

/// 클럽 가입 신청 관리 화면 (OWNER 전용)
class ClubJoinRequestsScreen extends StatefulWidget {
  final int clubId;

  const ClubJoinRequestsScreen({super.key, required this.clubId});

  @override
  State<ClubJoinRequestsScreen> createState() => _ClubJoinRequestsScreenState();
}

class _ClubJoinRequestsScreenState extends State<ClubJoinRequestsScreen> {
  final ClubService _clubService = ClubService();
  List<ClubJoinRequestInfo> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _clubService.getJoinRequests(widget.clubId);
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        debugPrint('[Error] 신청 목록 로드 오류: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신청 목록을 불러올 수 없습니다. 다시 시도해주세요.')),
        );
      }
    }
  }

  Future<void> _approve(ClubJoinRequestInfo request) async {
    try {
      final res = await _clubService.approveJoinRequest(widget.clubId, request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? '승인 완료')),
        );
        _loadRequests();
      }
    } catch (e) {
      debugPrint('[Error] 가입 승인 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    }
  }

  Future<void> _reject(ClubJoinRequestInfo request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('가입 거절'),
        content: Text('${request.userName ?? '신청자'}의 가입을 거절하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('거절', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final res = await _clubService.rejectJoinRequest(widget.clubId, request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? '거절 완료')),
        );
        _loadRequests();
      }
    } catch (e) {
      debugPrint('[Error] 가입 거절 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('가입 신청 관리'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        color: AppColors.clubPrimary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _requests.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    itemBuilder: (context, index) => _buildRequestCard(_requests[index]),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            '대기 중인 가입 신청이 없습니다',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(ClubJoinRequestInfo request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.clubPrimary.withOpacity(0.1),
                  child: Text(
                    (request.userName ?? '?')[0],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.clubPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.userName ?? '알 수 없음',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      if (request.userRank != null)
                        Text(
                          request.userRank!,
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                if (request.createdAt != null)
                  Text(
                    _formatDate(request.createdAt!),
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
              ],
            ),
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.message!,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reject(request),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('거절', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approve(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.clubPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('승인'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}';
    } catch (_) {
      return dateStr;
    }
  }
}
