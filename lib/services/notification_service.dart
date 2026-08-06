import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/lifestyle_entry.dart';
import '../models/lifestyle_scores.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showRiskAlerts({
    required LifestyleScores scores,
    required DailyHealthEntry health,
  }) async {
    if (scores.stressRisk >= 70) {
      await _show(
        id: 1,
        title: 'High stress risk',
        body: 'Stress risk is ${scores.stressRisk}. Reduce one task today.',
      );
    }
    if (scores.financialHealth <= 60) {
      await _show(
        id: 2,
        title: 'Spending alert',
        body: 'Financial health is low. Review today\'s expenses.',
      );
    }
    if (health.screenTimeHours >= 7) {
      await _show(
        id: 3,
        title: 'Screen time is high',
        body:
            'Phone usage is ${health.screenTimeHours.toStringAsFixed(1)} hours today.',
      );
    }
    if (health.sleepHours < 6) {
      await _show(
        id: 4,
        title: 'Sleep is low',
        body: 'Sleep is below 6 hours. Plan an earlier bedtime tonight.',
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
    );
    const details = NotificationDetails(android: android);
    await _plugin.show(id, title, body, details);
  }
}
