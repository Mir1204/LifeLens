import 'package:flutter/foundation.dart';

import '../models/app_usage_summary.dart';
import '../models/app_user.dart';
import '../models/lifestyle_entry.dart';
import '../models/lifestyle_scores.dart';
import 'local_database_service.dart';
import 'notification_service.dart';
import 'prediction_api_service.dart';

class LifeLensStore extends ChangeNotifier {
  LifeLensStore({required this.user}) {
    load();
  }

  static const defaultBackendUrl = 'http://172.20.10.2:8000';

  final AppUser user;
  final LocalDatabaseService database = LocalDatabaseService();
  final NotificationService notificationService = NotificationService();

  LifestyleScores? remoteScores;
  AppUsageSummary? appUsage;
  List<ScoreSnapshot> scoreHistory = [];
  String backendUrl = defaultBackendUrl;
  bool isLoading = true;
  bool isSyncing = false;
  bool isTestingBackend = false;
  String? syncError;
  String? backendStatus;
  DateTime? lastSyncedAt;

  final List<ExpenseEntry> expenses = [];

  final List<PlannerEntry> tasks = [];

  DailyHealthEntry health = DailyHealthEntry(
    sleepHours: 6.5,
    steps: 4300,
    screenTimeHours: 6.8,
  );

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    backendUrl =
        await database.setting('backend_url') ?? defaultBackendUrl;

    final loadedExpenses = await database.expenses(user.userId);
    final loadedTasks = await database.tasks(user.userId);
    final latestHealth = await database.latestHealth(user.userId);
    final latestAppUsage = await database.latestAppUsage(user.userId);
    final loadedScores = await database.scoreHistory(user.userId, 7);

    expenses
      ..clear()
      ..addAll(loadedExpenses);
    tasks
      ..clear()
      ..addAll(loadedTasks);
    if (latestHealth != null) health = latestHealth;
    appUsage = latestAppUsage;
    scoreHistory = loadedScores;

    isLoading = false;
    notifyListeners();
  }

  Future<void> addExpense(ExpenseEntry entry) async {
    remoteScores = null;
    expenses.insert(0, entry);
    await database.insertExpense(user.userId, entry);
    await recordLocalScoreSnapshot();
    await _persistDailyEntry();
    notifyListeners();
  }

  Future<void> addTask(PlannerEntry entry) async {
    remoteScores = null;
    tasks.insert(0, entry);
    await database.insertTask(user.userId, entry);
    await recordLocalScoreSnapshot();
    await _persistDailyEntry();
    notifyListeners();
  }

  Future<void> deleteExpense(ExpenseEntry entry) async {
    if (entry.id == null) return;
    expenses.remove(entry);
    await database.softDeleteExpense(entry.id!);
    await recordLocalScoreSnapshot();
    await _persistDailyEntry();
    notifyListeners();
  }

  Future<void> deleteTask(PlannerEntry entry) async {
    if (entry.id == null) return;
    tasks.remove(entry);
    await database.softDeleteTask(entry.id!);
    await recordLocalScoreSnapshot();
    await _persistDailyEntry();
    notifyListeners();
  }

  Future<void> toggleTask(PlannerEntry entry) async {
    if (entry.id == null) return;
    final index = tasks.indexOf(entry);
    if (index == -1) return;
    final updated = entry.copyWith(isCompleted: !entry.isCompleted);
    tasks[index] = updated;
    await database.toggleTaskComplete(entry.id!, done: updated.isCompleted);
    notifyListeners();
  }

  Future<void> updateHealth(DailyHealthEntry entry) async {
    remoteScores = null;
    health = entry;
    await database.insertHealth(user.userId, entry);
    await recordLocalScoreSnapshot();
    await _persistDailyEntry();
    await notificationService.showRiskAlerts(
      scores: calculateScores(),
      health: health,
    );
    notifyListeners();
  }

  void refreshScores() {
    notifyListeners();
  }

  Future<void> syncWithBackend() async {
    isSyncing = true;
    syncError = null;
    notifyListeners();

    try {
      remoteScores = await PredictionApiService(baseUrl: backendUrl).predict(
        PredictionPayload(
          userId: user.userId,
          health: health,
          dailySpending: todaySpending,
          calendarEvents: tasks.length,
          highPriorityTasks: highPriorityTasks,
          totalWorkload: totalWorkload,
        ),
      );
      lastSyncedAt = DateTime.now();
      await _persistScore(remoteScores!);
      await _persistDailyEntry();
      await notificationService.showRiskAlerts(
        scores: remoteScores!,
        health: health,
      );
    } catch (error) {
      syncError = error.toString();
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> saveBackendUrl(String value) async {
    final normalized = value.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized.isEmpty) return;
    backendUrl = normalized;
    await database.saveSetting('backend_url', backendUrl);
    backendStatus = null;
    notifyListeners();
  }

  Future<void> testBackendConnection() async {
    isTestingBackend = true;
    backendStatus = null;
    notifyListeners();

    try {
      final ok = await PredictionApiService(baseUrl: backendUrl).healthCheck();
      backendStatus = ok ? 'Backend is reachable' : 'Backend did not respond';
    } catch (error) {
      backendStatus = 'Backend failed: $error';
    } finally {
      isTestingBackend = false;
      notifyListeners();
    }
  }

  Future<void> saveAppUsage(AppUsageSummary summary) async {
    appUsage = summary;
    await database.replaceScreenTimeApps(user.userId, summary);
    await updateHealth(
      DailyHealthEntry(
        sleepHours: health.sleepHours,
        steps: health.steps,
        screenTimeHours: summary.totalHours,
        source: 'usage_stats',
      ),
    );
  }

  Future<void> recordLocalScoreSnapshot() async {
    await _persistScore(_calculateLocalScores());
  }

  Future<void> _persistScore(LifestyleScores scores) async {
    await database.insertScoreSnapshot(
      userId: user.userId,
      scores: scores,
      spending: todaySpending,
      sleepHours: health.sleepHours,
      screenTimeHours: health.screenTimeHours,
    );
    scoreHistory = await database.scoreHistory(user.userId, 7);
  }

  Future<void> _persistDailyEntry() async {
    await database.upsertDailyEntry(
      userId: user.userId,
      health: health,
      dailySpending: todaySpending,
      calendarEvents: tasks.length,
      highPriorityTasks: highPriorityTasks,
      totalWorkload: totalWorkload,
    );
  }

  double get todaySpending {
    final now = DateTime.now();
    return expenses
        .where((entry) => _isSameDay(entry.date, now))
        .fold(0, (total, entry) => total + entry.amount);
  }

  int get highPriorityTasks =>
      tasks.where((task) => task.priority == TaskPriority.high).length;

  int get totalWorkload => tasks.fold(0, (total, task) => total + task.workload);

  LifestyleScores calculateScores() {
    if (remoteScores != null) return remoteScores!;
    return _calculateLocalScores();
  }

  LifestyleScores _calculateLocalScores() {
    final sleepScore = (health.sleepHours / 8 * 100).clamp(0, 100);
    final activityScore = (health.steps / 8000 * 100).clamp(0, 100);
    final focusScore = (100 - (health.screenTimeHours - 4) * 10).clamp(0, 100);
    final workloadPenalty = (totalWorkload * 4).clamp(0, 40);
    final spendingPenalty = (todaySpending / 20).clamp(0, 45);

    final productivity = ((sleepScore * .30) +
            (activityScore * .25) +
            (focusScore * .30) +
            (100 - workloadPenalty) * .15)
        .round()
        .clamp(0, 100);

    final financialHealth = (100 - spendingPenalty).round().clamp(0, 100);

    final stressRisk = ((100 - sleepScore) * .35 +
            health.screenTimeHours * 5 +
            highPriorityTasks * 10 +
            totalWorkload * 2)
        .round()
        .clamp(0, 100);

    return LifestyleScores(
      productivity: productivity,
      financialHealth: financialHealth,
      stressRisk: stressRisk,
      burnoutRisk: _riskLabel(stressRisk),
      overspendingRisk: _riskLabel(100 - financialHealth),
      recommendations: _recommendations(
        productivity: productivity,
        financialHealth: financialHealth,
        stressRisk: stressRisk,
      ),
    );
  }

  List<String> _recommendations({
    required int productivity,
    required int financialHealth,
    required int stressRisk,
  }) {
    final items = <String>[];
    if (health.sleepHours < 7) {
      items.add('Sleep is below target. Try a fixed sleep time tonight.');
    }
    if (health.screenTimeHours > 6) {
      items.add('Screen time is high. Reduce late-night phone usage.');
    }
    if (financialHealth < 70) {
      items.add('Spending is rising today. Avoid non-essential expenses.');
    }
    if (stressRisk > 65) {
      items.add('Stress risk is high. Move one low-priority task to tomorrow.');
    }
    if (productivity >= 75 && stressRisk < 55) {
      items.add('Your routine is balanced today. Keep the same rhythm.');
    }
    return items;
  }

  String _riskLabel(int value) {
    if (value >= 70) return 'High';
    if (value >= 40) return 'Medium';
    return 'Low';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
