import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/club_contest_service.dart';

/// 클럽 이중 랭킹 화면 (Elo + 맥마흔 누적점수)
class ClubRankingsScreen extends StatefulWidget {
  final int clubId;

  const ClubRankingsScreen({super.key, required this.clubId});

  @override
  State<ClubRankingsScreen> createState() => _ClubRankingsScreenState();
}

class _ClubRankingsScreenState extends State<ClubRankingsScreen> with SingleTickerProviderStateMixin {
  final ClubContestService _service = ClubContestService();
  late TabController _tabController;

  List<Map<String, dynamic>> _eloRatings = [];
  List<Map<String, dynamic>> _mcMahonRatings = [];
  bool _isEloLoading = true;
  bool _isMcMahonLoading = true;
  String? _eloError;
  String? _mcMahonError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadEloRatings();
    _loadMcMahonRatings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEloRatings() async {
    setState(() { _isEloLoading = true; _eloError = null; });
    try {
      final result = await _service.getClubRatings(widget.clubId, type: 'elo');
      if (result['success'] == true) {
        setState(() {
          _eloRatings = (result['ratings'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _isEloLoading = false;
        });
      } else {
        setState(() { _eloError = result['message'] ?? '불러오기 실패'; _isEloLoading = false; });
      }
    } catch (e) {
      setState(() { _eloError = e.toString(); _isEloLoading = false; });
    }
  }

  Future<void> _loadMcMahonRatings() async {
    setState(() { _isMcMahonLoading = true; _mcMahonError = null; });
    try {
      final result = await _service.getClubRatings(widget.clubId, type: 'mcmahon');
      if (result['success'] == true) {
        setState(() {
          _mcMahonRatings = (result['ratings'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _isMcMahonLoading = false;
        });
      } else {
        setState(() { _mcMahonError = result['message'] ?? '불러오기 실패'; _isMcMahonLoading = false; });
      }
    } catch (e) {
      setState(() { _mcMahonError = e.toString(); _isMcMahonLoading = false; });
    }
  }

  void _showRatingHistory(int userId, String name, {required String type}) async {
    try {
      final result = await _service.getRatingHistory(widget.clubId, userId, type: type);
      if (!mounted) return;

      final currentRating = result['currentRating'] as int? ?? (type == 'mcmahon' ? 2500 : 1500);
      final wins = result['wins'] as int? ?? 0;
      final losses = result['losses'] as int? ?? 0;
      final history = (result['history'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final isMcMahon = type == 'mcmahon';

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.3,
            expand: false,
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatChip(
                          isMcMahon ? '맥마흔' : '레이팅',
                          '$currentRating',
                          AppColors.clubPrimary,
                        ),
                        const SizedBox(width: 12),
                        _buildStatChip('승', '$wins', AppColors.success),
                        const SizedBox(width: 12),
                        _buildStatChip('패', '$losses', AppColors.error),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isMcMahon ? '맥마흔 변동 히스토리' : 'Elo 변동 히스토리',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: history.isEmpty
                          ? const Center(child: Text('아직 기록이 없습니다.'))
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: history.length,
                              itemBuilder: (context, index) => _buildHistoryCard(history[index]),
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      debugPrint('[Error] 레이팅 히스토리 조회 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    }
  }

  Widget _buildHistoryCard(Map<String, dynamic> h) {
    final contestName = h['contestName'] as String? ?? '대회';
    final opponentName = h['opponentName'] as String? ?? '-';
    final resultStr = h['result'] as String? ?? '';
    final ratingChange = h['ratingChange'] as int? ?? 0;
    final round = h['round'] as int? ?? 0;

    final isPositive = ratingChange > 0;
    final isBye = resultStr == 'BYE';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isBye
                    ? AppColors.background
                    : isPositive
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                isBye ? '-' : isPositive ? '+$ratingChange' : '$ratingChange',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: isBye
                      ? AppColors.textTertiary
                      : isPositive ? AppColors.success : AppColors.error,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contestName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isBye ? '${round}R 부전승' : '${round}R vs $opponentName',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _getResultColor(resultStr).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _getResultLabel(resultStr),
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: _getResultColor(resultStr),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }

  String _getResultLabel(String result) {
    switch (result) {
      case 'WIN': return '승';
      case 'LOSS': return '패';
      case 'BYE': return '부전승';
      default: return result;
    }
  }

  Color _getResultColor(String result) {
    switch (result) {
      case 'WIN': return AppColors.success;
      case 'LOSS': return AppColors.error;
      case 'BYE': return AppColors.textTertiary;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 커스텀 탭 바
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: AppColors.clubPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: '클럽 점수 (Elo)'),
              Tab(text: '대회 맥마흔 점수'),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // 탭 콘텐츠
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildEloTab(),
              _buildMcMahonTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEloTab() {
    if (_isEloLoading) return const Center(child: CircularProgressIndicator());
    if (_eloError != null) return _buildErrorView(_eloError!, _loadEloRatings);
    if (_eloRatings.isEmpty) return _buildEmptyView();

    return RefreshIndicator(
      onRefresh: _loadEloRatings,
      color: AppColors.clubPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _eloRatings.length,
        itemBuilder: (context, index) {
          final r = _eloRatings[index];
          final rank = r['rank'] as int? ?? (index + 1);
          final name = r['name'] as String? ?? '알 수 없음';
          final rating = r['rating'] as int? ?? 1500;
          final wins = r['wins'] as int? ?? 0;
          final losses = r['losses'] as int? ?? 0;
          final gamesPlayed = r['gamesPlayed'] as int? ?? 0;
          final userId = r['userId'] as int? ?? 0;

          return _buildRankingCard(
            rank: rank,
            name: name,
            score: rating,
            wins: wins,
            losses: losses,
            gamesPlayed: gamesPlayed,
            onTap: () => _showRatingHistory(userId, name, type: 'elo'),
          );
        },
      ),
    );
  }

  Widget _buildMcMahonTab() {
    if (_isMcMahonLoading) return const Center(child: CircularProgressIndicator());
    if (_mcMahonError != null) return _buildErrorView(_mcMahonError!, _loadMcMahonRatings);
    if (_mcMahonRatings.isEmpty) return _buildEmptyView(message: '아직 맥마흔 대회 기록이 없습니다');

    return RefreshIndicator(
      onRefresh: _loadMcMahonRatings,
      color: AppColors.clubPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _mcMahonRatings.length,
        itemBuilder: (context, index) {
          final r = _mcMahonRatings[index];
          final rank = r['rank'] as int? ?? (index + 1);
          final name = r['name'] as String? ?? '알 수 없음';
          final mcMahonScore = r['mcMahonScore'] as int? ?? 2500;
          final userId = r['userId'] as int? ?? 0;
          final levelDisplay = r['levelDisplay'] as String?;

          return _buildMcMahonCard(
            rank: rank,
            name: name,
            score: mcMahonScore,
            levelDisplay: levelDisplay,
          );
        },
      ),
    );
  }

  Widget _buildRankingCard({
    required int rank,
    required String name,
    required int score,
    required int wins,
    required int losses,
    required int gamesPlayed,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildRankBadge(rank),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    Row(
                      children: [
                        Text(
                          '${wins}승 ${losses}패 (${gamesPlayed}국)',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(width: 6),
                          Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$score',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.clubPrimary),
                      ),
                      const SizedBox(width: 4),
                      if (wins > losses)
                        const Icon(Icons.arrow_upward, size: 16, color: AppColors.success)
                      else if (losses > wins)
                        const Icon(Icons.arrow_downward, size: 16, color: AppColors.error)
                      else if (gamesPlayed > 0)
                        Icon(Icons.remove, size: 16, color: AppColors.textTertiary),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  /// 맥마흔 전국 점수 전용 카드 (클럽 대전 기록 없음, 점수+기력만 표시)
  Widget _buildMcMahonCard({
    required int rank,
    required String name,
    required int score,
    String? levelDisplay,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildRankBadge(rank),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  if (levelDisplay != null)
                    Text(levelDisplay, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Text(
              '$score',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.clubPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: _getRankColor(rank),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.bold,
          color: rank <= 3 ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1: return const Color(0xFFFFD700);
      case 2: return const Color(0xFFC0C0C0);
      case 3: return const Color(0xFFCD7F32);
      default: return AppColors.background;
    }
  }

  Widget _buildErrorView(String error, VoidCallback retry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(error, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextButton(onPressed: retry, child: const Text('다시 시도')),
        ],
      ),
    );
  }

  Widget _buildEmptyView({String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard_outlined, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(message ?? '아직 레이팅 기록이 없습니다', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            '대회를 진행하고 종료하면 레이팅이 반영됩니다',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
