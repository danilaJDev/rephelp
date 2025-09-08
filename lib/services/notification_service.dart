import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rephelp/models/lesson.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final MethodChannel _channel = const MethodChannel(
    'com.example.rephelp/notifications',
  );

  Future<void> checkAndRequestExactAlarmPermission() async {
    final bool hasPermission = await _channel.invokeMethod(
      'checkExactAlarmPermission',
    );
    if (!hasPermission) {
      await _channel.invokeMethod('requestExactAlarmPermission');
    }
  }

  Future<void> init() async {
    await _configureLocalTimeZone();
    await checkAndRequestExactAlarmPermission();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  }

  Future<void> requestPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleLessonNotification(
    Lesson lesson,
    String studentName,
  ) async {
    final scheduleTime = lesson.startTime.subtract(const Duration(minutes: 15));

    if (scheduleTime.isBefore(DateTime.now())) {
      return;
    }

    final formattedTime = DateFormat('HH:mm').format(lesson.startTime);
    final notificationId = lesson.id!;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      'Напоминание о занятии',
      'Скоро начало занятия в $formattedTime с учеником $studentName.',
      tz.TZDateTime.from(scheduleTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'lesson_channel',
          'Напоминания о занятиях',
          channelDescription: 'Уведомления о предстоящих занятиях',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(int notificationId) async {
    await flutterLocalNotificationsPlugin.cancel(notificationId);
  }
}
