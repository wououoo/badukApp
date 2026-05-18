import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../../core/constants/api_constants.dart';

/// 앱 설정 모델
class AppConfig {
  final String latestVersion;
  final int latestBuildNumber;
  final int minimumBuildNumber;
  final bool forceUpdate;
  final String updateUrl;
  final String message;
  /// 테스트 로그인 버튼 노출 여부 (심사용 — 백엔드 DB 토글)
  final bool testLoginEnabled;

  AppConfig({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.minimumBuildNumber,
    required this.forceUpdate,
    required this.updateUrl,
    required this.message,
    this.testLoginEnabled = false,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      latestVersion: json['latestVersion'] ?? '1.0.0',
      latestBuildNumber: json['latestBuildNumber'] ?? 1,
      minimumBuildNumber: json['minimumBuildNumber'] ?? 1,
      forceUpdate: json['forceUpdate'] ?? false,
      updateUrl: json['updateUrl'] ?? '',
      message: json['message'] ?? '',
      testLoginEnabled: json['testLoginEnabled'] == true,
    );
  }
}

/// 버전 체크 서비스 (빌드번호 기반 비교)
class VersionService {
  static AppConfig? _cachedConfig;

  /// 캐시 초기화 (포그라운드 복귀 시 서버에서 새로 조회)
  static void clearCache() {
    _cachedConfig = null;
  }

  /// 앱 설정 조회 (세션 캐시)
  static Future<AppConfig?> fetchConfig() async {
    if (_cachedConfig != null) return _cachedConfig;

    try {
      final apiClient = ApiClient();
      final response = await apiClient.get(ApiConstants.appConfig);
      if (response.data is Map<String, dynamic>) {
        _cachedConfig = AppConfig.fromJson(response.data);
        return _cachedConfig;
      }
    } catch (e) {
      debugPrint('[VersionService] 앱 설정 조회 실패: $e');
    }
    return null;
  }

  /// 현재 빌드번호가 최소 빌드번호보다 낮은지 확인 (강제 업데이트 대상)
  static bool isOutdated(int currentBuild, int minimumBuild) {
    return currentBuild < minimumBuild;
  }

  /// 선택적 업데이트 표시 여부 (최신 빌드번호보다 낮은 경우)
  static Future<bool> shouldShowOptionalUpdate(int currentBuild) async {
    final config = await fetchConfig();
    if (config == null) return false;
    if (config.forceUpdate) return false;
    if (currentBuild >= config.latestBuildNumber) return false;

    // 24시간 스누즈 체크
    final prefs = await SharedPreferences.getInstance();
    final dismissedAt = prefs.getInt('optional_update_dismissed_at');
    if (dismissedAt != null) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - dismissedAt;
      if (elapsed < 24 * 60 * 60 * 1000) return false;
    }
    return true;
  }

  /// 선택적 업데이트 24시간 스누즈
  static Future<void> dismissOptionalUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('optional_update_dismissed_at', DateTime.now().millisecondsSinceEpoch);
  }
}
