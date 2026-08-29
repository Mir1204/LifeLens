import 'dart:convert';
import 'dart:io';

import '../models/lifestyle_entry.dart';
import '../models/lifestyle_scores.dart';

class PredictionPayload {
  const PredictionPayload({
    required this.health,
    required this.dailySpending,
    required this.calendarEvents,
    required this.highPriorityTasks,
    required this.totalWorkload,
    this.monthlyBudget,
  });

  final DailyHealthEntry health;
  final double dailySpending;
  final int calendarEvents;
  final int highPriorityTasks;
  final int totalWorkload;
  final double? monthlyBudget;

  Map<String, Object> toJson() {
    return {
      'sleep_hours': health.sleepHours,
      'steps': health.steps,
      'screen_time_hours': health.screenTimeHours,
      'daily_spending': dailySpending,
      'calendar_events': calendarEvents,
      'high_priority_tasks': highPriorityTasks,
      'total_workload': totalWorkload,
      // Keep the day with the aggregate even though the UI does not display it.
      // The backend uses it to build correct 3-day and 7-day windows.
      'entry_date': _dayKey(health.date),
      if (monthlyBudget != null) 'monthly_budget': monthlyBudget!,
    };
  }

  String _dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class PredictionApiService {
  const PredictionApiService({
    this.baseUrl = 'https://lifelens-backend-xh56.onrender.com',
  });

  final String baseUrl;

  Future<bool> healthCheck() async {
    final uri = Uri.parse('$baseUrl/health');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } finally {
      client.close(force: true);
    }
  }

  Future<LifestyleScores> predict(
    PredictionPayload payload, {
    required String accessToken,
  }) async {
    final uri = Uri.parse('$baseUrl/predict/daily-score');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 60);

    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      request.write(jsonEncode(payload.toJson()));

      final response = await request.close().timeout(
        const Duration(seconds: 90),
      );
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Backend returned ${response.statusCode}: $body');
      }

      return LifestyleScores.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } finally {
      client.close(force: true);
    }
  }

  Future<String> refreshAccessToken({required String refreshToken}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl/auth/refresh'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'refresh_token': refreshToken}));
      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const HttpException(
          'Your session has expired. Please sign in again.',
        );
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final accessToken = data['access_token'] as String?;
      final nextRefreshToken = data['refresh_token'] as String?;
      if (accessToken == null || nextRefreshToken == null) {
        throw const HttpException('Server returned invalid session tokens.');
      }
      return jsonEncode({'access': accessToken, 'refresh': nextRefreshToken});
    } finally {
      client.close(force: true);
    }
  }

  Future<void> deleteMyData({required String accessToken}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.deleteUrl(Uri.parse('$baseUrl/me/data'));
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      if (response.statusCode != 204) {
        throw const HttpException('Backend could not delete the account data.');
      }
    } finally {
      client.close(force: true);
    }
  }
}
