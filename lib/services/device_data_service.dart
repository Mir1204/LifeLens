import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:usage_stats/usage_stats.dart';

import '../models/app_usage_summary.dart';
import '../models/lifestyle_entry.dart';

class DeviceDataService {
  static const _channel = MethodChannel('lifelens/device_settings');

  final Health _health = Health();

  Future<DailyHealthEntry?> readHealthConnect({
    DailyHealthEntry? current,
  }) async {
    try {
      await _health.configure();
    } catch (e) {
      return null;
    }

    try {
      await Permission.activityRecognition.request();
    } catch (_) {}

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    // Sleep typically starts the evening before (e.g., 20:00 - 23:00) and ends today.
    final sleepQueryStart = todayStart.subtract(const Duration(hours: 14));

    final types = [
      HealthDataType.STEPS,
      HealthDataType.SLEEP_SESSION,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
    ];

    final granted = await _health.requestAuthorization(
      types,
      permissions: types.map((_) => HealthDataAccess.READ).toList(),
    );
    if (!granted) return null;

    final steps = await _health.getTotalStepsInInterval(todayStart, now);

    final sleepTypes = [
      HealthDataType.SLEEP_SESSION,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
    ];

    final points = await _health.getHealthDataFromTypes(
      types: sleepTypes,
      startTime: sleepQueryStart,
      endTime: now,
    );

    var sleepMinutes = 0.0;
    final uniquePoints = _health.removeDuplicates(points);

    // Prefer SLEEP_SESSION if present to avoid double-counting with individual stages.
    final sessions = uniquePoints
        .where((point) => point.type == HealthDataType.SLEEP_SESSION)
        .toList();

    if (sessions.isNotEmpty) {
      for (final session in sessions) {
        final duration = session.dateTo.difference(session.dateFrom).inMinutes;
        if (duration > 0 && duration <= 24 * 60) {
          sleepMinutes += duration;
        }
      }
    } else {
      // Otherwise, sum the stage segments (excluding awake intervals)
      final stages = uniquePoints
          .where((point) => point.type != HealthDataType.SLEEP_SESSION && point.type != HealthDataType.SLEEP_AWAKE)
          .toList();
      for (final point in stages) {
        final duration = point.dateTo.difference(point.dateFrom).inMinutes;
        if (duration > 0 && duration <= 24 * 60) {
          sleepMinutes += duration;
        }
      }
    }

    final fetchedSleep = sleepMinutes > 0 ? sleepMinutes / 60 : (current?.sleepHours ?? 0.0);
    final fetchedSteps = steps ?? (current?.steps ?? 0);

    return DailyHealthEntry(
      sleepHours: fetchedSleep,
      steps: fetchedSteps,
      screenTimeHours: current?.screenTimeHours ?? 0.0,
      source: 'health_connect',
      date: now,
    );
  }

  Future<AppUsageSummary> readAppUsage() async {
    final hasAccess =
        await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
    if (!hasAccess) {
      throw StateError('Usage Access has not been granted.');
    }
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final usage = await UsageStats.queryUsageStats(start, now);
    final filtered =
        usage.where((item) => (item.totalTimeInForegroundMs ?? 0) > 0).toList()
          ..sort(
            (a, b) => (b.totalTimeInForegroundMs ?? 0).compareTo(
              a.totalTimeInForegroundMs ?? 0,
            ),
          );

    final totalSeconds = filtered.fold<int>(
      0,
      (total, item) => total + ((item.totalTimeInForegroundMs ?? 0) ~/ 1000),
    );

    final topUsage = filtered.take(12).toList();
    final packages = topUsage
        .map((item) => item.packageName ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    final labels =
        await _channel.invokeMapMethod<String, dynamic>('resolveAppLabels', {
          'packages': packages,
        }) ??
        {};

    return AppUsageSummary(
      totalHours: totalSeconds / 3600,
      apps: topUsage
          .where((item) => !_isSystemPackage(item.packageName ?? ''))
          .take(5)
          .map((item) {
            final packageName = item.packageName ?? '';
            return UsedApp(
              name: labels[packageName]?.toString() ?? 'App activity',
              packageName: packageName,
              hours: (item.totalTimeInForegroundMs ?? 0) / 3600000,
            );
          })
          .toList(),
    );
  }

  bool _isSystemPackage(String packageName) =>
      packageName.startsWith('com.android.') ||
      packageName.startsWith('com.sec.android.') ||
      packageName.startsWith('com.samsung.android.') ||
      packageName == 'android';

  Future<void> openUsageAccessSettings() async {
    await _channel.invokeMethod<void>('openUsageAccessSettings');
  }
}
