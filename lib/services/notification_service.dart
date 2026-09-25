import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/lifestyle_entry.dart';
import '../models/lifestyle_scores.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize({bool requestPermission = true}) async {
    tz.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    // WorkManager starts a headless Flutter engine with no Activity. Android's
    // runtime permission dialog is valid only from the foreground app.
    if (requestPermission) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> scheduleTaskReminder({
    required int id,
    required DateTime when,
    required String title,
  }) async {
    if (!when.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      10000 + id,
      'Task reminder',
      title,
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'lifelens_reminders',
          'LifeLens reminders',
          channelDescription: 'Task and lifestyle reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelTaskReminder(int id) => _plugin.cancel(10000 + id);

  Future<void> scheduleDailyRoutine({
    required int id,
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      20000 + id,
      title,
      body,
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'lifelens_routines',
          'LifeLens routines',
          channelDescription: 'Healthy routine reminders',
          importance: Importance.defaultImportance,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<bool> requestPermission() async {
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  Future<void> showRiskAlerts({
    required LifestyleScores scores,
    required DailyHealthEntry health,
    required Future<bool> Function(String alertType) shouldShow,
    required NotificationPreferences preferences,
  }) async {
    if (preferences.isQuietNow) return;
    if (preferences.stressEnabled &&
        scores.stressRisk >= preferences.stressThreshold &&
        await shouldShow('stress')) {
      await _show(
        id: 1,
        title: 'Take one task off your plate',
        body:
            'Your stress risk is high today (${scores.stressRisk}/100). Move or simplify one non-essential task.',
      );
    }
    if (preferences.spendingEnabled &&
        scores.financialHealth <= preferences.financialHealthThreshold &&
        await shouldShow('spending')) {
      await _show(
        id: 2,
        title: 'Pause non-essential spending',
        body:
            'Today\'s spending is above your healthy pace. Check your expenses before the next purchase.',
      );
    }
    if (preferences.screenTimeEnabled &&
        health.screenTimeHours >= preferences.screenTimeThreshold &&
        await shouldShow('screen_time')) {
      await _show(
        id: 3,
        title: 'Time for a screen break',
        body:
            'You have used your phone for ${health.screenTimeHours.toStringAsFixed(1)} hours today. Take a 10-minute away-from-screen break now.',
      );
    }
    if (preferences.sleepEnabled &&
        health.sleepHours < preferences.sleepThreshold &&
        await shouldShow('sleep')) {
      await _show(
        id: 4,
        title: 'Protect tonight\'s sleep',
        body:
            'You logged ${health.sleepHours.toStringAsFixed(1)} hours of sleep. Aim for an earlier wind-down tonight.',
      );
    }
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    const android = AndroidNotificationDetails(
      'lifelens_alerts',
      'LifeLens Alerts',
      channelDescription: 'Lifestyle risk alerts from LifeLens',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.private,
      ticker: 'LifeLens private alert',
    );
    const details = NotificationDetails(android: android);
    await _plugin.show(id, title, body, details);
  }
}

class NotificationPreferences {
  const NotificationPreferences({
    this.stressEnabled = true,
    this.spendingEnabled = true,
    this.screenTimeEnabled = true,
    this.sleepEnabled = true,
    this.stressThreshold = 70,
    this.financialHealthThreshold = 60,
    this.screenTimeThreshold = 7,
    this.sleepThreshold = 6,
    this.quietStartMinutes,
    this.quietEndMinutes,
  });

  final bool stressEnabled, spendingEnabled, screenTimeEnabled, sleepEnabled;
  final int stressThreshold, financialHealthThreshold;
  final double screenTimeThreshold, sleepThreshold;
  final int? quietStartMinutes, quietEndMinutes;

  bool get isQuietNow {
    if (quietStartMinutes == null || quietEndMinutes == null) return false;
    final now = DateTime.now();
    final current = now.hour * 60 + now.minute;
    final start = quietStartMinutes!;
    final end = quietEndMinutes!;
    return start <= end
        ? current >= start && current < end
        : current >= start || current < end;
  }

  NotificationPreferences copyWith({
    bool? stressEnabled,
    bool? spendingEnabled,
    bool? screenTimeEnabled,
    bool? sleepEnabled,
    int? stressThreshold,
    int? financialHealthThreshold,
    double? screenTimeThreshold,
    double? sleepThreshold,
    int? quietStartMinutes,
    int? quietEndMinutes,
    bool clearQuietHours = false,
  }) => NotificationPreferences(
    stressEnabled: stressEnabled ?? this.stressEnabled,
    spendingEnabled: spendingEnabled ?? this.spendingEnabled,
    screenTimeEnabled: screenTimeEnabled ?? this.screenTimeEnabled,
    sleepEnabled: sleepEnabled ?? this.sleepEnabled,
    stressThreshold: stressThreshold ?? this.stressThreshold,
    financialHealthThreshold:
        financialHealthThreshold ?? this.financialHealthThreshold,
    screenTimeThreshold: screenTimeThreshold ?? this.screenTimeThreshold,
    sleepThreshold: sleepThreshold ?? this.sleepThreshold,
    quietStartMinutes: clearQuietHours
        ? null
        : quietStartMinutes ?? this.quietStartMinutes,
    quietEndMinutes: clearQuietHours
        ? null
        : quietEndMinutes ?? this.quietEndMinutes,
  );
}
