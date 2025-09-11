import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: (
        int id,
        String? title,
        String? body,
        String? payload,
      ) async {
        // Handle notification tapped logic here
      },
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tapped logic here
      },
    );

    // Request permissions on Android 13+
    final androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }


    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Moscow'));
  }

  static Future<void> scheduleLessonNotification({
    required int lessonId,
    required String studentName,
    required DateTime lessonTime,
    required int reminderMinutes,
  }) async {
    final tz.TZDateTime scheduledDate =
        tz.TZDateTime.from(lessonTime, tz.local)
            .subtract(Duration(minutes: reminderMinutes));

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'lesson_reminders',
      'Напоминания о занятиях',
      channelDescription: 'Уведомления о предстоящих занятиях',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      color: Colors.deepPurple,
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      lessonId,
      'Скоро занятие с $studentName',
      'Через $reminderMinutes минут',
      scheduledDate,
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelNotification(int notificationId) async {
    await _flutterLocalNotificationsPlugin.cancel(notificationId);
  }
}
