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
  static final ValueNotifier<NotificationDestination?> destinationNotifier =
      ValueNotifier(null);

  static Future<void> initialize({bool requestPermission = true}) async {
    tz.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _handleNotificationResponse(launchDetails!.notificationResponse!);
    }
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
    if (!await requestPermission()) return;
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
      payload: 'task:$id',
    );
  }

  Future<void> cancelTaskReminder(int id) => _plugin.cancel(10000 + id);

  Future<void> cancelDailyRoutine(int id) => _plugin.cancel(20000 + id);

  Future<void> scheduleDailyRoutine({
    required int id,
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    if (!await requestPermission()) return;
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

  Future<bool> showTestNotification() async {
    if (!await requestPermission()) return false;
    await _show(
      id: 999,
      title: 'LifeLens notifications are ready',
      body: 'This is a test notification. Your alert settings are working.',
      payload: 'today',
    );
    return true;
  }

  static void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    destinationNotifier.value = NotificationDestination.fromPayload(payload);
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
    if (!await requestPermission()) return;
    if (preferences.stressEnabled &&
        scores.stressRisk >= preferences.stressThreshold &&
        await shouldShow('stress')) {
      await _show(
        id: 1,
        title: 'Take one task off your plate',
        body:
            'Your stress risk is high today (${scores.stressRisk}/100). Move or simplify one non-essential task.',
        payload: 'today',
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
        payload: 'money',
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
        payload: 'trends',
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
        payload: 'trends',
      );
    }
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    String? payload,
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
    await _plugin.show(id, title, body, details, payload: payload);
  }
}

class NotificationDestination {
  const NotificationDestination._(this.tabIndex, {this.taskId});

  final int tabIndex;
  final int? taskId;

  factory NotificationDestination.fromPayload(String payload) {
    if (payload.startsWith('task:')) {
      return NotificationDestination._(
        2,
        taskId: int.tryParse(payload.substring(5)),
      );
    }
    return switch (payload) {
      'money' => const NotificationDestination._(1),
      'trends' => const NotificationDestination._(3),
      _ => const NotificationDestination._(0),
    };
  }
}

class RoutineReminderPreferences {
  const RoutineReminderPreferences({
    this.bedtimeEnabled = false,
    this.screenBreakEnabled = false,
    this.budgetCheckEnabled = false,
    this.checkInEnabled = false,
    this.bedtimeMinutes = 1320,
    this.screenBreakMinutes = 900,
    this.budgetCheckMinutes = 1140,
    this.checkInMinutes = 1200,
  });

  final bool bedtimeEnabled;
  final bool screenBreakEnabled;
  final bool budgetCheckEnabled;
  final bool checkInEnabled;
  final int bedtimeMinutes;
  final int screenBreakMinutes;
  final int budgetCheckMinutes;
  final int checkInMinutes;

  RoutineReminderPreferences copyWith({
    bool? bedtimeEnabled,
    bool? screenBreakEnabled,
    bool? budgetCheckEnabled,
    bool? checkInEnabled,
    int? bedtimeMinutes,
    int? screenBreakMinutes,
    int? budgetCheckMinutes,
    int? checkInMinutes,
  }) => RoutineReminderPreferences(
    bedtimeEnabled: bedtimeEnabled ?? this.bedtimeEnabled,
    screenBreakEnabled: screenBreakEnabled ?? this.screenBreakEnabled,
    budgetCheckEnabled: budgetCheckEnabled ?? this.budgetCheckEnabled,
    checkInEnabled: checkInEnabled ?? this.checkInEnabled,
    bedtimeMinutes: bedtimeMinutes ?? this.bedtimeMinutes,
    screenBreakMinutes: screenBreakMinutes ?? this.screenBreakMinutes,
    budgetCheckMinutes: budgetCheckMinutes ?? this.budgetCheckMinutes,
    checkInMinutes: checkInMinutes ?? this.checkInMinutes,
  );
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
    this.dailyAlertLimit = 2,
    this.quietStartMinutes,
    this.quietEndMinutes,
  });

  final bool stressEnabled, spendingEnabled, screenTimeEnabled, sleepEnabled;
  final int stressThreshold, financialHealthThreshold, dailyAlertLimit;
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
    int? dailyAlertLimit,
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
    dailyAlertLimit: dailyAlertLimit ?? this.dailyAlertLimit,
    quietStartMinutes: clearQuietHours
        ? null
        : quietStartMinutes ?? this.quietStartMinutes,
    quietEndMinutes: clearQuietHours
        ? null
        : quietEndMinutes ?? this.quietEndMinutes,
  );
}
