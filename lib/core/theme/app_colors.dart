import 'package:flutter/material.dart';

/// 바둑대회 앱 컬러 시스템 (코랄 오렌지 테마)
/// 라이트/다크 모드 지원
class AppColors {
  AppColors._();

  static bool _isDark = false;

  /// 다크모드 설정
  static void setDarkMode(bool isDark) {
    _isDark = isDark;
  }

  static bool get isDarkMode => _isDark;

  // ========== Primary (딥 코랄 계열) — 불변 ==========
  static const Color primary = Color(0xFFD4603C);
  static const Color primaryLight = Color(0xFFE8784A);
  static const Color primaryDark = Color(0xFFB84E30);

  // ========== Accent — 불변 ==========
  static const Color accent = Color(0xFFF0B89A);
  static const Color accentLight = Color(0xFFF8D8C8);

  // ========== Status (상태 뱃지) — 불변 ==========
  // 접수중 - 그린
  static const Color statusOpen = Color(0xFF10B981);
  static const Color statusOpenBg = Color(0xFFDCFCE7);
  static const Color statusOpenText = Color(0xFF166534);

  // 진행중 - 블루
  static const Color statusLive = Color(0xFF3B82F6);
  static const Color statusLiveBg = Color(0xFFDBEAFE);
  static const Color statusLiveText = Color(0xFF1E40AF);

  // D-Day / 임박 - 옐로우
  static const Color statusSoon = Color(0xFFF59E0B);
  static const Color statusSoonBg = Color(0xFFFEF3C7);
  static const Color statusSoonText = Color(0xFF92400E);

  // 종료 - 그레이
  static const Color statusClosed = Color(0xFF6B7280);
  static const Color statusClosedBg = Color(0xFFF3F4F6);
  static const Color statusClosedText = Color(0xFF4B5563);

  // ========== Background — 다크 지원 ==========
  static Color get background => _isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC);
  static Color get surface => _isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
  static Color get surfaceVariant => _isDark ? const Color(0xFF2A2420) : const Color(0xFFFFF5F0);
  static Color get card => _isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);

  // ========== Border & Divider — 다크 지원 ==========
  static Color get border => _isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0);
  static Color get divider => _isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0);

  // ========== Text — 다크 지원 ==========
  static Color get textPrimary => _isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1C1C1E);
  static Color get textSecondary => _isDark ? const Color(0xFFA0A0A0) : const Color(0xFF475569);
  static Color get textTertiary => _isDark ? const Color(0xFF707070) : const Color(0xFF64748B);
  static Color get textHint => _isDark ? const Color(0xFF505050) : const Color(0xFFCBD5E1);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ========== Semantic — 불변 ==========
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ========== Club (클럽 전용 - Teal 계열) — 불변 ==========
  static const Color clubPrimary = Color(0xFF0D9488);
  static const Color clubPrimaryLight = Color(0xFF14B8A6);
  static const Color clubPrimaryDark = Color(0xFF0F766E);
  static Color get clubBgTint => _isDark ? const Color(0xFF1A2A28) : const Color(0xFFF0FDFA);

  // ========== Misc — 다크 지원 ==========
  static Color get shimmerBase => _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0);
  static Color get shimmerHighlight => _isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF8FAFC);

  // ========== Legacy (기존 코드 호환용) ==========
  static const Color secondary = Color(0xFF64748B);
  static const Color secondaryLight = Color(0xFF94A3B8);
  static const Color secondaryDark = Color(0xFF475569);
}
