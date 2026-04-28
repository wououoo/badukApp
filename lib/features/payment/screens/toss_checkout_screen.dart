import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/payment.dart';
import '../../../data/providers/payment_provider.dart';

/// 토스페이먼츠 결제 WebView 화면
/// - 백엔드에서 제공하는 체크아웃 HTML 페이지를 로드
/// - 결제 성공/실패 URL을 인터셉트하여 처리
class TossCheckoutScreen extends ConsumerStatefulWidget {
  final String orderId;
  final int amount;
  final String orderName;
  final int? registrationId;

  const TossCheckoutScreen({
    super.key,
    required this.orderId,
    required this.amount,
    required this.orderName,
    this.registrationId,
  });

  @override
  ConsumerState<TossCheckoutScreen> createState() => _TossCheckoutScreenState();
}

class _TossCheckoutScreenState extends ConsumerState<TossCheckoutScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isConfirming = false;
  Timer? _loadTimeoutTimer;
  int _retryCount = 0;
  static const int _maxRetries = 2;
  static const Duration _loadTimeout = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Web: 같은 탭에서 백엔드 체크아웃 페이지로 이동
      // 백엔드가 confirm 처리 후 returnUrl로 다시 리다이렉트
      WidgetsBinding.instance.addPostFrameCallback((_) => _launchWebCheckout());
    } else {
      // initState 즉시 호출 시 WebView가 위젯 트리에 attach 되기 전에
      // loadRequest가 호출되어 stuck 되는 케이스가 있어 post frame으로 지연
      WidgetsBinding.instance.addPostFrameCallback((_) => _initWebView());
    }
  }

  @override
  void dispose() {
    _loadTimeoutTimer?.cancel();
    super.dispose();
  }

  /// 페이지 로딩 stuck 감지 → 자동 재시도
  void _scheduleLoadTimeout() {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(_loadTimeout, () {
      if (!mounted) return;
      if (!_isLoading) return; // 이미 로드 완료
      if (_retryCount >= _maxRetries) {
        debugPrint('[TossCheckout] 최대 재시도 횟수 초과, 에러 표시');
        _showError('결제 페이지 로딩이 지연됩니다. 네트워크 상태를 확인해주세요.');
        return;
      }
      _retryCount++;
      debugPrint('[TossCheckout] 로딩 타임아웃, 재시도 ($_retryCount/$_maxRetries)');
      _controller?.reload();
      _scheduleLoadTimeout();
    });
  }

  Future<void> _launchWebCheckout() async {
    final serverUrl = ApiConstants.baseUrl.replaceAll('/api', '');
    // Flutter 웹앱의 결과 페이지 URL (현재 origin 기준)
    final returnUrl = '${Uri.base.origin}/#/payment/result';

    final checkoutUrl = '$serverUrl/api/payment/toss/checkout'
        '?orderId=${Uri.encodeComponent(widget.orderId)}'
        '&amount=${widget.amount}'
        '&orderName=${Uri.encodeComponent(widget.orderName)}'
        '&returnUrl=${Uri.encodeComponent(returnUrl)}';

    final uri = Uri.parse(checkoutUrl);
    await launchUrl(
      uri,
      webOnlyWindowName: '_self',
    );
  }

  void _initWebView() {
    // 백엔드 URL에서 /api 제거하여 서버 루트 URL 구성
    final serverUrl = ApiConstants.baseUrl.replaceAll('/api', '');
    final checkoutUrl = '$serverUrl/api/payment/toss/checkout'
        '?orderId=${Uri.encodeComponent(widget.orderId)}'
        '&amount=${widget.amount}'
        '&orderName=${Uri.encodeComponent(widget.orderName)}';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
            // 로딩 시작 → 타임아웃 타이머 가동
            _scheduleLoadTimeout();
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
            // 로딩 완료 → 타임아웃 취소
            _loadTimeoutTimer?.cancel();
          },
          onWebResourceError: (error) {
            debugPrint('[TossCheckout] 리소스 에러: ${error.description}');
          },
          onNavigationRequest: (request) {
            return _handleNavigation(request.url);
          },
        ),
      )
      ..loadRequest(Uri.parse(checkoutUrl));
    _controller = controller;
    // 초기 로딩에도 타임아웃 적용
    _scheduleLoadTimeout();
  }

  NavigationDecision _handleNavigation(String url) {
    // 결제 성공 URL 인터셉트
    if (url.contains('/toss/success')) {
      final uri = Uri.parse(url);
      final paymentKey = uri.queryParameters['paymentKey'];
      final orderId = uri.queryParameters['orderId'];
      final amount = int.tryParse(uri.queryParameters['amount'] ?? '');

      if (paymentKey != null && orderId != null && amount != null) {
        _confirmPayment(paymentKey, orderId, amount);
      } else {
        _showError('결제 정보를 확인할 수 없습니다.');
      }
      return NavigationDecision.prevent;
    }

    // 결제 실패 URL 인터셉트
    if (url.contains('/toss/fail')) {
      final uri = Uri.parse(url);
      final message = uri.queryParameters['message'] ?? '결제가 취소되었습니다.';
      _showError(message);
      return NavigationDecision.prevent;
    }

    // 외부 앱 스킴 처리 (토스/카드사/인증 앱 등)
    // - intent://, supertoss://, ispmobile://, kakaotalk:// 등
    // - http/https/about/data 외의 모든 스킴은 외부 앱으로 launch
    if (url.startsWith('intent://') ||
        url.startsWith('supertoss://') ||
        url.startsWith('ispmobile://') ||
        url.startsWith('kftc-bankpay://') ||
        url.startsWith('lguthepay-xpay://') ||
        url.startsWith('kakaotalk://') ||
        url.startsWith('kb-acp://') ||
        url.startsWith('liivbank://') ||
        url.startsWith('newsmartpib://') ||
        url.startsWith('nhappcardansimclick://') ||
        url.startsWith('lottesmartpay://') ||
        url.startsWith('lotteappcard://') ||
        url.startsWith('mpocket.online.ansimclick://') ||
        url.startsWith('ansimclickscard://') ||
        url.startsWith('cloudpay://') ||
        url.startsWith('hanawalletmembers://') ||
        url.startsWith('shinhan-sr-ansimclick://') ||
        url.startsWith('smshinhanansimclick://') ||
        (!url.startsWith('http://') &&
            !url.startsWith('https://') &&
            !url.startsWith('about:') &&
            !url.startsWith('data:'))) {
      _launchExternalApp(url);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  /// 외부 앱 실행 (토스 앱, 카드사 앱, 인증 앱 등)
  /// - intent:// 의 경우 패키지를 추출해서 직접 launch 시도
  /// - 앱 미설치 시 Play 스토어 fallback (사용자가 설치 후 결제 진행 가능)
  Future<void> _launchExternalApp(String url) async {
    debugPrint('[TossCheckout] 외부 앱 실행 시도: $url');
    try {
      // intent:// 처리: 안드로이드 intent scheme 파싱
      if (url.startsWith('intent://')) {
        final packageMatch = RegExp(r'package=([^;]+)').firstMatch(url);
        final package = packageMatch?.group(1);

        // 1. intent URL을 그대로 launch 시도 (앱 설치되어 있으면 바로 열림)
        try {
          final intentUri = Uri.parse(url);
          if (await canLaunchUrl(intentUri)) {
            await launchUrl(intentUri, mode: LaunchMode.externalApplication);
            return;
          }
        } catch (_) {
          // intent:// 직접 launch 실패 시 다음 단계로
        }

        // 2. fallback URL이 있으면 그쪽으로 (보통 Play 스토어 또는 웹 페이지)
        final fallbackMatch =
            RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(url);
        if (fallbackMatch != null) {
          final fallbackUrl = Uri.decodeComponent(fallbackMatch.group(1)!);
          final fallbackUri = Uri.parse(fallbackUrl);
          if (await canLaunchUrl(fallbackUri)) {
            await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
            return;
          }
        }

        // 3. 패키지명으로 Play 스토어 fallback (앱 설치 유도)
        if (package != null) {
          final marketUri = Uri.parse('market://details?id=$package');
          if (await canLaunchUrl(marketUri)) {
            await launchUrl(marketUri, mode: LaunchMode.externalApplication);
          }
        }
        return;
      }

      // intent:// 가 아닌 일반 스킴 (supertoss://, kakaotalk:// 등)
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('[TossCheckout] 앱이 설치되지 않음: $url');
      }
    } catch (e) {
      debugPrint('[TossCheckout] 외부 앱 실행 실패: $e');
    }
  }

  Future<void> _confirmPayment(String paymentKey, String orderId, int amount) async {
    if (_isConfirming) return;

    setState(() => _isConfirming = true);

    try {
      final paymentNotifier = ref.read(paymentProvider.notifier);
      debugPrint('[TossCheckout] confirmPayment 호출 시작 - orderId=$orderId, amount=$amount');

      Payment? payment;
      String? confirmError;

      try {
        payment = await paymentNotifier.confirmPayment(
          paymentKey: paymentKey,
          orderId: orderId,
          amount: amount,
        );
        debugPrint('[TossCheckout] confirmPayment 응답 - payment=${payment?.paymentId}, status=${payment?.paymentStatus}');
      } catch (e) {
        confirmError = e.toString();
        debugPrint('[TossCheckout] confirmPayment 예외: $confirmError');
      }

      if (!mounted) return;

      // confirm 응답이 정상이면 즉시 성공 처리
      // - COMPLETED: 즉시결제 완료
      // - WAITING_FOR_DEPOSIT: 가상계좌 발급 완료 (입금 대기) — 우리 시스템 정책상 가상계좌만 사용하므로 일반적
      if (payment != null && (payment.isCompleted || payment.isWaitingForDeposit)) {
        debugPrint('[TossCheckout] 결제 처리 완료 - status=${payment.paymentStatus}');
        context.pop(true);
        return;
      }

      // confirm 실패/timeout이어도 백엔드는 처리됐을 수 있음
      // → orderId로 결제 상태 재조회 (최대 3회 polling)
      debugPrint('[TossCheckout] confirm 응답 불완전, 결제 상태 재조회 시작');
      Payment? recovered = await _pollPaymentStatusByOrderId(orderId);

      if (!mounted) return;

      if (recovered != null && (recovered.isCompleted || recovered.isWaitingForDeposit)) {
        debugPrint('[TossCheckout] 재조회로 결제 처리 확인 - status=${recovered.paymentStatus}');
        context.pop(true);
        return;
      }

      // 그래도 안 되면 에러
      _showError(confirmError ?? '결제 승인 중 오류가 발생했습니다.');
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }

  /// 결제 상태 재조회 (orderId 기반)
  /// confirm API 응답이 늦거나 실패해도 백엔드는 처리됐을 수 있으므로
  /// 직접 결제 상태를 조회해서 복구
  Future<Payment?> _pollPaymentStatusByOrderId(String orderId) async {
    final paymentNotifier = ref.read(paymentProvider.notifier);
    for (int i = 0; i < 3; i++) {
      try {
        await Future.delayed(Duration(milliseconds: 1000 * (i + 1)));
        final payment = await paymentNotifier.getPaymentByOrderId(orderId);
        debugPrint('[TossCheckout] poll #${i + 1}: status=${payment?.paymentStatus}');
        if (payment != null && (payment.isCompleted || payment.isWaitingForDeposit)) {
          return payment;
        }
      } catch (e) {
        debugPrint('[TossCheckout] poll #${i + 1} 실패: $e');
      }
    }
    return null;
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );

    // 에러 시 이전 화면으로 돌아감
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        context.pop(false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(false),
        ),
        title: Text(
          '결제하기',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          if (kIsWeb)
            // Web: WebView 사용 불가, 같은 탭에서 외부 페이지로 이동 중
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('결제 페이지로 이동 중...'),
                ],
              ),
            )
          else if (_controller != null)
            WebViewWidget(controller: _controller!),

          // 로딩 인디케이터
          if (!kIsWeb && (_isLoading || _isConfirming))
            Container(
              color: Colors.white.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isConfirming ? '결제 승인 중...' : '결제 화면 로딩 중...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
