import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';

class NotificationService {
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

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

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    if (Platform.isAndroid) {
      await _requestAndroidPermissions();
    }
  }

  static Future<void> _requestAndroidPermissions() async {
    final androidImplementation = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation != null) {
      final bool? notificationPermissionGranted = await androidImplementation
          .requestNotificationsPermission();
      debugPrint(
        'Permission for notifications ${notificationPermissionGranted == true ? "granted" : "denied"}',
      );

      final bool? exactAlarmsPermissionGranted = await androidImplementation
          .requestExactAlarmsPermission();
      debugPrint(
        'Permission for exact alarms ${exactAlarmsPermissionGranted == true ? "granted" : "denied"}',
      );
    }
  }

  static NotificationDetails _notificationDetails() {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'lesson_channel_id',
          'Lesson Reminders',
          channelDescription:
              'Channel for notifications about upcoming lessons',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails();
    return const NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );
  }

  static Future<void> scheduleLessonNotification({
    required int lessonId,
    required String studentName,
    required DateTime lessonTime,
    required int reminderMinutes,
  }) async {
    final scheduledNotificationDateTime = lessonTime.subtract(
      Duration(minutes: reminderMinutes),
    );

    if (scheduledNotificationDateTime.isBefore(DateTime.now())) {
      debugPrint(
        'Notification for lesson #$lessonId was not scheduled (time is in the past).',
      );
      return;
    }

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      lessonId,
      'Upcoming lesson with $studentName',
      'In $reminderMinutes minutes',
      tz.TZDateTime.from(scheduledNotificationDateTime, tz.local),
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint(
      'Notification for lesson #$lessonId scheduled for $scheduledNotificationDateTime',
    );
  }

  static Future<void> cancelNotification(int lessonId) async {
    await _flutterLocalNotificationsPlugin.cancel(lessonId);
    debugPrint('Notification for lesson #$lessonId canceled.');
  }
}
