import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/club_schedule.dart';
import '../../../data/services/club_service.dart';

class ClubSchedulesScreen extends StatefulWidget {
  final int clubId;
  final String? myRole;

  const ClubSchedulesScreen({super.key, required this.clubId, this.myRole});

  @override
  State<ClubSchedulesScreen> createState() => ClubSchedulesScreenState();
}

class ClubSchedulesScreenState extends State<ClubSchedulesScreen> with AutomaticKeepAliveClientMixin {
  final ClubService _clubService = ClubService();
  List<ClubSchedule> _schedules = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    try {
      final schedules = await _clubService.getClubSchedules(widget.clubId);
      setState(() {
        _schedules = schedules;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void refresh() {
    _loadSchedules();
  }

  bool get _isOwner => widget.myRole == 'OWNER' || widget.myRole == 'ADMIN';

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
      final weekday = weekdays[date.weekday - 1];
      return '${date.month}월 ${date.day}일 ($weekday)';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour < 12 ? '오전' : '오후';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$period $displayHour:${minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timeStr;
    }
  }

  Future<void> _showScheduleActions(ClubSchedule schedule) async {
    if (!_isOwner) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('수정'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('삭제', style: TextStyle(color: AppColors.error)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'edit') {
      _showScheduleForm(editSchedule: schedule);
    } else if (action == 'delete') {
      _deleteSchedule(schedule);
    }
  }

  Future<void> _deleteSchedule(ClubSchedule schedule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text('"${schedule.title}" 일정을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await _clubService.deleteClubSchedule(widget.clubId, schedule.id);
      _loadSchedules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정이 삭제되었습니다.')),
        );
      }
    } catch (e) {
      debugPrint('[Error] 일정 삭제 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
      }
    }
  }

  void showScheduleForm({ClubSchedule? editSchedule}) {
    _showScheduleForm(editSchedule: editSchedule);
  }

  Future<void> _showScheduleForm({ClubSchedule? editSchedule}) async {
    final titleController = TextEditingController(text: editSchedule?.title ?? '');
    final locationController = TextEditingController(text: editSchedule?.location ?? '');
    final memoController = TextEditingController(text: editSchedule?.memo ?? '');

    DateTime selectedDate = editSchedule != null
        ? DateTime.parse(editSchedule.date)
        : DateTime.now().add(const Duration(days: 1));
    TimeOfDay? selectedTime;
    if (editSchedule?.time != null) {
      try {
        final parts = editSchedule!.time!.split(':');
        selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {}
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editSchedule != null ? '일정 수정' : '새 일정',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '일정 제목 *',
                  border: OutlineInputBorder(),
                ),
                maxLength: 200,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (date != null) {
                          setModalState(() => selectedDate = date);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '날짜 *',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today, size: 20),
                        ),
                        child: Text(
                          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setModalState(() => selectedTime = time);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: '시간',
                          border: const OutlineInputBorder(),
                          suffixIcon: selectedTime != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setModalState(() => selectedTime = null),
                                )
                              : const Icon(Icons.access_time, size: 20),
                        ),
                        child: Text(
                          selectedTime != null
                              ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                              : '선택 안함',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: '장소',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                ),
                maxLength: 200,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: memoController,
                decoration: const InputDecoration(
                  labelText: '메모',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                maxLength: 500,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('일정 제목을 입력해주세요.')),
                      );
                      return;
                    }
                    try {
                      final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                      final timeStr = selectedTime != null
                          ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                          : null;

                      if (editSchedule != null) {
                        await _clubService.updateClubSchedule(
                          widget.clubId, editSchedule.id,
                          title: titleController.text.trim(),
                          date: dateStr,
                          time: timeStr,
                          location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                          memo: memoController.text.trim().isEmpty ? null : memoController.text.trim(),
                        );
                      } else {
                        await _clubService.createClubSchedule(
                          widget.clubId,
                          title: titleController.text.trim(),
                          date: dateStr,
                          time: timeStr,
                          location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                          memo: memoController.text.trim().isEmpty ? null : memoController.text.trim(),
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      debugPrint('[Error] 일정 저장 오류: $e');
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.clubPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    editSchedule != null ? '수정' : '등록',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );

    if (result == true) _loadSchedules();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_schedules.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadSchedules,
        child: ListView(
          children: [
            SizedBox(height: 120),
            Center(
              child: Column(
                children: [
                  Icon(Icons.event_outlined, size: 48, color: AppColors.textTertiary),
                  SizedBox(height: 12),
                  Text('등록된 일정이 없습니다', style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSchedules,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _schedules.length,
        itemBuilder: (context, index) {
          final schedule = _schedules[index];
          return _buildScheduleCard(schedule);
        },
      ),
    );
  }

  Widget _buildScheduleCard(ClubSchedule schedule) {
    return GestureDetector(
      onTap: _isOwner ? () => _showScheduleActions(schedule) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              schedule.title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.clubPrimary),
                const SizedBox(width: 6),
                Text(
                  _formatDate(schedule.date),
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                if (schedule.time != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.access_time, size: 16, color: AppColors.clubPrimary),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(schedule.time!),
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
            if (schedule.location != null && schedule.location!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.clubPrimary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      schedule.location!,
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
            if (schedule.memo != null && schedule.memo!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  schedule.memo!,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
