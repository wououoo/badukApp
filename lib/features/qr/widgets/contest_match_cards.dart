import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
// 모델은 전부 여기 정의돼 있다 (화면 파일과 같은 출처를 쓴다)
import '../../../data/services/mobile_qr_service.dart';

/// 대회 상세 화면의 순수 렌더 위젯 모음.
///
/// my_contest_detail_screen.dart가 3,200줄을 넘겨 어디를 고치면 무엇이 바뀌는지 알기 어려웠다.
/// 여기 모인 함수들은 상태(ref·setState)나 context를 전혀 쓰지 않고 인자만으로 그리므로,
/// 화면에서 떼어내도 동작이 같다. 화면에는 상태를 다루는 코드만 남는다.

Widget buildTeamMatchCard(TeamFullLeagueMatch match) {
  final team1 = match.team1Name;
  final team2 = match.team2Name;
  final t1Wins = match.team1Wins;
  final t2Wins = match.team2Wins;
  final isTeam1Winner = match.isCompleted && match.winnerTeamId != null && match.winnerTeamId == match.team1Id;
  final isTeam2Winner = match.isCompleted && match.winnerTeamId != null && match.winnerTeamId == match.team2Id;

  // BYE 매치
  if (match.isBye) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                team1,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '부전승',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }

  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: match.isCompleted ? AppColors.border : AppColors.info.withValues(alpha: 0.3),
      ),
    ),
    color: AppColors.surface,
    child: Column(
      children: [
        // 팀 매치 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Row(
            children: [
              // 팀1
              Expanded(
                child: Column(
                  children: [
                    Text(
                      team1,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isTeam1Winner ? FontWeight.bold : FontWeight.w500,
                        color: isTeam1Winner ? AppColors.primary : (isTeam2Winner ? AppColors.textTertiary : AppColors.textPrimary),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (match.isCompleted && isTeam1Winner)
                      buildResultBadge('승', AppColors.info),
                    if (match.isCompleted && isTeam2Winner)
                      buildResultBadge('패', AppColors.error),
                  ],
                ),
              ),
              // 스코어
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: match.isCompleted
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$t1Wins : $t2Wins',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: match.isCompleted ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
              // 팀2
              Expanded(
                child: Column(
                  children: [
                    Text(
                      team2,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isTeam2Winner ? FontWeight.bold : FontWeight.w500,
                        color: isTeam2Winner ? AppColors.primary : (isTeam1Winner ? AppColors.textTertiary : AppColors.textPrimary),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (match.isCompleted && isTeam2Winner)
                      buildResultBadge('승', AppColors.info),
                    if (match.isCompleted && isTeam1Winner)
                      buildResultBadge('패', AppColors.error),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 상태 표시
        if (match.isCompleted)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '종료',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.success),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '진행중',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.info),
              ),
            ),
          ),

        // 기별 상세 결과
        if (match.boards.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: match.boards.map((board) => buildBoardResultRow(board)).toList(),
            ),
          ),
        ],
      ],
    ),
  );
}

/// 기별 결과 행

Widget buildBoardResultRow(BoardResult board) {
  final p1 = board.team1MemberName ?? '-';
  final p2 = board.team2MemberName ?? '-';
  final isP1Winner = board.isCompleted && board.winnerMemberId != null && board.winnerMemberId == board.team1MemberId;
  final isP2Winner = board.isCompleted && board.winnerMemberId != null && board.winnerMemberId == board.team2MemberId;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        // 기 번호
        Container(
          width: 30,
          alignment: Alignment.center,
          child: Text(
            '${board.boardNumber}장',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 4),
        // 선수1
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isP1Winner)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: buildSmallResultBadge('승', AppColors.info),
                ),
              if (isP2Winner)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: buildSmallResultBadge('패', AppColors.error),
                ),
              Flexible(
                child: Text(
                  p1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isP1Winner ? FontWeight.w600 : FontWeight.normal,
                    color: isP1Winner ? AppColors.primary : (isP2Winner ? AppColors.textTertiary : AppColors.textPrimary),
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // vs
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'vs',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ),
        // 선수2
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  p2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isP2Winner ? FontWeight.w600 : FontWeight.normal,
                    color: isP2Winner ? AppColors.primary : (isP1Winner ? AppColors.textTertiary : AppColors.textPrimary),
                  ),
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isP2Winner)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: buildSmallResultBadge('승', AppColors.info),
                ),
              if (isP1Winner)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: buildSmallResultBadge('패', AppColors.error),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 작은 승/패 뱃지 (기별 결과용)

Widget buildSmallResultBadge(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}

/// 풀리그 전체 스케줄 기반 대진표 탭

Widget buildFullLeagueMatchCard(FullLeagueMatch match, int tableNumber) {
  if (match.isBye) {
    // 부전승 카드
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            buildTableNumber(tableNumber),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                match.player1,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '부전승',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }

  final isPlayer1Winner = match.isCompleted && !match.isNone && match.winnerId != null && match.winnerId == match.player1Id;
  final isPlayer2Winner = match.isCompleted && !match.isNone && match.winnerId != null && match.winnerId == match.player2Id;

  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: match.isCompleted ? AppColors.border : AppColors.info.withValues(alpha: 0.3),
      ),
    ),
    color: AppColors.surface,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          buildTableNumber(tableNumber),
          const SizedBox(width: 10),
          // Player 1
          Expanded(
            child: buildPlayerCell(
              name: match.player1,
              isWinner: isPlayer1Winner,
              isLoser: isPlayer2Winner,
              isCompleted: match.isCompleted,
              align: TextAlign.right,
            ),
          ),
          // 중앙 VS / 상태
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: match.isCompleted
                ? Container(
                    width: 44,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('vs', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: (match.isNone ? AppColors.error : AppColors.success).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            match.isNone ? '양패' : '종료',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: match.isNone ? AppColors.error : AppColors.success),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    width: 44,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('vs', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.textTertiary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '예정',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textTertiary),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          // Player 2
          Expanded(
            child: buildPlayerCell(
              name: match.player2,
              isWinner: isPlayer2Winner,
              isLoser: isPlayer1Winner,
              isCompleted: match.isCompleted,
              align: TextAlign.left,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 쉬는 선수 카드 (풀리그 홀수 인원)

Widget buildRestingPlayerCard(String playerName) {
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: AppColors.warning.withValues(alpha: 0.3)),
    ),
    color: AppColors.warning.withValues(alpha: 0.05),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.pause_circle_outline, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Text(
            '$playerName - 이번 라운드 쉼',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.warning),
          ),
        ],
      ),
    ),
  );
}

Widget buildResultBadge(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}

// ==================== 순위표 탭 ====================

Widget buildTableNumber(int number) {
  return Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    alignment: Alignment.center,
    child: Text(
      '$number',
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
    ),
  );
}

/// 선수 이름 + 승/패 뱃지

Widget buildPlayerCell({
  required String name,
  required bool isWinner,
  required bool isLoser,
  required bool isCompleted,
  required TextAlign align,
}) {
  final isLeft = align == TextAlign.left;

  return Row(
    mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
    children: [
      // 오른쪽 정렬일 때 뱃지가 이름 앞에
      if (!isLeft && isCompleted) ...[
        if (isWinner) buildResultBadge('승', AppColors.info),
        if (isLoser) buildResultBadge('패', AppColors.error),
        const SizedBox(width: 6),
      ],
      Flexible(
        child: Text(
          name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
            color: isWinner
                ? AppColors.primary
                : isLoser
                    ? AppColors.textTertiary
                    : AppColors.textPrimary,
          ),
          textAlign: align,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      // 왼쪽 정렬일 때 뱃지가 이름 뒤에
      if (isLeft && isCompleted) ...[
        const SizedBox(width: 6),
        if (isWinner) buildResultBadge('승', AppColors.info),
        if (isLoser) buildResultBadge('패', AppColors.error),
      ],
    ],
  );
}

/// 승/패 결과 뱃지
