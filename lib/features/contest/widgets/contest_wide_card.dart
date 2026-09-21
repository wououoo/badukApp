import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/contest.dart';

/// 대회 목록의 가로 넓은 카드.
///
/// 대회를 고르는 판단은 결국 **언제 · 어디서 · 얼마** 셋으로 끝난다.
/// 2열 카드에서는 이 셋이 좁은 폭에 눌려 줄바꿈되거나 잘렸다.
/// 한 줄에 하나씩 놓고 포스터를 위에 얹으면 목록이 사진첩처럼 넘어간다.
class ContestWideCard extends StatelessWidget {
  final Contest contest;
  final VoidCallback? onTap;

  const ContestWideCard({super.key, required this.contest, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _poster(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contest.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      letterSpacing: -0.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _metaRow(),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 11),
                  _footer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 포스터 자리. 이미지가 없는 대회는 반상 위 흑백돌로 채운다 —
  /// 빈 회색 상자를 두면 "준비가 덜 된 대회"처럼 보인다.
  Widget _poster() {
    final url = contest.posterUrl;
    return SizedBox(
      height: 104,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url.isNotEmpty)
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _StoneBackdrop(),
            )
          else
            const _StoneBackdrop(),
          if (_dday != null)
            Positioned(
              left: 12,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _dday!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _metaRow() {
    final parts = <String>[
      if (_date != null) _date!,
      if (contest.province != null && contest.province!.isNotEmpty)
        _shortProvince(contest.province!)
      else if (contest.region.isNotEmpty)
        contest.region,
      if ((contest.categoryCount ?? 0) > 0) '${contest.categoryCount}개 부문',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (int i = 0; i < parts.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(width: 6),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.divider,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              parts[i],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ],
    );
  }

  Widget _footer() {
    final fee = contest.participationFee;
    return Row(
      children: [
        if (fee != null && fee.isNotEmpty)
          Flexible(
            child: Text(
              fee,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: _open ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _open ? '신청하기' : _statusLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _open ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ── 값 계산 ─────────────────────────────────────────

  bool get _open => contest.status == 'OPEN' || contest.status == '접수중';

  String get _statusLabel {
    switch (contest.status) {
      case 'UPCOMING':
        return '접수 예정';
      case 'ENDED':
      case 'CLOSED':
        return '접수 마감';
      case 'LIVE':
        return '진행 중';
      default:
        return contest.status ?? '';
    }
  }

  String? get _date {
    final d = contest.startDate;
    if (d == null) return null;
    return '${d.month}월 ${d.day}일';
  }

  /// 접수 마감이 임박한 것만 알린다. 한참 남은 D-60은 알림이 아니라 소음이다.
  String? get _dday {
    final d = contest.startDate;
    if (d == null) return null;
    final left = d.difference(DateTime.now()).inDays;
    if (left < 0) return null;
    if (left == 0) return '오늘';
    if (left <= 14) return 'D-$left';
    return null;
  }

  String _shortProvince(String p) {
    const map = {
      '서울특별시': '서울', '부산광역시': '부산', '대구광역시': '대구',
      '인천광역시': '인천', '광주광역시': '광주', '대전광역시': '대전',
      '울산광역시': '울산', '세종특별자치시': '세종', '경기도': '경기',
      '강원특별자치도': '강원', '충청북도': '충북', '충청남도': '충남',
      '전북특별자치도': '전북', '전라남도': '전남', '경상북도': '경북',
      '경상남도': '경남', '제주특별자치도': '제주',
    };
    return map[p] ?? p;
  }
}

/// 포스터가 없을 때의 배경 — 반상 위에 흑백돌.
class _StoneBackdrop extends StatelessWidget {
  const _StoneBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.board,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Positioned(
            right: -18,
            top: -22,
            child: Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.35, -0.4),
                  colors: [Color(0xFFFFFFFF), Color(0xFFC6D0DB)],
                ),
              ),
            ),
          ),
          Positioned(
            right: 48,
            top: 36,
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.35),
                  colors: [Color(0xFF4A5462), Color(0xFF10151B)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  static const double _gap = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.boardGrid
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += _gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += _gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
