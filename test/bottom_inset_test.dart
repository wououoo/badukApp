// 하단 제스처 바에 가리는지 — 좌표로 잰다.
//
// Android 15부터 화면이 시스템 바 아래까지 그려지고(edge-to-edge),
// Android 16(targetSdk 36)은 그걸 끄는 방법 자체를 없앴다.
// 그래서 "하단이 가린다"는 이제 설정으로 못 고치고 화면마다 여백을 줘야만 한다.
//
// 문제는 이게 넘침(overflow)이 아니라 덮임이라 코드를 읽어선 안 보이고,
// 화면을 띄워도 인셋이 0이면 멀쩡해 보인다는 것이다.
// 그래서 제스처 바(48dp)를 흉내 낸 상태로 띄우고, 눌러야 할 것이
// 그 영역 안으로 내려왔는지 좌표로 잰다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baduk_app/data/models/payment.dart';
import 'package:baduk_app/features/payment/screens/payment_screen_v2.dart';
import 'package:baduk_app/features/payment/screens/payment_success_screen_v2.dart';
import 'package:baduk_app/features/profile/screens/my_registrations_screen.dart'
    show myRegistrationsProvider;
import 'package:baduk_app/features/profile/screens/my_registrations_screen_v2.dart';

/// 제스처 바 높이. 요즘 기기에서 흔한 값.
const double kGestureBar = 48;

void main() {
  /// 하단 인셋이 있는 상태로 화면을 띄운다.
  Future<void> pumpWithInset(WidgetTester tester, Widget home,
      {List<Override> overrides = const []}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            padding: EdgeInsets.only(bottom: kGestureBar, top: 24),
            viewPadding: EdgeInsets.only(bottom: kGestureBar, top: 24),
          ),
          child: MaterialApp(home: home),
        ),
      ),
    );
    await tester.pump();
  }

  /// 이 위젯의 아래끝이 제스처 바를 침범하는가.
  void expectAboveGestureBar(WidgetTester tester, Finder finder, String what) {
    expect(finder, findsWidgets, reason: '$what 을(를) 찾지 못했다');
    final rect = tester.getRect(finder.first);
    final screenBottom = tester.getSize(find.byType(MaterialApp)).height;
    final safeBottom = screenBottom - kGestureBar;

    expect(
      rect.bottom <= safeBottom + 0.5,
      isTrue,
      reason: '$what 의 아래끝이 ${rect.bottom.toStringAsFixed(1)}인데 '
          '제스처 바가 ${safeBottom.toStringAsFixed(1)}부터 시작한다 — '
          '${(rect.bottom - safeBottom).toStringAsFixed(1)}만큼 가린다',
    );
  }

  testWidgets('결제 화면의 주 버튼이 제스처 바에 안 가린다', (tester) async {
    await pumpWithInset(
      tester,
      const PaymentScreenV2(
        existingRegistrationId: 1,
        participantName: '김바둑',
        categoryName: '일반부',
        contestName: '태백 세계바둑콩그레스',
        amount: 30000,
        homepageId: 15,
      ),
    );
    expectAboveGestureBar(
        tester, find.text('30,000원 계좌 발급받기'), '결제 버튼');
  });

  testWidgets('결제 완료 화면의 주 버튼이 제스처 바에 안 가린다', (tester) async {
    await pumpWithInset(
      tester,
      PaymentSuccessScreenV2(
        payment: Payment(
          registrationId: 1,
          paymentMethod: 'TOSS',
          paymentStatus: 'WAITING_FOR_DEPOSIT',
          amount: 30000,
          participantName: '김바둑',
          categoryName: '일반부',
          contestName: '태백 세계바둑콩그레스',
        ),
      ),
    );
    expectAboveGestureBar(tester, find.text('계좌 확인하러 가기'), '계좌 확인 버튼');
  });

  testWidgets('내 참가신청 목록의 마지막 카드가 제스처 바에 안 가린다', (tester) async {
    // 목록은 버튼이 아니라 마지막 항목이 문제가 된다.
    final start = DateTime.now().add(const Duration(days: 5)).toIso8601String();
    final list = <Map<String, dynamic>>[
      for (int i = 1; i <= 3; i++)
        {
          'registrationId': i,
          'contestName': '대회 $i',
          'categoryName': '일반부',
          'participantName': '김바둑',
          'status': 'APPROVED',
          'paymentStatus': 'COMPLETED',
          'fee': 30000,
          'paidAmount': 30000,
          'contestStartDate': start,
          'options': const [],
          'homepageId': 1,
        },
    ];

    await pumpWithInset(
      tester,
      const MyRegistrationsScreenV2(),
      overrides: [myRegistrationsProvider.overrideWith((ref) async => list)],
    );

    // 목록 자체가 인셋만큼 아래 여백을 갖는지 본다.
    final listFinder = find.byType(ListView);
    expect(listFinder, findsWidgets);
    final listView = tester.widget<ListView>(listFinder.first);
    final pad = listView.padding?.resolve(TextDirection.ltr);
    expect(
      pad != null && pad.bottom >= 16,
      isTrue,
      reason: '목록 아래 여백이 ${pad?.bottom} — 마지막 카드가 제스처 바에 닿는다',
    );
  });
}
