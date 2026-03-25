import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/screens/home_screen.dart';
import '../features/contest/screens/contest_list_screen.dart';
import '../features/contest/screens/contest_detail_screen.dart';
import '../features/contest/screens/contest_registration_screen.dart';
import '../features/contest/screens/team_bulk_registration_screen.dart';
import '../features/contest/screens/team_join_screen.dart';
import '../features/contest/screens/contest_homepage_webview.dart';
import '../features/contest/screens/contest_photo_view_screen.dart';
import '../data/models/contest_photo.dart';
import '../features/history/screens/history_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/profile_edit_screen.dart';
import '../features/profile/screens/my_registrations_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/change_phone_screen.dart';
import '../features/settings/screens/terms_screen.dart';
import '../features/settings/screens/privacy_screen.dart';
import '../features/support/screens/support_screen.dart';
import '../features/support/screens/faq_screen.dart';
import '../features/support/screens/notice_list_screen.dart';
import '../features/support/screens/notice_detail_screen.dart';
import '../features/support/screens/inquiry_list_screen.dart';
import '../features/support/screens/inquiry_detail_screen.dart';
import '../features/support/screens/inquiry_create_screen.dart';
import '../features/notification/screens/notification_screen.dart';
import '../features/notification/screens/received_notifications_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/identity_verification_screen.dart';
import '../features/auth/screens/profile_setup_screen.dart';
import '../features/auth/screens/signup_preview_screen.dart';
import '../features/auth/screens/privacy_consent_screen.dart';
import '../features/auth/screens/account_withdrawal_screen.dart';
import '../features/main/main_screen.dart';
import '../features/portal/screens/portal_screen.dart';
import '../features/portal/screens/portal_detail_screen.dart';
import '../features/qr/screens/my_contests_screen.dart';
import '../features/qr/screens/my_contest_detail_screen.dart';
import '../features/qr/screens/qr_scanner_screen.dart';
import '../features/live/screens/live_contest_screen.dart';
import '../features/payment/screens/payment_screen.dart';
import '../features/payment/screens/payment_success_screen.dart';
import '../features/payment/screens/toss_checkout_screen.dart';
import '../features/payment/screens/refund_request_screen.dart';
import '../features/contest/screens/refund_policy_page.dart';
import '../features/admin/screens/host_applications_screen.dart';
import '../features/host/screens/host_apply_screen.dart';
import '../features/host/screens/contest_request_screen.dart';
import '../features/host/screens/my_requests_screen.dart';
import '../features/host/screens/request_detail_screen.dart';
import '../features/host/screens/admin_requests_screen.dart';
import '../features/admin/screens/push_notification_screen.dart';
import '../features/admin/screens/notice_manage_screen.dart';
import '../data/models/portal/portal_participant.dart';
import '../data/models/payment.dart';
import '../data/models/registration.dart';
import '../features/profile/screens/registration_edit_screen.dart';
import '../features/club/screens/my_clubs_screen.dart';
import '../features/club/screens/club_explore_screen.dart';
import '../features/club/screens/club_create_screen.dart';
import '../features/club/screens/club_detail_screen.dart';
import '../features/club/screens/club_join_requests_screen.dart';
import '../features/club/screens/club_member_picker_screen.dart';
import '../features/club/screens/club_post_detail_screen.dart';
import '../features/club/screens/club_post_create_screen.dart';
import '../features/club/screens/club_edit_screen.dart';
import '../features/club/screens/club_contest_create_screen.dart';
import '../features/club/screens/club_participant_select_screen.dart';
import '../features/club/screens/club_contest_manage_screen.dart';
import '../features/club/screens/club_rankings_screen.dart';
import '../features/club/screens/club_photo_view_screen.dart';
import '../data/models/club_photo.dart';
import '../data/models/club_post.dart';
import '../features/feed/screens/feed_screen.dart';
import '../features/calendar/screens/contest_calendar_screen.dart';
// import '../features/board_analysis/screens/board_capture_screen.dart'; // AI 계가 개발중
import '../data/providers/auth_provider.dart';
import '../data/services/contest_service.dart';

/// 인증 상태 변화를 감지하는 Listenable
class AuthNotifierListenable extends ChangeNotifier {
  AuthNotifierListenable(this._ref) {
    _ref.listen<AuthState>(authProvider, (previous, next) {
      notifyListeners();
    });
  }

  final Ref _ref;

  AuthState get authState => _ref.read(authProvider);
}

/// 전역 NavigatorKey (알림 탭 시 화면 이동 등에 사용)
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// 딥링크 대기 경로 저장
String? _pendingDeepLink;

/// GoRouter 프로바이더
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = AuthNotifierListenable(ref);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,

    // 인증 상태에 따른 리다이렉트
    redirect: (context, state) {
      final authState = authNotifier.authState;
      final currentPath = state.uri.path;

      debugPrint('[Router] redirect called: path=$currentPath, status=${authState.status}');

      // 로딩 중이면 리다이렉트 없음
      if (authState.status == AuthStatus.loading ||
          authState.status == AuthStatus.initial) {
        debugPrint('[Router] loading/initial, no redirect');
        return null;
      }

      // 인증 필요 없는 페이지들
      const publicPaths = ['/login'];

      // 현재 인증 상태 확인
      final isLoggedIn = authState.status == AuthStatus.authenticated ||
          authState.status == AuthStatus.socialLoggedIn ||
          authState.status == AuthStatus.identityVerified ||
          authState.status == AuthStatus.profileSetup ||
          authState.status == AuthStatus.needsPrivacyConsent;

      final isFullyAuthenticated = authState.status == AuthStatus.authenticated;
      final needsIdentityVerification = authState.status == AuthStatus.socialLoggedIn;
      final needsPrivacyConsent = authState.status == AuthStatus.needsPrivacyConsent;
      final needsProfileSetup = authState.status == AuthStatus.identityVerified;

      // /homepage/:id → /contest/:id 리다이렉트 (딥링크 인입 시 네이티브 상세 화면)
      if (currentPath.startsWith('/homepage/')) {
        final id = currentPath.replaceFirst('/homepage/', '');
        final redirectPath = '/contest/$id';
        if (!isLoggedIn) {
          _pendingDeepLink = redirectPath;
          debugPrint('[Router] deep link 저장 (미로그인): $redirectPath');
          return '/login';
        }
        return redirectPath;
      }

      // 로그인 안된 상태
      if (!isLoggedIn) {
        // 이미 로그인 페이지면 그대로
        if (currentPath == '/login') return null;
        // 딥링크 경로 저장 후 로그인으로
        if (currentPath != '/login') {
          _pendingDeepLink = currentPath;
          debugPrint('[Router] deep link 저장 (미로그인): $currentPath');
        }
        // 로그인 페이지로 리다이렉트
        debugPrint('[Router] not logged in, redirect to /login');
        return '/login';
      }

      // 소셜 로그인 완료, 본인인증 필요
      if (needsIdentityVerification) {
        if (currentPath == '/identity-verify') return null;
        return '/identity-verify';
      }

      // 개인정보 동의 필요
      if (needsPrivacyConsent) {
        if (currentPath == '/privacy-consent') return null;
        return '/privacy-consent';
      }

      // 본인인증 완료, 프로필 설정 필요
      if (needsProfileSetup) {
        if (currentPath == '/profile-setup') return null;
        return '/profile-setup';
      }

      // 완전히 인증된 상태
      if (isFullyAuthenticated) {
        // pending deep link 처리
        if (_pendingDeepLink != null) {
          final deepLink = _pendingDeepLink!;
          _pendingDeepLink = null;
          debugPrint('[Router] pending deep link 이동: $deepLink');
          return deepLink;
        }
        // 로그인 관련 페이지에 있으면 홈으로
        if (currentPath == '/login' ||
            currentPath == '/identity-verify' ||
            currentPath == '/privacy-consent' ||
            currentPath == '/profile-setup') {
          debugPrint('[Router] fully authenticated, redirect to /home');
          return '/home';
        }
      }

      return null;
    },

    routes: [
      // 로그인 (전체 화면)
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // 카카오 심사용 회원가입 미리보기 (캡처 후 삭제)
      GoRoute(
        path: '/signup-preview',
        builder: (context, state) => const SignupPreviewScreen(),
      ),

      // 본인인증 (전체 화면)
      GoRoute(
        path: '/identity-verify',
        builder: (context, state) => const IdentityVerificationScreen(),
      ),

      // 개인정보 동의 (전체 화면)
      GoRoute(
        path: '/privacy-consent',
        builder: (context, state) => const PrivacyConsentScreen(),
      ),

      // 프로필 설정 (전체 화면)
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),

      // 메인 (탭 네비게이션)
      ShellRoute(
        navigatorKey: GlobalKey<NavigatorState>(),
        builder: (context, state, child) => MainScreen(child: child),
        routes: [
          // 홈 탭
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),

          // 대회 탭
          GoRoute(
            path: '/contests',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ContestListScreen(),
            ),
          ),

          // 클럽 탭
          GoRoute(
            path: '/clubs-tab',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MyClubsScreen(),
            ),
          ),

          // 내정보 탭
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),

      // 내 참가신청 내역 (전체 화면)
      GoRoute(
        path: '/profile/registrations',
        builder: (context, state) => const MyRegistrationsScreen(),
      ),

      // 대회 기록 (전체 화면 - 내정보에서 진입)
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),

      // 피드 (전체 화면)
      GoRoute(
        path: '/feed',
        builder: (context, state) => const FeedScreen(),
      ),

      // 대회 캘린더 (전체 화면)
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const ContestCalendarScreen(),
      ),

      // 알림 (전체 화면)
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),

      // 받은 알림 전체 목록 (전체 화면)
      GoRoute(
        path: '/notifications/received',
        builder: (context, state) => const ReceivedNotificationsScreen(),
      ),

      // 대회 상세 (전체 화면)
      GoRoute(
        path: '/contest/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return ContestDetailScreen(contestId: id);
        },
      ),

      // 대회 사진 뷰어 (전체 화면)
      GoRoute(
        path: '/contest/:id/photos/:photoId',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          if (extra == null || extra['photo'] == null) {
            return const Scaffold(
              body: Center(child: Text('사진 정보를 불러올 수 없습니다.')),
            );
          }
          return ContestPhotoViewScreen(
            photo: extra['photo'] as ContestPhoto,
          );
        },
      ),

      // 대회 참가신청 (전체 화면)
      GoRoute(
        path: '/contest/:id/register',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final contest = state.extra as ContestDetail?;
          if (contest == null) {
            return const Scaffold(
              body: Center(child: Text('대회 정보를 불러올 수 없습니다.')),
            );
          }
          return ContestRegistrationScreen(
            homepageId: id,
            contest: contest,
          );
        },
      ),

      // 단체전 팀 대표 일괄 등록 (전체 화면)
      GoRoute(
        path: '/contest/:id/team-register',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final extra = state.extra as Map<String, dynamic>?;
          if (extra == null) {
            return const Scaffold(
              body: Center(child: Text('대회 정보를 불러올 수 없습니다.')),
            );
          }
          return TeamBulkRegistrationScreen(
            homepageId: id,
            contest: extra['contest'] as ContestDetail,
            category: extra['category'] as ContestCategory,
          );
        },
      ),

      // 단체전 팀 합류 (전체 화면)
      GoRoute(
        path: '/contest/:id/team-join',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final extra = state.extra as Map<String, dynamic>?;
          if (extra == null) {
            return const Scaffold(
              body: Center(child: Text('대회 정보를 불러올 수 없습니다.')),
            );
          }
          return TeamJoinScreen(
            homepageId: id,
            contest: extra['contest'] as ContestDetail,
            category: extra['category'] as ContestCategory,
          );
        },
      ),

      // 대회 홈페이지 WebView (내부 홈페이지)
      GoRoute(
        path: '/homepage-webview/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final title = state.uri.queryParameters['title'] ?? '대회 홈페이지';
          return ContestHomepageWebView(
            homepageId: id,
            title: title,
          );
        },
      ),

      // 외부 홈페이지 WebView
      GoRoute(
        path: '/external-homepage',
        builder: (context, state) {
          final url = state.uri.queryParameters['url'] ?? '';
          final title = state.uri.queryParameters['title'] ?? '대회 홈페이지';
          return ContestHomepageWebView(
            externalUrl: url,
            title: title,
          );
        },
      ),

      // 프로필 수정 (전체 화면)
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const ProfileEditScreen(),
      ),

      // 전화번호 변경 (전체 화면)
      GoRoute(
        path: '/change-phone',
        builder: (context, state) => const ChangePhoneScreen(),
      ),

      // 설정 (전체 화면)
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      // 이용약관 (전체 화면)
      GoRoute(
        path: '/terms',
        builder: (context, state) => const TermsScreen(),
      ),

      // 개인정보처리방침 (전체 화면)
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),

      // 회원 탈퇴 (전체 화면)
      GoRoute(
        path: '/account-withdrawal',
        builder: (context, state) => const AccountWithdrawalScreen(),
      ),

      // 고객센터 (전체 화면)
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportScreen(),
      ),

      // FAQ (전체 화면)
      GoRoute(
        path: '/support/faq',
        builder: (context, state) => const FaqScreen(),
      ),

      // 공지사항 목록 (전체 화면)
      GoRoute(
        path: '/support/notices',
        builder: (context, state) => const NoticeListScreen(),
      ),

      // 공지사항 상세 (전체 화면)
      GoRoute(
        path: '/support/notices/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return NoticeDetailScreen(noticeId: id);
        },
      ),

      // 1:1 문의 목록 (전체 화면)
      GoRoute(
        path: '/support/inquiries',
        builder: (context, state) => const InquiryListScreen(),
      ),

      // 문의 작성 (전체 화면)
      GoRoute(
        path: '/support/inquiries/create',
        builder: (context, state) => const InquiryCreateScreen(),
      ),

      // 문의 상세 (전체 화면)
      GoRoute(
        path: '/support/inquiries/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return InquiryDetailScreen(inquiryId: id);
        },
      ),

      // 포털 메인 (전체 화면)
      GoRoute(
        path: '/portal/:contestId',
        builder: (context, state) {
          final contestId = int.tryParse(state.pathParameters['contestId'] ?? '') ?? 0;
          return PortalScreen(contestId: contestId);
        },
      ),

      // 포털 상세 (전체 화면)
      GoRoute(
        path: '/portal/:contestId/detail',
        builder: (context, state) {
          final contestId = int.tryParse(state.pathParameters['contestId'] ?? '') ?? 0;
          final participant = state.extra as PortalParticipant?;
          if (participant == null) {
            return const Scaffold(
              body: Center(child: Text('참가자 정보를 불러올 수 없습니다.')),
            );
          }
          return PortalDetailScreen(
            contestId: contestId,
            participant: participant,
          );
        },
      ),

      // 라이브 대회 화면 (전체 화면)
      GoRoute(
        path: '/live/:contestId',
        builder: (context, state) {
          final contestId = int.tryParse(state.pathParameters['contestId'] ?? '') ?? 0;
          return LiveContestScreen(contestId: contestId);
        },
      ),

      // 내 참가 대회 목록 (QR 체크인)
      GoRoute(
        path: '/qr/contests',
        builder: (context, state) => const MyContestsScreen(),
      ),

      // 내 대회 상세 (QR 체크인)
      GoRoute(
        path: '/qr/contest/:contestId',
        builder: (context, state) {
          final contestId = int.tryParse(state.pathParameters['contestId'] ?? '') ?? 0;
          return MyContestDetailScreen(contestId: contestId);
        },
      ),

      // QR 스캔 (전체 화면)
      GoRoute(
        path: '/qr/scan',
        builder: (context, state) => const QRScannerScreen(),
      ),

      // // 바둑판 AI 계가 (기능 개발중 - 추후 활성화)
      // GoRoute(
      //   path: '/board-analysis',
      //   builder: (context, state) => const BoardCaptureScreen(),
      // ),

      // 결제 화면 (전체 화면)
      GoRoute(
        path: '/payment',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          if (extra == null) {
            return const Scaffold(
              body: Center(child: Text('결제 정보를 불러올 수 없습니다.')),
            );
          }
          return PaymentScreen(
            registration: extra['registration'],  // RegistrationData 객체 (신규 신청 시)
            existingRegistrationId: extra['registrationId'] as int?,  // 기존 참가신청 (미결제 재시도 시)
            participantName: extra['participantName'] as String,
            categoryName: extra['categoryName'] as String,
            contestName: extra['contestName'] as String,
            amount: extra['amount'] as int,
            homepageId: extra['homepageId'] as int?,
            contestStartDate: extra['contestStartDate'] as DateTime?,
          );
        },
      ),

      // 토스 결제 WebView (전체 화면)
      GoRoute(
        path: '/payment/toss-checkout',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return TossCheckoutScreen(
            orderId: extra['orderId'] as String,
            amount: extra['amount'] as int,
            orderName: extra['orderName'] as String,
            registrationId: extra['registrationId'] as int,
          );
        },
      ),

      // 결제 완료 화면 (전체 화면)
      GoRoute(
        path: '/payment/success',
        builder: (context, state) {
          final payment = _parsePaymentExtra(state.extra);
          if (payment == null) {
            return const Scaffold(
              body: Center(child: Text('결제 정보를 불러올 수 없습니다.')),
            );
          }
          return PaymentSuccessScreen(payment: payment);
        },
      ),

      // 참가신청 수정 화면 (전체 화면)
      GoRoute(
        path: '/registration/edit/:registrationId',
        builder: (context, state) {
          final registrationId = int.tryParse(state.pathParameters['registrationId'] ?? '') ?? 0;
          final extra = state.extra as Map<String, dynamic>?;
          return RegistrationEditScreen(registrationId: registrationId, currentData: extra);
        },
      ),

      // 환불 규정 페이지
      GoRoute(
        path: '/refund-policy/:homepageId',
        builder: (context, state) {
          final homepageId = int.tryParse(state.pathParameters['homepageId'] ?? '') ?? 0;
          final contestName = state.uri.queryParameters['name'] ?? '대회';
          return RefundPolicyPage(
            homepageId: homepageId,
            contestName: contestName,
          );
        },
      ),

      // 환불 신청 화면 (전체 화면)
      GoRoute(
        path: '/refund/:registrationId',
        builder: (context, state) {
          final registrationId = int.tryParse(state.pathParameters['registrationId'] ?? '') ?? 0;
          return RefundRequestScreen(registrationId: registrationId);
        },
      ),

      // (무통장입금/계좌인증 라우트 제거됨 - 토스 결제 전용)
      // 아래 줄은 기존 코드의 닫는 괄호를 유지하기 위한 더미
      GoRoute(
        path: '/deprecated-placeholder',
        builder: (context, state) {
          return const Scaffold(body: Center(child: Text('지원하지 않는 페이지입니다.')));
        },
      ),

      // 관리자: 주최자 신청 관리 (전체 화면)
      GoRoute(
        path: '/admin/host-applications',
        builder: (context, state) => const HostApplicationsScreen(),
      ),

      // 주최자 신청 화면 (전체 화면)
      GoRoute(
        path: '/host/apply',
        builder: (context, state) => const HostApplyScreen(),
      ),

      // 주최자: 대회 개최 의뢰 (전체 화면)
      GoRoute(
        path: '/host/create-contest',
        builder: (context, state) => const ContestRequestScreen(),
      ),

      // 주최자: 내 의뢰 목록 (전체 화면)
      GoRoute(
        path: '/host/requests',
        builder: (context, state) => const MyRequestsScreen(),
      ),

      // 주최자: 의뢰 상세 (전체 화면)
      GoRoute(
        path: '/host/requests/:requestId',
        builder: (context, state) {
          final requestId = int.tryParse(state.pathParameters['requestId'] ?? '') ?? 0;
          return RequestDetailScreen(requestId: requestId);
        },
      ),

      // 주최자: 의뢰 수정 (전체 화면)
      GoRoute(
        path: '/host/edit-request/:requestId',
        builder: (context, state) {
          final requestId = int.tryParse(state.pathParameters['requestId'] ?? '') ?? 0;
          return ContestRequestScreen(requestId: requestId);
        },
      ),

      // 관리자: 의뢰 관리 (전체 화면)
      GoRoute(
        path: '/admin/contest-requests',
        builder: (context, state) => const AdminRequestsScreen(),
      ),

      // 관리자: 푸시 알림 발송 (전체 화면)
      GoRoute(
        path: '/admin/push',
        builder: (context, state) => const PushNotificationScreen(),
      ),

      // 관리자: 공지사항 관리 (전체 화면)
      GoRoute(
        path: '/admin/notices',
        builder: (context, state) => const NoticeManageScreen(),
      ),

      // 관리자: 의뢰 수정 (전체 화면)
      GoRoute(
        path: '/host/admin/edit-request/:requestId',
        builder: (context, state) {
          final requestId = int.tryParse(state.pathParameters['requestId'] ?? '') ?? 0;
          return ContestRequestScreen(requestId: requestId, isAdmin: true);
        },
      ),

      // 내 클럽 목록 (전체 화면)
      GoRoute(
        path: '/clubs',
        builder: (context, state) => const MyClubsScreen(),
      ),

      // 클럽 탐색 (전체 화면)
      GoRoute(
        path: '/clubs/explore',
        builder: (context, state) => const ClubExploreScreen(),
      ),

      // 클럽 생성 (전체 화면)
      GoRoute(
        path: '/clubs/create',
        builder: (context, state) => const ClubCreateScreen(),
      ),

      // 클럽 멤버 선택 (단체전 팀 등록용, 전체 화면)
      // 고정 경로이므로 :clubId 매칭보다 먼저 위치해야 함
      GoRoute(
        path: '/clubs/pick-members',
        builder: (context, state) {
          final teamSize = state.extra is int ? state.extra as int : null;
          return ClubMemberPickerScreen(teamSize: teamSize);
        },
      ),

      // 클럽 상세 (전체 화면)
      GoRoute(
        path: '/clubs/:clubId',
        builder: (context, state) {
          final clubId = int.tryParse(state.pathParameters['clubId'] ?? '') ?? 0;
          return ClubDetailScreen(clubId: clubId);
        },
      ),

      // 클럽 정보 수정 (전체 화면)
      GoRoute(
        path: '/clubs/:clubId/edit',
        builder: (context, state) {
          final clubId = int.tryParse(state.pathParameters['clubId'] ?? '') ?? 0;
          return ClubEditScreen(clubId: clubId);
        },
      ),

      // 클럽 대회 생성 (전체 화면)
      GoRoute(
        path: '/clubs/:clubId/contests/create',
        builder: (context, state) {
          final clubId = int.tryParse(state.pathParameters['clubId'] ?? '') ?? 0;
          return ClubContestCreateScreen(clubId: clubId);
        },
      ),

      // 클럽 대회 관리 (전체 화면)
      GoRoute(
        path: '/clubs/:clubId/contests/:contestId/manage',
        builder: (context, state) {
          final clubId = int.tryParse(state.pathParameters['clubId'] ?? '') ?? 0;
          final contestId = int.tryParse(state.pathParameters['contestId'] ?? '') ?? 0;
          return ClubContestManageScreen(clubId: clubId, contestId: contestId);
        },
      ),

      // 클럽 대회 참가자 선택 (전체 화면, sortId 쿼리 파라미터)
      GoRoute(
        path: '/clubs/:clubId/contests/:contestId/select-participants',
        builder: (context, state) {
          final clubId = int.tryParse(state.pathParameters['clubId'] ?? '') ?? 0;
          final contestId = int.tryParse(state.pathParameters['contestId'] ?? '') ?? 0;
          final sortId = int.tryParse(state.uri.queryParameters['sortId'] ?? '') ?? 0;
          final gameType = state.uri.queryParameters['gameType'] ?? '';
          return ClubParticipantSelectScreen(clubId: clubId, contestId: contestId, sortId: sortId, gameType: gameType);
        },
      ),

      // 클럽 랭킹 (전체 화면)
      GoRoute(
        path: '/clubs/:clubId/rankings',
        builder: (context, state) {
          final clubId = int.tryParse(state.pathParameters['clubId'] ?? '') ?? 0;
          return ClubRankingsScreen(clubId: clubId);
        },
      ),

      // 클럽 가입 신청 관리 (전체 화면)
      GoRoute(
        path: '/clubs/:clubId/requests',
        builder: (context, state) {
          final clubId = int.tryParse(state.pathParameters['clubId'] ?? '') ?? 0;
          return ClubJoinRequestsScreen(clubId: clubId);
        },
      ),
      // 클럽 사진 뷰어 (전체 화면)
      GoRoute(
        path: '/clubs/:clubId/photos/:photoId',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          if (extra == null || extra['photo'] == null) {
            return const Scaffold(
              body: Center(child: Text('사진 정보를 불러올 수 없습니다.')),
            );
          }
          return ClubPhotoViewScreen(
            photo: extra['photo'] as ClubPhoto,
            canDelete: extra['canDelete'] as bool? ?? false,
          );
        },
      ),

      GoRoute(
        path: '/clubs/:clubId/posts/create',
        builder: (context, state) {
          final clubId = int.tryParse(state.pathParameters['clubId'] ?? '') ?? 0;
          final extra = state.extra;
          // extra가 ClubPostDetail이면 수정 모드
          if (extra is ClubPostDetail) {
            return ClubPostCreateScreen(clubId: clubId, editPost: extra);
          }
          // extra가 Map이면 myRole 전달
          final myRole = extra is Map<String, dynamic> ? extra['myRole'] as String? : null;
          return ClubPostCreateScreen(clubId: clubId, myRole: myRole);
        },
      ),
      GoRoute(
        path: '/clubs/:clubId/posts/:postId',
        builder: (context, state) {
          final clubId = int.tryParse(state.pathParameters['clubId'] ?? '') ?? 0;
          final postId = int.tryParse(state.pathParameters['postId'] ?? '') ?? 0;
          return ClubPostDetailScreen(clubId: clubId, postId: postId);
        },
      ),
    ],

    // 에러 페이지
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('페이지를 찾을 수 없습니다: ${state.uri}'),
      ),
    ),
  );
});

/// GoRouter extra에서 Payment 객체를 안전하게 파싱
/// (직렬화로 Map이 전달되는 경우 대응)
Payment? _parsePaymentExtra(Object? extra) {
  if (extra is Payment) return extra;
  if (extra is Map<String, dynamic>) return Payment.fromJson(extra);
  return null;
}
