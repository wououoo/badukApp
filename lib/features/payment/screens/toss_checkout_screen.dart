import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/payment_provider.dart';

/// 토스페이먼츠 결제 WebView 화면
/// - 백엔드에서 제공하는 체크아웃 HTML 페이지를 로드
/// - 결제 성공/실패 URL을 인터셉트하여 처리
class TossCheckoutScreen extends ConsumerStatefulWidget {
  final String orderId;
  final int amount;
  final String orderName;
  final int registrationId;

  const TossCheckoutScreen({
    super.key,
    required this.orderId,
    required this.amount,
    required this.orderName,
    required this.registrationId,
  });

  @override
  ConsumerState<TossCheckoutScreen> createState() => _TossCheckoutScreenState();
}

class _TossCheckoutScreenState extends ConsumerState<TossCheckoutScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    // 백엔드 URL에서 /api 제거하여 서버 루트 URL 구성
    final serverUrl = ApiConstants.baseUrl.replaceAll('/api', '');
    final checkoutUrl = '$serverUrl/api/payment/toss/checkout'
        '?orderId=${Uri.encodeComponent(widget.orderId)}'
        '&amount=${widget.amount}'
        '&orderName=${Uri.encodeComponent(widget.orderName)}';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onNavigationRequest: (request) {
            return _handleNavigation(request.url);
          },
        ),
      )
      ..loadRequest(Uri.parse(checkoutUrl));
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

    // 외부 앱 스킴 처리 (카드사 앱, 인증 앱 등)
    if (url.startsWith('intent://') ||
        url.startsWith('market://') ||
        url.startsWith('ispmobile://') ||
        url.startsWith('kftc-bankpay://') ||
        url.startsWith('lguthepay-xpay://') ||
        url.startsWith('supertoss://') ||
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
        (!url.startsWith('http://') && !url.startsWith('https://') && !url.startsWith('about:') && !url.startsWith('data:'))) {
      _launchExternalApp(url);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  /// 외부 앱 실행 (카드사 앱, 인증 앱 등)
  Future<void> _launchExternalApp(String url) async {
    try {
      Uri uri;
      if (url.startsWith('intent://')) {
        // intent:// → 패키지명 추출 후 마켓으로 fallback
        final packageMatch = RegExp(r'package=([^;]+)').firstMatch(url);
        final package = packageMatch?.group(1);

        // intent scheme을 https로 변환 시도
        final fallbackMatch = RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(url);
        if (fallbackMatch != null) {
          uri = Uri.parse(Uri.decodeComponent(fallbackMatch.group(1)!));
        } else if (package != null) {
          uri = Uri.parse('market://details?id=$package');
        } else {
          return;
        }
      } else {
        uri = Uri.parse(url);
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
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
      final payment = await paymentNotifier.confirmPayment(
        paymentKey: paymentKey,
        orderId: orderId,
        amount: amount,
      );

      if (!mounted) return;

      if (payment != null) {
        // 결제 성공 → true 반환하여 이전 화면에서 성공 처리
        context.pop(true);
      } else {
        _showError('결제 승인 중 오류가 발생했습니다.');
      }
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
          WebViewWidget(controller: _controller),

          // 로딩 인디케이터
          if (_isLoading || _isConfirming)
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
