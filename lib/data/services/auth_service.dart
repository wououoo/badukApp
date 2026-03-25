import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_constants.dart';
import '../api/api_client.dart';
import '../models/auth_response.dart';
import '../models/user.dart';

class AuthService {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  AuthService({
    ApiClient? apiClient,
    FlutterSecureStorage? storage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _storage = storage ?? const FlutterSecureStorage();

  // ========== 테스트 로그인 (토스 심사용) ==========

  /// 테스트 계정 로그인
  Future<SocialLoginResponse> loginWithTest(String testId, String testPassword) async {
    final response = await _apiClient.post(
      '/mobile/auth/test-login',
      data: {'testId': testId, 'testPassword': testPassword},
    );

    final socialResponse = SocialLoginResponse.fromJson(response.data);
    await _handleSocialLoginResponse(socialResponse);
    return socialResponse;
  }

  // ========== 소셜 로그인 ==========

  /// 카카오 로그인
  Future<SocialLoginResponse> loginWithKakao(String accessToken) async {
    final response = await _apiClient.post(
      ApiConstants.kakaoLogin,
      data: {'accessToken': accessToken},
    );

    final socialResponse = SocialLoginResponse.fromJson(response.data);
    await _handleSocialLoginResponse(socialResponse);
    return socialResponse;
  }

  /// 네이버 로그인
  Future<SocialLoginResponse> loginWithNaver(String accessToken) async {
    final response = await _apiClient.post(
      ApiConstants.naverLogin,
      data: {'accessToken': accessToken},
    );

    final socialResponse = SocialLoginResponse.fromJson(response.data);
    await _handleSocialLoginResponse(socialResponse);
    return socialResponse;
  }

  /// 애플 로그인
  Future<SocialLoginResponse> loginWithApple({
    required String identityToken,
    required String appleUserId,
    String? authorizationCode,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.appleLogin,
      data: {
        'accessToken': identityToken,
        'appleUserId': appleUserId,
        if (authorizationCode != null && authorizationCode.isNotEmpty)
          'authorizationCode': authorizationCode,
      },
    );

    final socialResponse = SocialLoginResponse.fromJson(response.data);
    await _handleSocialLoginResponse(socialResponse);
    return socialResponse;
  }

  /// 소셜 로그인 응답 처리
  Future<void> _handleSocialLoginResponse(SocialLoginResponse response) async {
    if (response.token != null) {
      await _storage.write(
        key: AppConstants.accessTokenKey,
        value: response.token,
      );
      // 메모리 캐시에도 토큰 저장 (storage 읽기 실패 방지)
      _apiClient.updateCachedToken(response.token);
    }
    if (response.refreshToken != null) {
      await _storage.write(
        key: AppConstants.refreshTokenKey,
        value: response.refreshToken,
      );
    }
    if (response.user != null) {
      await _saveUserInfo(response.user!);
    }
  }

  // ========== 본인인증 ==========

  /// 카카오 인증서 본인인증 (txId + accessToken 방식)
  Future<IdentityVerifyResponse> verifyKakaoCert({
    required String txId,
    required String accessToken,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.kakaoCertVerify,
      data: {
        'txId': txId,
        'accessToken': accessToken,
      },
    );

    return IdentityVerifyResponse.fromJson(response.data);
  }

  /// 카카오 추가 동의 기반 본인인증 (loginWithNewScopes 후 호출)
  Future<IdentityVerifyResponse> verifyIdentityWithKakaoScopes({
    required String kakaoAccessToken,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.kakaoVerifyIdentity,
      data: {
        'kakaoAccessToken': kakaoAccessToken,
      },
    );

    final result = IdentityVerifyResponse.fromJson(response.data);
    // 병합된 경우 새 토큰으로 교체
    if (response.data['merged'] == true && response.data['token'] != null) {
      await _storage.write(key: AppConstants.accessTokenKey, value: response.data['token']);
      _apiClient.updateCachedToken(response.data['token']);
      if (response.data['refreshToken'] != null) {
        await _storage.write(key: AppConstants.refreshTokenKey, value: response.data['refreshToken']);
      }
    }
    return result;
  }

  /// 수동 본인인증 (개발/테스트용)
  Future<IdentityVerifyResponse> setManualIdentity({
    required String name,
    required String phoneNumber,
    String? birthDate,
    String? gender,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.identityVerifyManual,
      data: {
        'name': name,
        'phoneNumber': phoneNumber,
        if (birthDate != null) 'birthDate': birthDate,
        if (gender != null) 'gender': gender,
      },
    );

    return IdentityVerifyResponse.fromJson(response.data);
  }

  /// 카카오 본인인증 토큰 검증 (기존 방식)
  Future<IdentityVerifyResponse> verifyIdentity(String identityToken) async {
    final response = await _apiClient.post(
      ApiConstants.identityVerify,
      data: {'identityToken': identityToken},
    );

    return IdentityVerifyResponse.fromJson(response.data);
  }

  /// 본인인증 정보 확인 및 저장
  Future<IdentityConfirmResponse> confirmIdentity({
    required String name,
    required String phoneNumber,
    required String birthDate,
    required String gender,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.identityVerifyConfirm,
      data: {
        'name': name,
        'phoneNumber': phoneNumber,
        'birthDate': birthDate,
        'gender': gender,
      },
    );

    final confirmResponse = IdentityConfirmResponse.fromJson(response.data);
    if (confirmResponse.user != null) {
      await _saveUserInfo(confirmResponse.user!);
    }
    return confirmResponse;
  }

  // ========== 프로필 업데이트 ==========

  /// 프로필 정보 업데이트 (이름, 기력, 지역, 클럽)
  Future<ProfileUpdateResponse> updateProfile({
    String? name,
    int? level,
    String? region,
    String? city,
    String? club,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (level != null) data['level'] = level;
    if (region != null) data['region'] = region;
    if (city != null) data['city'] = city;
    if (club != null) data['club'] = club;

    final response = await _apiClient.put(
      ApiConstants.userProfileUpdate,
      data: data,
    );

    final profileResponse = ProfileUpdateResponse.fromJson(response.data);
    if (profileResponse.user != null) {
      await _saveUserInfo(profileResponse.user!);
    }
    return profileResponse;
  }

  /// 현재 사용자 프로필 조회
  /// 예외를 호출부에 전파하여 401(인증만료)과 다른 에러를 구분할 수 있게 함
  Future<User?> getCurrentProfile() async {
    final response = await _apiClient.get(ApiConstants.userProfile);
    if (response.data['success'] == true && response.data['user'] != null) {
      final user = User.fromJson(response.data['user']);
      await _saveUserInfo(user);
      return user;
    }
    return null;
  }

  // ========== OTP 인증 ==========

  /// OTP 전용 Dio 인스턴스 (공유 커넥션풀/인터셉터 간섭 방지)
  static final Dio _otpDio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    contentType: 'application/json',
    headers: {'Accept': 'application/json'},
  ));

  /// OTP 인증번호 발송 요청
  Future<OtpSendResponse> sendOtp(String phone) async {
    final response = await _otpDio.post(
      ApiConstants.otpSend,
      data: {'phone': phone},
    );

    return OtpSendResponse.fromJson(response.data);
  }

  /// SMS OTP 본인인증용 OTP 발송 (SNS 로그인 후 본인인증용, 기존 OTP 발송 재사용)
  Future<OtpSendResponse> sendOtpForIdentity(String phone) async {
    return sendOtp(phone);
  }

  /// SMS OTP 본인인증 검증 (SNS 로그인 후 본인인증)
  /// JWT 토큰이 필요하므로 _apiClient 사용
  Future<IdentityOtpVerifyResponse> verifyOtpForIdentity({
    required String phone,
    required String otpCode,
    required String name,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.identityVerifyOtp,
      data: {
        'phone': phone,
        'otpCode': otpCode,
        'name': name,
      },
    );

    final result = IdentityOtpVerifyResponse.fromJson(response.data);
    // 병합된 경우 새 토큰으로 교체
    if (result.merged && result.token != null) {
      await _storage.write(key: AppConstants.accessTokenKey, value: result.token);
      _apiClient.updateCachedToken(result.token);
      if (result.refreshToken != null) {
        await _storage.write(key: AppConstants.refreshTokenKey, value: result.refreshToken);
      }
    }
    if (result.user != null) {
      await _saveUserInfo(result.user!);
    }
    return result;
  }

  /// OTP 인증번호 검증 및 로그인
  /// 반환 타입: SocialLoginResponse (identityVerified, profileCompleted 포함)
  Future<SocialLoginResponse> verifyOtp(String phone, String otpCode, {String? name}) async {
    final response = await _otpDio.post(
      ApiConstants.otpVerify,
      data: {
        'phone': phone,
        'otpCode': otpCode,
        if (name != null && name.isNotEmpty) 'name': name,
      },
    );

    final socialResponse = SocialLoginResponse.fromJson(response.data);
    await _handleSocialLoginResponse(socialResponse);
    return socialResponse;
  }

  /// 사용자 이름 업데이트 (신규 사용자용)
  Future<bool> updateUserName(String phone, String name) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.mobileUpdateName,
        data: {
          'phone': phone,
          'name': name,
        },
      );

      if (response.data['success'] == true) {
        // 저장된 사용자 정보 업데이트
        final savedUser = await getSavedUser();
        if (savedUser != null) {
          final updatedUser = User(
            id: savedUser.id,
            name: name,
            phone: savedUser.phone,
            rank: savedUser.rank,
          );
          await _saveUserInfo(updatedUser);
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ========== FCM 푸시 알림 ==========

  /// FCM 토큰 서버에 등록
  Future<bool> registerFcmToken(String fcmToken) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.userFcmToken,
        data: {'fcmToken': fcmToken},
      );
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[Auth] FCM 토큰 등록 실패: $e');
      return false;
    }
  }

  /// 푸시 알림 설정 변경 (전체 + 카테고리별)
  Future<Map<String, dynamic>?> updatePushSettings(Map<String, bool> settings) async {
    try {
      final response = await _apiClient.put(
        ApiConstants.userPushSettings,
        data: settings,
      );
      if (response.data['success'] == true) {
        return Map<String, dynamic>.from(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('[Auth] 푸시 설정 변경 실패: $e');
      return null;
    }
  }

  /// 푸시 알림 설정 조회
  Future<Map<String, dynamic>?> getPushSettings() async {
    try {
      final response = await _apiClient.get(ApiConstants.userPushSettings);
      if (response.data['success'] == true) {
        return Map<String, dynamic>.from(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('[Auth] 푸시 설정 조회 실패: $e');
      return null;
    }
  }

  /// 로그아웃 (모든 캐시 및 소셜 로그인 세션 초기화)
  Future<void> logout() async {
    // 1. 카카오 로그아웃 (세션 초기화)
    try {
      if (await kakao.AuthApi.instance.hasToken()) {
        await kakao.UserApi.instance.logout();
      }
    } catch (e) {
      // 카카오 로그아웃 실패해도 계속 진행
      debugPrint('[Auth] 카카오 로그아웃 실패 (무시): $e');
    }

    // 2. 모든 로컬 저장소 데이터 삭제
    _apiClient.updateCachedToken(null);
    await _storage.deleteAll();
  }

  /// 회원 탈퇴
  Future<void> withdraw({String? reason}) async {
    // 1. 서버에 탈퇴 요청 (사유 포함)
    await _apiClient.delete('/mobile/users/me', data: {
      if (reason != null) 'reason': reason,
    });

    // 2. 카카오 연결 해제
    try {
      if (await kakao.AuthApi.instance.hasToken()) {
        await kakao.UserApi.instance.unlink();
      }
    } catch (e) {
      debugPrint('[Auth] 카카오 연결 해제 실패 (무시): $e');
    }

    // 3. 모든 로컬 저장소 데이터 삭제
    _apiClient.updateCachedToken(null);
    await _storage.deleteAll();
  }

  /// 토큰 갱신
  Future<String?> refreshToken() async {
    final phone = await _storage.read(key: AppConstants.userPhoneKey);
    if (phone == null) return null;

    try {
      final response = await _apiClient.post(
        ApiConstants.mobileRefresh,
        data: {'phone': phone},
      );

      final newAccessToken = response.data['accessToken'] as String?;
      final newRefreshToken = response.data['refreshToken'] as String?;
      if (newAccessToken != null) {
        await _storage.write(key: AppConstants.accessTokenKey, value: newAccessToken);
        _apiClient.updateCachedToken(newAccessToken);
      }
      if (newRefreshToken != null) {
        await _storage.write(key: AppConstants.refreshTokenKey, value: newRefreshToken);
      }
      return newAccessToken;
    } catch (e) {
      await logout();
      return null;
    }
  }

  /// 로그인 상태 확인
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    return token != null;
  }

  /// 저장된 사용자 정보 가져오기
  Future<User?> getSavedUser() async {
    final userJsonStr = await _storage.read(key: AppConstants.userKey);
    if (userJsonStr == null) return null;

    try {
      final Map<String, dynamic> userData = jsonDecode(userJsonStr);
      return User.fromJson(userData);
    } catch (e) {
      // 기존 파이프 형식 데이터 마이그레이션 (하위 호환성)
      try {
        final Map<String, dynamic> userData = {};
        final parts = userJsonStr.split('|');
        for (final part in parts) {
          final separatorIndex = part.indexOf(':');
          if (separatorIndex > 0) {
            final key = part.substring(0, separatorIndex);
            final value = part.substring(separatorIndex + 1);
            userData[key] = value;
          }
        }
        final user = User.fromJson(userData);
        // JSON 형식으로 재저장
        await _saveUserInfo(user);
        return user;
      } catch (_) {
        return null;
      }
    }
  }

  /// 저장된 전화번호 가져오기
  Future<String?> getSavedPhone() async {
    return await _storage.read(key: AppConstants.userPhoneKey);
  }

  /// 사용자 정보 저장 (JSON 형식)
  Future<void> _saveUserInfo(User user) async {
    final userJson = jsonEncode(user.toJson());
    await _storage.write(key: AppConstants.userKey, value: userJson);

    // 전화번호 별도 저장 (토큰 갱신용)
    if (user.phone != null) {
      await _storage.write(key: AppConstants.userPhoneKey, value: user.phone!);
    }
  }

  /// 현재 토큰 가져오기
  Future<String?> getAccessToken() async {
    return await _storage.read(key: AppConstants.accessTokenKey);
  }

  // ========== 레거시 메서드 (하위 호환성) ==========

  /// 기존 로그인 (비밀번호 방식) - 사용 안함
  @Deprecated('Use verifyOtp instead')
  Future<AuthResponse> login(String phone, String password) async {
    final response = await _apiClient.post(
      ApiConstants.login,
      data: LoginRequest(phone: phone, password: password).toJson(),
    );

    final authResponse = AuthResponse.fromJson(response.data);

    await _storage.write(
      key: AppConstants.accessTokenKey,
      value: authResponse.token,
    );

    if (authResponse.user != null) {
      await _saveUserInfo(authResponse.user!);
    }

    return authResponse;
  }
}

/// OTP 발송 응답
class OtpSendResponse {
  final bool success;
  final String? message;

  OtpSendResponse({
    required this.success,
    this.message,
  });

  factory OtpSendResponse.fromJson(Map<String, dynamic> json) {
    return OtpSendResponse(
      success: json['success'] ?? false,
      message: json['message'],
    );
  }
}

/// 소셜 로그인 응답
class SocialLoginResponse {
  final bool success;
  final String? token;
  final String? refreshToken;
  final bool isNewUser;
  final bool identityVerified;
  final bool profileCompleted;
  final User? user;
  final String? message;

  SocialLoginResponse({
    required this.success,
    this.token,
    this.refreshToken,
    this.isNewUser = false,
    this.identityVerified = false,
    this.profileCompleted = false,
    this.user,
    this.message,
  });

  factory SocialLoginResponse.fromJson(Map<String, dynamic> json) {
    return SocialLoginResponse(
      success: json['success'] ?? false,
      token: json['token'],
      refreshToken: json['refreshToken'],
      isNewUser: json['isNewUser'] ?? false,
      identityVerified: json['identityVerified'] ?? false,
      profileCompleted: json['profileCompleted'] ?? false,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      message: json['message'],
    );
  }
}

/// 본인인증 응답 (카카오 본인인증 토큰 검증 결과)
class IdentityVerifyResponse {
  final bool success;
  final String? name;
  final String? phoneNumber;
  final String? birthDate;
  final String? gender;
  final String? message;

  IdentityVerifyResponse({
    required this.success,
    this.name,
    this.phoneNumber,
    this.birthDate,
    this.gender,
    this.message,
  });

  factory IdentityVerifyResponse.fromJson(Map<String, dynamic> json) {
    return IdentityVerifyResponse(
      success: json['success'] ?? false,
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      birthDate: json['birthDate'],
      gender: json['gender'],
      message: json['message'],
    );
  }
}

/// 본인인증 확인 응답
class IdentityConfirmResponse {
  final bool success;
  final User? user;
  final String? message;

  IdentityConfirmResponse({
    required this.success,
    this.user,
    this.message,
  });

  factory IdentityConfirmResponse.fromJson(Map<String, dynamic> json) {
    return IdentityConfirmResponse(
      success: json['success'] ?? false,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      message: json['message'],
    );
  }
}

/// SMS OTP 본인인증 응답 (병합 포함)
class IdentityOtpVerifyResponse {
  final bool success;
  final bool merged;
  final String? token;
  final String? refreshToken;
  final User? user;
  final String? message;

  IdentityOtpVerifyResponse({
    required this.success,
    this.merged = false,
    this.token,
    this.refreshToken,
    this.user,
    this.message,
  });

  factory IdentityOtpVerifyResponse.fromJson(Map<String, dynamic> json) {
    return IdentityOtpVerifyResponse(
      success: json['success'] ?? false,
      merged: json['merged'] ?? false,
      token: json['token'],
      refreshToken: json['refreshToken'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      message: json['message'],
    );
  }
}

/// 프로필 업데이트 응답
class ProfileUpdateResponse {
  final bool success;
  final User? user;
  final String? message;

  ProfileUpdateResponse({
    required this.success,
    this.user,
    this.message,
  });

  factory ProfileUpdateResponse.fromJson(Map<String, dynamic> json) {
    return ProfileUpdateResponse(
      success: json['success'] ?? false,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      message: json['message'],
    );
  }
}
