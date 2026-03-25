/// 웹용 NotificationService stub
/// 웹에서는 flutter_local_notifications가 지원되지 않으므로 빈 구현 제공
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {
    // 웹에서는 아무것도 하지 않음
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // 웹에서는 아무것도 하지 않음
  }

  Future<void> cancelAll() async {
    // 웹에서는 아무것도 하지 않음
  }

  Future<void> scheduleContestReminders({
    required int registrationId,
    required int homepageId,
    required String contestName,
    required DateTime contestStartDate,
  }) async {
    // 웹에서는 아무것도 하지 않음
  }

  Future<void> cancelContestReminders(int registrationId) async {
    // 웹에서는 아무것도 하지 않음
  }

  Future<void> scheduleFavoriteReminders({
    required int homepageId,
    required String contestName,
    required DateTime contestStartDate,
  }) async {
    // 웹에서는 아무것도 하지 않음
  }

  Future<void> cancelFavoriteReminders(int homepageId) async {
    // 웹에서는 아무것도 하지 않음
  }
}
