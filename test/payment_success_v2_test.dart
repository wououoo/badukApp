// 결제 결과 화면(V2) — 끝난 것과 안 끝난 것을 헷갈리지 않게.
//
// 우리 정책상 유료 결제는 가상계좌뿐이라, 이 화면에 오는 거의 모든 경우가
// "아직 안 끝났다"이다. 완료 문구가 뜨면 사용자는 입금을 안 하고 화면을 닫는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baduk_app/data/models/payment.dart';
import 'package:baduk_app/features/payment/screens/payment_success_screen_v2.dart';

void main() {
  Payment payment({
    required String status,
    int amount = 30000,
    String method = 'TOSS',
  }) {
    return Payment(
      registrationId: 1,
      paymentMethod: method,
      paymentStatus: status,
      amount: amount,
      participantName: '김바둑',
      categoryName: '일반부',
      contestName: '태백 세계바둑콩그레스',
    );
  }

  Future<void> pump(WidgetTester tester, Payment p) async {
    await tester.pumpWidget(
      MaterialApp(home: PaymentSuccessScreenV2(payment: p)),
    );
    await tester.pump();
  }

  group('입금 대기', () {
    testWidgets('끝났다고 말하지 않는다', (tester) async {
      await pump(tester, payment(status: 'WAITING_FOR_DEPOSIT'));

      expect(find.text('입금하면 자리가 확정됩니다'), findsOneWidget);
      expect(find.text('참가 확정'), findsNothing);
    });

    testWidgets('넣어야 할 금액과 기한을 앞세운다', (tester) async {
      await pump(tester, payment(status: 'WAITING_FOR_DEPOSIT'));

      expect(find.text('입금할 금액'), findsOneWidget);
      expect(find.text('30,000원'), findsOneWidget);
      expect(find.textContaining('30분'), findsOneWidget);
      expect(find.textContaining('자동 취소'), findsOneWidget);
    });

    testWidgets('다음 걸음은 홈이 아니라 계좌 확인이다', (tester) async {
      await pump(tester, payment(status: 'WAITING_FOR_DEPOSIT'));

      expect(find.text('계좌 확인하러 가기'), findsOneWidget);
      // 홈으로도 갈 수는 있어야 하되 주 버튼은 아니다
      expect(find.text('홈으로'), findsOneWidget);
    });
  });

  group('이미 끝난 결제', () {
    testWidgets('확정됐다고 알린다', (tester) async {
      await pump(tester, payment(status: 'COMPLETED'));

      expect(find.text('참가 확정'), findsOneWidget);
      expect(find.text('결제 금액'), findsOneWidget);
      expect(find.textContaining('자동 취소'), findsNothing);
    });

    testWidgets('무료 신청도 금액 자리가 비지 않는다', (tester) async {
      await pump(tester, payment(status: 'COMPLETED', amount: 0, method: 'FREE'));

      // 금액 자리와 결제 방법 자리 둘 다 '무료'로 나온다(둘 다 맞는 표시).
      expect(find.text('무료'), findsNWidgets(2));
      expect(find.text('0원'), findsNothing);
    });
  });

  testWidgets('무엇에 대한 결제인지 남는다', (tester) async {
    await pump(tester, payment(status: 'WAITING_FOR_DEPOSIT'));

    expect(find.text('태백 세계바둑콩그레스'), findsOneWidget);
    expect(find.text('일반부'), findsOneWidget);
    expect(find.text('김바둑'), findsOneWidget);
  });

  testWidgets('금액 표기에 원이 겹치지 않는다', (tester) async {
    await pump(tester, payment(status: 'WAITING_FOR_DEPOSIT'));
    expect(find.textContaining('원원'), findsNothing);
  });
}
