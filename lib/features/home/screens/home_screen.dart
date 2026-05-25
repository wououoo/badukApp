import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/banner_carousel.dart';
import '../../../core/widgets/icon_grid_menu.dart';
import '../../../core/widgets/horizontal_tab_menu.dart';
import '../../../data/models/contest.dart';
import '../../../data/models/qr/my_contest.dart';
import '../../../data/models/qr/match_preview.dart';
import '../../../data/providers/contest_provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/mobile_qr_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../contest/widgets/contest_status_badge.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../data/providers/notification_provider.dart';
import '../../profile/screens/my_registrations_screen.dart' show myRegistrationsProvider;

/// 홈 화면 (코랄 오렌지 테마)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userName = authState.user?.name ?? '회원';
    final isAuthenticated = authState.status == AuthStatus.authenticated;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(upcomingContestsProvider);
            ref.invalidate(ongoingContestsProvider);
            if (isAuthenticated) {
              ref.invalidate(favoritesProvider);
              ref.invalidate(myRegistrationsProvider);
              ref.read(favoriteIdsProvider.notifier).refresh();
              await ref.read(mobileQRProvider.notifier).refresh();
              await ref.read(myClubContestsProvider.notifier).refresh();
            }
          },
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // 앱바 (로고 + 알림벨 + 프로필아바타)
              SliverToBoxAdapter(
                child: _buildAppBar(context, userName),
              ),
              // 수평 탭 메뉴
              SliverToBoxAdapter(
                child: HorizontalTabMenu(
                  tabs: HorizontalTabMenu.defaultTabs(),
                  selectedIndex: 0,
                  onTabSelected: (index) {
                    final tabs = HorizontalTabMenu.defaultTabs();
                    if (index < tabs.length && tabs[index].routePath != null) {
                      final tab = tabs[index];
                      final path = tab.routePath!;
                      if (path != '/home') {
                        if (tab.isShellRoute) {
                          context.go(path);
                        } else {
                          context.push(path);
                        }
                      }
                    }
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              // 배너 캐러셀
              SliverToBoxAdapter(
                child: BannerCarousel(
                  height: 160,
                  items: _buildBannerItems(ref),
                  onTap: (routePath) {
                    if (routePath != null) {
                      context.push(routePath);
                    }
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              // 아이콘 그리드 메뉴 (10개 빠른액션)
              SliverToBoxAdapter(
                child: IconGridMenu(
                  items: _buildIconMenuItems(context, ref),
                  onItemTap: (routePath) {
                    if (routePath != null) {
                      context.push(routePath);
                    }
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              // // 바둑판 AI 계가 배너 (기능 개발중 - 추후 활성화)
              // SliverToBoxAdapter(
              //   child: _buildBoardAnalysisBanner(context),
              // ),
              // 내 참가신청 섹션 (인증된 경우에만)
              if (isAuthenticated)
                SliverToBoxAdapter(
                  child: _buildMyRegistrationsSection(context, ref),
                ),
              // 내가 참가 중인 대회 섹션 (인증된 경우에만)
              if (isAuthenticated)
                SliverToBoxAdapter(
                  child: _buildMyActiveContestsSection(context, ref),
                ),
              // 내 클럽 대회 섹션 (인증된 경우에만)
              if (isAuthenticated)
                SliverToBoxAdapter(
                  child: _buildMyClubContestsSection(context, ref),
                ),
              // 즐겨찾기 대회 섹션 (인증된 경우에만)
              if (isAuthenticated)
                SliverToBoxAdapter(
                  child: _buildFavoriteContestsSection(context, ref),
                ),
              // 진행 중인 대회 섹션
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context,
                  title: '진행 중인 대회',
                  icon: Icons.play_circle_filled,
                  iconColor: AppColors.statusLive,
                ),
              ),
              _buildOngoingContestsSliver(context, ref),
              // 다가오는 대회 섹션
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context,
                  title: '다가오는 대회',
                  icon: Icons.event,
                  iconColor: AppColors.statusOpen,
                  onMoreTap: () => context.go('/contests'),
                ),
              ),
              _buildUpcomingContestsSliver(context, ref),
              // 사업자 정보
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.only(top: 32),
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300, width: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '스톤웍스',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '대표: 우경주\n'
                        '사업자등록번호: 661-48-01150\n'
                        '주소: 서울특별시 강서구 송정로 35, 302호\n'
                        '연락처: 010-2520-3603\n'
                        '이메일: dnrudwn3603@gmail.com',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.6,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 하단 여백
              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 앱바 (로고 + 알림벨 + 프로필아바타)
  Widget _buildAppBar(BuildContext context, String userName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          // 로고 영역
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'B',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '안녕하세요, $userName님',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '오늘의 대회 소식을 확인하세요',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // 알림 버튼 (뱃지 포함)
          Consumer(builder: (context, ref, _) {
            final isAuth = ref.watch(authProvider).status == AuthStatus.authenticated;
            final count = isAuth ? (ref.watch(unreadCountProvider).valueOrNull ?? 0) : 0;
            return IconButton(
              onPressed: () => context.push('/notifications'),
              icon: Badge(
                isLabelVisible: count > 0,
                label: Text('$count', style: const TextStyle(fontSize: 10)),
                child: Icon(
                  Icons.notifications_outlined,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
              ),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            );
          }),
          const SizedBox(width: 4),
          // 프로필 아바타
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// posterUrl을 절대 URL로 변환
  String? _getFullPosterUrl(String? posterUrl) {
    if (posterUrl == null || posterUrl.isEmpty) return null;
    if (posterUrl.startsWith('http')) return posterUrl;
    final serverRoot = ApiConstants.baseUrl.replaceAll('/api', '');
    return '$serverRoot$posterUrl';
  }

  /// 배너 아이템 생성 (대회 포스터 우선)
  List<BannerItem> _buildBannerItems(WidgetRef ref) {
    final ongoingContests = ref.watch(ongoingContestsProvider);
    final upcomingContests = ref.watch(upcomingContestsProvider);
    final banners = <BannerItem>[];

    // 진행 중인 대회 (포스터 있으면 이미지 배너)
    ongoingContests.whenData((contests) {
      for (final contest in contests.take(3)) {
        banners.add(BannerItem(
          title: contest.name,
          subtitle: '${contest.totalParticipants ?? 0}명 참가 중',
          backgroundColor: const Color(0xFFB84E30),
          imageUrl: _getFullPosterUrl(contest.posterUrl),
          routePath: '/contest/${contest.id}',
        ));
      }
    });

    // 다가오는 대회 중 포스터 있는 것
    upcomingContests.whenData((contests) {
      for (final contest in contests.take(5)) {
        if (contest.posterUrl != null && contest.posterUrl!.isNotEmpty) {
          banners.add(BannerItem(
            title: contest.name,
            subtitle: contest.schedule ?? '대회 예정',
            backgroundColor: const Color(0xFFD4603C),
            imageUrl: _getFullPosterUrl(contest.posterUrl),
            routePath: '/contest/${contest.id}',
          ));
        }
      }
    });

    // 대회가 없거나 포스터가 하나도 없으면 기본 배너
    if (banners.isEmpty) {
      banners.add(const BannerItem(
        title: '바둑 대회에 참가하세요',
        subtitle: '다양한 대회 일정을 확인하고 신청하세요',
        backgroundColor: Color(0xFFD4603C),
        routePath: '/contests',
      ));
    }

    return banners;
  }

  /// 아이콘 메뉴 아이템 (대회 홈페이지, 라이브 현황 포함)
  List<IconMenuItem> _buildIconMenuItems(BuildContext context, WidgetRef ref) {
    return [
      const IconMenuItem(
        icon: Icons.emoji_events_outlined,
        label: '대회',
        color: Color(0xFFD4603C),
        routePath: '/contests',
      ),
      IconMenuItem(
        icon: Icons.language,
        label: '대회홈페이지',
        color: const Color(0xFF3B82F6),
        onTap: () => _showHomepageSelector(context, ref),
      ),
      const IconMenuItem(
        icon: Icons.how_to_reg,
        label: '신청내역',
        color: Color(0xFF7C3AED),
        routePath: '/profile/registrations',
      ),
      const IconMenuItem(
        icon: Icons.history,
        label: '대회내역',
        color: Color(0xFF3B82F6),
        routePath: '/history',
      ),
      const IconMenuItem(
        icon: Icons.qr_code_scanner,
        label: 'QR체크인',
        color: Color(0xFF10B981),
        routePath: '/qr/scan',
      ),
      const IconMenuItem(
        icon: Icons.groups_outlined,
        label: '클럽',
        color: Color(0xFFF59E0B),
        routePath: '/clubs-tab',
      ),
      IconMenuItem(
        icon: Icons.live_tv,
        label: '라이브',
        color: const Color(0xFFEF4444),
        onTap: () => _openLivePage(context),
      ),
      IconMenuItem(
        icon: Icons.favorite_outline,
        label: '즐겨찾기',
        color: const Color(0xFFEC4899),
        onTap: () => _showFavoritesSheet(context, ref),
      ),
      const IconMenuItem(
        icon: Icons.notifications_outlined,
        label: '알림',
        color: Color(0xFF6366F1),
        routePath: '/notifications',
      ),
      const IconMenuItem(
        icon: Icons.more_horiz,
        label: '더보기',
        color: Color(0xFF8B5CF6),
        routePath: '/support',
      ),
    ];
  }

  Widget _buildBoardAnalysisBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: () => context.push('/board-analysis'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2D2D2D), Color(0xFF404040)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('바둑판 AI 형세판단',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('사진으로 승률 분석',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onMoreTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          if (onMoreTap != null)
            TextButton(
              onPressed: onMoreTap,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('전체보기', style: TextStyle(fontSize: 13)),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOngoingContestsSliver(BuildContext context, WidgetRef ref) {
    final ongoingContests = ref.watch(ongoingContestsProvider);

    return ongoingContests.when(
      data: (contests) {
        if (contests.isEmpty) {
          return SliverToBoxAdapter(
            child: _buildEmptyCard('진행 중인 대회가 없습니다'),
          );
        }
        return SliverToBoxAdapter(
          child: SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: contests.length,
              itemBuilder: (context, index) {
                final contest = contests[index];
                return _buildOngoingContestCard(context, contest);
              },
            ),
          ),
        );
      },
      loading: () => SliverToBoxAdapter(
        child: SkeletonBuilders.horizontalContests(),
      ),
      error: (_, __) => SliverToBoxAdapter(
        child: _buildEmptyCard('데이터를 불러올 수 없습니다'),
      ),
    );
  }

  Widget _buildOngoingContestCard(BuildContext context, Contest contest) {
    final hasPoster = contest.posterUrl != null && contest.posterUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push('/contest/${contest.id}'),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: hasPoster
            ? _buildPosterContestCard(contest)
            : _buildCleanContestCard(contest),
      ),
    );
  }

  /// 포스터가 있는 대회 카드 (이미지 배경)
  Widget _buildPosterContestCard(Contest contest) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          _getFullPosterUrl(contest.posterUrl)!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceVariant),
        ),
        // 하단 그래디언트
        Positioned(
          left: 0, right: 0, bottom: 0, height: 80,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
              ),
            ),
          ),
        ),
        // 진행중 뱃지
        Positioned(
          top: 10, left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.statusLiveBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 6, color: AppColors.statusLive),
                SizedBox(width: 4),
                Text(
                  '진행중',
                  style: TextStyle(
                    color: AppColors.statusLiveText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 하단 텍스트
        Positioned(
          left: 12, right: 12, bottom: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contest.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${contest.totalParticipants ?? 0}명 참가',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 포스터 없는 대회 카드 (깔끔한 화이트)
  Widget _buildCleanContestCard(Contest contest) {
    return Row(
      children: [
        // 좌측 컬러 스트립
        Container(
          width: 4,
          decoration: const BoxDecoration(
            color: AppColors.statusLive,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
        ),
        // 콘텐츠
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 진행중 뱃지
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.statusLiveBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 6, color: AppColors.statusLive),
                          SizedBox(width: 4),
                          Text(
                            '진행중',
                            style: TextStyle(
                              color: AppColors.statusLiveText,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 대회명
                    Text(
                      contest.name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                // 참가자 수
                Row(
                  children: [
                    Icon(Icons.people_outline, color: AppColors.textTertiary, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      '${contest.totalParticipants ?? 0}명 참가',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingContestsSliver(BuildContext context, WidgetRef ref) {
    final upcomingContests = ref.watch(upcomingContestsProvider);

    return upcomingContests.when(
      data: (contests) {
        if (contests.isEmpty) {
          return SliverToBoxAdapter(
            child: _buildEmptyCard('예정된 대회가 없습니다'),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final contest = contests[index];
              return _buildUpcomingContestItem(context, contest);
            },
            childCount: contests.length > 5 ? 5 : contests.length,
          ),
        );
      },
      loading: () => SliverToBoxAdapter(
        child: SkeletonBuilders.upcomingContestList(),
      ),
      error: (_, __) => SliverToBoxAdapter(
        child: _buildEmptyCard('데이터를 불러올 수 없습니다'),
      ),
    );
  }

  Widget _buildUpcomingContestItem(BuildContext context, Contest contest) {
    return GestureDetector(
      onTap: () => context.push('/contest/${contest.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 날짜 표시
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getMonthDay(contest.startDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    _getMonthText(contest.startDate),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // 대회 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contest.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ContestStatusBadge.fromString(
                        contest.status,
                        contestDate: contest.startDate,
                        contestEndDate: contest.endDate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          contest.fullLocation.isNotEmpty
                              ? contest.fullLocation
                              : '장소 미정',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 화살표
            Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  String _getMonthDay(DateTime? date) {
    if (date == null) return '-';
    return date.day.toString();
  }

  String _getMonthText(DateTime? date) {
    if (date == null) return '';
    const months = [
      '1월', '2월', '3월', '4월', '5월', '6월',
      '7월', '8월', '9월', '10월', '11월', '12월'
    ];
    return months[date.month - 1];
  }

  /// 홈페이지 선택 다이얼로그
  void _showHomepageSelector(BuildContext context, WidgetRef ref) {
    final upcomingContests = ref.read(upcomingContestsProvider);
    final ongoingContests = ref.read(ongoingContestsProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              final allContests = <Contest>[];
              upcomingContests.whenData((contests) => allContests.addAll(contests));
              ongoingContests.whenData((contests) => allContests.addAll(contests));

              return Column(
                children: [
                  // 핸들바
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // 제목
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.language, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text(
                          '대회 홈페이지 선택',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // 대회 목록
                  Expanded(
                    child: allContests.isEmpty
                        ? Center(
                            child: Text(
                              '등록된 대회가 없습니다',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: allContests.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              indent: 72,
                            ),
                            itemBuilder: (context, index) {
                              final contest = allContests[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 4,
                                ),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.language,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                                title: Text(
                                  contest.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  contest.schedule ??
                                      _formatDate(contest.startDate),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: AppColors.textTertiary,
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  context.push(
                                    '/homepage/${contest.id}?title=${Uri.encodeComponent(contest.name)}',
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  /// 라이브 페이지 열기
  void _openLivePage(BuildContext context) async {
    final liveUrl = '${ApiConstants.webUrl}/live';
    final uri = Uri.parse(liveUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('라이브 페이지를 열 수 없습니다')),
        );
      }
    }
  }

  /// 즐겨찾기 바텀시트
  void _showFavoritesSheet(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.read(favoritesProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들바
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 제목
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.favorite, color: Color(0xFFEC4899), size: 22),
                    SizedBox(width: 10),
                    Text(
                      '즐겨찾기 대회',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 즐겨찾기 목록
              Flexible(
                child: favoritesAsync.when(
                  data: (favorites) {
                    if (favorites.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            '즐겨찾기한 대회가 없습니다',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: favorites.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: 72,
                      ),
                      itemBuilder: (context, index) {
                        final fav = favorites[index];
                        final homepageId = fav['homepageId'] as int? ?? 0;
                        final contestName = fav['contestName'] as String? ?? '';
                        final venue = fav['venue'] as String? ?? '';
                        final status = fav['status'] as String? ?? '';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE7F3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.favorite,
                              color: Color(0xFFEC4899),
                              size: 22,
                            ),
                          ),
                          title: Text(
                            contestName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            venue.isNotEmpty ? venue : '장소 미정',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: status.isNotEmpty
                              ? ContestStatusBadge.fromString(status)
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/contest/$homepageId');
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                  error: (_, __) => Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        '데이터를 불러올 수 없습니다',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 내 참가신청 섹션
  Widget _buildMyRegistrationsSection(BuildContext context, WidgetRef ref) {
    final registrationsAsync = ref.watch(myRegistrationsProvider);

    return registrationsAsync.when(
      data: (registrations) {
        if (registrations.isEmpty) return const SizedBox.shrink();

        final displayList = registrations.length > 3
            ? registrations.sublist(0, 3)
            : registrations;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 섹션 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.how_to_reg, size: 20, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Text(
                    '내 참가신청',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${registrations.length}건',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      context.push('/profile/registrations');
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('전체보기', style: TextStyle(fontSize: 13)),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 카드 리스트
            ...displayList.map((reg) => _buildRegistrationItem(context, reg)),
            const SizedBox(height: 8),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// 참가신청 카드 아이템
  Widget _buildRegistrationItem(BuildContext context, Map<String, dynamic> reg) {
    final status = reg['status'] as String? ?? 'PENDING';
    final paymentStatus = reg['paymentStatus'] as String? ?? 'UNPAID';
    final fee = (reg['fee'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: () {
        context.push('/profile/registrations');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 아이콘
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.how_to_reg, color: Color(0xFF7C3AED), size: 20),
            ),
            const SizedBox(width: 12),
            // 대회명 + 부문명
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reg['contestName'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    reg['categoryName'] ?? '',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 상태 배지들 + D-day
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // D-day 표시
                if (reg['contestStartDate'] != null) ...[
                  Builder(builder: (_) {
                    final startDate = DateTime.tryParse(reg['contestStartDate'].toString());
                    if (startDate == null) return const SizedBox.shrink();
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final target = DateTime(startDate.year, startDate.month, startDate.day);
                    final dDay = target.difference(today).inDays;
                    if (dDay < 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        dDay == 0 ? 'D-DAY' : 'D-$dDay',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: dDay == 0 ? AppColors.error : const Color(0xFF2563EB),
                        ),
                      ),
                    );
                  }),
                ],
                _buildMiniBadge(status),
                if (fee > 0) ...[
                  const SizedBox(height: 4),
                  _buildMiniPaymentBadge(paymentStatus),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case 'APPROVED':
        bg = AppColors.statusOpenBg;
        text = AppColors.statusOpenText;
        label = '승인';
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFF991B1B);
        label = '거절';
        break;
      case 'CANCELLED':
        bg = AppColors.statusClosedBg;
        text = AppColors.statusClosedText;
        label = '취소';
        break;
      default:
        bg = AppColors.statusSoonBg;
        text = AppColors.statusSoonText;
        label = '대기';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: text),
      ),
    );
  }

  Widget _buildMiniPaymentBadge(String paymentStatus) {
    Color bg;
    Color text;
    String label;

    switch (paymentStatus) {
      case 'COMPLETED':
        bg = AppColors.statusOpenBg;
        text = AppColors.statusOpenText;
        label = '결제완료';
        break;
      case 'PENDING':
        bg = AppColors.statusSoonBg;
        text = AppColors.statusSoonText;
        label = '결제대기';
        break;
      case 'REFUNDED':
        bg = AppColors.statusClosedBg;
        text = AppColors.statusClosedText;
        label = '환불';
        break;
      default:
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFF991B1B);
        label = '미결제';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: text),
      ),
    );
  }

  /// 즐겨찾기 대회 섹션
  Widget _buildFavoriteContestsSection(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return favoritesAsync.when(
      data: (favorites) {
        if (favorites.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              context,
              title: '즐겨찾기 대회',
              icon: Icons.favorite,
              iconColor: AppColors.error,
            ),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final fav = favorites[index];
                  return _buildFavoriteContestCard(context, ref, fav);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// 즐겨찾기 대회 카드
  Widget _buildFavoriteContestCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> favorite,
  ) {
    final homepageId = favorite['homepageId'] as int? ?? 0;
    final contestName = favorite['contestName'] as String? ?? '';
    final venue = favorite['venue'] as String? ?? '';
    final schedule = favorite['schedule'] as String? ?? '';
    final status = favorite['status'] as String? ?? '';

    return GestureDetector(
      onTap: () => context.push('/contest/$homepageId'),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (status.isNotEmpty)
                        ContestStatusBadge.fromString(status),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          ref.read(favoriteIdsProvider.notifier).toggle(homepageId);
                          ref.invalidate(favoritesProvider);
                        },
                        child: const Icon(
                          Icons.favorite,
                          size: 18,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    contestName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Row(
                children: [
                  if (venue.isNotEmpty) ...[
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        venue,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (schedule.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        schedule,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 내가 참가 중인 대회 섹션
  Widget _buildMyActiveContestsSection(BuildContext context, WidgetRef ref) {
    final qrState = ref.watch(mobileQRProvider);
    final contests = qrState.contests;

    // 참가 중인 대회가 없으면 표시하지 않음
    if (contests.isEmpty) {
      return const SizedBox.shrink();
    }

    // contestId로 그룹핑 (같은 대회의 여러 부문을 하나로)
    final grouped = <int, List<MyContest>>{};
    for (final c in contests) {
      grouped.putIfAbsent(c.contestId, () => []);
      grouped[c.contestId]!.add(c);
    }
    final groupedList = grouped.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.sports_esports,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '내 대회',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.statusLiveBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${groupedList.length}개 진행 중',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.statusLiveText,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => ref.read(mobileQRProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh, size: 20),
                color: AppColors.textSecondary,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        // 대회 목록 (가로 스크롤)
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: groupedList.length,
            itemBuilder: (context, index) {
              final group = groupedList[index];
              return _buildMyContestCard(context, group);
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// 내 클럽 대회 섹션
  Widget _buildMyClubContestsSection(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myClubContestsProvider);
    final contests = state.contests;

    if (contests.isEmpty) {
      return const SizedBox.shrink();
    }

    // contestId로 그룹핑
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final c in contests) {
      final contestId = c['contestId'] as int;
      grouped.putIfAbsent(contestId, () => []);
      grouped[contestId]!.add(c);
    }
    final groupedList = grouped.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.groups_outlined,
                  size: 18,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '내 클럽 대회',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${groupedList.length}개 진행 중',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => ref.read(myClubContestsProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh, size: 20),
                color: AppColors.textSecondary,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: groupedList.length,
            itemBuilder: (context, index) {
              final group = groupedList[index];
              return _buildClubContestCard(context, group);
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// 클럽 대회 카드
  Widget _buildClubContestCard(BuildContext context, List<Map<String, dynamic>> group) {
    final primary = group.first;
    // 가장 활성화된 부문 찾기
    final active = group.reduce((a, b) {
      final aRound = a['currentRound'] as int? ?? 0;
      final bRound = b['currentRound'] as int? ?? 0;
      if (a['opponent'] != null && b['opponent'] == null) return a;
      if (b['opponent'] != null && a['opponent'] == null) return b;
      return aRound >= bRound ? a : b;
    });

    final clubName = primary['clubName'] ?? '';
    final contestName = primary['contestName'] ?? '';

    return GestureDetector(
      onTap: () {
        final clubId = primary['clubId'];
        final contestId = primary['contestId'];
        if (clubId != null && contestId != null) {
          context.push('/clubs/$clubId/contests/$contestId/manage');
        }
      },
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.teal.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 클럽명 + 대회명
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.groups_outlined, size: 14, color: Colors.teal),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          clubName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.teal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (group.length == 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            primary['sortName'] ?? '',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${group.length}개 부문',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contestName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 하단: 현재 경기 정보
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: _buildClubMatchInfo(active),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 클럽 대회 경기 정보
  Widget _buildClubMatchInfo(Map<String, dynamic> contest) {
    final currentRound = contest['currentRound'] as int? ?? 0;
    final opponent = contest['opponent'] as String?;
    final matchCompleted = contest['matchCompleted'] as bool? ?? false;
    final won = contest['won'] as bool?;

    if (currentRound == 0) {
      return Center(
        child: Text(
          '대진표 대기 중',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$currentRound라운드',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 4),
        if (opponent != null) ...[
          Row(
            children: [
              const Text(
                'VS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  opponent,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (matchCompleted && won != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: won ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    won ? '승' : '패',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: won ? Colors.green : Colors.red,
                    ),
                  ),
                ),
            ],
          ),
        ] else
          Text(
            '부전승',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
      ],
    );
  }

  /// 내 대회 카드 (같은 대회의 여러 부문을 하나로 묶어 표시)
  Widget _buildMyContestCard(BuildContext context, List<MyContest> group) {
    final primary = group.first;
    // 가장 활성화된 부문 찾기 (라운드 진행 중 > 상대 있음 > 라운드 높음)
    final active = group.reduce((a, b) {
      if (a.opponent != null && b.opponent == null) return a;
      if (b.opponent != null && a.opponent == null) return b;
      return a.currentRound >= b.currentRound ? a : b;
    });

    return GestureDetector(
      onTap: () => context.push('/qr/contest/${primary.contestId}'),
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 대회명 + 부문 칩들
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      primary.contestName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 부문이 1개면 단일 칩, 여러 개면 개수 표시
                  if (group.length == 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        primary.sortName,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${group.length}개 부문',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 하단: 가장 활성화된 부문의 경기 정보 + footer (진행률·인접 매치)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildMatchInfo(active, showSortName: group.length > 1),
                    ),
                    _buildMatchFooter(active),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 매치 footer: 진행률 + 인접 매치 미리보기
  /// - 진행률·인접 매치 데이터가 없거나 표시 부적합 상태면 빈 위젯 반환
  Widget _buildMatchFooter(MyContest contest) {
    // 체크인 단계(currentRound == 0) 또는 DE 예선 탈락은 표시 안 함
    final isPreContest = contest.currentRound == 0;
    final isDeEliminated = contest.tournamentStarted == true &&
        contest.advancedToTournament == false;
    if (isPreContest || isDeEliminated) {
      return const SizedBox.shrink();
    }

    final hasProgress = contest.hasProgressInfo;
    final hasAdjacent = contest.hasAdjacentMatches;
    if (!hasProgress && !hasAdjacent) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasProgress)
            Row(
              children: [
                Icon(Icons.bar_chart, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'R${contest.currentRound} 진행 ${contest.completedMatchesInCurrentRound ?? 0}/${contest.totalMatchesInCurrentRound}경기',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          if (hasAdjacent) ...[
            const SizedBox(height: 3),
            ...contest.adjacentMatches.take(2).map((m) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _buildAdjacentMatchRow(m),
                )),
          ],
        ],
      ),
    );
  }

  /// 인접 매치 한 줄 표시
  Widget _buildAdjacentMatchRow(MatchPreview m) {
    final isCompleted = m.isCompleted;
    final isBye = m.isBye;
    String text;
    if (isBye) {
      text = '${m.matchNumber ?? '-'}번  ${m.player1Name ?? ''} (부전승)';
    } else {
      text = '${m.matchNumber ?? '-'}번  ${m.player1Name ?? ''} vs ${m.player2Name ?? ''}';
    }
    String statusLabel;
    Color statusColor;
    if (isCompleted) {
      statusLabel = '완료';
      statusColor = AppColors.success;
    } else if (m.status == 'SCHEDULED') {
      statusLabel = '대기';
      statusColor = AppColors.textTertiary;
    } else {
      statusLabel = '진행중';
      statusColor = AppColors.warning;
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          statusLabel,
          style: TextStyle(
            fontSize: 10,
            color: statusColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// 현재 경기 정보 표시
  Widget _buildMatchInfo(MyContest contest, {bool showSortName = false}) {
    // DE 토너먼트 시작된 경우
    if (contest.tournamentStarted == true) {
      if (contest.advancedToTournament == true) {
        // 본선 진출
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                if (showSortName) ...[
                  Text(
                    contest.sortName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    contest.tournamentStage ?? '본선',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (contest.tournamentOpponent != null) ...[
              Row(
                children: [
                  const Text(
                    'VS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      contest.tournamentOpponent!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ] else
              Text(
                '대진 대기 중',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
          ],
        );
      } else {
        // 예선 탈락
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showSortName)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    contest.sortName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              Icon(Icons.flag_outlined, size: 22, color: AppColors.textTertiary),
              const SizedBox(height: 4),
              Text(
                '예선 종료',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      }
    }

    // 부전승인 경우 ("없음" 상대)
    if (contest.opponent == '없음') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showSortName)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  contest.sortName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.statusLiveBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${contest.currentRound}R',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.statusLiveText,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '부전승',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      );
    }

    // 상대가 있는 경우 (경기 배정됨)
    if (contest.opponent != null && contest.opponent!.isNotEmpty) {
      // 단체전 풀리그: 팀 상대 + 개인 매치 정보 표시
      final isTeamFullLeague = contest.contestType == 'TEAM_FULL_LEAGUE';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 라운드 정보
          Row(
            children: [
              if (showSortName) ...[
                Text(
                  contest.sortName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.statusLiveBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${contest.currentRound}R',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.statusLiveText,
                  ),
                ),
              ),
              if (contest.matchNumber != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${contest.matchNumber}번 테이블',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              // 단체전 개인 전적
              if (isTeamFullLeague && contest.myWins != null) ...[
                const Spacer(),
                Text(
                  '${contest.myWins}승 ${contest.myLosses ?? 0}패',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // 팀 상대 정보
          Row(
            children: [
              const Text(
                'VS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  contest.opponent!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // 단체전: 개인 매치 상대 표시
          if (isTeamFullLeague && contest.myOpponent != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                if (contest.boardNumber != null)
                  Text(
                    '${contest.boardNumber}기',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary.withOpacity(0.7),
                    ),
                  ),
                if (contest.boardNumber != null)
                  const SizedBox(width: 6),
                Text(
                  'vs ${contest.myOpponent}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    // 상대가 없는 경우
    if (contest.currentRound > 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showSortName)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  contest.sortName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            Text(
              '${contest.currentRound}R 대기 중',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '상대 배정 전',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    // 대회 시작 전
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            contest.checkedIn ? Icons.check_circle : Icons.schedule,
            size: 24,
            color: contest.checkedIn ? AppColors.success : AppColors.textTertiary,
          ),
          const SizedBox(height: 4),
          Text(
            contest.checkedIn ? '체크인 완료' : '대회 시작 전',
            style: TextStyle(
              fontSize: 12,
              color: contest.checkedIn ? AppColors.success : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

