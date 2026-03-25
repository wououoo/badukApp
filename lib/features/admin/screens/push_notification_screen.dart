import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/api/api_client.dart';
import '../../../data/providers/auth_provider.dart';

/// 푸시 발송 통계 Provider (관리자용)
final pushStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final apiClient = ApiClient.instance;
  final response = await apiClient.get('/admin/fcm/stats');
  return response.data;
});

/// 내 대회 목록 Provider (주최자용 - 자기 대회만)
final myContestsForPushProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final apiClient = ApiClient.instance;
  final response = await apiClient.get('/mobile/host/fcm/my-contests');
  return (response.data['contests'] as List?)?.cast<Map<String, dynamic>>() ?? [];
});

/// 푸시 알림 발송 화면
/// - 주최자: 자기 대회 참가자에게만 발송
/// - 관리자: 모든 대회 + 전체 사용자 발송
class PushNotificationScreen extends ConsumerStatefulWidget {
  const PushNotificationScreen({super.key});

  @override
  ConsumerState<PushNotificationScreen> createState() => _PushNotificationScreenState();
}

class _PushNotificationScreenState extends ConsumerState<PushNotificationScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  String _targetType = 'contest'; // 'contest' or 'all' (관리자만)
  Map<String, dynamic>? _selectedContest;
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendPush() async {
    final authState = ref.read(authProvider);
    final isAdmin = authState.user?.isAdmin ?? false;

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 입력해주세요.')),
      );
      return;
    }

    if (_targetType == 'contest' && _selectedContest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('대회를 선택해주세요.')),
      );
      return;
    }

    // 전체 발송은 관리자만
    if (_targetType == 'all' && !isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전체 발송은 관리자만 가능합니다.')),
      );
      return;
    }

    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('푸시 알림 발송'),
        content: Text(
          _targetType == 'all'
              ? '전체 사용자에게 푸시 알림을 발송하시겠습니까?'
              : '${_selectedContest!['contestName']} 참가자에게 푸시 알림을 발송하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('발송', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSending = true);

    try {
      final apiClient = ApiClient.instance;

      // 관리자 전체 발송: /api/admin/fcm/broadcast
      // 대회 참가자 발송: /api/mobile/host/fcm/contest/{homepageId} (주최자용)
      final endpoint = _targetType == 'all'
          ? '/admin/fcm/broadcast'
          : '/mobile/host/fcm/contest/${_selectedContest!['homepageId']}';

      final response = await apiClient.post(endpoint, data: {
        'title': title,
        'body': body,
      });

      if (mounted) {
        final success = response.data['success'] as bool? ?? false;
        final message = response.data['message'] as String? ?? '발송 완료';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );

        if (success) {
          _titleController.clear();
          _bodyController.clear();
          setState(() => _selectedContest = null);
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('[Error] 발송 실패: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('발송에 실패했습니다. 다시 시도해주세요.'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.user?.isAdmin ?? false;
    final contestsAsync = ref.watch(myContestsForPushProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('푸시 알림 발송'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 통계 (관리자만)
            if (isAdmin) ...[
              Consumer(
                builder: (context, ref, _) {
                  final statsAsync = ref.watch(pushStatsProvider);
                  return statsAsync.when(
                    data: (stats) => _buildStatsCard(stats),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            // 발송 대상 선택
            const Text(
              '발송 대상',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTargetSelector(contestsAsync, isAdmin),
            const SizedBox(height: 24),

            // 빠른 템플릿
            const Text(
              '빠른 템플릿',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTemplates(),
            const SizedBox(height: 24),

            // 메시지 입력
            const Text(
              '알림 내용',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildMessageForm(),
            const SizedBox(height: 24),

            // 미리보기
            _buildPreview(),
            const SizedBox(height: 24),

            // 발송 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendPush,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '푸시 알림 발송',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStatsCard(Map<String, dynamic> stats) {
    final totalUsers = stats['totalUsers'] as int? ?? 0;
    final pushEnabledUsers = stats['pushEnabledUsers'] as int? ?? 0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Icon(Icons.people, size: 32, color: AppColors.textSecondary),
                  const SizedBox(height: 8),
                  Text(
                    '$totalUsers',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '전체 사용자',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 60,
              color: AppColors.divider,
            ),
            Expanded(
              child: Column(
                children: [
                  Icon(Icons.notifications_active, size: 32, color: AppColors.success),
                  const SizedBox(height: 8),
                  Text(
                    '$pushEnabledUsers',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '푸시 가능',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetSelector(AsyncValue<List<Map<String, dynamic>>> contestsAsync, bool isAdmin) {
    return Column(
      children: [
        // 대상 유형 선택 (관리자만 전체 발송 옵션)
        if (isAdmin) ...[
          Row(
            children: [
              Expanded(
                child: _buildTargetTypeButton(
                  label: '대회 참가자',
                  value: 'contest',
                  icon: Icons.emoji_events,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTargetTypeButton(
                  label: '전체 사용자',
                  value: 'all',
                  icon: Icons.public,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // 대회 선택 (대회 참가자 선택 시)
        if (_targetType == 'contest')
          contestsAsync.when(
            data: (contests) {
              if (contests.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Center(
                    child: Text(
                      '관리 중인 대회가 없습니다',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }
              return _buildContestDropdown(contests);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const Text('오류가 발생했습니다'),
          ),
      ],
    );
  }

  Widget _buildTargetTypeButton({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _targetType == value;
    return InkWell(
      onTap: () => setState(() {
        _targetType = value;
        if (value == 'all') _selectedContest = null;
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContestDropdown(List<Map<String, dynamic>> contests) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          isExpanded: true,
          hint: const Text('대회를 선택하세요'),
          value: _selectedContest,
          items: contests.map((contest) {
            final name = contest['contestName'] as String? ?? '제목 없음';
            final count = contest['participantCount'] as int? ?? 0;
            return DropdownMenuItem(
              value: contest,
              child: Text('$name ($count명)'),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedContest = value),
        ),
      ),
    );
  }

  /// 대회명 가져오기 (선택된 대회 or 기본값)
  String get _contestName {
    if (_selectedContest != null) {
      return _selectedContest!['contestName'] as String? ?? '대회';
    }
    return '대회';
  }

  Widget _buildTemplates() {
    final templates = [
      {'label': '대진표 공개', 'title': '대진표 공개', 'body': '[${_contestName}] 대진표가 공개되었습니다. 앱에서 확인해주세요.'},
      {'label': '결과 발표', 'title': '결과 발표', 'body': '[${_contestName}] 경기 결과가 등록되었습니다. 앱에서 순위를 확인해주세요.'},
      {'label': '다음 라운드', 'title': '다음 라운드 안내', 'body': '[${_contestName}] 다음 라운드가 곧 시작됩니다. 대진표를 확인해주세요.'},
      {'label': '체크인 안내', 'title': '체크인 안내', 'body': '[${_contestName}] 체크인이 시작되었습니다. 대회장에서 체크인해주세요.'},
      {'label': '대회 시작', 'title': '대회 시작', 'body': '[${_contestName}] 대회가 곧 시작됩니다. 대회장으로 이동해주세요.'},
      {'label': '대회 종료', 'title': '대회 종료', 'body': '[${_contestName}] 대회가 종료되었습니다. 참가해주셔서 감사합니다.'},
      {'label': '점심시간', 'title': '점심시간', 'body': '[${_contestName}] 점심시간입니다. 식사 후 시간에 맞춰 대회장으로 돌아와주세요.'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: templates.map((tpl) {
        final isSelected = _titleController.text == tpl['title'] &&
            _bodyController.text == tpl['body'];
        return GestureDetector(
          onTap: () {
            setState(() {
              _titleController.text = tpl['title']!;
              _bodyController.text = tpl['body']!;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.divider,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              tpl['label']!,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMessageForm() {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: '제목',
            hintText: '알림 제목을 입력하세요',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bodyController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: '내용',
            hintText: '알림 내용을 입력하세요',
            alignLabelWithHint: true,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty && body.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '미리보기',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.notifications, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isNotEmpty ? title : '제목',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body.isNotEmpty ? body : '내용',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
