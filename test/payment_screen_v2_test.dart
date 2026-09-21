// 결제 화면(V2) — 무엇을 내는지, 언제까지인지.
//
// 옛 화면은 "2시간 내에 입금"이라고 알렸지만 서버는 30분이었다
// (PaymentController.VIRTUAL_ACCOUNT_VALID_MINUTES = 30).
// 2시간인 줄 알고 미루면 신청이 취소되므로, 이 숫자가 다시 틀어지지 않게 못 박는다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baduk_app/features/payment/screens/payment_screen_v2.dart';

void main() {
  Future<void> pump(WidgetTester tester, {int amount = 30000}) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PaymentScreenV2(
            existingRegistrationId: 1,
            participantName: '김바둑',
            categoryName: '일반부',
            contestName: '태백 세계바둑콩그레스',
            amount: amount,
            homepageId: 15,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('입금 기한은 30분이라고 알린다', (tester) async {
    await pump(tester);

    expect(find.textContaining('30분'), findsOneWidget);
    // 옛 화면의 잘못된 안내가 되살아나지 않게 막는다
    expect(find.textContaining('2시간'), findsNothing);
  });

  testWidgets('기한을 넘기면 어떻게 되는지 말해준다', (tester) async {
    await pump(tester);
    expect(find.textContaining('자동으로 취소'), findsOneWidget);
  });

  testWidgets('지금 돈이 빠져나가지 않는다고 알린다', (tester) async {
    // 카드 결제가 아니라 계좌 발급이라 버튼을 눌러도 출금되지 않는다.
    await pump(tester);
    expect(find.textContaining('빠져나가지'), findsOneWidget);
  });

  testWidgets('금액을 크게 보여주고 버튼에도 적는다', (tester) async {
    await pump(tester, amount: 75000);

    expect(find.text('75,000원'), findsOneWidget);
    expect(find.text('75,000원 계좌 발급받기'), findsOneWidget);
  });

  testWidgets('무엇에 대한 결제인지 남는다', (tester) async {
    await pump(tester);

    expect(find.text('태백 세계바둑콩그레스'), findsOneWidget);
    expect(find.text('일반부'), findsOneWidget);
    expect(find.text('김바둑'), findsOneWidget);
  });

  testWidgets('금액 표기에 원이 겹치지 않는다', (tester) async {
    await pump(tester);
    expect(find.textContaining('원원'), findsNothing);
    expect(find.textContaining('₩'), findsNothing);
  });
}
