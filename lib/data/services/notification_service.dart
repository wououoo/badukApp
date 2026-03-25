import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../routing/app_router.dart';

/// FCM 푸시 알림 서비스
/// 포그라운드 알림 표시 및 알림 채널 관리
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// 알림 채널 ID
  static const String _channelId = 'baduk_contest';
  static const String _channelName = '바둑대회 알림';
  static const String _channelDescription = '대국 시작, 라운드 결과 등 알림';

  /// 초기화
  Future<void> initialize() async {
    if (kIsWeb) return;

    // Android 설정
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 설정
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Android 알림 채널 생성
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }

    // 타임존 초기화
    tz.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }

    // FCM 포그라운드 메시지 리스너
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    debugPrint('[Notification] 서비스 초기화 완료');
  }

  /// Android 알림 채널 생성
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[Notification] 포그라운드 메시지 수신: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    // 로컬 알림으로 표시
    showNotification(
      title: notification.title ?? '알림',
      body: notification.body ?? '',
      payload: message.data.toString(),
    );
  }

  /// 알림 탭 처리 - payload에 따라 적절한 화면으로 이동
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[Notification] 알림 탭: ${response.payload}');

    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    try {
      if (response.payload != null && response.payload!.isNotEmpty) {
        // payload에서 라우트 정보 추출
        // FCM data 형식: {type: contest, contestId: 123} 등
        final data = _parsePayload(response.payload!);
        final type = data['type'];
        final contestId = data['contestId'];

        if (type == 'contest' && contestId != null) {
          GoRouter.of(context).push('/contest/$contestId');
        } else if (type == 'live' && contestId != null) {
          GoRouter.of(context).push('/live/$contestId');
        } else if (type == 'notice') {
          GoRouter.of(context).push('/support/notices');
        } else if (type == 'club_post' || type == 'club_notice' || type == 'club_comment_reply') {
          final clubId = data['clubId'];
          final postId = data['postId'];
          if (clubId != null && postId != null) {
            GoRouter.of(context).push('/clubs/$clubId/posts/$postId');
          } else if (clubId != null) {
            GoRouter.of(context).push('/clubs/$clubId');
          }
        } else if (type == 'club_join_approved') {
          final clubId = data['clubId'];
          if (clubId != null) GoRouter.of(context).push('/clubs/$clubId');
        } else if (type == 'club_contest') {
          final clubId = data['clubId'];
          if (clubId != null) GoRouter.of(context).push('/clubs/$clubId');
        } else {
          // 기본: 홈으로 이동
          GoRouter.of(context).go('/home');
        }
      }
    } catch (e) {
      debugPrint('[Notification] 알림 탭 처리 오류: $e');
    }
  }

  /// payload 문자열을 Map으로 변환
  Map<String, String> _parsePayload(String payload) {
    try {
      // JSON 형식 시도
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {
      // JSON이 아닌 경우 toString 형식 파싱: {key: value, key2: value2}
    }

    final result = <String, String>{};
    final cleaned = payload.replaceAll('{', '').replaceAll('}', '');
    for (final pair in cleaned.split(',')) {
      final kv = pair.trim().split(':');
      if (kv.length >= 2) {
        result[kv[0].trim()] = kv.sublist(1).join(':').trim();
      }
    }
    return result;
  }

  /// 로컬 알림 표시
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// 모든 알림 취소
  Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }

  /// 대회 리마인더 알림 스케줄링 (D-1 08:00, 당일 07:00)
  Future<void> scheduleContestReminders({
    required int registrationId,
    required int homepageId,
    required String contestName,
    required DateTime contestStartDate,
  }) async {
    // 중복 방지
    final prefs = await SharedPreferences.getInstance();
    final key = 'contest_reminder_$registrationId';
    if (prefs.getBool(key) == true) return;

    final now = tz.TZDateTime.now(tz.local);
    final payload = '{"type":"contest","contestId":"$homepageId"}';

    // D-1: 전날 08:00
    final dMinus1 = tz.TZDateTime(
      tz.local,
      contestStartDate.year,
      contestStartDate.month,
      contestStartDate.day - 1,
      8,
    );
    if (dMinus1.isAfter(now)) {
      await _localNotifications.zonedSchedule(
        registrationId * 10 + 1,
        '내일 대회가 열립니다!',
        '$contestName - 내일 대회에 참가하세요.',
        dMinus1,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('[Notification] D-1 알림 예약: $dMinus1');
    }

    // 당일: 07:00
    final dDay = tz.TZDateTime(
      tz.local,
      contestStartDate.year,
      contestStartDate.month,
      contestStartDate.day,
      7,
    );
    if (dDay.isAfter(now)) {
      await _localNotifications.zonedSchedule(
        registrationId * 10 + 2,
        '오늘 대회 당일입니다!',
        '$contestName - 오늘 대회가 시작됩니다. 준비하세요!',
        dDay,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('[Notification] 당일 알림 예약: $dDay');
    }

    await prefs.setBool(key, true);
  }

  /// 대회 리마인더 알림 취소
  Future<void> cancelContestReminders(int registrationId) async {
    await _localNotifications.cancel(registrationId * 10 + 1);
    await _localNotifications.cancel(registrationId * 10 + 2);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('contest_reminder_$registrationId');

    debugPrint('[Notification] 대회 리마인더 취소: registrationId=$registrationId');
  }

  /// 즐겨찾기 대회 리마인더 알림 스케줄링 (D-1 08:00, 당일 07:00)
  Future<void> scheduleFavoriteReminders({
    required int homepageId,
    required String contestName,
    required DateTime contestStartDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'favorite_reminder_$homepageId';
    if (prefs.getBool(key) == true) return;

    final now = tz.TZDateTime.now(tz.local);
    final payload = '{"type":"contest","contestId":"$homepageId"}';
    // 즐겨찾기 알림 ID: 100000 + homepageId * 10 + offset (참가신청 알림과 겹치지 않도록)
    final baseId = 100000 + homepageId * 10;

    // D-1: 전날 08:00
    final dMinus1 = tz.TZDateTime(
      tz.local,
      contestStartDate.year,
      contestStartDate.month,
      contestStartDate.day - 1,
      8,
    );
    if (dMinus1.isAfter(now)) {
      await _localNotifications.zonedSchedule(
        baseId + 1,
        '관심 대회가 내일 열립니다!',
        '$contestName - 내일 대회가 시작됩니다.',
        dMinus1,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('[Notification] 즐겨찾기 D-1 알림 예약: $dMinus1');
    }

    // 당일: 07:00
    final dDay = tz.TZDateTime(
      tz.local,
      contestStartDate.year,
      contestStartDate.month,
      contestStartDate.day,
      7,
    );
    if (dDay.isAfter(now)) {
      await _localNotifications.zonedSchedule(
        baseId + 2,
        '관심 대회 당일입니다!',
        '$contestName - 오늘 대회가 시작됩니다!',
        dDay,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('[Notification] 즐겨찾기 당일 알림 예약: $dDay');
    }

    await prefs.setBool(key, true);
  }

  /// 즐겨찾기 대회 리마인더 알림 취소
  Future<void> cancelFavoriteReminders(int homepageId) async {
    final baseId = 100000 + homepageId * 10;
    await _localNotifications.cancel(baseId + 1);
    await _localNotifications.cancel(baseId + 2);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('favorite_reminder_$homepageId');

    debugPrint('[Notification] 즐겨찾기 리마인더 취소: homepageId=$homepageId');
  }
}
