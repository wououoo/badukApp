import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/api_client.dart';

/// 관리자용 전체 의뢰 목록 Provider
final adminContestRequestsProvider = FutureProvider.family<Map<String, dynamic>, String?>((ref, status) async {
  final apiClient = ApiClient.instance;
  final path = status != null && status.isNotEmpty
      ? '/mobile/host/admin/contest-requests?status=$status'
      : '/mobile/host/admin/contest-requests';
  final response = await apiClient.get(path);
  return response.data;
});

/// 관리자용 의뢰 관리 화면
class AdminRequestsScreen extends ConsumerStatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  ConsumerState<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends ConsumerState<AdminRequestsScreen> {
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(adminContestRequestsProvider(_selectedStatus));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('의뢰 관리'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 필터 탭
          _buildFilterTabs(requestsAsync),
          // 목록
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(adminContestRequestsProvider(_selectedStatus));
              },
              child: requestsAsync.when(
                data: (data) {
                  final requests = data['requests'] as List? ?? [];
                  if (requests.isEmpty) {
                    return Center(
                      child: Text('의뢰가 없습니다', style: TextStyle(color: AppColors.textSecondary)),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index] as Map<String, dynamic>;
                      return _RequestCard(
                        request: request,
                        onStatusChange: () => ref.invalidate(adminContestRequestsProvider(_selectedStatus)),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      const Text('오류가 발생했습니다'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(adminContestRequestsProvider(_selectedStatus)),
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(AsyncValue<Map<String, dynamic>> requestsAsync) {
    final pendingCount = requestsAsync.whenOrNull(
      data: (data) => data['pendingCount'] as int? ?? 0,
    ) ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('전체', null),
            const SizedBox(width: 8),
            _buildFilterChip('대기 ($pendingCount)', 'PENDING', highlight: pendingCount > 0),
            const SizedBox(width: 8),
            _buildFilterChip('진행 중', 'IN_PROGRESS'),
            const SizedBox(width: 8),
            _buildFilterChip('완료', 'COMPLETED'),
            const SizedBox(width: 8),
            _buildFilterChip('거절', 'REJECTED'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String? status, {bool highlight = false}) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedStatus = status);
        ref.invalidate(adminContestRequestsProvider(status));
      },
      selectedColor: highlight ? Colors.orange.withOpacity(0.3) : AppColors.primary.withOpacity(0.2),
      backgroundColor: highlight ? Colors.orange.withOpacity(0.1) : null,
      checkmarkColor: highlight ? Colors.orange : AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? (highlight ? Colors.orange : AppColors.primary)
            : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onStatusChange;

  const _RequestCard({required this.request, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    final status = request['status'] as String? ?? 'PENDING';
    final statusText = request['statusText'] as String? ?? '검토 대기';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/host/requests/${request['requestId']}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request['title'] ?? '제목 없음',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildStatusChip(status, statusText),
                ],
              ),
              const SizedBox(height: 8),
              // 의뢰자 정보
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${request['userName'] ?? '-'} (${request['userPhone'] ?? '-'})',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              if (request['schedule'] != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        request['schedule'],
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),

              // 홈페이지 URL이 있으면 링크 표시
              if (request['homepageUrl'] != null && request['homepageUrl'].toString().isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final url = Uri.parse(request['homepageUrl']);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: Icon(Icons.open_in_new, size: 16, color: AppColors.success),
                    label: Text('홈페이지 바로가기', style: TextStyle(color: AppColors.success)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.success),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // 관리 버튼들 (2줄로 배치)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showStatusChangeDialog(context, status),
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('상태 변경'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditUrlDialog(context),
                      icon: const Icon(Icons.link, size: 16),
                      label: const Text('URL 설정'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/host/admin/edit-request/${request['requestId']}'),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('수정'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showDeleteDialog(context),
                      icon: Icon(Icons.delete, size: 16, color: AppColors.error),
                      label: Text('삭제', style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, String statusText) {
    Color color;
    switch (status) {
      case 'PENDING':
        color = Colors.orange;
        break;
      case 'IN_PROGRESS':
        color = Colors.blue;
        break;
      case 'COMPLETED':
        color = AppColors.success;
        break;
      case 'REJECTED':
        color = AppColors.error;
        break;
      default:
        color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String newStatus, {String? memo, String? homepageUrl}) async {
    try {
      final apiClient = ApiClient.instance;
      await apiClient.dio.patch(
        '/mobile/host/admin/contest-requests/${request['requestId']}/status',
        data: {
          'status': newStatus,
          if (memo != null) 'adminMemo': memo,
          if (homepageUrl != null) 'homepageUrl': homepageUrl,
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상태가 변경되었습니다.')),
        );
        onStatusChange();
      }
    } catch (e) {
      if (context.mounted) {
        debugPrint('[Error] 상태 변경 실패: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상태 변경에 실패했습니다. 다시 시도해주세요.'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showRejectDialog(BuildContext context) {
    final memoController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('의뢰 거절'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('거절 사유를 입력해주세요.'),
            const SizedBox(height: 16),
            TextField(
              controller: memoController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '거절 사유',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus(context, 'REJECTED', memo: memoController.text);
            },
            child: Text('거절', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showStatusChangeDialog(BuildContext context, String currentStatus) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('상태 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusOption(ctx, context, 'PENDING', '검토 대기', Colors.orange, currentStatus),
            _buildStatusOption(ctx, context, 'IN_PROGRESS', '제작 중', Colors.blue, currentStatus),
            _buildStatusOption(ctx, context, 'COMPLETED', '완료', AppColors.success, currentStatus),
            _buildStatusOption(ctx, context, 'REJECTED', '거절', AppColors.error, currentStatus),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(BuildContext dialogContext, BuildContext parentContext, String status, String label, Color color, String currentStatus) {
    final isSelected = status == currentStatus;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected ? color : AppColors.textSecondary,
      ),
      title: Text(label, style: TextStyle(color: color, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      onTap: isSelected ? null : () {
        Navigator.pop(dialogContext);
        if (status == 'COMPLETED') {
          _showCompleteDialog(parentContext);
        } else if (status == 'REJECTED') {
          _showRejectDialog(parentContext);
        } else {
          _updateStatus(parentContext, status);
        }
      },
    );
  }

  void _showEditUrlDialog(BuildContext context) {
    final urlController = TextEditingController(text: request['homepageUrl'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('홈페이지 URL 수정'),
        content: TextField(
          controller: urlController,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://swissbaduk.org/homepage/1',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final url = urlController.text.trim();
              _updateStatus(context, request['status'], homepageUrl: url.isNotEmpty ? url : null);
            },
            child: Text('저장', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showCompleteDialog(BuildContext context) {
    final homepageUrlController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('제작 완료'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('생성된 홈페이지 URL을 입력해주세요.'),
            const SizedBox(height: 16),
            TextField(
              controller: homepageUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://swissbaduk.org/homepage/1',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final homepageUrl = homepageUrlController.text.trim();
              _updateStatus(context, 'COMPLETED', homepageUrl: homepageUrl.isNotEmpty ? homepageUrl : null);
            },
            child: Text('완료', style: TextStyle(color: AppColors.success)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('의뢰 삭제'),
        content: Text('정말 "${request['title']}" 의뢰를 삭제하시겠습니까?\n\n삭제된 의뢰는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteRequest(context);
            },
            child: Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRequest(BuildContext context) async {
    try {
      final apiClient = ApiClient.instance;
      await apiClient.delete('/mobile/host/admin/contest-requests/${request['requestId']}');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('의뢰가 삭제되었습니다.')),
        );
        onStatusChange();
      }
    } catch (e) {
      if (context.mounted) {
        debugPrint('[Error] 삭제 실패: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제에 실패했습니다. 다시 시도해주세요.'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
