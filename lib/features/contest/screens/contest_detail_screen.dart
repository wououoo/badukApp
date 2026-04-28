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
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/contest_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../widgets/contest_status_badge.dart';
import '../widgets/contest_photos_tab.dart';
import '../widgets/refund_policy_section.dart';

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
  bool _mcMahonSortByScore = true; // 맥마흔 정렬: true=점수순, false=승수순
  int _pairingSortIndex = 0; // 대진표 탭에서 선택된 부문 인덱스
  int _selectedRound = 1; // 대진표 탭에서 선택된 라운드

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
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
          _buildPairingsTab(contest),
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
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: '정보'),
            Tab(text: '부문'),
            Tab(text: '상금'),
            Tab(text: '지도'),
            Tab(text: '대진표'),
            Tab(text: '결과'),
            Tab(text: '사진'),
          ],
        ),
      ),
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
          // 일정
          if (contest.schedule != null && contest.schedule!.isNotEmpty)
            _buildInfoItem(
              icon: Icons.calendar_today_outlined,
              label: '대회일정',
              value: contest.schedule!,
            ),
          // 장소
          if (contest.venue != null && contest.venue!.isNotEmpty)
            _buildInfoItem(
              icon: Icons.location_on_outlined,
              label: '장소',
              value: contest.venue!,
            ),
          // 길찾기 버튼
          if (contest.latitude != null && contest.longitude != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openDirections(
                    contest.latitude!, contest.longitude!, contest.venue ?? '',
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
            ),
          // 주최/주관
          if (contest.organizer != null && contest.organizer!.isNotEmpty)
            _buildInfoItem(
              icon: Icons.business_outlined,
              label: '주최/주관',
              value: contest.organizer!,
            ),
          // 후원
          if (contest.sponsor != null && contest.sponsor!.isNotEmpty)
            _buildInfoItem(
              icon: Icons.handshake_outlined,
              label: '후원',
              value: contest.sponsor!,
            ),
          // 접수기간
          if (contest.registrationPeriod != null &&
              contest.registrationPeriod!.isNotEmpty)
            _buildInfoItem(
              icon: Icons.event_available_outlined,
              label: '접수기간',
              value: contest.registrationPeriod!,
            ),
          // 참가비
          if (contest.participationFee != null &&
              contest.participationFee!.isNotEmpty)
            _buildInfoItem(
              icon: Icons.payments_outlined,
              label: '참가비',
              value: contest.participationFee!,
              valueColor: AppColors.primary,
            ),
          // 참가자격
          if (contest.eligibility != null && contest.eligibility!.isNotEmpty)
            _buildInfoItem(
              icon: Icons.verified_user_outlined,
              label: '참가자격',
              value: contest.eligibility!,
            ),
          // 문의처
          if (contest.contactInfo != null && contest.contactInfo!.isNotEmpty)
            _buildInfoItem(
              icon: Icons.phone_outlined,
              label: '문의처',
              value: contest.contactInfo!,
              isLast: !contest.hasChatManager,
            ),
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
                              child: Text(
                                category.categoryName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
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
                        const SizedBox(height: 6),
                        // 세부 정보
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            if (category.skillRequirement != null)
                              _buildCategoryChip(
                                Icons.grade_outlined,
                                category.skillRequirement!,
                              ),
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
        for (final title in prizeTitles) {
          prizeData[title] = {};
          for (final prize in normalPrizes) {
            if (prize.prizeTitle == title && prize.rankName != null) {
              prizeData[title]![prize.rankName!] = prize.prizeContent ?? '-';
            }
          }
        }

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
                _buildPrizeTableWithFixedColumn(prizeTitles, rankNames, prizeData),
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
  ) {
    final allColumns = ['시상 내역', ...rankNames];

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
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String text, {bool isFirst = false}) {
    return Container(
      constraints: BoxConstraints(
        minWidth: isFirst ? 100 : 80,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        textAlign: isFirst ? TextAlign.left : TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isTitle = false, bool isPrize = false}) {
    return Container(
      constraints: BoxConstraints(
        minWidth: isTitle ? 100 : 80,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isTitle || isPrize ? FontWeight.w600 : FontWeight.normal,
          color: isPrize ? AppColors.primary : AppColors.textPrimary,
        ),
        textAlign: isTitle ? TextAlign.left : TextAlign.center,
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

  Widget _buildRankingsContent(List<SortRankings> sortRankings) {
    final currentSort = sortRankings[_selectedSortIndex];
    final isMcMahon = currentSort.gameRoomType == 'MCM';

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
        // 맥마흔 정렬 옵션
        if (isMcMahon)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '정렬: ',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('점수순'),
                  selected: _mcMahonSortByScore,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _mcMahonSortByScore = true);
                    }
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceVariant,
                  labelStyle: TextStyle(
                    color: _mcMahonSortByScore ? Colors.white : AppColors.textPrimary,
                    fontWeight: _mcMahonSortByScore ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('승수순'),
                  selected: !_mcMahonSortByScore,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _mcMahonSortByScore = false);
                    }
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceVariant,
                  labelStyle: TextStyle(
                    color: !_mcMahonSortByScore ? Colors.white : AppColors.textPrimary,
                    fontWeight: !_mcMahonSortByScore ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        // 순위표
        Expanded(
          child: _buildRankingsList(currentSort),
        ),
      ],
    );
  }

  Widget _buildRankingsList(SortRankings sortRankings) {
    if (sortRankings.rankings.isEmpty) {
      return _buildEmptyResultsState();
    }

    final gameRoomType = sortRankings.gameRoomType;
    final isMcMahon = gameRoomType == 'MCM';

    // 맥마흔인 경우 정렬 옵션에 따라 재정렬 및 순위 재계산
    List<RankingEntry> displayRankings;
    if (isMcMahon) {
      final sortedRankings = List<RankingEntry>.from(sortRankings.rankings);
      if (_mcMahonSortByScore) {
        // 점수순: totalPoints 내림차순 > totalWins 내림차순
        sortedRankings.sort((a, b) {
          final scoreA = a.totalPoints ?? 0;
          final scoreB = b.totalPoints ?? 0;
          if (scoreA != scoreB) return scoreB.compareTo(scoreA);
          return b.totalWins.compareTo(a.totalWins);
        });
      } else {
        // 승수순: totalWins 내림차순 > totalPoints 내림차순
        sortedRankings.sort((a, b) {
          if (a.totalWins != b.totalWins) return b.totalWins.compareTo(a.totalWins);
          final scoreA = a.totalPoints ?? 0;
          final scoreB = b.totalPoints ?? 0;
          return scoreB.compareTo(scoreA);
        });
      }
      // 순위 재계산 (새 RankingEntry 생성)
      displayRankings = sortedRankings.asMap().entries.map((entry) {
        final newRank = entry.key + 1;
        final original = entry.value;
        return RankingEntry(
          rank: newRank,
          participantName: original.participantName,
          participantNumber: original.participantNumber,
          totalWins: original.totalWins,
          sos: original.sos,
          sosos: original.sosos,
          totalPoints: original.totalPoints,
        );
      }).toList();
    } else {
      displayRankings = sortRankings.rankings;
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: displayRankings.length,
      itemBuilder: (context, index) {
        final ranking = displayRankings[index];
        return _buildRankingCard(ranking, gameRoomType);
      },
    );
  }

  Widget _buildRankingCard(RankingEntry ranking, String? gameRoomType) {
    final isTopThree = ranking.rank <= 3;
    final medalIcon = _getMedalIcon(ranking.rank);
    final medalColor = _getMedalColor(ranking.rank);
    // 맥마흔: 'MCM' (백엔드에서 하드코딩)
    final isMcMahon = gameRoomType == 'MCM';
    // 스위스리그: '스위스리그', '단체전스위스리그', 또는 null (기본값)
    final isSwiss = gameRoomType == null ||
                    gameRoomType == '스위스리그' ||
                    gameRoomType == '단체전스위스리그' ||
                    gameRoomType == 'SWISS';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: isTopThree
            ? Border.all(color: medalColor.withOpacity(0.5), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // 순위
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isTopThree
                    ? medalColor.withOpacity(0.15)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: isTopThree
                    ? Text(
                        medalIcon,
                        style: const TextStyle(fontSize: 22),
                      )
                    : Text(
                        '${ranking.rank}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            // 이름
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ranking.participantName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isTopThree ? FontWeight.w700 : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildStatChip('${ranking.totalWins}승'),
                      // 맥마흔: 맥마흔 점수 표시, SOS/SOSOS 안 보임
                      if (isMcMahon && ranking.totalPoints != null)
                        _buildStatChip('${ranking.totalPoints!.toInt()}점'),
                      // 스위스리그: SOS/SOSOS 표시
                      if (isSwiss && ranking.sos != null)
                        _buildStatChip('SOS ${ranking.sos!.toStringAsFixed(1)}'),
                      if (isSwiss && ranking.sosos != null)
                        _buildStatChip('SOSOS ${ranking.sosos!.toStringAsFixed(1)}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  /// 대진표 탭
  Widget _buildPairingsTab(ContestDetail contest) {
    final rankingsAsync = ref.watch(homepageRankingsProvider(widget.contestId));

    return rankingsAsync.when(
      data: (sortRankings) {
        if (sortRankings.isEmpty) {
          return _buildEmptyState(
            icon: Icons.grid_view_outlined,
            message: '대진표 데이터가 없습니다',
          );
        }
        return _buildPairingsContent(sortRankings);
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (error, _) => _buildEmptyState(
        icon: Icons.grid_view_outlined,
        message: '대진표를 불러올 수 없습니다',
      ),
    );
  }

  Widget _buildPairingsContent(List<SortRankings> sortRankings) {
    if (_pairingSortIndex >= sortRankings.length) {
      _pairingSortIndex = 0;
    }
    final currentSort = sortRankings[_pairingSortIndex];
    final contestId = currentSort.contestId;
    final sortId = currentSort.sortId;

    if (contestId == null || sortId == null) {
      return _buildEmptyState(
        icon: Icons.grid_view_outlined,
        message: '대진표 데이터가 없습니다',
      );
    }

    final pairingsAsync = ref.watch(
      pairingsProvider((contestId: contestId, sortId: sortId)),
    );

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
                  final isSelected = _pairingSortIndex == index;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(sort.sortName),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _pairingSortIndex = index;
                            _selectedRound = 1;
                          });
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
        // 대진표 내용
        Expanded(
          child: pairingsAsync.when(
            data: (response) => _buildPairingsData(response),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (error, _) => _buildEmptyState(
              icon: Icons.grid_view_outlined,
              message: '대진표를 불러올 수 없습니다',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPairingsData(PairingsResponse response) {
    if (response.pairings.isEmpty) {
      return _buildEmptyState(
        icon: Icons.grid_view_outlined,
        message: '아직 대진표가 생성되지 않았습니다',
      );
    }

    final maxRound = response.maxRound;
    if (_selectedRound > maxRound) {
      _selectedRound = maxRound > 0 ? maxRound : 1;
    }

    // 선택된 라운드의 대진 필터링
    final roundPairings = response.pairings.where((p) {
      final round = p['round'] ?? p['roundNumber'];
      return round == _selectedRound;
    }).toList();

    return Column(
      children: [
        // 라운드 선택
        if (maxRound > 0)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
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
                children: List.generate(maxRound, (index) {
                  final round = index + 1;
                  final isSelected = _selectedRound == round;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('$round라운드'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedRound = round);
                        }
                      },
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceVariant,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 13,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
              ),
            ),
          ),
        // 대진 목록
        Expanded(
          child: roundPairings.isEmpty
              ? _buildEmptyState(
                  icon: Icons.grid_view_outlined,
                  message: '$_selectedRound라운드 대진표가 없습니다',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: roundPairings.length,
                  itemBuilder: (context, index) {
                    return _buildPairingCard(roundPairings[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPairingCard(Map<String, dynamic> pairing) {
    // 맥마흔: player1Name/player2Name, 스위스리그: player1/player2
    // 단체전풀리그: team1Name/team2Name
    final player1 = pairing['player1Name'] ?? pairing['player1'] ?? pairing['team1Name'] ?? '?';
    final player2 = pairing['player2Name'] ?? pairing['player2'] ?? pairing['team2Name'] ?? '';
    final player1Id = pairing['player1Id'] ?? pairing['team1Id'];
    final player2Id = pairing['player2Id'] ?? pairing['team2Id'];
    final tableNumber = pairing['tableNumber'] ?? pairing['matchNumber'] ?? pairing['player1Number'];
    final isBye = pairing['isByeMatch'] == true ||
        pairing['bye'] == true ||
        pairing['none'] == true ||
        player2.toString().isEmpty ||
        player1.toString() == '부전승' || player2.toString() == '부전승';
    // 맥마흔: winnerId로 판단, 스위스리그: end + winner(이름)로 판단
    // 단체전풀리그: winnerTeamId로 판단
    final winnerId = pairing['winnerId'] ?? pairing['winnerTeamId'];
    final winnerName = pairing['winnerName'] ?? pairing['winner'];
    final isCompleted = pairing['isCompleted'] == true ||
        pairing['end'] == true ||
        winnerId != null;

    // 승자 판별: ID 기반(맥마흔/단체전풀리그) 또는 이름 기반(스위스리그)
    bool player1Won = false;
    bool player2Won = false;
    if (winnerId != null) {
      player1Won = winnerId == player1Id;
      player2Won = winnerId == player2Id;
    } else if (winnerName != null && isCompleted && !isBye) {
      player1Won = winnerName == player1.toString();
      player2Won = winnerName == player2.toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // 테이블 번호
            if (tableNumber != null)
              Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$tableNumber',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            // 선수1
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (player1Won)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('승', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                        ),
                      Flexible(
                        child: Text(
                          '$player1',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: player1Won ? FontWeight.w700 : FontWeight.w500,
                            color: player1Won ? AppColors.textPrimary : AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // VS
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                isBye ? 'BYE' : 'VS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isBye
                      ? AppColors.textTertiary
                      : isCompleted
                          ? AppColors.primary
                          : AppColors.textSecondary,
                ),
              ),
            ),
            // 선수2
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isBye ? '부전승' : '$player2',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: player2Won ? FontWeight.w700 : FontWeight.w500,
                            color: isBye ? AppColors.textTertiary : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (player2Won)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('승', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMedalIcon(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  Color _getMedalColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppColors.textTertiary;
    }
  }
}

/// 탭바 Delegate
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
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
