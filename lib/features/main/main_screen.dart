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
import '../../data/providers/chat_provider.dart';
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

    // 401 → refresh 실패 시 호출됨 (ApiClient._clearTokensAndLogout)
    // 토큰은 이미 삭제된 상태. AuthState를 unauthenticated로 전환하면
    // 라우터(refreshListenable)가 자동으로 /login으로 리다이렉트
    ApiClient.onUnauthorized = () {
      if (!mounted) return;
      ref.read(authProvider.notifier).logout();
    };

    // 채팅 안읽은 수 폴링 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatUnreadCountProvider.notifier).startPolling();
    });
  }

  @override
  void dispose() {
    // MainScreen이 트리에서 빠진 후 콜백이 발화하지 않도록 정리
    ApiClient.onUnauthorized = null;
    ApiClient.onUpdateRequired = null;
    WidgetsBinding.instance.removeObserver(this);
    ref.read(chatUnreadCountProvider.notifier).stopPolling();
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
                  // 문의 탭 - 일단 비활성
                  // _buildChatNavItem(context),
                  _buildNavItem(
                    context,
                    index: 3,
                    icon: Icons.groups_outlined,
                    activeIcon: Icons.groups,
                    label: '클럽',
                    path: '/clubs-tab',
                  ),
                  _buildNavItem(
                    context,
                    index: 4,
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

  Widget _buildChatNavItem(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);
    final isSelected = currentIndex == 2;
    final unreadCount = ref.watch(chatUnreadCountProvider);

    return GestureDetector(
      onTap: () {
        ref.read(chatRoomListProvider.notifier).refresh();
        context.go('/chat');
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline,
                  color: isSelected ? const Color(0xFF1C1C1E) : AppColors.textTertiary,
                  size: 24,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Text(
                '문의',
                style: TextStyle(
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
    if (location.startsWith('/chat')) return 2;
    if (location.startsWith('/clubs-tab')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }
}
