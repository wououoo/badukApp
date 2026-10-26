// 추가 항목 위젯 — 서버로 보내는 값과 화면에 그리는 것.
//
// 이 위젯은 대회가 DB에 적어 둔 정의(JSON)를 그대로 그린다.
// 즉 앱을 다시 배포하지 않고 바꿀 수 있는 범위가 곧 이 위젯이 견디는 범위라,
// "정의가 이렇게 오면 이렇게 된다"를 여기에 못 박아 둔다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baduk_app/features/contest/widgets/registration_option_selector.dart';

void main() {
  /// 위젯을 띄우고, 마지막으로 보고된 payload와 유효성을 돌려준다.
  Future<_Reported> pump(
    WidgetTester tester,
    List<Map<String, dynamic>> defs, {
    Map<String, dynamic>? initial,
  }) async {
    final reported = _Reported();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RegistrationOptionSelector(
              definitions: defs,
              initial: initial,
              onChanged: (payload, valid) {
                reported.payload = payload;
                reported.valid = valid;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return reported;
  }

  /// payload에서 한 항목을 꺼낸다.
  Map<String, dynamic>? entryOf(List<Map<String, dynamic>>? payload, String key) {
    if (payload == null) return null;
    for (final e in payload) {
      if (e['key'] == key) return e;
    }
    return null;
  }

  group('금액 표기', () {
    testWidgets("'원'이 겹치지 않는다", (tester) async {
      // 실제로 났던 버그: 15,000원원.
      // 금액을 만드는 함수가 이미 '원'을 붙이는데 호출부에서 또 붙였다.
      await pump(tester, [
        {
          'key': 'lunch',
          'label': '점심 식사',
          'type': 'MULTI_SELECT',
          'choices': [
            {'value': 'd1', 'label': '1일차', 'extraFee': 15000},
          ],
        },
      ]);

      expect(find.textContaining('원원'), findsNothing);
      expect(find.text('+15,000원'), findsOneWidget);
    });

    testWidgets('금액이 없는 선택지는 금액을 안 적는다', (tester) async {
      await pump(tester, [
        {
          'key': 'tshirt',
          'label': '티셔츠',
          'type': 'SINGLE_SELECT',
          'choices': [
            {'value': '100', 'label': '100cm'},
          ],
        },
      ]);

      expect(find.text('100cm'), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
    });
  });

  group('서버로 보내는 값', () {
    testWidgets('고른 값이 values에 담긴다', (tester) async {
      final r = await pump(tester, [
        {
          'key': 'lunch',
          'label': '점심',
          'type': 'MULTI_SELECT',
          'choices': [
            {'value': 'd1', 'label': '1일차', 'extraFee': 15000},
            {'value': 'd2', 'label': '2일차', 'extraFee': 15000},
          ],
        },
      ]);

      await tester.tap(find.text('1일차'));
      await tester.pump();
      await tester.tap(find.text('2일차'));
      await tester.pump();

      final e = entryOf(r.payload, 'lunch');
      expect(e, isNotNull);
      expect(e!['values'], ['d1', 'd2']);
    });

    testWidgets('하나만 고르는 항목은 값이 바뀌어 담긴다', (tester) async {
      final r = await pump(tester, [
        {
          'key': 'size',
          'label': '사이즈',
          'type': 'SINGLE_SELECT',
          'choices': [
            {'value': 's', 'label': 'S'},
            {'value': 'm', 'label': 'M'},
          ],
        },
      ]);

      await tester.tap(find.text('S'));
      await tester.pump();
      expect(entryOf(r.payload, 'size')!['values'], ['s']);

      await tester.tap(find.text('M'));
      await tester.pump();
      // 하나만 고를 수 있으므로 앞엣것은 빠져야 한다
      expect(entryOf(r.payload, 'size')!['values'], ['m']);
    });

    testWidgets('수량이 1이면 quantities에 안 싣는다', (tester) async {
      // 서버는 quantities에 없는 값을 1로 본다.
      // 굳이 1을 실어 보내면 기존 대회의 payload 모양이 바뀐다.
      final r = await pump(tester, [
        {
          'key': 'lunch',
          'label': '점심',
          'type': 'MULTI_SELECT',
          'choices': [
            {'value': 'd1', 'label': '1일차', 'extraFee': 15000},
          ],
        },
      ]);

      await tester.tap(find.text('1일차'));
      await tester.pump();

      expect(entryOf(r.payload, 'lunch')!['quantities'], isEmpty);
    });
  });

  group('수량(maxQuantity)', () {
    final lodging = [
      {
        'key': 'room',
        'label': '숙박',
        'type': 'MULTI_SELECT',
        'choices': [
          {'value': 'n1', 'label': '1일차 밤', 'extraFee': 30000, 'maxQuantity': 3},
        ],
      }
    ];

    testWidgets('maxQuantity가 없으면 ±가 안 나온다', (tester) async {
      await pump(tester, [
        {
          'key': 'lunch',
          'label': '점심',
          'type': 'MULTI_SELECT',
          'choices': [
            {'value': 'd1', 'label': '1일차', 'extraFee': 15000},
          ],
        },
      ]);

      await tester.tap(find.text('1일차'));
      await tester.pump();

      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.remove), findsNothing);
    });

    testWidgets('고르기 전에는 ±가 안 나온다', (tester) async {
      await pump(tester, lodging);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('고르면 ±가 나오고 수량이 payload에 실린다', (tester) async {
      final r = await pump(tester, lodging);

      await tester.tap(find.text('1일차 밤'));
      await tester.pump();
      expect(find.byIcon(Icons.add), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(entryOf(r.payload, 'room')!['quantities'], {'n1': 2});
    });

    testWidgets('수량을 올리면 금액이 소계로 바뀐다', (tester) async {
      await pump(tester, lodging);

      await tester.tap(find.text('1일차 밤'));
      await tester.pump();
      expect(find.text('+30,000원'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(find.text('+60,000원'), findsOneWidget);
      // 단가는 따로 남아 있어야 무엇을 몇 개 사는지 알 수 있다
      expect(find.text('개당 30,000원'), findsOneWidget);
    });

    testWidgets('1 아래로도, 최대치 위로도 안 간다', (tester) async {
      final r = await pump(tester, lodging);

      await tester.tap(find.text('1일차 밤'));
      await tester.pump();

      // 1에서 더 내려도 그대로 (항목을 뺀 것과 같아지므로)
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      // 3까지 올리고 한 번 더 눌러도 3
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();
      }
      expect(entryOf(r.payload, 'room')!['quantities'], {'n1': 3});
    });
  });

  group('모르는 type', () {
    testWidgets('선택지가 없으면 자유 입력으로 받는다', (tester) async {
      // 나중에 서버에서 새 타입을 만들어도 구버전 앱이 빈 화면을 내지 않아야 한다.
      await pump(tester, [
        {
          'key': 'memo',
          'label': '요청사항',
          'type': 'DATE_RANGE', // 앱이 모르는 타입
        },
      ]);

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('모르는 타입이 필수여도 제출을 막지 않는다', (tester) async {
      // 고를 방법이 없는데 값을 요구하면 신청 자체가 영구히 막힌다.
      final r = await pump(tester, [
        {
          'key': 'memo',
          'label': '요청사항',
          'type': 'DATE_RANGE',
          'required': true,
        },
      ]);

      expect(r.valid, isFalse, reason: '입력 전에는 필수를 채우지 않은 상태');

      await tester.enterText(find.byType(TextField), '9월 20일');
      await tester.pump();

      expect(r.valid, isTrue, reason: '입력하면 통과할 수 있어야 한다');
    });

    testWidgets('선택지가 있으면 고르는 화면으로 떨어진다', (tester) async {
      await pump(tester, [
        {
          'key': 'x',
          'label': '무언가',
          'type': 'WHAT_IS_THIS',
          'choices': [
            {'value': 'a', 'label': 'A'},
          ],
        },
      ]);

      expect(find.byType(TextField), findsNothing);
      expect(find.text('A'), findsOneWidget);
    });
  });

  group('반드시 포함되는 선택지', () {
    final lunch4 = [
      {
        'key': 'lunch',
        'label': '점심',
        'type': 'MULTI_SELECT',
        'choices': [
          {'value': 'd1', 'label': '1일차', 'extraFee': 15000, 'required': true},
          {'value': 'd2', 'label': '2일차', 'extraFee': 15000, 'required': true},
        ],
      }
    ];

    testWidgets('처음부터 골라진 채로 시작한다', (tester) async {
      final r = await pump(tester, lunch4);
      expect(entryOf(r.payload, 'lunch')!['values'], ['d1', 'd2']);
    });

    testWidgets('눌러도 해제되지 않는다', (tester) async {
      // 화면에서만 풀리고 제출에서 막히면 사용자가 이유를 모른다.
      final r = await pump(tester, lunch4);

      await tester.tap(find.text('1일차'));
      await tester.pump();

      expect(entryOf(r.payload, 'lunch')!['values'], contains('d1'));
      expect(find.text('모든 참가자 포함'), findsNWidgets(2));
    });
  });

  group('조건부 노출(showWhen)', () {
    // 셔틀 '이용' 선택 시에만 '탑승 희망 편'이 뜨고, 그때만 필수.
    List<Map<String, dynamic>> shuttleDefs() => [
          {
            'key': 'shuttle',
            'label': '셔틀버스 이용 여부',
            'type': 'SINGLE_SELECT',
            'required': true,
            'choices': [
              {'value': 'yes', 'label': '이용'},
              {'value': 'no', 'label': '미이용'},
            ],
          },
          {
            'key': 'shuttle_runs',
            'label': '탑승 희망 편',
            'type': 'MULTI_SELECT',
            'required': true,
            'showWhen': {
              'key': 'shuttle',
              'values': ['yes'],
            },
            'choices': [
              {'value': 'sat_go', 'label': '[토] 가는 편'},
              {'value': 'sat_back', 'label': '[토] 오는 편'},
            ],
          },
        ];

    testWidgets('조건 미충족이면 숨고, 충족하면 노출+필수', (tester) async {
      final r = await pump(tester, shuttleDefs());

      // shuttle 미선택 → 회차 숨김
      expect(find.text('[토] 가는 편'), findsNothing);

      // 이용 선택 → 회차 노출, 회차 미선택이라 아직 invalid
      await tester.tap(find.text('이용'));
      await tester.pump();
      expect(find.text('[토] 가는 편'), findsOneWidget);
      expect(r.valid, isFalse);

      // 회차 선택 → 통과
      await tester.tap(find.text('[토] 가는 편'));
      await tester.pump();
      expect(r.valid, isTrue);
    });

    testWidgets('숨겨지면 이전 선택값이 제출에서 빠지고 필수도 면제', (tester) async {
      final r = await pump(tester, shuttleDefs());

      await tester.tap(find.text('이용'));
      await tester.pump();
      await tester.tap(find.text('[토] 오는 편'));
      await tester.pump();
      expect(entryOf(r.payload, 'shuttle_runs')!['values'], ['sat_back']);

      // 미이용으로 전환 → 회차 숨김 + 값 비움 + 회차 필수 면제
      await tester.tap(find.text('미이용'));
      await tester.pump();
      expect(find.text('[토] 오는 편'), findsNothing);
      final e = entryOf(r.payload, 'shuttle_runs');
      expect(e == null || (e['values'] as List).isEmpty, isTrue);
      expect(r.valid, isTrue);
    });
  });

  testWidgets('정의가 없으면 아무것도 안 그린다', (tester) async {
    await pump(tester, []);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });
}

class _Reported {
  List<Map<String, dynamic>>? payload;
  bool? valid;
}
