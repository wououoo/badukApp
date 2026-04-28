import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/error/error_handler.dart';
import 'data/providers/auth_provider.dart';
import 'data/providers/theme_provider.dart';
import 'routing/app_router.dart';

// 조건부 import (웹에서는 stub 사용)
import 'data/services/notification_service_stub.dart'
    if (dart.library.io) 'data/services/notification_service.dart';

// 백그라운드 메시지 핸들러
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] 백그라운드 메시지 수신: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚠️ 앱 재설치 후 stale 데이터 제거
  // - iOS: Keychain은 앱 삭제와 무관하게 남음 (FlutterSecureStorage가 사용) → 재설치 시 stale 토큰 잔존
  // - Android: allowBackup=false로 막아도 안전망 차원에서 같이 처리
  // SharedPreferences는 iOS/Android 모두 앱 삭제 시 함께 삭제되므로
  // "초기화 플래그가 없음 = 첫 실행(재설치 직후)"로 판별 가능.
  if (!kIsWeb) {
    try {
      final prefs = await SharedPreferences.getInstance();
      const initFlagKey = 'app_initialized_v1';
      if (prefs.getBool(initFlagKey) != true) {
        debugPrint('[INIT] 첫 실행 감지 → SecureStorage 전체 정리 (재설치 stale 데이터 방지)');
        try {
          const storage = FlutterSecureStorage();
          await storage.deleteAll();
        } catch (e) {
          debugPrint('[INIT] SecureStorage 정리 실패 (무시): $e');
        }
        await prefs.setBool(initFlagKey, true);
      }
    } catch (e) {
      debugPrint('[INIT] 첫 실행 처리 실패 (무시): $e');
    }
  }

  // Android WebView 플랫폼 초기화
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    WebViewPlatform.instance = AndroidWebViewPlatform();
  }

  // Firebase 초기화 (웹 제외)
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();

      // FCM 설정
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // 알림 권한 요청
      try {
        NotificationSettings settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('[FCM] 권한 상태: ${settings.authorizationStatus}');
      } catch (e) {
        debugPrint('[FCM] 권한 요청 실패 (무시): $e');
      }

      // FCM 토큰 가져오기 (실패해도 앱은 계속 실행)
      try {
        String? token = await messaging.getToken();
        debugPrint('[FCM] 토큰: ${token?.substring(0, 20)}...');
      } catch (e) {
        debugPrint('[FCM] 토큰 가져오기 실패 (무시): $e');
      }

      // 백그라운드 핸들러 등록
      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (e) {
        debugPrint('[FCM] 백그라운드 핸들러 등록 실패 (무시): $e');
      }

      // 로컬 알림 서비스 초기화 (포그라운드 알림 표시)
      try {
        await NotificationService().initialize();
      } catch (e) {
        debugPrint('[NotificationService] 초기화 실패 (무시): $e');
      }
    } catch (e) {
      debugPrint('[Firebase] 초기화 실패 (무시하고 앱 계속 실행): $e');
    }

    // 네이버 지도 SDK 초기화 (Maps 상품 - AndroidManifest NCP_KEY_ID로 인증)
    try {
      await NaverMapSdk.instance.initialize(
        onAuthFailed: (error) {
          debugPrint('[네이버맵] 인증 실패: $error');
        },
      );
    } catch (e) {
      debugPrint('[네이버맵] 초기화 실패 (무시): $e');
    }
  }

  // 카카오 SDK 초기화 (빌드 시 --dart-define으로 주입)
  const kakaoNativeKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: 'e50cfb50ae0d4424f60fc863d0e0b7e4',
  );
  const kakaoJsKey = String.fromEnvironment(
    'KAKAO_JS_APP_KEY',
    defaultValue: 'f32424db5aca3d957e09d0f945efc805',
  );
  KakaoSdk.init(
    nativeAppKey: kakaoNativeKey,
    javaScriptAppKey: kakaoJsKey,
  );

  // 키 해시 출력 (카카오 개발자 콘솔 등록용 - 등록 후 삭제)
  try {
    var keyHash = await KakaoSdk.origin;
    debugPrint('[Kakao] KeyHash: $keyHash');
  } catch (e) {
    debugPrint('[Kakao] KeyHash 조회 실패: $e');
  }

  runApp(const ProviderScope(child: BadukApp()));
}

class BadukApp extends ConsumerStatefulWidget {
  const BadukApp({super.key});

  @override
  ConsumerState<BadukApp> createState() => _BadukAppState();
}

class _BadukAppState extends ConsumerState<BadukApp> {
  @override
  void initState() {
    super.initState();
    _setupFcmTokenRefresh();
  }

  /// FCM 토큰 갱신 리스너 설정
  void _setupFcmTokenRefresh() {
    if (kIsWeb) return;

    // 토큰 갱신 시 서버에 업데이트 (FCM 사용 불가 환경에서도 앱 시작 막지 않음)
    try {
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (newToken) {
          debugPrint('[FCM] 토큰 갱신됨');
          ref.read(authProvider.notifier).registerFcmToken();
        },
        onError: (error) {
          debugPrint('[FCM] 토큰 갱신 리스너 에러 (무시): $error');
        },
      );
    } catch (e) {
      debugPrint('[FCM] 토큰 갱신 리스너 등록 실패 (무시): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    // 라이트 모드 고정
    AppColors.setDarkMode(false);

    return MaterialApp.router(
      title: '바둑대회',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: router,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      builder: (context, child) {
        // 시스템 글자 크기 확대 시 UI 깨짐 방지 (항상 1.0 고정)
        final mediaQuery = MediaQuery.of(context);
        const clampedTextScaler = TextScaler.linear(1.0);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clampedTextScaler),
          child: child!,
        );
      },
    );
  }
}
