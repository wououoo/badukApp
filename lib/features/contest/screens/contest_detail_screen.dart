import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' hide Story;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/contest_service.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/models/homepage_image.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/contest_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../widgets/contest_status_badge.dart';
import '../widgets/contest_photos_tab.dart';
import '../widgets/refund_policy_section.dart';
import '../../live/widgets/live_sort_content.dart';
import '../../live/widgets/live_de_content.dart';

// Re-export for RankingEntry type
export '../../../data/services/contest_service.dart' show SortRankings, RankingEntry;

/// 대회 상세 화면 (런너블 스타일)
class ContestDetailScreen extends ConsumerStatefulWidget {
  final int contestId;

  const ContestDetailScreen({super.key, required this.contestId});

  @override
  ConsumerState<ContestDetailScreen> createState() =>
      _ContestDetailScreenState();
}

class _ContestDetailScreenState extends ConsumerState<ContestDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _selectedCategoryId;
  int _selectedSortIndex = 0; // 결과 탭에서 선택된 부문 인덱스

  // 홈페이지 안내 이미지 (운영진이 올린 부문/상금/지도/대진표/결과 안내)
  List<HomepageImage> _homepageImages = [];
  final Set<int> _expandedImageIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadHomepageImages();
  }

  Future<void> _loadHomepageImages() async {
    final images = await ContestService().getHomepageImages(widget.contestId);
    if (!mounted) return;
    setState(() {
      _homepageImages = images.where((i) => i.isVisible).toList()
        ..sort((a, b) => (a.displayOrder ?? 0).compareTo(b.displayOrder ?? 0));
    });
  }

  String _buildImageFullUrl(String imageUrl) {
    if (imageUrl.startsWith('http')) return imageUrl;
    return '${ApiConstants.baseUrl.replaceAll('/api', '')}$imageUrl';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildFavoriteButton({ContestDetail? contest}) {
    final favoriteIds = ref.watch(favoriteIdsProvider);
    final isFavorite = favoriteIds.contains(widget.contestId);

    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          size: 20,
          color: isFavorite ? AppColors.error : null,
        ),
      ),
      onPressed: () {
        ref.read(favoriteIdsProvider.notifier).toggle(
          widget.contestId,
          contestName: contest?.name,
          contestStartDate: contest?.contestStartDate,
        );
        ref.invalidate(favoritesProvider);
      },
    );
  }

  void _openHomepage(BuildContext context) {
    final encodedTitle = Uri.encodeComponent('대회 홈페이지');
    context.push('/homepage-webview/${widget.contestId}?title=$encodedTitle');
  }

  /// 공유 BottomSheet (카카오톡 / 링크 복사 / 기타)
  void _showShareBottomSheet(ContestDetail contest) {
    final url = '${ApiConstants.webUrl}/homepage/${widget.contestId}';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '공유하기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 카카오톡 공유
                  _shareOption(
                    icon: Icons.chat_bubble,
                    iconColor: const Color(0xFF3C1E1E),
                    bgColor: const Color(0xFFFEE500),
                    label: '카카오톡',
                    onTap: () {
                      Navigator.pop(ctx);
                      _shareKakao(contest, url);
                    },
                  ),
                  // 링크 복사
                  _shareOption(
                    icon: Icons.link,
                    iconColor: AppColors.textPrimary,
                    bgColor: AppColors.background,
                    label: '링크 복사',
                    onTap: () {
                      Navigator.pop(ctx);
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('링크가 복사되었습니다.')),
                      );
                    },
                  ),
                  // 기타 공유
                  _shareOption(
                    icon: Icons.more_horiz,
                    iconColor: AppColors.textPrimary,
                    bgColor: AppColors.background,
                    label: '기타',
                    onTap: () {
                      Navigator.pop(ctx);
                      final text = '${contest.name}\n'
                          '${contest.schedule != null ? '일정: ${contest.schedule}\n' : ''}'
                          '${contest.venue != null ? '장소: ${contest.venue}\n' : ''}'
                          '$url';
                      Share.share(text, subject: contest.name);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shareOption({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// 카카오톡 공유
  Future<void> _shareKakao(ContestDetail contest, String url) async {
    try {
      final webUrl = Uri.parse(url);
      final template = FeedTemplate(
        content: Content(
          title: contest.name,
          description: [
            if (contest.schedule != null) '일정: ${contest.schedule}',
            if (contest.venue != null) '장소: ${contest.venue}',
          ].join('\n'),
          link: Link(
            webUrl: webUrl,
            mobileWebUrl: webUrl,
          ),
        ),
        buttons: [
          Button(
            title: '대회 보기',
            link: Link(
              webUrl: webUrl,
              mobileWebUrl: webUrl,
            ),
          ),
        ],
      );

      // 카카오톡 앱이 설치되어 있는지 확인
      if (await ShareClient.instance.isKakaoTalkSharingAvailable()) {
        final uri = await ShareClient.instance.shareDefault(template: template);
        await ShareClient.instance.launchKakaoTalk(uri);
      } else {
        // 카카오톡 미설치 시 웹 공유
        final uri = await WebSharerClient.instance.makeDefaultUrl(template: template);
        await launchBrowserTab(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카카오톡 공유에 실패했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contestDetail = ref.watch(contestDetailProvider(widget.contestId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: contestDetail.when(
        data: (contest) => _buildContent(contest),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, _) => _buildErrorState(error.toString()),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 64,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                '데이터를 불러올 수 없습니다',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(contestDetailProvider(widget.contestId));
                },
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ContestDetail contest) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          _buildSliverAppBar(contest),
          _buildSliverPersistentHeader(contest),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(contest),
          _buildCategoryTab(contest),
          _buildPrizeTab(contest),
          _buildMapTab(contest),
          _buildResultsTab(contest),
          ContestPhotosTab(homepageId: widget.contestId),
        ],
      ),
    );
  }

  /// 슬라이버 앱바 (히어로 이미지 + 기본 정보)
  Widget _buildSliverAppBar(ContestDetail contest) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.9),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, size: 20),
        ),
        onPressed: () => context.pop(),
      ),
      actions: [
        // 즐겨찾기 버튼
        _buildFavoriteButton(contest: contest),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share_outlined, size: 20),
          ),
          onPressed: () => _showShareBottomSheet(contest),
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.language, size: 20),
          ),
          onPressed: () => _openHomepage(context),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 배경 이미지 (바둑판 패턴)
            _buildHeroImage(),
            // 그라데이션 오버레이
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            // 대회 기본 정보
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 상태 뱃지
                  ContestStatusBadge.fromString(
                    contest.status,
                    contestDate: null,
                  ),
                  const SizedBox(height: 12),
                  // 대회명
                  Text(
                    contest.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (contest.subtitle != null &&
                      contest.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      contest.subtitle!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 히어로 이미지 (바둑판 패턴)
  Widget _buildHeroImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1C1C1E),
            Color(0xFF2D2D2D),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _BadukBoardHeroPainter(),
      ),
    );
  }

  /// 탭바 (Persistent Header)
  Widget _buildSliverPersistentHeader(ContestDetail contest) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverTabBarDelegate(
        height: 52,
        child: _buildWrapTabs(),
      ),
    );
  }

  /// 탭바 (가로 스크롤 + 아이콘 + 언더라인 인디케이터)
  Widget _buildWrapTabs() {
    final tabs = <({IconData icon, String label})>[
      (icon: Icons.info_outline, label: '정보'),
      (icon: Icons.category_outlined, label: '부문'),
      (icon: Icons.emoji_events_outlined, label: '상금'),
      (icon: Icons.place_outlined, label: '지도'),
      (icon: Icons.leaderboard_outlined, label: '결과'),
      (icon: Icons.photo_library_outlined, label: '사진'),
    ];
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          color: AppColors.surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final selected = _tabController.index == i;
                final color =
                    selected ? AppColors.primary : AppColors.textSecondary;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _tabController.animateTo(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color:
                              selected ? AppColors.primary : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tabs[i].icon, size: 18, color: color),
                        const SizedBox(width: 6),
                        Text(
                          tabs[i].label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  /// 정보 탭
  Widget _buildInfoTab(ContestDetail contest) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 대회 정보 카드
          _buildInfoCard(contest),
          const SizedBox(height: 20),
          // 대기 방법 (있는 경우)
          if (contest.gameMethods.isNotEmpty) ...[
            _buildGameMethodsSection(contest),
            const SizedBox(height: 20),
          ],
          // 안내 이미지 섹션 (부문/상금/지도/대진표/결과 등 운영진 업로드)
          if (_homepageImages.isNotEmpty) ...[
            _buildHomepageImagesSection(),
            const SizedBox(height: 20),
          ],
          // 환불 규정
          RefundPolicySection(
            homepageId: widget.contestId,
            compact: true,
            onTapDetail: () {
              context.push(
                '/refund-policy/${widget.contestId}'
                '?name=${Uri.encodeComponent(contest.name)}',
              );
            },
          ),
          const SizedBox(height: 20),
          // 참가신청 버튼
          _buildApplyButton(contest),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ContestDetail contest) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 안내 정보는 서버(HomepageInfoRows)가 순서·라벨·표시여부까지 정해서 내려준다.
          // 여기서는 받은 순서대로 그리기만 한다 — 항목이 추가돼도 앱 수정/재배포 불필요.
          ..._buildInfoRowWidgets(contest),
          // 채팅으로 문의 버튼 - 일단 비활성
          // if (contest.hasChatManager)
          //   Padding(
          //     padding: const EdgeInsets.only(top: 12),
          //     child: SizedBox(
          //       width: double.infinity,
          //       child: OutlinedButton.icon(
          //         onPressed: () => _openChatWithHost(contest),
          //         icon: const Icon(Icons.chat_bubble_outline, size: 18),
          //         label: const Text('채팅으로 문의'),
          //         style: OutlinedButton.styleFrom(
          //           foregroundColor: AppColors.primary,
          //           side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
          //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          //           padding: const EdgeInsets.symmetric(vertical: 12),
          //         ),
          //       ),
          //     ),
          //   ),
        ],
      ),
    );
  }

  Future<void> _openChatWithHost(ContestDetail contest) async {
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      context.push('/login');
      return;
    }

    try {
      final chatService = ChatService();
      final room = await chatService.getOrCreateRoom(homepageId: contest.id);
      if (mounted) {
        context.push('/chat/${room['roomId']}', extra: {
          'contestTitle': room['contestTitle'] ?? contest.name,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('채팅방 생성에 실패했습니다.')),
        );
      }
    }
  }

  Widget _buildMapTab(ContestDetail contest) {
    if (contest.latitude == null || contest.longitude == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text('위치 정보가 등록되지 않았습니다',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    // 웹에서는 네이버맵 SDK 미지원
    if (kIsWeb) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(contest.venue ?? '', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openDirections(contest.latitude!, contest.longitude!, contest.venue ?? ''),
              icon: const Icon(Icons.directions),
              label: const Text('네이버 지도에서 보기'),
            ),
          ],
        ),
      );
    }

    final position = NLatLng(contest.latitude!, contest.longitude!);
    debugPrint('[지도] lat=${contest.latitude}, lng=${contest.longitude}, venue=${contest.venue}');

    return Stack(
      children: [
        // 지도 - 전체 영역 채움
        Positioned.fill(
          child: NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: position,
                zoom: 15,
              ),
              mapType: NMapType.basic,
              locale: const Locale('ko'),
              contentPadding: const EdgeInsets.only(bottom: 70),
              consumeSymbolTapEvents: false,
            ),
            onMapReady: (controller) {
              debugPrint('[지도] onMapReady 호출됨');
              final marker = NMarker(
                id: 'contest_${contest.id}',
                position: position,
              );
              marker.setCaption(NOverlayCaption(
                text: contest.venue ?? contest.name,
                textSize: 12,
              ));
              controller.addOverlay(marker);
            },
            forceGesture: true,
          ),
        ),
        // 하단 길찾기 버튼
        Positioned(
          left: 16,
          right: 16,
          bottom: 80,
          child: ElevatedButton.icon(
            onPressed: () => _openDirections(
              contest.latitude!, contest.longitude!, contest.venue ?? '',
            ),
            icon: const Icon(Icons.directions, size: 20),
            label: Text(contest.venue ?? '길찾기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              elevation: 4,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openDirections(double lat, double lng, String name) async {
    final encodedName = Uri.encodeComponent(name);
    // 네이버맵 앱 → 카카오맵 앱 → 네이버맵 웹 순으로 시도
    final naverAppUrl = Uri.parse(
      'nmap://route/car?dlat=$lat&dlng=$lng&dname=$encodedName&appname=com.swissbaduk.baduk_app'
    );
    final kakaoMapUrl = Uri.parse(
      'kakaomap://route?ep=$lat,$lng&by=CAR'
    );
    final naverWebUrl = Uri.parse(
      'https://map.naver.com/v5/directions/-/${lat},${lng},${encodedName}/-/transit'
    );

    if (await canLaunchUrl(naverAppUrl)) {
      await launchUrl(naverAppUrl);
    } else if (await canLaunchUrl(kakaoMapUrl)) {
      await launchUrl(kakaoMapUrl);
    } else {
      await launchUrl(naverWebUrl, mode: LaunchMode.externalApplication);
    }
  }

  /// 서버가 내려준 안내 정보 행들을 순서대로 위젯으로 변환.
  /// 장소 행 뒤에는 길찾기 버튼을 끼워 넣는다(좌표가 있을 때만).
  List<Widget> _buildInfoRowWidgets(ContestDetail contest) {
    final rows = contest.infoRows;
    final widgets = <Widget>[];

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final isLastRow = i == rows.length - 1;
      final hasDirections = row.key == 'venue' &&
          contest.latitude != null &&
          contest.longitude != null;

      widgets.add(_buildInfoItem(
        icon: _infoRowIcon(row.key),
        label: row.label,
        value: row.value,
        // 참가비는 기존과 동일하게 강조색 유지
        valueColor: row.key == 'participationFee' ? AppColors.primary : null,
        // 길찾기 버튼이 뒤에 붙으면 구분선을 남겨둔다
        isLast: isLastRow && !hasDirections,
      ));

      if (hasDirections) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openDirections(
                contest.latitude!,
                contest.longitude!,
                contest.venue ?? '',
              ),
              icon: const Icon(Icons.directions, size: 18),
              label: const Text('길찾기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ));
      }
    }

    return widgets;
  }

  /// 안내 항목 의미 키 → 아이콘.
  /// 서버가 Flutter 아이콘 코드를 보내면 서버가 앱에 묶이므로 매핑은 앱이 갖는다.
  /// 모르는 키(=서버에 새로 추가된 항목)는 기본 아이콘으로 그려지므로 앱 수정 없이 표시된다.
  IconData _infoRowIcon(String key) {
    switch (key) {
      case 'organizer':
        return Icons.business_outlined;
      case 'sponsor':
        return Icons.handshake_outlined;
      case 'cooperation':
        return Icons.groups_outlined;
      case 'financialSupport':
        return Icons.account_balance_outlined;
      case 'eligibility':
        return Icons.verified_user_outlined;
      case 'participationFee':
        return Icons.payments_outlined;
      case 'schedule':
        return Icons.calendar_today_outlined;
      case 'venue':
        return Icons.location_on_outlined;
      case 'registrationPeriod':
        return Icons.event_available_outlined;
      case 'contactInfo':
        return Icons.phone_outlined;
      case 'additionalInfo':
        return Icons.info_outline;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: AppColors.divider),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight:
                        valueColor != null ? FontWeight.w600 : FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 홈페이지 안내 이미지 섹션 (부문/상금/지도/대진표/결과 등)
  Widget _buildHomepageImagesSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _homepageImages.map(_buildHomepageImageItem).toList(),
      ),
    );
  }

  Widget _buildHomepageImageItem(HomepageImage image) {
    final isAlways = image.displayMode == 'always';
    final isExpanded = isAlways || _expandedImageIds.contains(image.id);
    final title = (image.title == null || image.title!.isEmpty) ? '안내' : image.title!;

    final header = isAlways
        ? Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          )
        : InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedImageIds.remove(image.id);
                } else {
                  _expandedImageIds.add(image.id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isExpanded ? '클릭하여 접기' : '클릭하여 펼치기',
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          if (isExpanded) ...[
            if (image.description != null && image.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  image.description!,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _buildImageFullUrl(image.imageUrl),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: AppColors.background,
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image, color: AppColors.textTertiary),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 120,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGameMethodsSection(ContestDetail contest) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '대국 진행 방식',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...contest.gameMethods.map((method) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 7),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (method.gameType != null)
                            Text(
                              method.gameType!,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          if (method.description != null)
                            Text(
                              method.description!,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          if (method.thinkingTime != null)
                            Text(
                              '제한시간: ${method.thinkingTime}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildApplyButton(ContestDetail contest) {
    final isAvailable = contest.registrationAvailable;
    final status = contest.registrationStatus;

    String buttonText;
    Color backgroundColor;
    Color textColor;

    if (isAvailable) {
      buttonText = '참가신청하기';
      backgroundColor = AppColors.primary;
      textColor = AppColors.textOnPrimary;
    } else {
      switch (status) {
        case 'UPCOMING':
          buttonText = '접수 예정';
          break;
        case 'ENDED':
          buttonText = '접수 마감';
          break;
        case 'CLOSED':
          buttonText = '접수 마감';
          break;
        default:
          buttonText = '신청 불가';
      }
      backgroundColor = AppColors.surfaceVariant;
      textColor = AppColors.textSecondary;
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isAvailable ? () => _navigateToRegistration(contest) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          disabledBackgroundColor: AppColors.surfaceVariant,
          disabledForegroundColor: AppColors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Text(
          buttonText,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _navigateToRegistration(ContestDetail contest) async {
    final result = await context.push(
      '/contest/${widget.contestId}/register',
      extra: contest,
    );
    // 참가신청 성공 후 돌아오면 대회 상세 새로고침
    if (result == true) {
      ref.invalidate(contestDetailProvider(widget.contestId));
    }
  }

  /// 부문 탭
  Widget _buildCategoryTab(ContestDetail contest) {
    if (contest.categories.isEmpty) {
      return _buildEmptyState(
        icon: Icons.category_outlined,
        message: '등록된 부문이 없습니다',
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: contest.categories.length,
            itemBuilder: (context, index) {
        final category = contest.categories[index];
        final isSelected = _selectedCategoryId == category.id;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedCategoryId = category.id;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 선택 표시
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      border: Border.all(
                        color:
                            isSelected ? AppColors.primary : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  // 부문 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (category.groupName != null && category.groupName!.isNotEmpty)
                                    Text(
                                      category.groupName!.replaceAll(RegExp(r'\s+'), ' ').trim(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  Text(
                                    category.categoryName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 대회 유형 태그
                            if (category.contestType != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _getContestTypeLabel(category.contestType!),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // 참가 자격 — 멀티라인 긴 텍스트라 풀폭으로 표시 (칩에 넣으면 오버플로우)
                        if (category.skillRequirement != null &&
                            category.skillRequirement!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.grade_outlined,
                                  size: 14, color: AppColors.textTertiary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  category.skillRequirement!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        // 세부 정보 (시간/잔여석 등 짧은 칩만)
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            if (category.gameTime != null)
                              _buildCategoryChip(
                                Icons.timer_outlined,
                                category.gameTime!,
                              ),
                            if (category.maxParticipants != null && category.currentParticipants != null) ...[
                              Builder(builder: (_) {
                                final remaining = category.maxParticipants! - category.currentParticipants!;
                                if (remaining <= 5 && remaining > 0) {
                                  return _buildCategoryChip(
                                    Icons.warning_amber,
                                    '잔여 $remaining석',
                                    color: AppColors.error,
                                  );
                                } else if (remaining <= 0) {
                                  return _buildCategoryChip(
                                    Icons.block,
                                    '마감',
                                    color: AppColors.textTertiary,
                                  );
                                } else {
                                  return _buildCategoryChip(
                                    Icons.people_outline,
                                    category.participantsDisplayText ?? '${category.currentParticipants}/${category.maxParticipants}명',
                                  );
                                }
                              }),
                            ] else if (category.participantsDisplayText != null) ...[
                              _buildCategoryChip(
                                Icons.people_outline,
                                category.participantsDisplayText!,
                              ),
                            ],
                          ],
                        ),
                        if (category.note != null &&
                            category.note!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            category.note!,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
          ),
        ),
        // 참가신청 버튼 + 문의 버튼
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Row(
            children: [
              // 주최자 채팅 - 일단 비활성
              // if (contest.hasChatManager)
              //   Padding(
              //     padding: const EdgeInsets.only(right: 10),
              //     child: SizedBox(
              //       width: 56,
              //       height: 56,
              //       child: OutlinedButton(
              //         onPressed: () => _openChatWithHost(contest),
              //         style: OutlinedButton.styleFrom(
              //           padding: EdgeInsets.zero,
              //           side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
              //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              //         ),
              //         child: Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 22),
              //       ),
              //     ),
              //   ),
              Expanded(child: _buildApplyButton(contest)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: color ?? AppColors.textSecondary,
            fontWeight: color != null ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }

  String _getContestTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'mcmahon':
        return '맥마흔';
      case 'fullleague':
        return '풀리그';
      case 'tournament':
        return '토너먼트';
      case 'swiss':
        return '스위스리그';
      default:
        return type;
    }
  }

  /// 상금 탭 (테이블 형식)
  Widget _buildPrizeTab(ContestDetail contest) {
    if (contest.prizes.isEmpty) {
      return _buildEmptyState(
        icon: Icons.emoji_events_outlined,
        message: '등록된 상금 정보가 없습니다',
      );
    }

    // 그룹별로 상금 분류
    final prizeGroups = <String, List<ContestPrize>>{};
    for (final prize in contest.prizes) {
      final group = prize.groupName ?? '기타';
      prizeGroups.putIfAbsent(group, () => []).add(prize);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: prizeGroups.length,
      itemBuilder: (context, index) {
        final groupName = prizeGroups.keys.elementAt(index);
        final groupPrizes = prizeGroups[groupName]!;

        // isFullRow인 상금과 일반 상금 분리 (웹과 동일)
        final spanningPrizes = groupPrizes.where((p) => p.isFullRow).toList();
        final normalPrizes = groupPrizes.where((p) => !p.isFullRow).toList();

        // 일반 상금에서 prizeTitle 목록 추출 (중복 제거, 순서 유지)
        final prizeTitles = <String>[];
        for (final prize in normalPrizes) {
          if (prize.prizeTitle != null &&
              !prizeTitles.contains(prize.prizeTitle)) {
            prizeTitles.add(prize.prizeTitle!);
          }
        }

        // 일반 상금에서 rankName 목록 추출 (중복 제거, 순서 유지)
        final rankNames = <String>[];
        for (final prize in normalPrizes) {
          if (prize.rankName != null && !rankNames.contains(prize.rankName)) {
            rankNames.add(prize.rankName!);
          }
        }

        // prizeTitle별 rankName -> prizeContent 매핑
        final prizeData = <String, Map<String, String>>{};
        // prizeTitle별 remarks (비고)
        final prizeRemarks = <String, String>{};
        for (final title in prizeTitles) {
          prizeData[title] = {};
          for (final prize in normalPrizes) {
            if (prize.prizeTitle == title && prize.rankName != null) {
              prizeData[title]![prize.rankName!] = prize.prizeContent ?? '-';
            }
            // 같은 prizeTitle 안에서 remarks가 있는 첫 행 사용
            if (prize.prizeTitle == title
                && prize.remarks != null
                && prize.remarks!.trim().isNotEmpty
                && !prizeRemarks.containsKey(title)) {
              prizeRemarks[title] = prize.remarks!;
            }
          }
        }
        // 한 부문이라도 remarks 있으면 비고 컬럼 표시
        final hasRemarks = prizeRemarks.isNotEmpty;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 그룹 헤더
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                color: AppColors.primary,
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      groupName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // 일반 상금 테이블
              if (normalPrizes.isNotEmpty)
                _buildPrizeTableWithFixedColumn(prizeTitles, rankNames, prizeData, prizeRemarks, hasRemarks),
              // isFullRow 상금: 전체 너비로 표시 (웹의 colspan과 동일)
              ...spanningPrizes.map((prize) => Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    if (prize.prizeTitle != null) ...[
                      Text(
                        prize.prizeTitle!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        prize.prizeContent ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  /// 상금 테이블: 전체 가로 스크롤
  Widget _buildPrizeTableWithFixedColumn(
    List<String> prizeTitles,
    List<String> rankNames,
    Map<String, Map<String, String>> prizeData,
    Map<String, String> prizeRemarks,
    bool hasRemarks,
  ) {
    final allColumns = ['시상 내역', ...rankNames, if (hasRemarks) '비고'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder(
          horizontalInside: BorderSide(color: AppColors.divider),
          bottom: BorderSide(color: AppColors.divider),
        ),
        children: [
          // 헤더 행
          TableRow(
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
            ),
            children: allColumns.map((col) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                col,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                textAlign: col == '시상 내역' ? TextAlign.left : TextAlign.center,
              ),
            )).toList(),
          ),
          // 데이터 행
          ...prizeTitles.asMap().entries.map((entry) {
            final idx = entry.key;
            final title = entry.value;
            return TableRow(
              decoration: BoxDecoration(
                color: idx % 2 == 0 ? AppColors.surface : AppColors.surfaceVariant,
              ),
              children: [
                // 시상 내역 컬럼
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                // 순위별 상금 컬럼
                ...rankNames.map((rank) {
                  final content = prizeData[title]?[rank] ?? '-';
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text(
                      content,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }),
                // 비고 컬럼
                if (hasRemarks)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text(
                      prizeRemarks[title] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// 결과 탭
  Widget _buildResultsTab(ContestDetail contest) {
    final rankingsAsync = ref.watch(homepageRankingsProvider(widget.contestId));

    return rankingsAsync.when(
      data: (sortRankings) {
        if (sortRankings.isEmpty) {
          return _buildEmptyResultsState();
        }
        return _buildRankingsContent(sortRankings);
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (error, _) => _buildEmptyResultsState(),
    );
  }

  Widget _buildEmptyResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '대회 결과가 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '대회가 종료된 후 결과가 공개됩니다',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// gameRoomType이 영문 enum(DE/SWISS/...) 또는 레거시 한글("더블엘리미네이션" 등)로
  /// 혼재되어 오므로, 라이브 위젯이 기대하는 영문 enum으로 정규화한다.
  String _normalizeContestType(String? raw) {
    final t = (raw ?? '').trim();
    final u = t.toUpperCase();
    const known = {
      'DE',
      'TOURNAMENT',
      'MCM',
      'SWISS',
      'FULL_LEAGUE',
      'TEAM_SWISS',
      'TEAM_FULL_LEAGUE',
    };
    if (known.contains(u)) return u;
    // 레거시 한글 표시명 → enum (부분일치, 순서 중요)
    if (t.contains('더블')) return 'DE';
    if (t.contains('토너먼트') || t.contains('싱글')) return 'TOURNAMENT';
    if (t.contains('맥마흔')) return 'MCM';
    final isTeam = t.contains('단체');
    final isFull = t.contains('풀');
    if (isTeam && isFull) return 'TEAM_FULL_LEAGUE';
    if (isTeam) return 'TEAM_SWISS';
    if (isFull) return 'FULL_LEAGUE';
    if (t.contains('스위스')) return 'SWISS';
    return u; // 알 수 없으면 원본(대문자)
  }

  Widget _buildRankingsContent(List<SortRankings> sortRankings) {
    if (_selectedSortIndex >= sortRankings.length) _selectedSortIndex = 0;
    final currentSort = sortRankings[_selectedSortIndex];
    // gameRoomType은 영문 enum('DE') 또는 레거시 한글('더블엘리미네이션')로 혼재되어 오므로 정규화
    final type = _normalizeContestType(currentSort.gameRoomType);
    final isDE = type == 'DE' || type == 'TOURNAMENT';
    final cid = currentSort.contestId;
    final sid = currentSort.sortId;

    return Column(
      children: [
        // 부문 선택 칩
        if (sortRankings.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.divider),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: sortRankings.asMap().entries.map((entry) {
                  final index = entry.key;
                  final sort = entry.value;
                  final isSelected = _selectedSortIndex == index;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(sort.sortName),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedSortIndex = index);
                        }
                      },
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceVariant,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        // 라이브 순위/대진 (부문 단위 임베드 — DE는 예선/본선, 그 외는 순위표/대진표 탭)
        Expanded(
          child: (cid == null || sid == null)
              ? _buildEmptyResultsState()
              : isDE
                  ? LiveDEContent(
                      key: ValueKey('de-$cid-$sid'),
                      contestId: cid,
                      sortId: sid,
                    )
                  : LiveSortContent(
                      key: ValueKey('sort-$cid-$sid'),
                      contestId: cid,
                      sortId: sid,
                      contestType: type,
                      autoRefresh: false,
                    ),
        ),
      ],
    );
  }
}

/// 탭바 Delegate (커스텀 Wrap 칩 탭 지원)
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _SliverTabBarDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.surface,
      height: height,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

/// 히어로 이미지용 바둑판 패턴
class _BadukBoardHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const gridCount = 19;
    final cellWidth = size.width / gridCount;
    final cellHeight = size.height / gridCount;

    // 가로선
    for (int i = 0; i <= gridCount; i++) {
      canvas.drawLine(
        Offset(0, i * cellHeight),
        Offset(size.width, i * cellHeight),
        paint,
      );
    }

    // 세로선
    for (int i = 0; i <= gridCount; i++) {
      canvas.drawLine(
        Offset(i * cellWidth, 0),
        Offset(i * cellWidth, size.height),
        paint,
      );
    }

    // 화점 (Star points)
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final starPoints = [
      Offset(4 * cellWidth, 4 * cellHeight),
      Offset(4 * cellWidth, 10 * cellHeight),
      Offset(4 * cellWidth, 16 * cellHeight),
      Offset(10 * cellWidth, 4 * cellHeight),
      Offset(10 * cellWidth, 10 * cellHeight), // 천원
      Offset(10 * cellWidth, 16 * cellHeight),
      Offset(16 * cellWidth, 4 * cellHeight),
      Offset(16 * cellWidth, 10 * cellHeight),
      Offset(16 * cellWidth, 16 * cellHeight),
    ];

    for (final point in starPoints) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
