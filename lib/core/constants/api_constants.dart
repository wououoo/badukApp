class ApiConstants {
  ApiConstants._();

  // ========== 서버 URL 설정 ==========
  // 사용할 서버의 주석을 해제하세요

  // 로컬 개발 서버 (iOS 시뮬레이터, 웹)
  // static const String baseUrl = 'http://localhost:8080/api';
  // static const String webUrl = 'http://localhost:3000';  // 개발용 React 프론트엔드

  // 로컬 개발 서버 (Android 에뮬레이터용 - 10.0.2.2는 호스트 PC의 localhost)
  // static const String baseUrl = 'http://10.0.2.2:8080/api';
  // static const String webUrl = 'http://10.0.2.2:3000';

  // // 프로덕션 서버
  static const String baseUrl = 'https://swissbaduk.org/api';
  static const String webUrl = 'https://swissbaduk.org';

  // ====================================

  // 타임아웃
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  // 인증 엔드포인트 (기존 - 비밀번호 방식)
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';

  // 모바일 OTP 인증 엔드포인트
  static const String otpSend = '/mobile/auth/otp/send';
  static const String otpVerify = '/mobile/auth/otp/verify';
  static const String mobileRefresh = '/mobile/auth/refresh';
  static const String mobileUpdateName = '/mobile/auth/update-name';

  // 소셜 로그인 엔드포인트
  static const String kakaoLogin = '/mobile/auth/kakao';
  static const String naverLogin = '/mobile/auth/naver';
  static const String appleLogin = '/mobile/auth/apple';
  static const String identityVerify = '/mobile/auth/identity-verify';
  static const String identityVerifyConfirm = '/mobile/auth/identity-verify/confirm';
  static const String kakaoCertVerify = '/mobile/auth/kakao-cert/verify';
  static const String identityVerifyManual = '/mobile/auth/identity-verify/manual';
  static const String identityVerifyOtp = '/mobile/auth/identity-verify/otp';
  static const String kakaoVerifyIdentity = '/mobile/auth/kakao/verify-identity';

  // 모바일 사용자 프로필 엔드포인트
  static const String userProfile = '/mobile/users/me';
  static const String userProfileUpdate = '/mobile/users/me/profile';

  // 대회 홈페이지 엔드포인트 (참가신청용)
  static const String publicHomepages = '/contest-homepage/public';
  static const String homepageDetail = '/contest-homepage';
  static const String homepageCategories = '/contest-homepage';

  // 참가신청 엔드포인트
  static const String registration = '/contest-registration';
  static const String registrationVerify = '/contest-registration/verify';
  // 단체전 팀 목록: /contest-registration/homepage/{homepageId}/category/{categoryId}/teams
  static const String registrationTeams = '/contest-registration/homepage';

  // 결제 엔드포인트
  static const String payment = '/payment';
  static const String paymentConfirm = '/payment/confirm';
  static const String tossCheckout = '/payment/toss/checkout';
  static const String refund = '/refund';

  // 부문 변경 엔드포인트
  static const String categoryChangePreview = '/payment/category-change/preview';
  static const String categoryChangePrepare = '/payment/category-change/prepare';
  static const String categoryChange = '/payment/category-change';

  // 내 참가신청 엔드포인트
  static const String myRegistrations = '/mobile/users/me/registrations';
  static const String myRegistrationUpdate = '/mobile/users/me/registrations';

  // 사용자 이력 엔드포인트
  static const String userHistory = '/mobile/users/me/contest-history';
  static const String mcmahonScore = '/mobile/users/me/mcmahon-score';
  static const String userStats = '/mobile/users/me/stats';

  // FCM 엔드포인트
  static const String fcmToken = '/fcm/token';
  static const String userFcmToken = '/mobile/users/me/fcm-token';
  static const String userPushSettings = '/mobile/users/me/push-settings';
  static const String myClubContests = '/mobile/users/me/club-contests';
  static const String testPush = '/mobile/users/me/test-push';

  // 라이브 대회 엔드포인트 (순위표/대진표 조회용)
  static const String liveContests = '/live/contests';
  static const String liveContestDetail = '/live/contests';

  // 모바일 대회 엔드포인트 (ContestHomepage 기반)
  static const String contests = '/mobile/contests';
  static const String contestDetail = '/mobile/contests';

  // 포털 엔드포인트 (QR 체크인용)
  static const String portalContest = '/portal/contest';
  static const String portalSearch = '/portal/search';
  static const String portalCheckIn = '/portal/check-in';
  static const String portalRoundResults = '/portal/round-results';
  static const String portalRankings = '/portal/rankings';
  static const String portalMaxRound = '/portal/max-round';

  // 체크인 엔드포인트
  static const String checkInOnSite = '/check-in/on-site';

  // 맥마흔 QR 엔드포인트 (라운드 결과 조회) - 구버전
  static const String mcmahonRoundResults = '/QR/mcmahon/round-results';
  static const String mcmahonMaxRound = '/QR/mcmahon/max-round';

  // 맥마흔 라운드 결과 조회 (한방 쿼리) - 신버전
  static const String mcmahonRoundsDetail = '/mobile/users/me/mcmahon-rounds';

  // 비-MCM 라운드 결과 조회
  static const String contestRoundsDetail = '/mobile/users/me/contest-rounds';

  // 즐겨찾기 엔드포인트
  static const String myFavorites = '/mobile/users/me/favorites';

  // 알림 수신함 엔드포인트
  static const String myNotifications = '/mobile/users/me/notifications';
  static const String unreadCount = '/mobile/users/me/notifications/unread-count';
  static const String readAllNotifications = '/mobile/users/me/notifications/read-all';

  // 클럽(동호회) 엔드포인트
  static const String clubs = '/mobile/clubs';
  static const String myClubs = '/mobile/clubs/my';

  // 앱 설정 엔드포인트
  static const String appConfig = '/mobile/app/config';

  // AI 바둑판 분석 (별도 서버 - endgo.kr)
  // static const String aiBaseUrl = 'http://localhost:8083/api';  // 로컬 개발
  static const String aiBaseUrl = 'https://endgo.kr/api';  // 프로덕션
  static const String boardAnalyze = '/board/analyze';
  static const String boardApiKey = 'baduk-board-dev-key-2024';

  // 위치
  static const String nearbyContests = '/location/nearby-contests';
  static const String geocode = '/location/geocode';

  // 개인정보 동의 엔드포인트
  static const String privacyConsent = '/mobile/privacy/consent';
  static const String privacyConsentStatus = '/mobile/privacy/consent/status';
  static const String privacyConsentHistory = '/mobile/privacy/consent/history';
  static const String privacyConsentWithdraw = '/mobile/privacy/consent/withdraw';
  static const String privacyPolicy = '/mobile/privacy/policy';
}
// [마지막 릴리즈] 1.1.2+51 (2026-05-16 10:45)
