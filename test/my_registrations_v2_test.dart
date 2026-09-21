// 내 참가신청 목록(V2) — 무엇을 어느 칸에 넣는가.
//
// 이 화면의 값어치는 "지금 뭘 해야 하는지"를 위에 올려 주는 데 있다.
// 분류가 틀리면 입금 기한이 지난 뒤에야 알게 되므로, 경계값을 못 박아 둔다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baduk_app/features/profile/screens/my_registrations_screen.dart'
    show myRegistrationsProvider;
import 'package:baduk_app/features/profile/screens/my_registrations_screen_v2.dart';

void main() {
  /// 목록을 갈아끼워 화면을 띄운다. 서버를 부르지 않는다.
  Future<void> pump(WidgetTester tester, List<Map<String, dynamic>> list) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myRegistrationsProvider.overrideWith((ref) async => list),
        ],
        child: const MaterialApp(home: MyRegistrationsScreenV2()),
      ),
    );
    await tester.pump(); // Future 해소
  }

  String iso(Duration fromNow) =>
      DateTime.now().add(fromNow).toIso8601String();

  Map<String, dynamic> reg({
    required int id,
    String name = '테스트 대회',
    String category = '일반부',
    String status = 'APPROVED',
    String payment = 'COMPLETED',
    int fee = 30000,
    int paid = 30000,
    String? startDate,
    Map<String, dynamic>? va,
    List<Map<String, dynamic>> options = const [],
  }) {
    return {
      'registrationId': id,
      'contestName': name,
      'categoryName': category,
      'participantName': '김바둑',
      'status': status,
      'paymentStatus': payment,
      'fee': fee,
      'paidAmount': paid,
      'contestStartDate': startDate,
      if (va != null) 'virtualAccount': va,
      'options': options,
      'homepageId': 1,
    };
  }

  group('세 칸으로 나누기', () {
    testWidgets('입금 대기는 해야 할 일로 간다', (tester) async {
      await pump(tester, [
        reg(
          id: 1,
          payment: 'WAITING_FOR_DEPOSIT',
          paid: 0,
          startDate: iso(const Duration(days: 10)),
          va: {
            'amount': 30000,
            'vaBankName': '국민은행',
            'vaAccountNumber': '12345678',
            'vaCustomerName': '김바둑',
            'vaDueDate': iso(const Duration(minutes: 20)),
          },
        ),
      ]);

      expect(find.text('해야 할 일'), findsOneWidget);
      expect(find.text('예정'), findsNothing);
    });

    testWidgets('결제 끝나고 아직 안 열린 대회는 예정으로 간다', (tester) async {
      await pump(tester, [
        reg(id: 1, startDate: iso(const Duration(days: 10))),
      ]);

      expect(find.text('예정'), findsOneWidget);
      expect(find.text('해야 할 일'), findsNothing);
    });

    testWidgets('지난 대회는 아래로 내려간다', (tester) async {
      await pump(tester, [
        reg(id: 1, startDate: iso(const Duration(days: -10))),
      ]);

      expect(find.text('지난 · 취소'), findsOneWidget);
    });

    testWidgets('취소된 건은 날짜가 미래여도 지난 칸으로 간다', (tester) async {
      await pump(tester, [
        reg(
          id: 1,
          status: 'CANCELLED',
          payment: 'REFUNDED',
          startDate: iso(const Duration(days: 10)),
        ),
      ]);

      expect(find.text('지난 · 취소'), findsOneWidget);
      expect(find.text('예정'), findsNothing);
    });

    testWidgets('날짜를 모르면 지난 칸으로 밀지 않는다', (tester) async {
      // 아직 열릴 대회를 숨기는 쪽이 더 나쁜 실수다.
      await pump(tester, [reg(id: 1, startDate: null)]);

      expect(find.text('예정'), findsOneWidget);
      expect(find.text('지난 · 취소'), findsNothing);
    });

    testWidgets('취소된 건은 입금 대기여도 해야 할 일이 아니다', (tester) async {
      // 이미 취소된 신청에 입금을 재촉하면 안 된다.
      await pump(tester, [
        reg(
          id: 1,
          status: 'CANCELLED',
          payment: 'WAITING_FOR_DEPOSIT',
          paid: 0,
          startDate: iso(const Duration(days: 10)),
        ),
      ]);

      expect(find.text('해야 할 일'), findsNothing);
      expect(find.text('지난 · 취소'), findsOneWidget);
    });

    testWidgets('세 칸이 동시에 나온다', (tester) async {
      await pump(tester, [
        reg(id: 1, name: '지난것', startDate: iso(const Duration(days: -5))),
        reg(id: 2, name: '예정것', startDate: iso(const Duration(days: 5))),
        reg(
          id: 3,
          name: '입금할것',
          payment: 'WAITING_FOR_DEPOSIT',
          paid: 0,
          startDate: iso(const Duration(days: 3)),
          va: {
            'amount': 30000,
            'vaBankName': '국민은행',
            'vaAccountNumber': '111',
            'vaCustomerName': '김바둑',
            'vaDueDate': iso(const Duration(minutes: 25)),
          },
        ),
      ]);

      expect(find.text('해야 할 일'), findsOneWidget);
      expect(find.text('예정'), findsOneWidget);
      expect(find.text('지난 · 취소'), findsOneWidget);
    });
  });

  group('급한 카드', () {
    Map<String, dynamic> waiting(int id, String name, Duration due) => reg(
          id: id,
          name: name,
          payment: 'WAITING_FOR_DEPOSIT',
          paid: 0,
          startDate: iso(const Duration(days: 5)),
          va: {
            'amount': 30000,
            'vaBankName': '국민은행',
            'vaAccountNumber': '12345678',
            'vaCustomerName': '김바둑',
            'vaDueDate': iso(due),
          },
        );

    testWidgets('계좌와 금액이 목록에서 바로 보인다', (tester) async {
      await pump(tester, [waiting(1, '급한대회', const Duration(minutes: 20))]);

      expect(find.text('입금 대기'), findsOneWidget);
      expect(find.text('30,000원'), findsOneWidget);
      expect(find.textContaining('국민은행'), findsOneWidget);
      expect(find.text('복사'), findsOneWidget);
      expect(find.textContaining('예금주'), findsOneWidget);
    });

    testWidgets('반상 카드는 하나뿐이다', (tester) async {
      // 검은 면이 여럿이면 어디를 봐야 할지 알 수 없다.
      await pump(tester, [
        waiting(1, '먼저', const Duration(minutes: 10)),
        waiting(2, '나중', const Duration(minutes: 25)),
      ]);

      // '입금 대기' 머리표는 반상 카드에만 붙는다 → 하나뿐이어야 한다.
      expect(find.text('입금 대기'), findsOneWidget);
      // 둘째 건도 목록에는 남아 있어야 한다(감추는 게 아니라 표현만 낮춘다).
      expect(find.text('먼저'), findsOneWidget);
      expect(find.text('나중'), findsOneWidget);
    });

    testWidgets('기한이 지나면 남은 시간 대신 지났다고 알린다', (tester) async {
      await pump(tester, [waiting(1, '놓친대회', const Duration(minutes: -3))]);

      expect(find.text('기한 지남'), findsOneWidget);
    });
  });

  group('카드 내용', () {
    testWidgets('신청한 추가 항목이 목록에서 보인다', (tester) async {
      await pump(tester, [
        reg(
          id: 1,
          startDate: iso(const Duration(days: 5)),
          options: [
            {
              'optionKey': 'lunch',
              'optionLabel': '점심',
              'choiceValue': 'd1',
              'choiceLabel': '1일차',
              'quantity': 1,
            },
          ],
        ),
      ]);

      expect(find.textContaining('점심'), findsOneWidget);
    });

    testWidgets('미납이 있으면 미납 금액을 앞세운다', (tester) async {
      await pump(tester, [
        reg(
          id: 1,
          payment: 'PENDING',
          fee: 30000,
          paid: 0,
          startDate: iso(const Duration(days: 5)),
        ),
      ]);

      expect(find.text('미납'), findsOneWidget);
      expect(find.text('30,000원'), findsOneWidget);
    });

    testWidgets('금액 표기에 원이 겹치지 않는다', (tester) async {
      await pump(tester, [
        reg(id: 1, startDate: iso(const Duration(days: 5))),
      ]);

      expect(find.textContaining('원원'), findsNothing);
      expect(find.textContaining('₩'), findsNothing);
    });
  });

  testWidgets('아무것도 없으면 대회를 보러 갈 길을 준다', (tester) async {
    await pump(tester, []);

    expect(find.text('아직 신청한 대회가 없습니다'), findsOneWidget);
    expect(find.text('대회 둘러보기'), findsOneWidget);
  });
}
