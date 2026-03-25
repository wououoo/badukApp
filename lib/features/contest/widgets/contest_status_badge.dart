import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 대회 상태 타입
enum ContestStatus {
  open,     // 접수중
  ended,    // 접수종료
  soon,     // 임박 (D-7 이내)
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

  /// 문자열로부터 상태 파싱
  factory ContestStatusBadge.fromString(String? statusStr, {DateTime? contestDate, DateTime? contestEndDate}) {
    ContestStatus status;
    int? dDay;

    // D-Day 계산 (시작일/종료일 기반)
    if (contestDate != null) {
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final startOnly = DateTime(contestDate.year, contestDate.month, contestDate.day);
      final endOnly = contestEndDate != null
          ? DateTime(contestEndDate.year, contestEndDate.month, contestEndDate.day)
          : startOnly; // 종료일 없으면 시작일 = 종료일 (1일 대회)

      final diffToStart = startOnly.difference(todayOnly).inDays;
      dDay = diffToStart;

      if (todayOnly.isAfter(endOnly)) {
        // 오늘이 종료일 이후 → 종료
        status = ContestStatus.closed;
      } else if (!todayOnly.isBefore(startOnly) && !todayOnly.isAfter(endOnly)) {
        // 오늘이 시작일~종료일 사이 → 진행중
        status = ContestStatus.live;
      } else if (diffToStart <= 7) {
        // 시작일까지 7일 이내 → 임박
        status = ContestStatus.soon;
      } else {
        status = ContestStatus.open;
      }
    } else {
      // 문자열로 판단
      switch (statusStr?.toLowerCase()) {
        case '접수중':
        case 'open':
          status = ContestStatus.open;
          break;
        case '접수종료':
        case 'ended':
          status = ContestStatus.ended;
          break;
        case '진행중':
        case 'live':
          status = ContestStatus.live;
          break;
        case '종료됨':
        case 'closed':
          status = ContestStatus.closed;
          break;
        default:
          status = ContestStatus.open;
      }
    }

    return ContestStatusBadge(status: status, dDay: dDay);
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
      case ContestStatus.open:
        return AppColors.statusOpenBg;
      case ContestStatus.ended:
        return AppColors.statusSoonBg;  // 접수종료는 임박과 같은 색상
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
      case ContestStatus.open:
        return AppColors.statusOpenText;
      case ContestStatus.ended:
        return AppColors.statusSoonText;  // 접수종료는 임박과 같은 색상
      case ContestStatus.soon:
        return AppColors.statusSoonText;
      case ContestStatus.live:
        return AppColors.statusLiveText;
      case ContestStatus.closed:
        return AppColors.statusClosedText;
    }
  }
}
