import '../models/lifestyle_entry.dart';
import '../models/lifestyle_scores.dart';

class PredictionPayload {
  const PredictionPayload({
    required this.health,
    required this.dailySpending,
    required this.calendarEvents,
    required this.highPriorityTasks,
  });

  final DailyHealthEntry health;
  final double dailySpending;
  final int calendarEvents;
  final int highPriorityTasks;

  Map<String, Object> toJson() {
    return {
      'sleep_hours': health.sleepHours,
      'steps': health.steps,
      'screen_time_hours': health.screenTimeHours,
      'daily_spending': dailySpending,
      'calendar_events': calendarEvents,
      'high_priority_tasks': highPriorityTasks,
    };
  }
}

class PredictionApiService {
  const PredictionApiService({this.baseUrl = 'http://10.0.2.2:8000'});

  final String baseUrl;

  Future<LifestyleScores?> predict(PredictionPayload payload) async {
    // Mark's FastAPI endpoint can be connected here once it is ready.
    // Suggested endpoint: POST /predict/daily-score with payload.toJson().
    return null;
  }
}
