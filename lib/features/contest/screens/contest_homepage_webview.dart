import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_constants.dart';

/// 대회 홈페이지 화면
/// - 웹: 새 탭으로 열기
/// - 모바일: WebView (별도 파일에서 처리)
class ContestHomepageWebView extends StatefulWidget {
  final int? homepageId;
  final String? externalUrl;
  final String title;

  const ContestHomepageWebView({
    super.key,
    this.homepageId,
    this.externalUrl,
    this.title = '대회 홈페이지',
  }) : assert(homepageId != null || externalUrl != null);

  @override
  State<ContestHomepageWebView> createState() => _ContestHomepageWebViewState();
}

class _ContestHomepageWebViewState extends State<ContestHomepageWebView> {
  String get _url {
    if (widget.externalUrl != null) {
      return widget.externalUrl!;
    }
    return '${ApiConstants.webUrl}/homepage/${widget.homepageId}';
  }

  @override
  void initState() {
    super.initState();
    // 웹/모바일 모두 새 탭으로 열기 (WebView는 모바일 앱 배포 시 별도 구현)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openUrl();
    });
  }

  void _openUrl() async {
    final uri = Uri.parse(_url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('홈페이지로 이동 중...'),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _openUrl,
              child: const Text('직접 열기'),
            ),
          ],
        ),
      ),
    );
  }
}
