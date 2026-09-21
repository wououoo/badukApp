// 홈 '지금 할 일' 카드 — 있을 때만 뜨고, 없으면 자리를 차지하지 않는다.
//
// 이 카드는 홈 맨 위를 쓴다. 보여줄 게 없는데도 자리를 차지하면
// 대회를 둘러보러 온 사람의 화면을 빈 상자가 가린다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baduk_app/features/home/widgets/home_todo_section.dart';
import 'package:baduk_app/features/profile/screens/my_registrations_screen.dart'
    show myRegistrationsProvider;

void main() {
  String iso(Duration fromNow) => DateTime.now().add(fromNow).toIso8601String();

  Future<void> pump(
    WidgetTester tester,
    List<Map<String, dynamic>> list, {
    bool preview = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myRegistrationsProvider.overrideWith((ref) async => list),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeTodoSection(previewSample: preview),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Map<String, dynamic> waiting({
    required Duration due,
    String name = '태백 세계바둑콩그레스',
    int amount = 30000,
  }) {
    return {
      'registrationId': 1,
      'contestName': name,
      'categoryName': '일반부',
      'participantName': '김바둑',
      'status': 'APPROVED',
      'paymentStatus': 'WAITING_FOR_DEPOSIT',
      'fee': amount,
      'paidAmount': 0,
      'contestStartDate': iso(const Duration(days: 10)),
      'virtualAccount': {
        'amount': amount,
        'vaBankName': '국민은행',
        'vaAccountNumber': '12345678',
        'vaCustomerName': '김바둑',
        'vaDueDate': iso(due),
      },
      'homepageId': 1,
    };
  }

  Map<String, dynamic> paidUpcoming({required Duration startsIn}) {
    return {
      'registrationId': 2,
      'contestName': '다가오는 대회',
      'categoryName': '일반부',
      'participantName': '김바둑',
      'status': 'APPROVED',
      'paymentStatus': 'COMPLETED',
      'fee': 30000,
      'paidAmount': 30000,
      'contestStartDate': iso(startsIn),
      'homepageId': 1,
    };
  }

  testWidgets('할 일이 없으면 자리를 차지하지 않는다', (tester) async {
    await pump(tester, []);

    expect(find.byType(Card), findsNothing);
    expect(find.textContaining('입금'), findsNothing);
  });

  testWidgets('입금할 게 있으면 금액과 남은 시간이 뜬다', (tester) async {
    await pump(tester, [waiting(due: const Duration(minutes: 18))]);

    expect(find.textContaining('30,000'), findsWidgets);
    expect(find.text('태백 세계바둑콩그레스'), findsWidgets);
  });

  testWidgets('결제가 끝난 건은 입금 재촉을 하지 않는다', (tester) async {
    await pump(tester, [paidUpcoming(startsIn: const Duration(days: 3))]);

    expect(find.textContaining('입금'), findsNothing);
  });

  testWidgets('금액 표기에 원이 겹치지 않는다', (tester) async {
    await pump(tester, [waiting(due: const Duration(minutes: 18))]);
    expect(find.textContaining('원원'), findsNothing);
  });

  testWidgets('미리보기 스위치를 켜면 실데이터 없이도 그려진다', (tester) async {
    // 화면을 눈으로 확인하기 위한 자리. 배포 시에는 꺼져 있어야 한다.
    await pump(tester, [], preview: true);

    expect(find.byType(SizedBox), findsWidgets);
    expect(find.textContaining('원'), findsWidgets);
  });
}
