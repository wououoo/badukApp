// 라이브 순위(V2) — 내 줄과 내 다음 판.
//
// 대회장에서 폰을 보는 이유는 사실상 "내가 몇 위인가"와 "몇 번 자리로 가나" 둘뿐이다.
// 이름으로 나를 찾으므로, 못 찾는 경우와 잘못 찾는 경우를 못 박아 둔다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baduk_app/data/models/live_contest.dart';
import 'package:baduk_app/data/models/user.dart';
import 'package:baduk_app/data/providers/auth_provider.dart';
import 'package:baduk_app/data/services/live_contest_service.dart';
import 'package:baduk_app/features/live/widgets/live_sort_content_v2.dart';

/// 서버 대신 정해진 값을 돌려주는 가짜 서비스.
class _FakeLiveService extends LiveContestService {
  _FakeLiveService({required this.rankings, required this.pairings});

  final List<LiveStanding> rankings;
  final List<LivePairing> pairings;

  @override
  Future<List<LiveStanding>> getRankings(int contestId, int sortId) async =>
      rankings;

  @override
  Future<LivePairingsResponse> getPairings(int contestId, int sortId) async =>
      LivePairingsResponse(
        pairings: pairings,
        maxRound: 3,
        round: 1,
        contestType: 'SWISS',
      );
}

void main() {
  LiveStanding standing(String name, int rank, {int wins = 0, int losses = 0}) =>
      LiveStanding(rank: rank, name: name, wins: wins, losses: losses);

  LivePairing pairing({
    required String p1,
    required String p2,
    int round = 1,
    int? table,
    bool completed = false,
    bool bye = false,
  }) =>
      LivePairing(
        round: round,
        tableNumber: table,
        player1Name: p1,
        player2Name: p2,
        isCompleted: completed,
        isByeMatch: bye,
      );

  /// 로그인 이름을 갈아끼우고 위젯을 띄운다.
  Future<void> pump(
    WidgetTester tester, {
    required String? myName,
    required List<LiveStanding> rankings,
    required List<LivePairing> pairings,
    String contestType = 'SWISS',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => myName == null ? null : User(id: 1, name: myName),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: LiveSortContentV2(
              contestId: 1,
              sortId: 1,
              contestType: contestType,
              autoRefresh: false,
              serviceOverride:
                  _FakeLiveService(rankings: rankings, pairings: pairings),
            ),
          ),
        ),
      ),
    );
    await tester.pump(); // 로딩 해소
    await tester.pump();
  }

  group('내 현황 바', () {
    testWidgets('내 순위와 전적이 위에 뜬다', (tester) async {
      await pump(
        tester,
        myName: '김바둑',
        rankings: [
          standing('이알파', 1, wins: 3),
          standing('김바둑', 2, wins: 2, losses: 1),
        ],
        pairings: [],
      );

      expect(find.text('나'), findsOneWidget);
      expect(find.text('김바둑'), findsWidgets);
      expect(find.textContaining('2위'), findsOneWidget);
      expect(find.textContaining('2승 1패'), findsOneWidget);
    });

    testWidgets('다음 판의 상대와 자리 번호가 뜬다', (tester) async {
      await pump(
        tester,
        myName: '김바둑',
        rankings: [standing('김바둑', 1)],
        pairings: [
          pairing(p1: '김바둑', p2: '박지훈', round: 2, table: 12),
        ],
      );

      expect(find.textContaining('박지훈'), findsWidgets);
      expect(find.text('12번'), findsOneWidget);
    });

    testWidgets('끝난 판은 다음 판이 아니다', (tester) async {
      await pump(
        tester,
        myName: '김바둑',
        rankings: [standing('김바둑', 1)],
        pairings: [
          pairing(p1: '김바둑', p2: '이미끝남', round: 1, table: 3, completed: true),
          pairing(p1: '김바둑', p2: '다음상대', round: 2, table: 7),
        ],
      );

      expect(find.text('7번'), findsOneWidget);
      expect(find.text('3번'), findsNothing);
    });

    testWidgets('여러 판이 남았으면 이른 라운드가 먼저다', (tester) async {
      await pump(
        tester,
        myName: '김바둑',
        rankings: [standing('김바둑', 1)],
        pairings: [
          pairing(p1: '나중상대', p2: '김바둑', round: 3, table: 9),
          pairing(p1: '김바둑', p2: '먼저상대', round: 2, table: 4),
        ],
      );

      expect(find.text('4번'), findsOneWidget);
      expect(find.text('9번'), findsNothing);
    });

    testWidgets('부전승이면 상대 대신 부전승이라고 적는다', (tester) async {
      await pump(
        tester,
        myName: '김바둑',
        rankings: [standing('김바둑', 1)],
        pairings: [pairing(p1: '김바둑', p2: '', round: 2, bye: true)],
      );

      expect(find.textContaining('부전승'), findsOneWidget);
    });

    testWidgets('이 부문에 내가 없으면 아무것도 안 뜬다', (tester) async {
      // 남의 대회를 볼 때 빈 검은 상자가 뜨면 방해만 된다.
      await pump(
        tester,
        myName: '김바둑',
        rankings: [standing('이알파', 1), standing('박지훈', 2)],
        pairings: [pairing(p1: '이알파', p2: '박지훈')],
      );

      expect(find.text('나'), findsNothing);
    });

    testWidgets('로그인하지 않았으면 아무것도 안 뜬다', (tester) async {
      await pump(
        tester,
        myName: null,
        rankings: [standing('김바둑', 1)],
        pairings: [],
      );

      expect(find.text('나'), findsNothing);
    });
  });

  group('단체전', () {
    testWidgets('팀 순위표에서는 내 이름으로 강조하지 않는다', (tester) async {
      // 그 줄은 팀 이름이라 사람 이름과 맞지 않는다.
      await pump(
        tester,
        myName: '김바둑',
        contestType: 'TEAM_SWISS',
        rankings: [standing('김바둑', 1)], // 우연히 팀명이 같은 경우
        pairings: [],
      );

      expect(find.text('나'), findsNothing);
    });
  });
}
