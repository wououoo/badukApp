import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/api_client.dart';
import '../../../data/providers/contest_request_provider.dart';

/// 의뢰 상세 조회 Provider
final requestDetailProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, requestId) async {
  final apiClient = ApiClient.instance;
  final response = await apiClient.get('/mobile/host/contest-requests/$requestId');
  return response.data;
});

/// 의뢰 상세 화면
class RequestDetailScreen extends ConsumerWidget {
  final int requestId;

  const RequestDetailScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(requestDetailProvider(requestId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('의뢰 상세'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: detailAsync.when(
        data: (data) => _buildContent(context, ref, data),
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
                onPressed: () => ref.invalidate(requestDetailProvider(requestId)),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'PENDING';
    final statusText = data['statusText'] as String? ?? '검토 대기';
    final attachments = data['attachments'] as List? ?? [];
    final categories = data['categories'] as List? ?? [];
    final homepageUrl = data['homepageUrl'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상태 카드
          _buildStatusCard(context, status, statusText, homepageUrl),
          const SizedBox(height: 20),

          // 기본 정보
          _buildSection('대회 정보', [
            _buildInfoRow('대회명', data['title']),
            if (data['schedule'] != null)
              _buildInfoRow('일시', data['schedule']),
            if (data['organizer'] != null)
              _buildInfoRow('주최', data['organizer']),
            if (data['venue'] != null)
              _buildInfoRow('장소', data['venue']),
            if (data['participationFee'] != null)
              _buildInfoRow('참가비', data['participationFee']),
            if (data['contactInfo'] != null)
              _buildInfoRow('문의처', data['contactInfo']),
          ]),

          // 부문
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSection('부문', [
              ...categories.map((cat) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(cat['categoryName'] ?? ''),
                    const Spacer(),
                    Text(
                      _getContestTypeLabel(cat['contestType']),
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              )),
            ]),
          ],

          // 첨부파일
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSection('첨부파일', [
              ...attachments.map((file) => _buildFileItem(context, ref, file)),
            ]),
          ],

          // 추가 요청사항
          if (data['additionalNotes'] != null && data['additionalNotes'].toString().isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSection('추가 요청사항', [
              Text(
                data['additionalNotes'],
                style: const TextStyle(fontSize: 14),
              ),
            ]),
          ],

          // 의뢰 정보
          const SizedBox(height: 20),
          _buildSection('의뢰 정보', [
            _buildInfoRow('의뢰자', data['userName'] ?? '-'),
            _buildInfoRow('연락처', data['userPhone'] ?? '-'),
            _buildInfoRow('의뢰일', _formatDate(data['createdAt'])),
          ]),

          // PENDING 상태일 때만 수정/삭제 버튼 표시
          if (status == 'PENDING') ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/host/edit-request/$requestId'),
                    icon: const Icon(Icons.edit),
                    label: const Text('수정'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteDialog(context, ref),
                    icon: const Icon(Icons.delete),
                    label: const Text('삭제'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('의뢰 삭제'),
        content: const Text('정말 이 의뢰를 삭제하시겠습니까?\n삭제된 의뢰는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteRequest(context, ref);
            },
            child: Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRequest(BuildContext context, WidgetRef ref) async {
    try {
      final apiClient = ApiClient.instance;
      await apiClient.delete('/mobile/host/contest-requests/$requestId');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('의뢰가 삭제되었습니다.')),
        );
        ref.invalidate(myContestRequestsProvider);
        context.pop();
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

  Widget _buildStatusCard(BuildContext context, String status, String statusText, String? homepageUrl) {
    Color color;
    IconData icon;
    String description;

    switch (status) {
      case 'PENDING':
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        description = '의뢰가 접수되었습니다. 확인 후 연락드리겠습니다.';
        break;
      case 'IN_PROGRESS':
        color = Colors.blue;
        icon = Icons.build;
        description = '홈페이지 제작이 진행 중입니다.';
        break;
      case 'COMPLETED':
        color = AppColors.success;
        icon = Icons.check_circle;
        description = '홈페이지 제작이 완료되었습니다!';
        break;
      case 'REJECTED':
        color = AppColors.error;
        icon = Icons.cancel;
        description = '죄송합니다. 의뢰가 거절되었습니다.';
        break;
      default:
        color = AppColors.textSecondary;
        icon = Icons.info;
        description = '';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(fontSize: 14, color: color.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 완료 상태이고 홈페이지 URL이 있으면 링크 표시
          if (status == 'COMPLETED' && homepageUrl != null && homepageUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final url = Uri.parse(homepageUrl);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('홈페이지 바로가기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(BuildContext context, WidgetRef ref, Map<String, dynamic> file) {
    final originalFilename = file['originalFilename'] as String? ?? '파일';
    final path = file['path'] as String? ?? '';

    // 파일명에서 UUID 파일명 추출
    final filename = path.split('/').last.split('\\').last;

    IconData icon = Icons.insert_drive_file;
    if (originalFilename.endsWith('.hwp') || originalFilename.endsWith('.hwpx')) {
      icon = Icons.description;
    } else if (originalFilename.endsWith('.pdf')) {
      icon = Icons.picture_as_pdf;
    } else if (originalFilename.endsWith('.jpg') || originalFilename.endsWith('.png') || originalFilename.endsWith('.jpeg')) {
      icon = Icons.image;
    }

    return InkWell(
      onTap: () => _downloadFile(context, ref, filename, originalFilename),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                originalFilename,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.download, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadFile(BuildContext context, WidgetRef ref, String filename, String originalFilename) async {
    try {
      // 토큰 가져오기
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: AppConstants.accessTokenKey);

      if (token == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다.')),
          );
        }
        return;
      }

      // 다운로드 URL 구성 (토큰을 쿼리 파라미터로 추가)
      final downloadUrl = '${ApiConstants.baseUrl}/mobile/host/contest-requests/$requestId/files/$filename?token=$token';

      // URL을 열어서 다운로드 (브라우저에서 처리)
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('파일을 열 수 없습니다: $originalFilename')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        debugPrint('[Error] 다운로드 실패: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('다운로드에 실패했습니다. 다시 시도해주세요.'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _getContestTypeLabel(String? type) {
    switch (type) {
      case 'MCM':
        return '맥마흔';
      case 'SWISS':
        return '스위스리그';
      case 'FULL_LEAGUE':
        return '풀리그';
      case 'DE':
        return '더블엘리미네이션';
      case 'TEAM_SWISS':
        return '단체전';
      default:
        return type ?? '';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}
