import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/mobile_qr_provider.dart';

/// QR 스캔 화면
class QRScannerScreen extends ConsumerStatefulWidget {
  const QRScannerScreen({super.key});

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> {
  MobileScannerController? _cameraController;
  bool _isProcessing = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _cameraController = MobileScannerController();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('QR 스캔'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'QR 스캔은 모바일 앱에서만\n사용할 수 있습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final cameraController = _cameraController!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('QR 스캔'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_off, color: Colors.white),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 카메라 뷰
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),

          // 스캔 가이드 오버레이
          _buildScanOverlay(),

          // 하단 안내 텍스트
          Positioned(
            left: 0,
            right: 0,
            bottom: 100,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  '대회 QR 코드를 스캔하세요',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),

          // 참가 정보 확인 중 로딩 오버레이
          if (_isSearching)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      '참가 정보 확인 중...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
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

  Widget _buildScanOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanAreaSize = constraints.maxWidth * 0.7;
        final left = (constraints.maxWidth - scanAreaSize) / 2;
        final top = (constraints.maxHeight - scanAreaSize) / 2 - 50;

        return Stack(
          children: [
            // 어두운 오버레이
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.5),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Positioned(
                    left: left,
                    top: top,
                    child: Container(
                      width: scanAreaSize,
                      height: scanAreaSize,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 스캔 영역 테두리
            Positioned(
              left: left,
              top: top,
              child: Container(
                width: scanAreaSize,
                height: scanAreaSize,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // 코너 강조
                    _buildCorner(Alignment.topLeft),
                    _buildCorner(Alignment.topRight),
                    _buildCorner(Alignment.bottomLeft),
                    _buildCorner(Alignment.bottomRight),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCorner(Alignment alignment) {
    final isTop = alignment == Alignment.topLeft || alignment == Alignment.topRight;
    final isLeft = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;

    return Positioned(
      top: isTop ? 0 : null,
      bottom: !isTop ? 0 : null,
      left: isLeft ? 0 : null,
      right: !isLeft ? 0 : null,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? const BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
            bottom: !isTop ? const BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
            left: isLeft ? const BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
            right: !isLeft ? const BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);

    // QR 코드 파싱
    _processQRCode(code);
  }

  Future<void> _processQRCode(String code) async {
    // 대회 ID 추출 시도
    int? contestId = _extractContestId(code);

    if (contestId != null) {
      setState(() => _isSearching = true);
      try {
        // 로그인된 유저 정보로 자동 검색
        await ref.read(mobileQRProvider.notifier).loadContestDetail(contestId);
        final state = ref.read(mobileQRProvider);

        if (mounted) {
          if (state.selectedContestDetail != null) {
            // 참가 정보 있음 → 바로 상세 화면으로 이동
            context.go('/qr/contest/$contestId');
          } else {
            // 참가 정보 없음 → 포털로 이동 (수동 검색)
            context.go('/portal/$contestId');
          }
        }
      } catch (e) {
        // API 호출 실패 시 포털로 폴백
        if (mounted) {
          context.go('/portal/$contestId');
        }
      }
    } else {
      // 인식 실패
      _showError('유효하지 않은 QR 코드입니다');
      setState(() => _isProcessing = false);
    }
  }

  int? _extractContestId(String code) {
    // 다양한 QR 포맷 지원

    // 1. 숫자만 있는 경우 (대회 ID)
    final numOnly = int.tryParse(code);
    if (numOnly != null) return numOnly;

    // 2. URL 형식: https://도메인/portal/123 또는 /qr/123
    final portalMatch = RegExp(r'/portal/(\d+)').firstMatch(code);
    if (portalMatch != null) {
      return int.tryParse(portalMatch.group(1) ?? '');
    }

    final qrMatch = RegExp(r'/qr/(\d+)').firstMatch(code);
    if (qrMatch != null) {
      return int.tryParse(qrMatch.group(1) ?? '');
    }

    // 3. contest=123 형식
    final contestMatch = RegExp(r'contest[=:](\d+)').firstMatch(code);
    if (contestMatch != null) {
      return int.tryParse(contestMatch.group(1) ?? '');
    }

    // 4. id=123 형식
    final idMatch = RegExp(r'id[=:](\d+)').firstMatch(code);
    if (idMatch != null) {
      return int.tryParse(idMatch.group(1) ?? '');
    }

    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
