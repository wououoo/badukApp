import 'package:flutter/material.dart';

/// 이미지 전체화면 확대 보기 — 배너·포스터 등 URL 하나만 있으면 어디서든 쓴다.
///
/// 핀치로 확대(최대 5배), 확대 상태에서 드래그로 이동, 우측 상단 ✕ 또는 뒤로가기로 닫는다.
/// 라우터(go_router)에 경로를 따로 등록하지 않고 Navigator 위에 바로 띄운다 —
/// 딥링크가 필요 없는 일회성 보기라 경로를 늘릴 이유가 없다.
Future<void> showFullImage(
  BuildContext context, {
  required String imageUrl,
  String? title,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, __, ___) => _FullImageViewer(imageUrl: imageUrl, title: title),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _FullImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? title;

  const _FullImageViewer({required this.imageUrl, this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 5.0,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
          // 상단: 제목 + 닫기
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: title == null
                        ? const SizedBox.shrink()
                        : Text(
                            title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    icon: const Icon(Icons.close, color: Colors.white, size: 26),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
          // 하단 안내
          const Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: SafeArea(
              child: Text(
                '두 손가락으로 확대할 수 있어요',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
