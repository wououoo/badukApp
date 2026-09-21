/// 화면 개편(V2) 스위치.
///
/// 개편한 화면은 원본을 지우지 않고 `*_v2.dart`로 따로 두었다.
/// 여기 [useV2] 하나만 false로 바꾸면 앱 전체가 예전 화면으로 즉시 돌아간다.
/// (라우터 여러 군데를 고칠 필요 없이 이 파일 한 줄이다)
///
/// 지금 V2가 걸려 있는 화면
///   - 홈            home_screen_v2.dart
///   - 대회 목록     contest_list_screen_v2.dart
///   - 대회 상세     contest_detail_screen_v2.dart
///   - 참가신청      contest_registration_screen_v2.dart
///   - 결제(계좌발급) payment_screen_v2.dart
///   - 결제 완료     payment_success_screen_v2.dart
///   - 환불 신청     refund_request_screen_v2.dart
///   - 신청 정보 수정 registration_edit_screen_v2.dart
///   - 내 정보(프로필) profile_screen_v2.dart
///   - 설정           settings_screen_v2.dart
///   - 내 참가신청   my_registrations_screen_v2.dart
///   - 라이브 목록   live_contest_list_screen_v2.dart
///   - 라이브 순위   live_sort_content_v2.dart
///
/// V2가 아니라 원본을 직접 고친 것들은 이 스위치로 되돌아가지 않는다.
///   - 대회 목록의 1열 와이드 카드
///   - 내 참가신청의 가상계좌 박스 색
///   - my_contest_detail의 위젯 분리, withOpacity 치환 등
///   - 추가 항목 위젯(registration_option_selector)의 칩→카드, 보라→코랄
///   이것들은 동작이 같거나 색만 바뀐 것이라 되돌릴 일이 거의 없다.
///   정말 필요하면 작업 전 백업(/tmp/baduk_app_lib_105033)에서 해당 파일만 복사한다.
class UiFlags {
  UiFlags._();

  /// true = 개편한 화면(V2), false = 예전 화면
  static const bool useV2 = true;

  /// 홈 '지금 할 일' 카드를 실제 데이터 없이도 그려서 눈으로 확인하기 위한 스위치.
  /// 배포 전에는 반드시 false. 실제 입금 대기 건이 생기면 false로 두어도 같은 화면이 나온다.
  static const bool previewTodoSample = false;
}
