import 'dart:io';
import 'package:flutter/material.dart';
import 'board_analysis_result_screen.dart';

/// 바둑판 4개 꼭짓점 선택 화면
///
/// 사용자가 사진 위에서 바둑판의 4개 모서리를 순서대로 탭한다.
/// 순서: 좌상 → 우상 → 우하 → 좌하
class CornerSelectionScreen extends StatefulWidget {
  final File imageFile;

  const CornerSelectionScreen({super.key, required this.imageFile});

  @override
  State<CornerSelectionScreen> createState() => _CornerSelectionScreenState();
}

class _CornerSelectionScreenState extends State<CornerSelectionScreen> {
  final List<Offset> _corners = [];
  String _nextColor = 'B'; // 기본: 흑 차례

  // 이미지 표시 영역 정보 (좌표 변환용)
  final GlobalKey _imageKey = GlobalKey();

  static const _cornerLabels = ['좌상', '우상', '우하', '좌하'];
  static const _cornerColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('꼭짓점 선택'),
        actions: [
          if (_corners.isNotEmpty)
            IconButton(
              onPressed: _undoLastCorner,
              icon: const Icon(Icons.undo),
              tooltip: '되돌리기',
            ),
        ],
      ),
      body: Column(
        children: [
          // 안내 메시지
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: _corners.length < 4
                ? Colors.blue.shade50
                : Colors.green.shade50,
            child: Text(
              _corners.length < 4
                  ? '${_cornerLabels[_corners.length]} 모서리를 탭하세요 (${_corners.length + 1}/4)'
                  : '4개 꼭짓점 선택 완료!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _corners.length < 4
                    ? Colors.blue.shade800
                    : Colors.green.shade800,
              ),
            ),
          ),

          // 이미지 + 꼭짓점 오버레이
          Expanded(
            child: GestureDetector(
              onTapDown: _corners.length < 4 ? _onTap : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 사진
                  InteractiveViewer(
                    child: Image.file(
                      widget.imageFile,
                      key: _imageKey,
                      fit: BoxFit.contain,
                    ),
                  ),
                  // 꼭짓점 마커
                  ..._buildCornerMarkers(),
                  // 연결선
                  if (_corners.length >= 2)
                    CustomPaint(
                      painter: _CornerLinePainter(_corners),
                    ),
                ],
              ),
            ),
          ),

          // 하단 컨트롤
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 다음 차례 선택
                Row(
                  children: [
                    const Text('다음 차례:', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 12),
                    _buildColorChip('B', '흑'),
                    const SizedBox(width: 8),
                    _buildColorChip('W', '백'),
                  ],
                ),
                const SizedBox(height: 12),
                // 분석 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _corners.length == 4 ? _startAnalysis : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D2D2D),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('AI 계가 시작',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorChip(String color, String label) {
    final selected = _nextColor == color;
    return GestureDetector(
      onTap: () => setState(() => _nextColor = color),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (color == 'B' ? Colors.black : Colors.white)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? (color == 'B' ? Colors.black : Colors.grey) : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected && color == 'B' ? Colors.white : Colors.black,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCornerMarkers() {
    return _corners.asMap().entries.map((entry) {
      final i = entry.key;
      final offset = entry.value;
      final color = _cornerColors[i];

      return Positioned(
        left: offset.dx - 14,
        top: offset.dy - 14,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(
              '${i + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  void _onTap(TapDownDetails details) {
    if (_corners.length >= 4) return;
    setState(() {
      _corners.add(details.localPosition);
    });
  }

  void _undoLastCorner() {
    if (_corners.isNotEmpty) {
      setState(() {
        _corners.removeLast();
      });
    }
  }

  void _startAnalysis() {
    if (_corners.length != 4) return;

    // 위젯 좌표를 이미지 원본 좌표로 변환
    final renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final widgetSize = renderBox.size;

    // 이미지 원본 크기 가져오기 (decodedImage)
    // 여기서는 위젯 좌표를 그대로 전달하고, Python 측에서 이미지 좌표로 처리
    // (Image.file + BoxFit.contain이므로 변환이 필요)
    final image = Image.file(widget.imageFile);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((info, _) {
        final imgWidth = info.image.width.toDouble();
        final imgHeight = info.image.height.toDouble();

        // BoxFit.contain 비율 계산
        final scale = _calculateContainScale(
          widgetSize.width, widgetSize.height,
          imgWidth, imgHeight,
        );
        final offsetX = (widgetSize.width - imgWidth * scale) / 2;
        final offsetY = (widgetSize.height - imgHeight * scale) / 2;

        // 위젯 좌표 → 이미지 원본 좌표 변환
        final imageCorners = _corners.map((c) {
          final x = (c.dx - offsetX) / scale;
          final y = (c.dy - offsetY) / scale;
          return [x.clamp(0.0, imgWidth), y.clamp(0.0, imgHeight)];
        }).toList();

        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BoardAnalysisResultScreen(
              imageFile: widget.imageFile,
              corners: imageCorners,
              nextColor: _nextColor,
            ),
          ),
        );
      }),
    );
  }

  double _calculateContainScale(
    double containerW, double containerH,
    double imageW, double imageH,
  ) {
    return (containerW / imageW < containerH / imageH)
        ? containerW / imageW
        : containerH / imageH;
  }
}

/// 꼭짓점을 연결하는 선 페인터
class _CornerLinePainter extends CustomPainter {
  final List<Offset> corners;
  _CornerLinePainter(this.corners);

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length < 2) return;

    final paint = Paint()
      ..color = Colors.yellow.withOpacity(0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(corners[0].dx, corners[0].dy);
    for (int i = 1; i < corners.length; i++) {
      path.lineTo(corners[i].dx, corners[i].dy);
    }
    if (corners.length == 4) {
      path.close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerLinePainter oldDelegate) {
    return oldDelegate.corners.length != corners.length;
  }
}
