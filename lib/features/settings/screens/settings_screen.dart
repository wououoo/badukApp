import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/api_client.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/services/biometric_service.dart';

/// 설정 화면
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const String _pushEnabledKey = 'push_notifications_enabled';

  String _appVersion = '';
  bool _notificationsEnabled = true;
  bool _pushSettingLoading = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  // 카테고리별 푸시 설정
  bool _pushContest = true;
  bool _pushPayment = true;
  bool _pushClubGeneral = true;
  bool _pushClubContest = true;
  bool _pushSystem = true;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadPushSetting();
    _loadBiometricSetting();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      });
    } catch (e) {
      setState(() => _appVersion = '1.0.0');
    }
  }

  /// 서버에서 푸시 알림 설정 불러오기
  Future<void> _loadPushSetting() async {
    // 먼저 로컬 캐시 로드
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool(_pushEnabledKey) ?? true;
    });

    // 서버에서 최신 설정 조회
    try {
      final result = await ref.read(authProvider.notifier).getPushSettings();
      if (result != null && mounted) {
        setState(() {
          _notificationsEnabled = result['pushEnabled'] ?? true;
          _pushContest = result['pushContest'] ?? true;
          _pushPayment = result['pushPayment'] ?? true;
          _pushClubGeneral = result['pushClubGeneral'] ?? true;
          _pushClubContest = result['pushClubContest'] ?? true;
          _pushSystem = result['pushSystem'] ?? true;
        });
        await prefs.setBool(_pushEnabledKey, _notificationsEnabled);
      }
    } catch (e) {
      // 서버 조회 실패 시 로컬 값 유지
    }
  }

  /// 생체 인증 설정 불러오기
  Future<void> _loadBiometricSetting() async {
    final biometric = BiometricService.instance;
    final available = await biometric.isAvailable();
    final enabled = await biometric.isEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  /// 생체 인증 설정 변경
  Future<void> _updateBiometricSetting(bool enabled) async {
    final biometric = BiometricService.instance;
    if (enabled) {
      // 활성화 시 먼저 인증 확인
      final authenticated = await biometric.authenticate();
      if (!authenticated) return;
    }
    await biometric.setEnabled(enabled);
    if (mounted) {
      setState(() => _biometricEnabled = enabled);
    }
  }

  /// 푸시 알림 설정 변경 (전체 on/off)
  Future<void> _updatePushSetting(bool enabled) async {
    final oldValue = _notificationsEnabled;
    setState(() {
      _notificationsEnabled = enabled;
      _pushSettingLoading = true;
    });

    try {
      final result = await ref.read(authProvider.notifier).updatePushSettings({'enabled': enabled});
      if (result != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_pushEnabledKey, enabled);
        // 푸시 켤 때 모든 카테고리도 ON으로 리셋 (서버에서 처리됨)
        if (enabled && mounted) {
          setState(() {
            _pushContest = true;
            _pushPayment = true;
            _pushClubGeneral = true;
            _pushClubContest = true;
            _pushSystem = true;
          });
        }
      } else {
        throw Exception('서버 응답 실패');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _notificationsEnabled = oldValue);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림 설정 변경에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _pushSettingLoading = false);
    }
  }

  /// 카테고리별 푸시 설정 변경
  Future<void> _updateCategorySetting(String key, bool value) async {
    // 현재 값 백업
    final backupValues = {
      'contest': _pushContest,
      'payment': _pushPayment,
      'clubGeneral': _pushClubGeneral,
      'clubContest': _pushClubContest,
      'system': _pushSystem,
    };

    // UI 즉시 반영
    setState(() {
      switch (key) {
        case 'contest': _pushContest = value; break;
        case 'payment': _pushPayment = value; break;
        case 'clubGeneral': _pushClubGeneral = value; break;
        case 'clubContest': _pushClubContest = value; break;
        case 'system': _pushSystem = value; break;
      }
    });

    try {
      final result = await ref.read(authProvider.notifier).updatePushSettings({key: value});
      if (result == null) throw Exception('서버 응답 실패');
    } catch (e) {
      // 실패 시 복구
      if (mounted) {
        setState(() {
          _pushContest = backupValues['contest']!;
          _pushPayment = backupValues['payment']!;
          _pushClubGeneral = backupValues['clubGeneral']!;
          _pushClubContest = backupValues['clubContest']!;
          _pushSystem = backupValues['system']!;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림 설정 변경에 실패했습니다.')),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  Future<void> _withdraw() async {
    // 1차 확인
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text(
          '정말 탈퇴하시겠습니까?\n\n'
          '탈퇴 시 모든 데이터가 삭제되며\n복구할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );

    if (firstConfirm != true || !mounted) return;

    // 2차 확인
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('최종 확인'),
        content: const Text('정말로 탈퇴하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );

    if (secondConfirm != true || !mounted) return;

    // 탈퇴 처리
    try {
      await ref.read(authProvider.notifier).withdraw();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원 탈퇴 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.')),
        );
      }
    }
  }


  Future<void> _sendTestPush() async {
    try {
      final response = await ApiClient.instance.post(ApiConstants.testPush);
      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        final success = data['success'] == true;
        final message = data['message'] ?? '';
        final pushEnabled = data['pushEnabled'] ?? false;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(success ? '발송 성공' : '발송 실패'),
            content: Text(
              '푸시 설정: ${pushEnabled ? "켜짐" : "꺼짐"}\n'
              '결과: $message',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        debugPrint('[Error] 테스트 푸시 실패: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('테스트 푸시에 실패했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),

          // 계정 섹션
          _buildSectionHeader('계정'),
          _buildSettingsTile(
            icon: Icons.person_outline,
            title: '프로필 수정',
            subtitle: '기력, 지역, 소속 변경',
            onTap: () => context.push('/profile/edit'),
          ),
          _buildSettingsTile(
            icon: Icons.phone_android,
            title: '전화번호 변경',
            subtitle: '카카오 본인인증으로 변경',
            onTap: () => context.push('/change-phone'),
          ),
          if (_biometricAvailable)
            _buildSwitchTile(
              icon: Icons.fingerprint,
              title: '생체 인증 잠금',
              subtitle: '앱 재시작 시 생체 인증으로 본인 확인',
              value: _biometricEnabled,
              onChanged: (v) => _updateBiometricSetting(v),
            ),
          _buildSettingsTile(
            icon: Icons.logout,
            title: '로그아웃',
            titleColor: AppColors.error,
            onTap: _logout,
          ),
          _buildSettingsTile(
            icon: Icons.person_off_outlined,
            title: '회원 탈퇴',
            titleColor: AppColors.textTertiary,
            onTap: () => context.push('/account-withdrawal'),
          ),

          const SizedBox(height: 24),

          // // 화면 섹션 (라이트 모드 고정으로 비활성화)
          // _buildSectionHeader('화면'),
          // _buildThemeTile(),
          //
          // const SizedBox(height: 24),

          // 알림 섹션
          _buildSectionHeader('알림'),
          _buildSwitchTile(
            icon: Icons.notifications_outlined,
            title: '푸시 알림',
            subtitle: '전체 알림 켜기/끄기',
            value: _notificationsEnabled,
            onChanged: _pushSettingLoading
                ? (v) {}
                : (v) => _updatePushSetting(v),
          ),
          if (_notificationsEnabled) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                '알림 카테고리',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            _buildCategorySwitchTile(
              icon: Icons.emoji_events_outlined,
              title: '대회 알림',
              subtitle: '대회 리마인더, 대진표, 대국 시작, 결과',
              value: _pushContest,
              onChanged: (v) => _updateCategorySetting('contest', v),
            ),
            _buildCategorySwitchTile(
              icon: Icons.payment_outlined,
              title: '결제 알림',
              subtitle: '입금 확인, 결제 완료, 환불',
              value: _pushPayment,
              onChanged: (v) => _updateCategorySetting('payment', v),
            ),
            _buildCategorySwitchTile(
              icon: Icons.groups_outlined,
              title: '클럽 활동',
              subtitle: '가입 승인, 공지, 댓글 알림',
              value: _pushClubGeneral,
              onChanged: (v) => _updateCategorySetting('clubGeneral', v),
            ),
            _buildCategorySwitchTile(
              icon: Icons.sports_outlined,
              title: '클럽 대회',
              subtitle: '클럽 대회 생성, 대진표, 결과, 레이팅 변동',
              value: _pushClubContest,
              onChanged: (v) => _updateCategorySetting('clubContest', v),
            ),
            _buildCategorySwitchTile(
              icon: Icons.campaign_outlined,
              title: '시스템 공지',
              subtitle: '운영자 공지사항',
              value: _pushSystem,
              onChanged: (v) => _updateCategorySetting('system', v),
            ),
          ],
          _buildSettingsTile(
            icon: Icons.send_outlined,
            title: '테스트 푸시 발송',
            subtitle: '나에게 테스트 알림 보내기',
            onTap: _sendTestPush,
          ),

          const SizedBox(height: 24),

          // 지원 섹션
          _buildSectionHeader('지원'),
          _buildSettingsTile(
            icon: Icons.headset_mic_outlined,
            title: '고객센터',
            subtitle: '공지사항, FAQ, 1:1 문의',
            onTap: () => context.push('/support'),
          ),

          const SizedBox(height: 24),

          // 정보 섹션
          _buildSectionHeader('정보'),
          _buildSettingsTile(
            icon: Icons.description_outlined,
            title: '이용약관',
            onTap: () => context.push('/terms'),
          ),
          _buildSettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: '개인정보처리방침',
            onTap: () => context.push('/privacy'),
          ),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: '앱 버전',
            trailing: Text(
              _appVersion,
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // 사업자 정보
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '바둑대회',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '상호명: 스톤웍스\n'
                  '대표: 우경주\n'
                  '사업자등록번호: 661-48-01150\n'
                  '주소: 서울특별시 강서구 송정로 35 302호\n'
                  '연락처: 010-2520-3603',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Copyright 2025 StoneWorks. All rights reserved.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildThemeTile() {
    final themeMode = ref.watch(themeModeProvider);
    String themeLabel;
    switch (themeMode) {
      case ThemeMode.light:
        themeLabel = '라이트';
        break;
      case ThemeMode.dark:
        themeLabel = '다크';
        break;
      default:
        themeLabel = '시스템';
    }

    return _buildSettingsTile(
      icon: Icons.palette_outlined,
      title: '테마',
      subtitle: themeLabel,
      onTap: () => _showThemeDialog(),
    );
  }

  void _showThemeDialog() {
    final currentMode = ref.read(themeModeProvider);

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('테마 선택'),
        children: [
          _themeOption(ctx, '시스템 설정', ThemeMode.system, currentMode),
          _themeOption(ctx, '라이트', ThemeMode.light, currentMode),
          _themeOption(ctx, '다크', ThemeMode.dark, currentMode),
        ],
      ),
    );
  }

  Widget _themeOption(BuildContext ctx, String label, ThemeMode mode, ThemeMode current) {
    return SimpleDialogOption(
      onPressed: () {
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
        Navigator.pop(ctx);
      },
      child: Row(
        children: [
          Icon(
            mode == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: mode == current ? AppColors.primary : AppColors.textTertiary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: mode == current ? FontWeight.w600 : FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: titleColor ?? AppColors.textSecondary),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: titleColor ?? AppColors.textPrimary,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              )
            : null,
        trailing: trailing ?? (onTap != null
            ? Icon(Icons.chevron_right, color: AppColors.textTertiary)
            : null),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildCategorySwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: AppColors.textTertiary, size: 20),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              )
            : null,
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: AppColors.textSecondary),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              )
            : null,
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
