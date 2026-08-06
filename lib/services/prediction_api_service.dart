import 'dart:convert';
import 'dart:io';

import '../models/lifestyle_entry.dart';
import '../models/lifestyle_scores.dart';

class PredictionPayload {
  const PredictionPayload({
    required this.userId,
    required this.health,
    required this.dailySpending,
    required this.calendarEvents,
    required this.highPriorityTasks,
    required this.totalWorkload,
  });

  final String userId;
  final DailyHealthEntry health;
  final double dailySpending;
  final int calendarEvents;
  final int highPriorityTasks;
  final int totalWorkload;

  Map<String, Object> toJson() {
    return {
      'user_id': userId,
      'sleep_hours': health.sleepHours,
      'steps': health.steps,
      'screen_time_hours': health.screenTimeHours,
      'daily_spending': dailySpending,
      'calendar_events': calendarEvents,
      'high_priority_tasks': highPriorityTasks,
      'total_workload': totalWorkload,
    };
  }
}

class PredictionApiService {
  const PredictionApiService({this.baseUrl = 'http://172.20.10.2:8000'});

  final String baseUrl;

  Future<bool> healthCheck() async {
    final uri = Uri.parse('$baseUrl/health');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 8));
      return response.statusCode >= 200 && response.statusCode < 300;
    } finally {
      client.close(force: true);
    }
  }

  Future<LifestyleScores> predict(PredictionPayload payload) async {
    final uri = Uri.parse('$baseUrl/predict/daily-score');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);

    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload.toJson()));

      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Backend returned ${response.statusCode}: $body');
      }

      return LifestyleScores.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } finally {
      client.close(force: true);
    }
  }
}
