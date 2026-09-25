import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../models/lifestyle_entry.dart';
import '../models/lifestyle_scores.dart';
import 'device_data_service.dart';
import 'local_database_service.dart';
import 'notification_service.dart';
import 'prediction_api_service.dart';
import 'secure_storage_service.dart';

const _backgroundSyncTask = 'lifelens.background_daily_sync';
const _backgroundSyncWorkName = 'lifelens.background_daily_sync.work';
const _initialBackgroundSyncWorkName = 'lifelens.background_initial_sync.work';

@pragma('vm:entry-point')
void lifeLensBackgroundDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    if (taskName != _backgroundSyncTask) return true;
    return BackgroundSyncService().run();
  });
}

class BackgroundSyncService {
  Future<void> schedule() async {
    await Workmanager().cancelByUniqueName(_backgroundSyncWorkName);
    await Workmanager().registerPeriodicTask(
      _backgroundSyncWorkName,
      _backgroundSyncTask,
      frequency: const Duration(minutes: 15),
    );
    await Workmanager().registerOneOffTask(
      _initialBackgroundSyncWorkName,
      _backgroundSyncTask,
    );
    await LocalDatabaseService().saveSetting(
      'background_sync_scheduled_at',
      DateTime.now().toIso8601String(),
    );
  }

  Future<bool> run() async {
    try {
      final database = LocalDatabaseService();
      await database.saveSetting(
        'background_sync_last_attempt_at',
        DateTime.now().toIso8601String(),
      );
      final user = await database.signedInUser();
      if (user == null) return true;

      var health =
          await database.latestHealth(user.userId) ??
          DailyHealthEntry(sleepHours: 0, steps: 0, screenTimeHours: 0);
      final device = DeviceDataService();
      try {
        health = await device.readHealthConnect(fallback: health);
        final usage = await device.readAppUsage();
        await database.replaceScreenTimeApps(user.userId, usage);
        health = DailyHealthEntry(
          sleepHours: health.sleepHours,
          steps: health.steps,
          screenTimeHours: usage.totalHours,
          source: 'background_device_sync',
          date: usage.updatedAt,
        );
      } catch (_) {
        // Permission can be unavailable in a headless worker; sync the last
        // safely stored daily values instead of failing the whole job.
      }
      final now = DateTime.now();
      if (health.date.year != now.year ||
          health.date.month != now.month ||
          health.date.day != now.day) {
        health = DailyHealthEntry(
          sleepHours: health.sleepHours,
          steps: health.steps,
          screenTimeHours: health.screenTimeHours,
          source: health.source,
          date: now,
        );
      }
      await database.insertHealth(user.userId, health);

      final tasks = await database.tasks(user.userId);
      final expenses = await database.expenses(user.userId);
      final isSameDay = (DateTime value) =>
          value.year == health.date.year &&
          value.month == health.date.month &&
          value.day == health.date.day;
      final dayTasks = tasks.where(
        (task) => !task.isCompleted && isSameDay(task.date),
      );
      final spending = expenses
          .where((expense) => isSameDay(expense.date))
          .fold<double>(0, (sum, expense) => sum + expense.amount);
      final highPriority = dayTasks
          .where((task) => task.priority.name == 'high')
          .length;
      final workload = dayTasks.fold<int>(
        0,
        (sum, task) => sum + task.workload,
      );
      await database.upsertDailyEntry(
        userId: user.userId,
        health: health,
        dailySpending: spending,
        calendarEvents: dayTasks.length,
        highPriorityTasks: highPriority,
        totalWorkload: workload,
      );

      if (await database.setting('backend_sync_consent') != 'true') {
        await database.saveSetting(
          'background_sync_last_at',
          DateTime.now().toIso8601String(),
        );
        await database.saveSetting(
          'background_sync_last_error',
          'Backend sync is disabled in Profile settings.',
        );
        return true;
      }
      final secureStorage = SecureStorageService();
      var token = await secureStorage.token();
      if (token == null) return true;
      final backendUrl =
          await database.setting('backend_url') ??
          'https://lifelens-backend-xh56.onrender.com';
      final api = PredictionApiService(baseUrl: backendUrl);
      final payload = PredictionPayload(
        health: health,
        dailySpending: spending,
        calendarEvents: dayTasks.length,
        highPriorityTasks: highPriority,
        totalWorkload: workload,
        monthlyBudget: user.monthlyBudget,
      );
      LifestyleScores scores;
      try {
        scores = await api.predict(payload, accessToken: token);
      } on HttpException catch (error) {
        if (!error.message.contains('401')) rethrow;
        final refresh = await secureStorage.refreshToken();
        if (refresh == null) rethrow;
        final renewed =
            jsonDecode(await api.refreshAccessToken(refreshToken: refresh))
                as Map<String, dynamic>;
        token = renewed['access'] as String;
        await secureStorage.saveToken(token);
        await secureStorage.saveRefreshToken(renewed['refresh'] as String);
        scores = await api.predict(payload, accessToken: token);
      }
      await NotificationService.initialize(requestPermission: false);
      await NotificationService().showRiskAlerts(
        scores: scores,
        health: health,
        preferences: NotificationPreferences(
          stressEnabled:
              (await database.setting('notify_stress_enabled')) != 'false',
          spendingEnabled:
              (await database.setting('notify_spending_enabled')) != 'false',
          screenTimeEnabled:
              (await database.setting('notify_screen_enabled')) != 'false',
          sleepEnabled:
              (await database.setting('notify_sleep_enabled')) != 'false',
          stressThreshold:
              int.tryParse(
                await database.setting('notify_stress_threshold') ?? '',
              ) ??
              70,
          financialHealthThreshold:
              int.tryParse(
                await database.setting('notify_financial_threshold') ?? '',
              ) ??
              60,
          screenTimeThreshold:
              double.tryParse(
                await database.setting('notify_screen_threshold') ?? '',
              ) ??
              7,
          sleepThreshold:
              double.tryParse(
                await database.setting('notify_sleep_threshold') ?? '',
              ) ??
              6,
          quietStartMinutes: int.tryParse(
            await database.setting('notify_quiet_start') ?? '',
          ),
          quietEndMinutes: int.tryParse(
            await database.setting('notify_quiet_end') ?? '',
          ),
        ),
        shouldShow: (type) async {
          final day = health.date.toIso8601String().substring(0, 10);
          final key = 'risk_alert_${user.userId}_${type}_$day';
          if (await database.setting(key) == 'sent') return false;
          await database.saveSetting(key, 'sent');
          return true;
        },
      );
      await database.saveSetting(
        'background_sync_last_at',
        DateTime.now().toIso8601String(),
      );
      await database.saveSetting('background_sync_last_error', '');
      return true;
    } catch (error) {
      final database = LocalDatabaseService();
      await database.saveSetting(
        'background_sync_last_error',
        error.toString(),
      );
      return false;
    }
  }
}
