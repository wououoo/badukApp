import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/offline_banner.dart';
import '../../data/api/api_client.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/contest_provider.dart';
import '../../data/providers/mobile_qr_provider.dart';
import '../../data/providers/notification_provider.dart';
import '../../data/providers/user_provider.dart';
import '../../data/services/version_service.dart';
import '../../features/profile/screens/my_registrations_screen.dart';

/// 메인 화면 (Bottom Navigation Shell)
class MainScreen extends ConsumerStatefulWidget {
  final Widget child;

  const MainScreen({super.key, required this.child});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with WidgetsBindingObserver {
  DateTime? _lastBackPressed;
  bool _updateDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 위젯 트리 빌드 완료 후 버전 체크
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
    });

    // 426 응답 시 업데이트 다이얼로그 표시
    ApiClient.onUpdateRequired = () {
      if (!_updateDialogShown && mounted) {
        _updateDialogShown = true;
        _showForceUpdateDialogSimple();
      }
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 백그라운드에서 포그라운드로 복귀 시 버전 체크
    if (state == AppLifecycleState.resumed) {
      _updateDialogShown = false;
      VersionService.clearCache();
      _checkForUpdate();
      // 홈 데이터도 새로고침
      _refreshHomeData();
    }
  }

  Future<void> _checkForUpdate() async {
    if (kIsWeb || _updateDialogShown) return;

    try {
      final config = await VersionService.fetchConfig();
      if (config == null || !mounted) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      if (currentBuild < config.latestBuildNumber) {
        _updateDialogShown = true;
        _showForceUpdateDialog(config);
      }
    } catch (e) {
      debugPrint('[VersionCheck] 버전 체크 실패: $e');
    }
  }

  void _showForceUpdateDialog(AppConfig config) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.system_update, color: AppColors.primary, size: 28),
              SizedBox(width: 8),
              Text('업데이트 필요'),
            ],
          ),
          content: Text(config.message),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final uri = Uri.parse(config.updateUrl);
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('업데이트하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 426 응답 시 업데이트 다이얼로그 (서버 config 없이)
  void _showForceUpdateDialogSimple() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.system_update, color: AppColors.primary, size: 28),
              SizedBox(width: 8),
              Text('업데이트 필요'),
            ],
          ),
          content: const Text('새로운 버전이 출시되었습니다.\n업데이트 후 이용해주세요.'),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final uri = Uri.parse('https://play.google.com/store/apps/details?id=com.swissbaduk.baduk_app');
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('업데이트하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressed != null &&
            now.difference(_lastBackPressed!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPressed = now;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('뒤로 버튼을 한번 더 누르면 종료됩니다'),
              duration: Duration(seconds: 2),
            ),
          );
      },
      child: Scaffold(
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: widget.child),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    context,
                    index: 0,
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: '홈',
                    path: '/home',
                  ),
                  _buildNavItem(
                    context,
                    index: 1,
                    icon: Icons.emoji_events_outlined,
                    activeIcon: Icons.emoji_events,
                    label: '대회',
                    path: '/contests',
                  ),
                  // QR 스캔 버튼 (가운데)
                  _buildQRButton(context),
                  _buildNavItem(
                    context,
                    index: 2,
                    icon: Icons.groups_outlined,
                    activeIcon: Icons.groups,
                    label: '클럽',
                    path: '/clubs-tab',
                  ),
                  _buildNavItem(
                    context,
                    index: 3,
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: '내정보',
                    path: '/profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String path,
  }) {
    final currentIndex = _calculateSelectedIndex(context);
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () {
        // 홈 탭 진입 시 데이터 새로고침
        if (index == 0) {
          _refreshHomeData();
        }
        context.go(path);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 12 : 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1C1C1E).withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? const Color(0xFF1C1C1E) : AppColors.textTertiary,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1C1C1E),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQRButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/qr/scan'),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2D2D2D), Color(0xFF404040)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2D2D2D).withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.qr_code_scanner,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  /// 홈 탭 진입 시 모든 홈 프로바이더 새로고침
  void _refreshHomeData() {
    ref.invalidate(upcomingContestsProvider);
    ref.invalidate(ongoingContestsProvider);
    ref.invalidate(unreadCountProvider);

    final authState = ref.read(authProvider);
    if (authState.status == AuthStatus.authenticated) {
      ref.invalidate(favoritesProvider);
      ref.invalidate(myRegistrationsProvider);
      ref.read(favoriteIdsProvider.notifier).refresh();
      ref.read(mobileQRProvider.notifier).refresh();
      ref.read(myClubContestsProvider.notifier).refresh();
    }
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/contests')) return 1;
    if (location.startsWith('/clubs-tab')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }
}
