import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';

/// 테마 모드 Notifier (system / light / dark)
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String _key = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    switch (value) {
      case 'light':
        state = ThemeMode.light;
        AppColors.setDarkMode(false);
        break;
      case 'dark':
        state = ThemeMode.dark;
        AppColors.setDarkMode(true);
        break;
      default:
        state = ThemeMode.system;
        // system 모드에서는 실제 밝기를 알 수 없으므로 false로 기본값
        AppColors.setDarkMode(false);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    AppColors.setDarkMode(mode == ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    switch (mode) {
      case ThemeMode.light:
        await prefs.setString(_key, 'light');
        break;
      case ThemeMode.dark:
        await prefs.setString(_key, 'dark');
        break;
      case ThemeMode.system:
        await prefs.remove(_key);
        break;
    }
  }
}

/// 테마 모드 프로바이더
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
