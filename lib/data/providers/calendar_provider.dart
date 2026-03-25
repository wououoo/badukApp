import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar_contest.dart';
import '../services/contest_service.dart';

/// 캘린더 대회 조회 Provider (year, month 기반)
final calendarContestsProvider = FutureProvider.family<List<CalendarContest>, ({int year, int month})>(
  (ref, params) async {
    final service = ContestService();
    return service.getCalendarContests(params.year, params.month);
  },
);
