import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._();
  static BiometricService get instance => _instance;
  BiometricService._();

  static const String _enabledKey = 'biometric_enabled';

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// 생체 인증이 사용 가능한지 확인
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (e) {
      debugPrint('[Biometric] isAvailable error: $e');
      return false;
    }
  }

  /// 생체 인증 활성화 여부 조회
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// 생체 인증 활성화/비활성화 설정
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  /// 생체 인증 실행
  Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: '본인 확인을 위해 인증해주세요',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      debugPrint('[Biometric] authenticate error: $e');
      return false;
    }
  }
}
