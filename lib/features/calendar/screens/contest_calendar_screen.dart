import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/calendar_contest.dart';
import '../../../data/providers/calendar_provider.dart';

class ContestCalendarScreen extends ConsumerStatefulWidget {
  const ContestCalendarScreen({super.key});

  @override
  ConsumerState<ContestCalendarScreen> createState() => _ContestCalendarScreenState();
}

enum _CalendarFilter { all, public_, club }

class _ContestCalendarScreenState extends ConsumerState<ContestCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  _CalendarFilter _filter = _CalendarFilter.all;

  ({int year, int month}) get _currentMonth =>
      (year: _focusedDay.year, month: _focusedDay.month);

  @override
  Widget build(BuildContext context) {
    final contestsAsync = ref.watch(calendarContestsProvider(_currentMonth));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('대회 캘린더'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: contestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text('캘린더를 불러올 수 없습니다',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(calendarContestsProvider(_currentMonth)),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (contests) => _buildContent(contests),
      ),
    );
  }

  Widget _buildContent(List<CalendarContest> allContests) {
    // 필터 적용
    final contests = allContests.where((c) {
      if (_filter == _CalendarFilter.public_) return c.isPublic;
      if (_filter == _CalendarFilter.club) return c.isClub;
      return true;
    }).toList();

    // 날짜별 대회 매핑
    final eventMap = <DateTime, List<CalendarContest>>{};
    for (final contest in contests) {
      if (contest.startDate == null) continue;
      final start = _normalizeDate(contest.startDate!);
      final end = contest.endDate != null ? _normalizeDate(contest.endDate!) : start;
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        eventMap.putIfAbsent(d, () => []).add(contest);
      }
    }

    final selectedNorm = _normalizeDate(_selectedDay);
    final selectedContests = eventMap[selectedNorm] ?? [];

    return Column(
      children: [
        // 필터 칩
        _buildFilterChips(),
        // 캘린더
        Container(
          color: Colors.white,
          child: TableCalendar<CalendarContest>(
            locale: 'ko_KR',
            firstDay: DateTime(2020, 1, 1),
            lastDay: DateTime(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) => eventMap[_normalizeDate(day)] ?? [],
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: AppColors.clubPrimary,
                shape: BoxShape.circle,
              ),
              markerSize: 6,
              markersMaxCount: 3,
              outsideDaysVisible: false,
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.textSecondary),
              rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ),
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: '월'},
          ),
        ),
        const Divider(height: 1),
        // 선택 날짜 대회 목록
        Expanded(child: _buildContestList(selectedContests)),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _filterChip('전체', _CalendarFilter.all),
          const SizedBox(width: 8),
          _filterChip('공개대회', _CalendarFilter.public_),
          const SizedBox(width: 8),
          _filterChip('클럽대회', _CalendarFilter.club),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _CalendarFilter filter) {
    final selected = _filter == filter;
    return GestureDetector(
      onTap: () => setState(() => _filter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildContestList(List<CalendarContest> contests) {
    if (contests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_outlined, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 8),
            Text(
              '이 날짜에 대회가 없습니다',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: contests.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${_selectedDay.month}월 ${_selectedDay.day}일 — ${contests.length}개 대회',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }
        return _buildContestCard(contests[index - 1]);
      },
    );
  }

  Widget _buildContestCard(CalendarContest contest) {
    final isClub = contest.isClub;
    final iconData = isClub ? Icons.groups_outlined : Icons.emoji_events_outlined;
    final color = isClub ? AppColors.clubPrimary : AppColors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onContestTap(contest),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contest.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (isClub && contest.clubName != null) ...[
                          Text(
                            contest.clubName!,
                            style: TextStyle(fontSize: 12, color: AppColors.clubPrimary),
                          ),
                          Text(' · ', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                        ],
                        if (!isClub && contest.venue != null) ...[
                          Flexible(
                            child: Text(
                              contest.venue!,
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(' · ', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                        ],
                        if (contest.status != null)
                          Text(
                            contest.status!,
                            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                          ),
                        if (isClub)
                          Text(
                            '클럽대회',
                            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  void _onContestTap(CalendarContest contest) {
    if (contest.isClub && contest.clubId != null) {
      context.push('/clubs/${contest.clubId}');
    } else {
      context.push('/contest/${contest.id}');
    }
  }

  DateTime _normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
