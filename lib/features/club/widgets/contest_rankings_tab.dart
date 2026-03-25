import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 순위 탭
class ContestRankingsTab extends StatelessWidget {
  final List<Map<String, dynamic>> rankings;
  final bool isTeamContest;
  final String currentType;
  final int teamSize;
  final String sortBy;
  final ValueChanged<String>? onSortByChanged;

  const ContestRankingsTab({
    super.key,
    required this.rankings,
    required this.isTeamContest,
    required this.currentType,
    required this.teamSize,
    this.sortBy = 'wins',
    this.onSortByChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (rankings.isEmpty) {
      return const Center(child: Text('라운드 결과가 저장되면 순위가 표시됩니다', textAlign: TextAlign.center));
    }
    return Column(
      children: [
        if (currentType == '맥마흔' && onSortByChanged != null)
          _buildSortToggle(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: rankings.length,
            itemBuilder: (context, index) => _buildRankingCard(index, rankings[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildSortToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSortButton('승수순', 'wins'),
                _buildSortButton('점수순', 'score'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton(String label, String value) {
    final isSelected = sortBy == value;
    return GestureDetector(
      onTap: () => onSortByChanged?.call(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.clubPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildRankingCard(int index, Map<String, dynamic> r) {
    final rank = (r['rank'] is num) ? (r['rank'] as num).toInt() : (index + 1);
    final name = isTeamContest
        ? (r['teamName']?.toString() ?? r['participantName']?.toString() ?? r['name']?.toString() ?? '')
        : (r['participantName']?.toString() ?? r['name']?.toString() ?? '');
    final totalWins = (r['totalWins'] ?? r['wins'] ?? 0);
    final totalPoints = r['totalPoints'] ?? r['winRate'] ?? r['sos'] ?? 0.0;
    final isNone = ((r['none'] is num) ? (r['none'] as num).toInt() : 0) > 0;
    final totalIndividualWins = r['totalIndividualWins'];

    List<int> boardWins = [];
    if (isTeamContest) {
      final ts = teamSize > 0 ? teamSize : 5;
      for (int i = 1; i <= ts; i++) {
        final pw = r['player${i}Wins'];
        boardWins.add((pw is num) ? pw.toInt() : 0);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6), elevation: 0,
      color: isNone ? AppColors.background : AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isNone ? AppColors.textTertiary.withOpacity(0.2) : AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: isTeamContest
            ? _buildTeamRankingRow(rank, name, totalWins, totalIndividualWins, boardWins, isNone)
            : (currentType == '더블엘리미네이션')
                ? _buildDERankingRow(rank, name, r)
                : (currentType == '맥마흔')
                    ? _buildMcMahonRankingRow(rank, name, r, isNone)
                    : Row(
                        children: [
                          _buildRankBadge(rank),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isNone ? AppColors.textTertiary : AppColors.textPrimary, decoration: isNone ? TextDecoration.lineThrough : null), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          _buildStatChip('승', (totalWins is num) ? (totalWins as num).toInt() : 0, isBold: true),
                          const SizedBox(width: 10),
                          _buildStatChip('SOS', 0, isBold: false, doubleValue: (r['useSwissLeague'] ?? r['sos'] ?? totalPoints) is num ? (r['useSwissLeague'] ?? r['sos'] ?? totalPoints).toDouble() : 0.0),
                          const SizedBox(width: 10),
                          _buildStatChip('SOSOS', 0, isBold: false, doubleValue: (r['sososPoints'] ?? r['sosos'] ?? 0) is num ? (r['sososPoints'] ?? r['sosos'] ?? 0).toDouble() : 0.0),
                        ],
                      ),
      ),
    );
  }

  Widget _buildMcMahonRankingRow(int rank, String name, Map<String, dynamic> r, bool isNone) {
    final mcMahonScore = (r['mcMahonScore'] is num) ? (r['mcMahonScore'] as num).toInt() : 0;
    final wins = (r['totalWins'] ?? r['wins'] ?? 0);
    final losses = (r['totalLosses'] ?? r['losses'] ?? 0);
    final sos = (r['useSwissLeague'] ?? r['sos'] ?? 0);

    return Row(
      children: [
        _buildRankBadge(rank),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isNone ? AppColors.textTertiary : AppColors.textPrimary, decoration: isNone ? TextDecoration.lineThrough : null), overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 6),
        _buildStatChip('점수', mcMahonScore, isBold: true),
        const SizedBox(width: 8),
        _buildStatChip('승', (wins is num) ? (wins as num).toInt() : 0),
        const SizedBox(width: 8),
        _buildStatChip('패', (losses is num) ? (losses as num).toInt() : 0),
        const SizedBox(width: 8),
        _buildStatChip('SOS', 0, doubleValue: (sos is num) ? sos.toDouble() : 0.0),
      ],
    );
  }

  Widget _buildDERankingRow(int rank, String name, Map<String, dynamic> r) {
    final wins = (r['wins'] is num) ? (r['wins'] as num).toInt() : 0;
    final losses = (r['losses'] is num) ? (r['losses'] as num).toInt() : 0;
    final status = r['status']?.toString() ?? '';

    Color statusColor;
    Color statusBg;
    if (status == '본선진출') {
      statusColor = AppColors.success;
      statusBg = AppColors.success.withOpacity(0.12);
    } else if (status == '탈락') {
      statusColor = Colors.red;
      statusBg = Colors.red.withOpacity(0.08);
    } else {
      statusColor = AppColors.textTertiary;
      statusBg = AppColors.textTertiary.withOpacity(0.08);
    }

    return Row(
      children: [
        _buildRankBadge(rank),
        const SizedBox(width: 10),
        Expanded(child: Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        SizedBox(width: 30, child: _buildStatChip('승', wins, isBold: true)),
        const SizedBox(width: 6),
        SizedBox(width: 30, child: _buildStatChip('패', losses)),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: status.isNotEmpty
              ? Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
                  child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildTeamRankingRow(int rank, String name, dynamic totalWins, dynamic totalIndividualWins, List<int> boardWins, bool isNone) {
    return Row(
      children: [
        _buildRankBadge(rank),
        const SizedBox(width: 10),
        Expanded(
          flex: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 24, maxWidth: 80),
            child: Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isNone ? AppColors.textTertiary : AppColors.textPrimary, decoration: isNone ? TextDecoration.lineThrough : null), overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 10),
        Text('${totalWins}승', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.clubPrimary)),
        const SizedBox(width: 10),
        Container(width: 1, height: 20, color: AppColors.border),
        const SizedBox(width: 6),
        Expanded(
          child: Row(
            children: [
              _buildStatChip('총', totalIndividualWins is num ? totalIndividualWins.toInt() : 0, isBold: true),
              ...boardWins.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _buildStatChip('${e.key + 1}장', e.value),
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, int value, {bool isBold = false, double? doubleValue}) {
    final displayText = doubleValue != null ? doubleValue.toStringAsFixed(1) : '$value';
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: isBold ? FontWeight.w600 : FontWeight.normal)),
        const SizedBox(height: 1),
        Text(displayText, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, color: isBold ? AppColors.clubPrimary : AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildRankBadge(int rank) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: _getRankColor(rank), borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.center,
      child: Text('$rank', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: rank <= 3 ? Colors.white : AppColors.textPrimary)),
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
}
