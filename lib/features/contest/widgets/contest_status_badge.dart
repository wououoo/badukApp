import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 대회 상태 타입 (백엔드 ContestHomepage.getContestStatus()와 1:1)
enum ContestStatus {
  upcoming, // 접수 예정 (접수 시작 전)
  open,     // 접수중
  ended,    // 접수종료 (접수 마감 ~ 대회 시작 전)
  soon,     // 임박 (D-7 이내) — 클라이언트 전용 (현재 미사용)
  live,     // 진행중
  closed,   // 종료됨
}

/// 대회 상태 뱃지 위젯
class ContestStatusBadge extends StatelessWidget {
  final ContestStatus status;
  final int? dDay; // D-Day 숫자 (soon 상태일 때 사용)

  const ContestStatusBadge({
    super.key,
    required this.status,
    this.dDay,
  });

  /// 백엔드의 contestStatus 문자열만으로 상태 결정 (단일 출처)
  /// 인자로 받는 contestDate/contestEndDate는 클라이언트 재계산 폐기로 무시됨
  /// (백엔드 ContestHomepage.getContestStatus()가 Asia/Seoul 기준 권위 있는 값)
  factory ContestStatusBadge.fromString(String? statusStr, {DateTime? contestDate, DateTime? contestEndDate}) {
    ContestStatus status;
    switch (statusStr?.toUpperCase()) {
      case '접수예정':
      case 'UPCOMING':
        status = ContestStatus.upcoming;
        break;
      case '접수중':
      case 'OPEN':
        status = ContestStatus.open;
        break;
      case '접수종료':
      case 'ENDED':
        status = ContestStatus.ended;
        break;
      case '진행중':
      case 'LIVE':
        status = ContestStatus.live;
        break;
      case '종료됨':
      case 'CLOSED':
        status = ContestStatus.closed;
        break;
      default:
        status = ContestStatus.open;
    }
    return ContestStatusBadge(status: status);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String get _label {
    switch (status) {
      case ContestStatus.upcoming:
        return '접수 예정';
      case ContestStatus.open:
        return '접수중';
      case ContestStatus.ended:
        return '접수종료';
      case ContestStatus.soon:
        if (dDay != null && dDay! > 0) {
          return 'D-$dDay';
        }
        return 'D-Day';
      case ContestStatus.live:
        return '진행중';
      case ContestStatus.closed:
        return '종료됨';
    }
  }

  Color get _backgroundColor {
    switch (status) {
      case ContestStatus.upcoming:
        return AppColors.statusSoonBg;  // 임박과 비슷한 노란 톤
      case ContestStatus.open:
        return AppColors.statusOpenBg;
      case ContestStatus.ended:
        return AppColors.statusSoonBg;
      case ContestStatus.soon:
        return AppColors.statusSoonBg;
      case ContestStatus.live:
        return AppColors.statusLiveBg;
      case ContestStatus.closed:
        return AppColors.statusClosedBg;
    }
  }

  Color get _textColor {
    switch (status) {
      case ContestStatus.upcoming:
        return AppColors.statusSoonText;
      case ContestStatus.open:
        return AppColors.statusOpenText;
      case ContestStatus.ended:
        return AppColors.statusSoonText;
      case ContestStatus.soon:
        return AppColors.statusSoonText;
      case ContestStatus.live:
        return AppColors.statusLiveText;
      case ContestStatus.closed:
        return AppColors.statusClosedText;
    }
  }
}
