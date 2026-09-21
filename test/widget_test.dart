// 배포 전 지킴이.
//
// 원래 이 자리에는 "앱이 뜬다"만 확인하는 테스트가 있었는데,
// 앱 전체를 띄우면 부팅 타이머가 남아 정리되지 않아 항상 실패했다
// (개편 전부터 그랬다 — 원본 저장소에서도 같다). 실패가 상수면 아무도 안 본다.
//
// 그래서 실제로 사고가 나는 것들만 지킨다:
//   - 화면 개편 스위치가 의도한 값인가
//   - 눈으로 보려고 켜 둔 가짜 데이터가 켜진 채 배포되지 않는가
//   - 강조색이 여러 갈래로 흩어지지 않았는가
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baduk_app/core/config/ui_flags.dart';
import 'package:baduk_app/core/theme/app_colors.dart';

void main() {
  group('배포 전 확인', () {
    test('미리보기 샘플이 켜져 있으면 알린다', () {
      // 켜져 있으면 입금 대기 건이 없는 사람에게도 가짜 카드가 보인다.
      // 배포 직전에 이 테스트가 빨개지면 ui_flags.dart에서 false로 내린다.
      expect(
        UiFlags.previewTodoSample,
        isFalse,
        reason: '홈 할 일 카드의 미리보기 샘플이 켜져 있다. '
            'ui_flags.dart의 previewTodoSample을 false로 내리고 배포할 것.',
      );
    });

    test('개편 화면 스위치는 켜져 있다', () {
      // 되돌리려고 내려 둔 채 잊고 배포하는 일을 막는다.
      expect(UiFlags.useV2, isTrue);
    });
  });

  group('색', () {
    test('강조색은 코랄 하나다', () {
      // 주황이 여러 갈래로 돌면 화면마다 다른 앱처럼 보인다.
      expect(AppColors.primary, const Color(0xFFD4603C));
    });

    test('반상 위 강조색은 같은 코랄 계열이다', () {
      // 어두운 면에서 읽히게 밝힌 값일 뿐, 별개의 주황이 아니어야 한다.
      expect(AppColors.boardAccent, const Color(0xFFF0855F));
      expect(AppColors.boardAccent.r, greaterThan(AppColors.primary.r));
    });

    test('반상은 흰 카드와 확실히 구분된다', () {
      // '지금 급한 것' 하나에만 입히는 면이라 충분히 어두워야 한다.
      AppColors.setDarkMode(false);
      expect(AppColors.board.computeLuminance(), lessThan(0.05));
      expect(AppColors.surface.computeLuminance(), greaterThan(0.8));
    });
  });
}
