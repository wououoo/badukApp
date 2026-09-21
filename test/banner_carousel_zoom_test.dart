import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baduk_app/core/widgets/banner_carousel.dart';

// 배너 크게 보기 — 한 번 탭은 대회로, 더블탭·확대 아이콘은 전체화면 보기.
// 포스터 없는 배너는 더블탭을 걸지 않아 한 번 탭이 늦어지지 않아야 한다.
void main() {
  const viewerHint = '두 손가락으로 확대할 수 있어요';

  Widget host({required List<BannerItem> items, required ValueChanged<String?> onTap}) {
    return MaterialApp(
      home: Scaffold(
        body: BannerCarousel(
          items: items,
          autoScrollDuration: const Duration(hours: 1), // 테스트 중 자동 넘김이 끼어들지 않게
          onTap: onTap,
        ),
      ),
    );
  }

  const posterBanner = BannerItem(
    title: '제3회 태백시 세계 바둑 콩그레스',
    subtitle: '대회 예정',
    backgroundColor: Colors.brown,
    imageUrl: 'https://example.com/poster.jpg',
    routePath: '/contest/15',
  );
  const plainBanner = BannerItem(
    title: '바둑 대회에 참가하세요',
    subtitle: '다양한 대회 일정을 확인하고 신청하세요',
    backgroundColor: Colors.orange,
    routePath: '/contests',
  );

  testWidgets('포스터 배너 한 번 탭은 대회로 이동하고 크게 보기는 안 열린다', (tester) async {
    String? routed;
    await tester.pumpWidget(host(items: [posterBanner], onTap: (r) => routed = r));

    await tester.tap(find.text(posterBanner.title));
    // 더블탭 대기 시간이 지나야 한 번 탭으로 확정된다
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(routed, '/contest/15');
    expect(find.text(viewerHint), findsNothing);
  });

  testWidgets('포스터 배너 더블탭은 크게 보기를 열고 대회로 이동하지 않는다', (tester) async {
    String? routed;
    await tester.pumpWidget(host(items: [posterBanner], onTap: (r) => routed = r));

    final target = find.text(posterBanner.title);
    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(target);
    await tester.pumpAndSettle();

    expect(find.text(viewerHint), findsOneWidget);
    expect(routed, isNull);

    // 닫기
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text(viewerHint), findsNothing);
  });

  testWidgets('확대 아이콘을 누르면 크게 보기가 열린다 (대회로 이동하지 않음)', (tester) async {
    String? routed;
    await tester.pumpWidget(host(items: [posterBanner], onTap: (r) => routed = r));

    await tester.tap(find.byIcon(Icons.zoom_out_map));
    // 바깥 배너가 더블탭을 기다리는 동안 제스처 판정이 보류된다 → 대기 시간 뒤 아이콘 탭이 이긴다
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text(viewerHint), findsOneWidget);
    expect(routed, isNull);
  });

  testWidgets('포스터 없는 배너는 확대 아이콘이 없고 한 번 탭이 바로 반응한다', (tester) async {
    String? routed;
    await tester.pumpWidget(host(items: [plainBanner], onTap: (r) => routed = r));

    expect(find.byIcon(Icons.zoom_out_map), findsNothing);
    await tester.tap(find.text(plainBanner.title));
    await tester.pump(); // 더블탭 대기 없이 즉시
    expect(routed, '/contests');
  });
}
