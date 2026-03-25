import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/portal_provider.dart';
import '../../../data/models/portal/portal_participant.dart';
import '../utils/portal_translations.dart';
import '../widgets/on_site_registration_modal.dart';

/// 포털 메인 화면
class PortalScreen extends ConsumerStatefulWidget {
  final int contestId;

  const PortalScreen({
    super.key,
    required this.contestId,
  });

  @override
  ConsumerState<PortalScreen> createState() => _PortalScreenState();
}

class _PortalScreenState extends ConsumerState<PortalScreen> {
  final _searchController = TextEditingController();
  final _passwordController = TextEditingController();
  String _language = 'ko';

  String t(String key) => PortalTranslations.get(_language, key);

  @override
  void dispose() {
    _searchController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portalProvider(widget.contestId));
    final notifier = ref.read(portalProvider(widget.contestId).notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: state.isLoading && state.contest == null
            ? _buildLoading()
            : state.error != null && state.contest == null
                ? _buildError(state.error!)
                : _buildContent(state, notifier),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(t('loading'), style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              error,
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('뒤로 가기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(PortalState state, PortalNotifier notifier) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 언어 선택
          _buildLanguageSelector(),
          const SizedBox(height: 16),

          // 대회 헤더
          _buildContestHeader(state),
          const SizedBox(height: 16),

          // 빠른 액션 버튼
          _buildQuickActions(),
          const SizedBox(height: 24),

          // 선택된 참가자 or 검색 폼
          if (state.selectedParticipant != null)
            _buildParticipantCard(state, notifier)
          else
            _buildSearchSection(state, notifier),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildLanguageButton('ko', '한국어'),
        const SizedBox(width: 8),
        _buildLanguageButton('en', 'EN'),
      ],
    );
  }

  Widget _buildLanguageButton(String code, String label) {
    final isSelected = _language == code;
    return InkWell(
      onTap: () {
        setState(() => _language = code);
        ref.read(portalProvider(widget.contestId).notifier).setLanguage(code);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildContestHeader(PortalState state) {
    final contest = state.contest;
    if (contest == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            contest.contestName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          if (contest.contestType != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                t('contestType_${contest.contestType}'),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.live_tv,
            label: t('viewLiveStatus'),
            color: AppColors.statusLive,
            onTap: () {
              // TODO: Live 화면으로 이동
              context.push('/live/${widget.contestId}');
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.person_add,
            label: t('onSiteRegistration'),
            color: AppColors.statusOpen,
            onTap: _showOnSiteRegistrationModal,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection(PortalState state, PortalNotifier notifier) {
    return Column(
      children: [
        // 검색 입력
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: t('searchPlaceholder'),
                    hintStyle: TextStyle(color: AppColors.textHint),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onSubmitted: (_) => _handleSearch(notifier),
                ),
              ),
              InkWell(
                onTap: () => _handleSearch(notifier),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    state.isLoading ? t('searching') : t('search'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 검색 결과
        if (state.searchResult != null) _buildSearchResults(state, notifier),
      ],
    );
  }

  void _handleSearch(PortalNotifier notifier) {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('enterName'))),
      );
      return;
    }
    notifier.searchParticipant(query);
  }

  Widget _buildSearchResults(PortalState state, PortalNotifier notifier) {
    final result = state.searchResult!;

    if (!result.found) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              result.message ?? t('noResults'),
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (result.multipleResults) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.message ?? '여러 명의 참가자가 검색되었습니다.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            ...result.participants.map((p) => _buildParticipantItem(p, notifier)),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildParticipantItem(PortalParticipant p, PortalNotifier notifier) {
    return InkWell(
      onTap: () => notifier.selectParticipant(p),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (p.maskedPhone != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      p.maskedPhone!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                p.sortName ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantCard(PortalState state, PortalNotifier notifier) {
    final participant = state.selectedParticipant!;
    final isCheckedIn = notifier.isCheckedInForToday;
    final isTodayContest = notifier.isTodayContestDate;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 참가자 이름 & 부문
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                participant.name,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.statusLiveBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  participant.sortName ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.statusLiveText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 현재 경기 정보
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildInfoRow(t('currentRound'), '${participant.currentRound}R'),
                if (participant.opponent != null)
                  _buildInfoRow(t('opponent'), participant.opponent!),
                if (participant.matchNumber != null && participant.matchNumber! > 0)
                  _buildInfoRow(t('matchNumber'), '${participant.matchNumber}'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 체크인 섹션
          if (participant.checkInEnabled) ...[
            if (isCheckedIn)
              _buildCheckedInStatus(notifier)
            else
              _buildCheckInButton(state, notifier, isTodayContest),
            const SizedBox(height: 20),
          ],

          // 버튼들
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    context.push(
                      '/portal/${widget.contestId}/detail',
                      extra: participant,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    t('viewDetail'),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    notifier.clearSelection();
                    _searchController.clear();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    t('newSearch'),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckedInStatus(PortalNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statusOpenBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.statusOpen.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: AppColors.statusOpen),
          const SizedBox(width: 8),
          Text(
            t('checkedIn'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.statusOpenText,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _showCancelCheckInDialog(notifier),
            child: Text(
              t('cancelCheckIn'),
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInButton(PortalState state, PortalNotifier notifier, bool isTodayContest) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: state.isLoading || !isTodayContest
            ? null
            : () async {
                final result = await notifier.checkIn();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result.success ? t('checkInSuccess') : (result.message ?? t('checkInFailed')),
                      ),
                      backgroundColor: result.success ? AppColors.success : AppColors.error,
                    ),
                  );
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: isTodayContest ? AppColors.primary : AppColors.textTertiary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          state.isLoading
              ? t('processing')
              : (isTodayContest ? t('checkIn') : t('notContestDate')),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showCancelCheckInDialog(PortalNotifier notifier) {
    _passwordController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('cancelCheckIn')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('enterPassword')),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: t('password'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('cancel')),
          ),
          TextButton(
            onPressed: () async {
              final password = _passwordController.text;
              if (password.isEmpty) return;

              Navigator.pop(context);
              final result = await notifier.cancelCheckIn(password);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.success ? t('checkInCancelled') : (result.message ?? t('cancelFailed')),
                    ),
                    backgroundColor: result.success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            child: Text(
              t('confirm'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showOnSiteRegistrationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OnSiteRegistrationModal(
        contestId: widget.contestId,
        language: _language,
      ),
    );
  }
}
