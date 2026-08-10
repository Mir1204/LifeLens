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

  static const defaultBackendUrl = 'http://127.0.0.1:8000';

  AppUser user;
  final LocalDatabaseService database = LocalDatabaseService();
  final NotificationService notificationService = NotificationService();

  LifestyleScores? remoteScores;
  AppUsageSummary? appUsage;
  List<ScoreSnapshot> scoreHistory = [];
  String backendUrl = defaultBackendUrl;
  bool isLoading = true;
  bool isSyncing = false;
  bool isTestingBackend = false;
  bool backendSyncConsent = false;
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

    final savedBackendUrl = await database.setting('backend_url');
    backendUrl = _normalizeBackendUrl(savedBackendUrl);
    if (savedBackendUrl != backendUrl) {
      await database.saveSetting('backend_url', backendUrl);
    }
    backendSyncConsent =
        await database.setting('backend_sync_consent') == 'true';

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

  String _normalizeBackendUrl(String? savedUrl) {
    final url = savedUrl?.trim().replaceAll(RegExp(r'/+$'), '');
    if (url == null || url.isEmpty) return defaultBackendUrl;
    if (url == 'http://172.20.10.2:8000' || url == 'http://172.20.10.3:8000') {
      return defaultBackendUrl;
    }
    return url;
  }

  Future<void> addExpense(ExpenseEntry entry) async {
    remoteScores = null;
    final id = await database.insertExpense(user.userId, entry);
    expenses.insert(0, entry.copyWith(id: id));
    await recordLocalScoreSnapshot();
    await _persistDailyEntry();
    notifyListeners();
  }

  Future<void> updateExpense(ExpenseEntry updated) async {
    if (updated.id == null) return;
    remoteScores = null;
    final index = expenses.indexWhere((expense) => expense.id == updated.id);
    if (index == -1) return;
    expenses[index] = updated;
    await database.updateExpense(updated);
    await recordLocalScoreSnapshot();
    await _persistDailyEntry();
    notifyListeners();
  }

  Future<void> updateUserProfile(AppUser updatedUser) async {
    user = updatedUser;
    remoteScores = null;
    await database.updateUserProfile(updatedUser);
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
    if (!backendSyncConsent) {
      syncError =
          'Backend sync needs consent. Enable privacy consent in Profile first.';
      notifyListeners();
      return;
    }

    isSyncing = true;
    syncError = null;
    notifyListeners();

    try {
      remoteScores = await PredictionApiService(baseUrl: backendUrl).predict(
        PredictionPayload(
          userId: backendUserId,
          health: health,
          dailySpending: todaySpending,
          calendarEvents: tasks.length,
          highPriorityTasks: highPriorityTasks,
          totalWorkload: totalWorkload,
          monthlyBudget: monthlySpendingBudget > 0
              ? monthlySpendingBudget
              : null,
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

  Future<void> saveBackendSyncConsent(bool value) async {
    backendSyncConsent = value;
    await database.saveSetting('backend_sync_consent', value.toString());
    if (!value) {
      remoteScores = null;
      lastSyncedAt = null;
      syncError = null;
    }
    notifyListeners();
  }

  String get backendUserId => 'anon_${_stableHash(user.userId)}';

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

  Future<void> loadDemoData({required bool highRisk}) async {
    remoteScores = null;
    final now = DateTime.now();

    health = DailyHealthEntry(
      sleepHours: highRisk ? 4.8 : 7.6,
      steps: highRisk ? 1800 : 9200,
      screenTimeHours: highRisk ? 8.4 : 3.2,
      source: 'demo',
    );
    await database.insertHealth(user.userId, health);

    if (highRisk) {
      await addExpense(
        ExpenseEntry(
          amount: 950,
          category: 'Shopping',
          date: now,
          note: 'Demo spike',
          recurringLabel: null,
        ),
      );
      await addTask(
        PlannerEntry(
          title: 'Finish urgent project review',
          date: now,
          priority: TaskPriority.high,
          workload: 5,
        ),
      );
      await addTask(
        PlannerEntry(
          title: 'Prepare presentation changes',
          date: now,
          priority: TaskPriority.high,
          workload: 4,
        ),
      );
    } else {
      await addExpense(
        ExpenseEntry(
          amount: 120,
          category: 'Food',
          date: now,
          note: 'Demo balanced day',
          recurringLabel: 'Snacks',
        ),
      );
      await addTask(
        PlannerEntry(
          title: 'Review notes calmly',
          date: now,
          priority: TaskPriority.medium,
          workload: 2,
        ),
      );
    }

    await recordLocalScoreSnapshot();
    await _persistDailyEntry();
    notifyListeners();
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

  double get monthlySpendingBudget {
    final explicitBudget = user.monthlyBudget;
    if (explicitBudget != null && explicitBudget > 0) return explicitBudget;
    final income = user.monthlyIncome;
    if (income != null && income > 0) return income * .5;
    return 0;
  }

  double get dailySpendingBudget {
    final budget = monthlySpendingBudget;
    if (budget <= 0) return 0;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    return budget / daysInMonth;
  }

  int get highPriorityTasks =>
      tasks.where((task) => task.priority == TaskPriority.high).length;

  int get totalWorkload =>
      tasks.fold(0, (total, task) => total + task.workload);

  LifestyleScores calculateScores() {
    if (remoteScores != null) return remoteScores!;
    return _calculateLocalScores();
  }

  LifestyleScores _calculateLocalScores() {
    final sleepScore = (health.sleepHours / 8 * 100).clamp(0, 100);
    final activityScore = (health.steps / 8000 * 100).clamp(0, 100);
    final focusScore = (100 - (health.screenTimeHours - 4) * 10).clamp(0, 100);
    final workloadPenalty = (totalWorkload * 4).clamp(0, 40);
    final spendingPenalty = _spendingPenalty();

    final productivity =
        ((sleepScore * .30) +
                (activityScore * .25) +
                (focusScore * .30) +
                (100 - workloadPenalty) * .15)
            .round()
            .clamp(0, 100);

    final financialHealth = (100 - spendingPenalty).round().clamp(0, 100);

    final stressRisk =
        ((100 - sleepScore) * .35 +
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

  double _spendingPenalty() {
    final dailyBudget = dailySpendingBudget;
    if (dailyBudget <= 0) return (todaySpending / 20).clamp(0, 45);
    final budgetRatio = todaySpending / dailyBudget;
    return (budgetRatio * 45).clamp(0, 60);
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
      final dailyBudget = dailySpendingBudget;
      if (dailyBudget > 0) {
        items.add(
          'Today spending crossed your daily budget pace. Keep non-essential expenses low.',
        );
      } else {
        items.add('Add income or monthly budget to judge spending accurately.');
      }
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

  String _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in 'lifelens_backend_v1:$value'.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
