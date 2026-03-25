import 'package:flutter/material.dart';
import '../../../data/services/board_analysis_service.dart';

/// 계가 결과를 바둑판 위에 시각화하는 위젯
/// ownership 데이터로 각 교차점의 영역 소유를 표시
class OwnershipBoardWidget extends StatelessWidget {
  final BoardAnalysisResult result;

  const OwnershipBoardWidget({super.key, required this.result});

  static const int boardSize = 19;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFDEB887), // 바둑판 색
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomPaint(
          painter: _OwnershipBoardPainter(
            stones: result.stones,
            ownership: result.ownership,
          ),
        ),
      ),
    );
  }
}

class _OwnershipBoardPainter extends CustomPainter {
  final List<List<String>> stones;
  final List<double>? ownership;

  _OwnershipBoardPainter({required this.stones, this.ownership});

  static const int boardSize = 19;

  @override
  void paint(Canvas canvas, Size size) {
    final double margin = size.width * 0.04;
    final double boardWidth = size.width - margin * 2;
    final double cellSize = boardWidth / (boardSize - 1);

    // 돌 위치를 Set으로 변환 (빠른 조회용)
    final Map<String, String> stoneMap = {};
    for (final stone in stones) {
      if (stone.length >= 2) {
        stoneMap[stone[1]] = stone[0]; // GTP좌표 → 색상
      }
    }

    // 1. 격자선 그리기
    final linePaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..strokeWidth = 0.8;

    for (int i = 0; i < boardSize; i++) {
      final pos = margin + i * cellSize;
      // 가로선
      canvas.drawLine(
        Offset(margin, pos),
        Offset(size.width - margin, pos),
        linePaint,
      );
      // 세로선
      canvas.drawLine(
        Offset(pos, margin),
        Offset(pos, size.height - margin),
        linePaint,
      );
    }

    // 2. 화점(별점) 그리기
    final dotPaint = Paint()..color = Colors.black.withOpacity(0.6);
    const starPoints = [3, 9, 15];
    for (final r in starPoints) {
      for (final c in starPoints) {
        canvas.drawCircle(
          Offset(margin + c * cellSize, margin + r * cellSize),
          cellSize * 0.1,
          dotPaint,
        );
      }
    }

    // 3. ownership 영역 표시
    if (ownership != null && ownership!.length == boardSize * boardSize) {
      for (int row = 0; row < boardSize; row++) {
        for (int col = 0; col < boardSize; col++) {
          final idx = row * boardSize + col;
          final val = ownership![idx];
          final gtp = _toGtp(col, row);

          // 돌이 있는 곳은 건너뜀
          if (stoneMap.containsKey(gtp)) continue;

          final cx = margin + col * cellSize;
          final cy = margin + row * cellSize;
          final rectSize = cellSize * 0.35;

          if (val > 0.1) {
            // 흑 영역 - 검정 반투명 사각형
            final opacity = (val.clamp(0.1, 1.0) * 0.6);
            final paint = Paint()
              ..color = Colors.black.withOpacity(opacity);
            canvas.drawRect(
              Rect.fromCenter(
                  center: Offset(cx, cy), width: rectSize, height: rectSize),
              paint,
            );
          } else if (val < -0.1) {
            // 백 영역 - 흰색 반투명 사각형 + 테두리
            final opacity = ((-val).clamp(0.1, 1.0) * 0.7);
            final paint = Paint()
              ..color = Colors.white.withOpacity(opacity);
            final borderPaint = Paint()
              ..color = Colors.black.withOpacity(opacity * 0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5;
            canvas.drawRect(
              Rect.fromCenter(
                  center: Offset(cx, cy), width: rectSize, height: rectSize),
              paint,
            );
            canvas.drawRect(
              Rect.fromCenter(
                  center: Offset(cx, cy), width: rectSize, height: rectSize),
              borderPaint,
            );
          }
        }
      }
    }

    // 4. 돌 그리기
    final stoneRadius = cellSize * 0.44;
    for (final stone in stones) {
      if (stone.length < 2) continue;
      final color = stone[0];
      final gtp = stone[1];
      final pos = _fromGtp(gtp);
      if (pos == null) continue;

      final cx = margin + pos[0] * cellSize;
      final cy = margin + pos[1] * cellSize;

      // 돌 그림자
      canvas.drawCircle(
        Offset(cx + 1, cy + 1),
        stoneRadius,
        Paint()..color = Colors.black.withOpacity(0.2),
      );

      // 돌
      if (color == 'B') {
        canvas.drawCircle(
          Offset(cx, cy),
          stoneRadius,
          Paint()..color = Colors.black,
        );
      } else {
        canvas.drawCircle(
          Offset(cx, cy),
          stoneRadius,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          Offset(cx, cy),
          stoneRadius,
          Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }
    }
  }

  String _toGtp(int col, int row) {
    const cols = "ABCDEFGHJKLMNOPQRST";
    return '${cols[col]}${boardSize - row}';
  }

  /// GTP 좌표 → [col, row] (0-indexed)
  List<int>? _fromGtp(String gtp) {
    if (gtp.length < 2) return null;
    const cols = "ABCDEFGHJKLMNOPQRST";
    final colIdx = cols.indexOf(gtp[0].toUpperCase());
    if (colIdx < 0) return null;
    final rowNum = int.tryParse(gtp.substring(1));
    if (rowNum == null) return null;
    return [colIdx, boardSize - rowNum];
  }

  @override
  bool shouldRepaint(covariant _OwnershipBoardPainter oldDelegate) => true;
}
