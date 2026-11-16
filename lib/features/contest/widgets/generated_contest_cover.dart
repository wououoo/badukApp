import 'package:flutter/material.dart';

import '../../../data/models/contest.dart';

/// 포스터가 없는 대회의 자동 생성 커버.
///
/// 빈 회색 상자나 로고 워터마크는 "준비가 덜 된 대회"처럼 보인다.
/// 대신 **반상 격자 + 흑백돌** 모티프로 바둑 느낌을 주고,
/// 배경색은 **대회 id 해시로 고정 팔레트에서 선택**해 대회마다 다르게 —
/// 같은 대회는 늘 같은 색이라 목록이 알록달록하면서도 일관된다.
class GeneratedContestCover extends StatelessWidget {
  final Contest contest;

  const GeneratedContestCover({super.key, required this.contest});

  /// 흰 오버레이 텍스트와 잘 어울리는 짙은 2색 그라데이션 팔레트.
  static const List<List<Color>> _palette = [
    [Color(0xFF2A3A5C), Color(0xFF1C2840)], // 네이비
    [Color(0xFF2F5D50), Color(0xFF1E3E35)], // 포레스트
    [Color(0xFF5B3A4E), Color(0xFF3C2434)], // 버건디
    [Color(0xFF7A4A38), Color(0xFF563225)], // 테라코타
    [Color(0xFF3C4A6B), Color(0xFF28344E)], // 슬레이트블루
    [Color(0xFF4A3B66), Color(0xFF312648)], // 플럼
    [Color(0xFF2E5560), Color(0xFF1C3942)], // 틸
    [Color(0xFF5A4632), Color(0xFF3A2D20)], // 모카
  ];

  List<Color> get _colors => _palette[contest.id.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _colors,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          // 반상 격자 (은은하게)
          Positioned.fill(child: CustomPaint(painter: _GobanPainter())),
          // 흰 돌 (우상단, 모서리에 살짝 걸침)
          Positioned(
            right: -16,
            top: -20,
            child: _stone(74, const [Color(0xFFFFFFFF), Color(0xFFCAD4DF)]),
          ),
          // 흑 돌 (그 아래)
          Positioned(
            right: 46,
            top: 30,
            child: _stone(46, const [Color(0xFF4A5462), Color(0xFF10151B)]),
          ),
        ],
      ),
    );
  }

  Widget _stone(double size, List<Color> gradient) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: gradient,
        ),
      ),
    );
  }
}

/// 반상 격자선. 그라데이션 위에 흰선을 아주 옅게 얹는다.
class _GobanPainter extends CustomPainter {
  static const double _gap = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (double y = _gap; y < size.height; y += _gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = _gap; x < size.width; x += _gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
