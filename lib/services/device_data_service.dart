import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:usage_stats/usage_stats.dart';

import '../models/app_usage_summary.dart';
import '../models/lifestyle_entry.dart';

class DeviceDataService {
  static const _channel = MethodChannel('lifelens/device_settings');

  final Health _health = Health();

  Future<DailyHealthEntry> readHealthConnect({
    required DailyHealthEntry fallback,
  }) async {
    await _health.configure();
    await Permission.activityRecognition.request();

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final types = [
      HealthDataType.STEPS,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
    ];

    final granted = await _health.requestAuthorization(
      types,
      permissions: types.map((_) => HealthDataAccess.READ).toList(),
    );
    if (!granted) return fallback;

    final steps = await _health.getTotalStepsInInterval(start, now);
    final points = await _health.getHealthDataFromTypes(
      types: types.where((type) => type != HealthDataType.STEPS).toList(),
      startTime: start,
      endTime: now,
    );

    var sleepMinutes = 0.0;
    for (final point in _health.removeDuplicates(points)) {
      final value = point.value;
      if (value is NumericHealthValue) {
        sleepMinutes += value.numericValue.toDouble();
      } else {
        sleepMinutes += point.dateTo.difference(point.dateFrom).inMinutes;
      }
    }

    return DailyHealthEntry(
      sleepHours: sleepMinutes > 0 ? sleepMinutes / 60 : fallback.sleepHours,
      steps: steps ?? fallback.steps,
      screenTimeHours: fallback.screenTimeHours,
    );
  }

  Future<AppUsageSummary> readAppUsage() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final usage = await UsageStats.queryUsageStats(start, now);
    final filtered = usage
        .where((item) => (item.totalTimeInForegroundMs ?? 0) > 0)
        .toList()
      ..sort(
        (a, b) => (b.totalTimeInForegroundMs ?? 0).compareTo(
          a.totalTimeInForegroundMs ?? 0,
        ),
      );

    final totalSeconds = filtered.fold<int>(
      0,
      (total, item) => total + ((item.totalTimeInForegroundMs ?? 0) ~/ 1000),
    );

    return AppUsageSummary(
      totalHours: totalSeconds / 3600,
      apps: filtered
          .take(5)
          .map(
            (item) => UsedApp(
              name: item.packageName ?? 'Unknown app',
              packageName: item.packageName ?? '',
              hours: (item.totalTimeInForegroundMs ?? 0) / 3600000,
            ),
          )
          .toList(),
    );
  }

  Future<void> openUsageAccessSettings() async {
    await _channel.invokeMethod<void>('openUsageAccessSettings');
  }
}
