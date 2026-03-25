import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 오프라인 캐시 키 상수
class CacheKeys {
  static const String contestsList = 'cache_contests_list';
  static String contestDetail(int id) => 'cache_contest_detail_$id';
  static const String userProfile = 'cache_user_profile';
  static const String userStats = 'cache_user_stats';
  static const String clubList = 'cache_club_list';
}

class CacheService {
  static final CacheService _instance = CacheService._();
  static CacheService get instance => _instance;
  CacheService._();

  static const String _timestampSuffix = '_timestamp';

  /// 데이터를 캐시에 저장 (기본 TTL: 60분)
  Future<void> save(String key, dynamic jsonData, {int ttlMinutes = 60}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(jsonData);
      await prefs.setString(key, jsonString);
      await prefs.setInt(
        '$key$_timestampSuffix',
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint('[Cache] Saved: $key (TTL: ${ttlMinutes}min)');
    } catch (e) {
      debugPrint('[Cache] Save error: $e');
    }
  }

  /// 캐시에서 데이터 로드 (TTL 검사, 기본 60분)
  Future<dynamic> load(String key, {int ttlMinutes = 60}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(key);
      if (jsonString == null) return null;

      final timestamp = prefs.getInt('$key$_timestampSuffix') ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - timestamp;
      final ttlMs = ttlMinutes * 60 * 1000;

      if (elapsed > ttlMs) {
        debugPrint('[Cache] Expired: $key');
        await clear(key);
        return null;
      }

      debugPrint('[Cache] Hit: $key');
      return json.decode(jsonString);
    } catch (e) {
      debugPrint('[Cache] Load error: $e');
      return null;
    }
  }

  /// 특정 키 캐시 삭제
  Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await prefs.remove('$key$_timestampSuffix');
  }

  /// 모든 캐시 삭제
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
      (k) => k.startsWith('cache_'),
    );
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
