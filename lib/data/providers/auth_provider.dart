import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../models/auth_response.dart';
import '../services/auth_service.dart'; // SocialLoginResponse 포함
import '../services/biometric_service.dart';

/// AuthService 프로바이더
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// 인증 상태
enum AuthStatus {
  initial,
  loading,
  otpSent,           // OTP 발송됨
  otpVerifying,      // OTP 검증 중
  socialLoggedIn,    // 소셜 로그인 완료, 본인인증 필요
  identityVerified,  // 본인인증 완료, 추가정보 필요
  needsPrivacyConsent, // 개인정보 동의 필요
  profileSetup,      // 추가정보 입력 중
  authenticated,     // 모든 인증 완료
  unauthenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;
  final String? phone;       // OTP 발송된 전화번호
  final bool isNewUser;      // 신규 사용자 여부
  final int? otpResendSeconds; // OTP 재발송 대기 시간

  // 소셜 로그인 관련
  final bool identityVerified;   // 본인인증 완료 여부
  final bool profileCompleted;   // 프로필 설정 완료 여부

  // 본인인증 결과 데이터 (임시 저장)
  final String? verifiedName;
  final String? verifiedPhone;
  final String? verifiedBirthDate;
  final String? verifiedGender;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.phone,
    this.isNewUser = false,
    this.otpResendSeconds,
    this.identityVerified = false,
    this.profileCompleted = false,
    this.verifiedName,
    this.verifiedPhone,
    this.verifiedBirthDate,
    this.verifiedGender,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    String? phone,
    bool? isNewUser,
    int? otpResendSeconds,
    bool? identityVerified,
    bool? profileCompleted,
    String? verifiedName,
    String? verifiedPhone,
    String? verifiedBirthDate,
    String? verifiedGender,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      phone: phone ?? this.phone,
      isNewUser: isNewUser ?? this.isNewUser,
      otpResendSeconds: otpResendSeconds ?? this.otpResendSeconds,
      identityVerified: identityVerified ?? this.identityVerified,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      verifiedName: verifiedName ?? this.verifiedName,
      verifiedPhone: verifiedPhone ?? this.verifiedPhone,
      verifiedBirthDate: verifiedBirthDate ?? this.verifiedBirthDate,
      verifiedGender: verifiedGender ?? this.verifiedGender,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading || status == AuthStatus.otpVerifying;
  bool get isOtpSent => status == AuthStatus.otpSent;
  bool get needsIdentityVerification => status == AuthStatus.socialLoggedIn;
  bool get needsPrivacyConsent => status == AuthStatus.needsPrivacyConsent;
  bool get needsProfileSetup => status == AuthStatus.identityVerified;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  bool _isCheckingAuth = false;

  AuthNotifier(this._authService) : super(const AuthState()) {
    _checkAuthStatus();
  }

  /// savedUser의 실제 identityVerified/profileCompleted 값으로 AuthState 복원
  /// (네트워크 에러 등으로 서버 프로필 조회 실패 시 사용)
  /// 강제 true 부여 금지 — 본인인증 미완료 사용자가 보호 기능 우회하는 것 방지
  AuthState _restoreFromSavedUser(User savedUser) {
    final identityVerified = savedUser.identityVerified ?? false;
    final profileCompleted = savedUser.profileCompleted ?? false;

    AuthStatus status;
    if (profileCompleted) {
      status = AuthStatus.authenticated;
    } else if (identityVerified) {
      status = AuthStatus.identityVerified;
    } else {
      status = AuthStatus.socialLoggedIn;
    }

    debugPrint('[Auth] savedUser 복원: name=${savedUser.name}, '
        'identityVerified=$identityVerified, profileCompleted=$profileCompleted, status=$status');

    return AuthState(
      status: status,
      user: savedUser,
      identityVerified: identityVerified,
      profileCompleted: profileCompleted,
    );
  }

  /// 초기 인증 상태 확인
  Future<void> _checkAuthStatus() async {
    if (_isCheckingAuth) return; // 중복 호출 방지
    _isCheckingAuth = true;
    debugPrint('[Auth] _checkAuthStatus called');
    state = state.copyWith(status: AuthStatus.loading);

    try {
      // 토큰 조회에 5초 timeout (스토리지 자체 hang 방지)
      final isLoggedIn = await _authService.isLoggedIn().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[Auth] isLoggedIn timeout → unauth로 진행');
          return false;
        },
      );
      if (!isLoggedIn) {
        // 토큰이 없어도 저장된 유저 정보가 있으면 인증 유지 시도
        final savedUser = await _authService.getSavedUser().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
        if (savedUser != null) {
          state = _restoreFromSavedUser(savedUser);
          return;
        }
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      // 서버에서 최신 프로필 정보 가져오기 (8초 timeout - 네트워크 지연 대응)
      User? user;
      try {
        user = await _authService.getCurrentProfile().timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            debugPrint('[Auth] getCurrentProfile timeout');
            return null;
          },
        );
      } catch (e) {
        debugPrint('[Auth] 프로필 조회 실패, 저장된 정보로 시도: $e');
      }

      if (user == null) {
        // 프로필 조회 실패 → 저장된 사용자 정보로 인증 유지
        final savedUser = await _authService.getSavedUser();
        if (savedUser != null) {
          state = _restoreFromSavedUser(savedUser);
          return;
        }
        // 저장된 정보도 없으면 미인증 (logout 호출 안함 - 토큰 보존)
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      // 프로필 상태에 따라 인증 상태 결정
      if (user.profileCompleted == true) {
        // 프로필 완료 → 완전 인증 (개인정보 동의 여부와 무관)
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
          identityVerified: true,
          profileCompleted: true,
        );
        // FCM 토큰 등록
        registerFcmToken();
      } else if (user.identityVerified == true) {
        // 본인인증 완료, 프로필 미완료
        state = AuthState(
          status: AuthStatus.identityVerified,
          user: user,
          identityVerified: true,
          profileCompleted: false,
        );
      } else {
        // 소셜 로그인만 완료
        state = AuthState(
          status: AuthStatus.socialLoggedIn,
          user: user,
          identityVerified: false,
          profileCompleted: false,
        );
      }
    } on DioException catch (e) {
      debugPrint('[Auth] DioException: type=${e.type}, statusCode=${e.response?.statusCode}');
      // 네트워크/서버 에러: 저장된 정보로 인증 유지 (실제 인증 단계 그대로 복원)
      final savedUser = await _authService.getSavedUser();
      if (savedUser != null) {
        state = _restoreFromSavedUser(savedUser);
        return;
      }
      // 저장된 유저가 없으면 생체 인증 시도
      final biometric = BiometricService.instance;
      final biometricEnabled = await biometric.isEnabled();
      final biometricAvailable = await biometric.isAvailable();
      if (biometricEnabled && biometricAvailable) {
        final authenticated = await biometric.authenticate();
        if (authenticated) {
          debugPrint('[Auth] 생체 인증 성공, 로그인 유지');
          // 생체 인증 성공이지만 유저 정보 없음 → 로그아웃
        }
      }
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      debugPrint('[Auth] _checkAuthStatus error: $e');
      // 일반 에러 시에도 저장된 사용자 정보로 인증 유지 (실제 인증 단계 그대로 복원)
      final savedUser = await _authService.getSavedUser();
      if (savedUser != null) {
        state = _restoreFromSavedUser(savedUser);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    }
    _isCheckingAuth = false;
    debugPrint('[Auth] _checkAuthStatus done: status=${state.status}');
  }

  /// OTP 인증번호 발송 요청
  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final response = await _authService.sendOtp(phone);

      if (response.success) {
        state = AuthState(
          status: AuthStatus.otpSent,
          phone: phone,
          otpResendSeconds: 180, // 3분
        );
        return true;
      } else {
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: response.message ?? '인증번호 발송에 실패했습니다.',
        );
        return false;
      }
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  /// OTP 인증번호 검증 및 로그인
  /// SocialLoginResponse로 받아서 _handleSocialLoginSuccess로 상태 처리
  Future<bool> verifyOtp(String otpCode, {String? name}) async {
    if (state.phone == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: '전화번호 정보가 없습니다. 다시 시도해주세요.',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.otpVerifying);

    try {
      final response = await _authService.verifyOtp(
        state.phone!,
        otpCode,
        name: name,
      );

      if (response.success && response.token != null) {
        return _handleSocialLoginSuccess(response);
      } else {
        state = AuthState(
          status: AuthStatus.otpSent,
          phone: state.phone,
          errorMessage: response.message ?? '인증에 실패했습니다.',
        );
        return false;
      }
    } catch (e) {
      state = AuthState(
        status: AuthStatus.otpSent,
        phone: state.phone,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  /// 사용자 이름 업데이트 (신규 사용자용)
  Future<bool> updateUserName(String name) async {
    if (state.user?.phone == null) return false;

    try {
      final success = await _authService.updateUserName(state.user!.phone!, name);
      if (success) {
        final updatedUser = User(
          id: state.user!.id,
          name: name,
          phone: state.user!.phone,
          rank: state.user!.rank,
        );
        state = state.copyWith(user: updatedUser, isNewUser: false);
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// OTP 입력 화면으로 돌아가기 (전화번호 재입력)
  void resetToPhoneInput() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // ========== 소셜 로그인 ==========

  /// 테스트 계정 로그인 (토스 심사용)
  Future<bool> loginWithTest(String testId, String testPassword) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final response = await _authService.loginWithTest(testId, testPassword);

      if (response.success) {
        return _handleSocialLoginSuccess(response);
      } else {
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: response.message ?? '테스트 로그인에 실패했습니다.',
        );
        return false;
      }
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  /// 카카오 로그인
  Future<bool> loginWithKakao(String accessToken) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final response = await _authService.loginWithKakao(accessToken);

      if (response.success) {
        return _handleSocialLoginSuccess(response);
      } else {
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: response.message ?? '카카오 로그인에 실패했습니다.',
        );
        return false;
      }
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  /// 애플 로그인
  Future<bool> loginWithApple({
    required String identityToken,
    required String appleUserId,
    String? authorizationCode,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final response = await _authService.loginWithApple(
        identityToken: identityToken,
        appleUserId: appleUserId,
        authorizationCode: authorizationCode,
      );

      if (response.success) {
        return _handleSocialLoginSuccess(response);
      } else {
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: response.message ?? '애플 로그인에 실패했습니다.',
        );
        return false;
      }
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  /// 네이버 로그인
  Future<bool> loginWithNaver(String accessToken) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final response = await _authService.loginWithNaver(accessToken);

      if (response.success) {
        return _handleSocialLoginSuccess(response);
      } else {
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: response.message ?? '네이버 로그인에 실패했습니다.',
        );
        return false;
      }
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  /// 소셜 로그인 성공 처리
  bool _handleSocialLoginSuccess(SocialLoginResponse response) {
    if (response.profileCompleted) {
      // 프로필까지 완료된 경우 → 완전 인증
      state = AuthState(
        status: AuthStatus.authenticated,
        user: response.user,
        identityVerified: true,
        profileCompleted: true,
      );
      // FCM 토큰 등록
      registerFcmToken();
    } else if (response.identityVerified) {
      // 본인인증 완료, 프로필 미완료 → 프로필 설정 필요
      state = AuthState(
        status: AuthStatus.identityVerified,
        user: response.user,
        identityVerified: true,
        profileCompleted: false,
      );
    } else {
      // 본인인증 미완료 → 본인인증 필요
      state = AuthState(
        status: AuthStatus.socialLoggedIn,
        user: response.user,
        identityVerified: false,
        profileCompleted: false,
      );
    }
    return true;
  }

  // ========== 본인인증 ==========

  /// 카카오 추가 동의 기반 본인인증 (loginWithNewScopes 후 호출)
  Future<bool> verifyIdentityWithKakaoScopes({
    required String kakaoAccessToken,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final response = await _authService.verifyIdentityWithKakaoScopes(
        kakaoAccessToken: kakaoAccessToken,
      );

      if (response.success) {
        final updatedUser = await _authService.getCurrentProfile();

        state = AuthState(
          status: AuthStatus.identityVerified,
          user: updatedUser ?? state.user,
          identityVerified: true,
          profileCompleted: false,
          verifiedName: response.name,
          verifiedPhone: response.phoneNumber,
          verifiedBirthDate: response.birthDate,
          verifiedGender: response.gender,
        );
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.socialLoggedIn,
          errorMessage: response.message ?? '카카오 본인인증에 실패했습니다.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.socialLoggedIn,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  /// 카카오 인증서 본인인증 (txId + accessToken 방식)
  Future<bool> verifyIdentityWithKakao({
    required String txId,
    required String accessToken,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final response = await _authService.verifyKakaoCert(
        txId: txId,
        accessToken: accessToken,
      );

      if (response.success) {
        // 본인인증 완료 후 최신 프로필 정보 가져오기 (연동된 맥마흔 정보 포함)
        final updatedUser = await _authService.getCurrentProfile();

        state = AuthState(
          status: AuthStatus.identityVerified,
          user: updatedUser ?? state.user,
          identityVerified: true,
          profileCompleted: false,
          verifiedName: response.name,
          verifiedPhone: response.phoneNumber,
          verifiedBirthDate: response.birthDate,
          verifiedGender: response.gender,
        );
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.socialLoggedIn,
          errorMessage: response.message ?? '카카오 인증서 본인인증에 실패했습니다.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.socialLoggedIn,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  /// 수동 본인인증 (개발/테스트용)
  Future<bool> setManualIdentity({
    required String name,
    required String phoneNumber,
    String? birthDate,
    String? gender,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final response = await _authService.setManualIdentity(
        name: name,
        phoneNumber: phoneNumber,
        birthDate: birthDate,
        gender: gender,
      );

      if (response.success) {
        // 본인인증 완료 후 최신 프로필 정보 가져오기 (연동된 맥마흔 정보 포함)
        final updatedUser = await _authService.getCurrentProfile();

        state = AuthState(
          status: AuthStatus.identityVerified,
          user: updatedUser ?? state.user,
          identityVerified: true,
          profileCompleted: false,
          verifiedName: response.name,
          verifiedPhone: response.phoneNumber,
          verifiedBirthDate: response.birthDate,
          verifiedGender: response.gender,
        );
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.socialLoggedIn,
          errorMessage: response.message ?? '본인인증에 실패했습니다.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.socialLoggedIn,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  /// 카카오 본인인증 실행 (기존 방식)
  Future<bool> verifyIdentity(String identityToken) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final response = await _authService.verifyIdentity(identityToken);

      if (response.success) {
        // 본인인증 결과 임시 저장
        state = state.copyWith(
          status: AuthStatus.identityVerified,
          identityVerified: true,
          verifiedName: response.name,
          verifiedPhone: response.phoneNumber,
          verifiedBirthDate: response.birthDate,
          verifiedGender: response.gender,
        );
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.socialLoggedIn, // 소셜 로그인 상태로 복귀
          errorMessage: response.message ?? '본인인증에 실패했습니다.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.socialLoggedIn,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  /// 본인인증 정보 확인 및 저장
  Future<bool> confirmIdentity() async {
    if (state.verifiedName == null || state.verifiedPhone == null) {
      state = state.copyWith(
        errorMessage: '본인인증 정보가 없습니다. 다시 인증해주세요.',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading);

    try {
      final response = await _authService.confirmIdentity(
        name: state.verifiedName!,
        phoneNumber: state.verifiedPhone!,
        birthDate: state.verifiedBirthDate ?? '',
        gender: state.verifiedGender ?? '',
      );

      if (response.success) {
        state = AuthState(
          status: AuthStatus.identityVerified,
          user: response.user,
          identityVerified: true,
          profileCompleted: false,
        );
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.socialLoggedIn,
          errorMessage: response.message ?? '본인인증 정보 저장에 실패했습니다.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.socialLoggedIn,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  // ========== 프로필 설정 ==========

  /// 프로필 정보 업데이트 (초기 설정 또는 수정)
  Future<bool> updateProfile({
    String? name,
    int? level,
    String? region,
    String? city,
    String? club,
  }) async {
    final previousStatus = state.status;
    state = state.copyWith(status: AuthStatus.profileSetup);

    try {
      final response = await _authService.updateProfile(
        name: name,
        level: level,
        region: region,
        city: city,
        club: club,
      );

      if (response.success) {
        // 프로필 수정 성공 - 서버에서 최신 프로필 정보 재조회
        final updatedUser = await _authService.getCurrentProfile();
        state = AuthState(
          status: AuthStatus.authenticated,
          user: updatedUser ?? response.user ?? state.user,
          identityVerified: true,
          profileCompleted: true,
        );
        // FCM 토큰 등록
        registerFcmToken();
        return true;
      } else {
        // 실패 시 이전 상태로 복원
        state = state.copyWith(
          status: previousStatus == AuthStatus.authenticated
              ? AuthStatus.authenticated
              : AuthStatus.identityVerified,
          errorMessage: response.message ?? '프로필 저장에 실패했습니다.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: previousStatus == AuthStatus.authenticated
            ? AuthStatus.authenticated
            : AuthStatus.identityVerified,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  /// 전화번호 변경 (카카오 본인인증, 이미 인증된 사용자용)
  Future<bool> changePhone({required String kakaoAccessToken}) async {
    try {
      final response = await _authService.verifyIdentityWithKakaoScopes(
        kakaoAccessToken: kakaoAccessToken,
      );

      if (response.success) {
        // 인증 상태 유지하면서 프로필만 새로고침
        final updatedUser = await _authService.getCurrentProfile();
        if (updatedUser != null) {
          state = state.copyWith(user: updatedUser);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Auth] 전화번호 변경 실패: $e');
      return false;
    }
  }

  /// 프로필 새로고침
  Future<void> refreshProfile() async {
    try {
      final user = await _authService.getCurrentProfile();
      if (user != null) {
        state = state.copyWith(user: user);
      }
    } catch (e) {
      // 무시
    }
  }

  // ========== SMS OTP 본인인증 (SNS 로그인 후) ==========

  /// SMS OTP 발송 (본인인증용)
  Future<bool> sendOtpForIdentity(String phone) async {
    try {
      final response = await _authService.sendOtpForIdentity(phone);
      if (response.success) {
        return true;
      } else {
        state = state.copyWith(
          errorMessage: response.message ?? '인증번호 발송에 실패했습니다.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  /// SMS OTP 검증 후 본인인증 완료
  Future<bool> verifyOtpForIdentity({
    required String phone,
    required String otpCode,
    required String name,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final response = await _authService.verifyOtpForIdentity(
        phone: phone,
        otpCode: otpCode,
        name: name,
      );

      if (response.success) {
        // 병합 여부와 관계없이 최신 프로필 조회
        final updatedUser = await _authService.getCurrentProfile();

        state = AuthState(
          status: AuthStatus.identityVerified,
          user: updatedUser ?? response.user ?? state.user,
          identityVerified: true,
          profileCompleted: false,
          verifiedName: name,
          verifiedPhone: phone,
        );
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.socialLoggedIn,
          errorMessage: response.message ?? '본인인증에 실패했습니다.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.socialLoggedIn,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  /// 본인인증 건너뛰기 (나중에 하기)
  void skipIdentityVerification() {
    debugPrint('[Auth] skipIdentityVerification called');
    debugPrint('[Auth] Before: status=${state.status}');
    // 본인인증 없이 메인으로 이동 (제한된 기능)
    state = state.copyWith(
      status: AuthStatus.authenticated,
      identityVerified: false,
      profileCompleted: false,
    );
    debugPrint('[Auth] After: status=${state.status}');
  }

  // ========== 개인정보 동의 ==========

  /// 개인정보 동의 완료 처리
  Future<void> completePrivacyConsent() async {
    final user = state.user;
    if (user == null) return;

    // 프로필까지 이미 완료된 기존 사용자 → authenticated
    if (state.profileCompleted) {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user.copyWith(privacyConsented: true),
        identityVerified: true,
        profileCompleted: true,
      );
      registerFcmToken();
    } else {
      // 신규 사용자 → 프로필 설정으로
      state = AuthState(
        status: AuthStatus.identityVerified,
        user: user.copyWith(privacyConsented: true),
        identityVerified: true,
        profileCompleted: false,
      );
    }
  }

  // ========== FCM 푸시 알림 ==========

  /// FCM 토큰을 서버에 등록
  Future<void> registerFcmToken() async {
    if (!state.isAuthenticated) return;
    if (kIsWeb) return; // 웹에서는 스킵

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        final success = await _authService.registerFcmToken(token);
        debugPrint('[Auth] FCM 토큰 등록 ${success ? "성공" : "실패"}');
      }
    } catch (e) {
      debugPrint('[Auth] FCM 토큰 등록 오류: $e');
    }
  }

  /// 푸시 알림 설정 변경 (전체 + 카테고리별)
  Future<Map<String, dynamic>?> updatePushSettings(Map<String, bool> settings) async {
    return await _authService.updatePushSettings(settings);
  }

  /// 푸시 알림 설정 조회
  Future<Map<String, dynamic>?> getPushSettings() async {
    return await _authService.getPushSettings();
  }

  /// 로그아웃
  Future<void> logout() async {
    await BiometricService.instance.setEnabled(false);
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// 회원 탈퇴
  Future<void> withdraw({String? reason}) async {
    await _authService.withdraw(reason: reason);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// 에러 메시지 초기화
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// 에러 메시지 추출
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString();
    if (errorStr.contains('400')) {
      return '잘못된 요청입니다.';
    }
    if (errorStr.contains('401')) {
      return '인증에 실패했습니다.';
    }
    if (errorStr.contains('404')) {
      return '사용자를 찾을 수 없습니다.';
    }
    if (errorStr.contains('500')) {
      return '서버 오류가 발생했습니다.';
    }
    if (errorStr.contains('SocketException') || errorStr.contains('TimeoutException')) {
      return '네트워크 연결을 확인해주세요.';
    }
    return '오류가 발생했습니다. 다시 시도해주세요.';
  }
}

/// AuthNotifier 프로바이더
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

/// 현재 사용자 프로바이더 (편의용)
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

/// 로그인 여부 프로바이더 (편의용)
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});
