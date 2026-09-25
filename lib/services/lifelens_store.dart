import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/app_usage_summary.dart';
import '../models/app_user.dart';
import '../models/lifestyle_entry.dart';
import '../models/lifestyle_scores.dart';
import '../models/wellbeing_models.dart';
import 'device_data_service.dart';
import 'google_calendar_service.dart';
import 'local_database_service.dart';
import 'notification_service.dart';
import 'prediction_api_service.dart';
import 'secure_storage_service.dart';

class LifeLensStore extends ChangeNotifier {
  LifeLensStore({required this.user}) {
    load();
  }

  static const defaultBackendUrl = 'https://lifelens-backend-xh56.onrender.com';

  AppUser user;
  final LocalDatabaseService database = LocalDatabaseService();
  final NotificationService notificationService = NotificationService();

  LifestyleScores? remoteScores;
  AppUsageSummary? appUsage;
  List<ScoreSnapshot> scoreHistory = [];
  String backendUrl = defaultBackendUrl;
  bool isLoading = true;
  bool isSyncing = false;
  bool isOnline = true;
  bool backendSyncConsent = false;
  bool isTestingBackend = false;
  String? syncError;
  String? backendStatus;
  DateTime? lastSyncedAt;
  DateTime? lastBackgroundSyncedAt;
  DateTime? backgroundSyncScheduledAt;
  String? lastBackgroundSyncError;
  NotificationPreferences notificationPreferences =
      const NotificationPreferences();
  Timer? _connectivityTimer;
  Timer? _deviceRefreshTimer;
  final DeviceDataService _deviceDataService = DeviceDataService();
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();
  final SecureStorageService _secureStorage = SecureStorageService();

  final List<ExpenseEntry> expenses = [];

  final List<PlannerEntry> tasks = [];
  List<DailyCheckIn> checkIns = [];
  List<String> customExpenseCategories = [];
  List<String> customRecurringLabels = [];
  UserGoals goals = const UserGoals();
  List<Map<String, Object?>> pendingSyncItems = [];

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

    final savedConsent = await database.setting('backend_sync_consent');
    backendSyncConsent = savedConsent == 'true';
    notificationPreferences = NotificationPreferences(
      stressEnabled:
          (await database.setting('notify_stress_enabled')) != 'false',
      spendingEnabled:
          (await database.setting('notify_spending_enabled')) != 'false',
      screenTimeEnabled:
          (await database.setting('notify_screen_enabled')) != 'false',
      sleepEnabled: (await database.setting('notify_sleep_enabled')) != 'false',
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
    );
    lastBackgroundSyncedAt = DateTime.tryParse(
      await database.setting('background_sync_last_at') ?? '',
    );
    backgroundSyncScheduledAt = DateTime.tryParse(
      await database.setting('background_sync_scheduled_at') ?? '',
    );
    lastBackgroundSyncError = await database.setting(
      'background_sync_last_error',
    );

    final loadedExpenses = await database.expenses(user.userId);
    final loadedTasks = await database.tasks(user.userId);
    final latestHealth = await database.latestHealth(user.userId);
    final latestAppUsage = await database.latestAppUsage(user.userId);
    final loadedScores = await database.scoreHistory(user.userId, 7);
    final loadedCheckIns = await database.checkIns(user.userId);
    final pendingItems = await database.pendingSyncItems(user.userId);

    expenses
      ..clear()
      ..addAll(loadedExpenses);
    tasks
      ..clear()
      ..addAll(loadedTasks);
    if (latestHealth != null) health = latestHealth;
    appUsage = latestAppUsage;
    scoreHistory = loadedScores;
    checkIns = loadedCheckIns;
    pendingSyncItems = pendingItems;
    customExpenseCategories = _savedStringList(
      await database.setting('expense_categories_${user.userId}'),
    );
    customRecurringLabels = _savedStringList(
      await database.setting('expense_recurring_labels_${user.userId}'),
    );
    goals = UserGoals(
      sleepHours:
          double.tryParse(await database.setting('goal_sleep_hours') ?? '') ??
          7.5,
      steps: int.tryParse(await database.setting('goal_steps') ?? '') ?? 8000,
      screenTimeHours:
          double.tryParse(await database.setting('goal_screen_hours') ?? '') ??
          5,
      monthlyBudget:
          double.tryParse(
            await database.setting('goal_monthly_budget') ?? '',
          ) ??
          monthlySpendingBudget,
    );

    isLoading = false;
    notifyListeners();

    _autoFetchHealthData();
    _startDeviceRefreshLoop();
    _startConnectivityLoop();
  }

  List<String> _savedStringList(String? raw) {
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .toSet()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addCustomExpenseCategory(String value) async {
    final clean = value.trim();
    if (clean.isEmpty || customExpenseCategories.contains(clean)) return;
    customExpenseCategories = [...customExpenseCategories, clean];
    await database.saveSetting(
      'expense_categories_${user.userId}',
      jsonEncode(customExpenseCategories),
    );
    notifyListeners();
  }

  Future<void> addCustomRecurringLabel(String value) async {
    final clean = value.trim();
    if (clean.isEmpty || customRecurringLabels.contains(clean)) return;
    customRecurringLabels = [...customRecurringLabels, clean];
    await database.saveSetting(
      'expense_recurring_labels_${user.userId}',
      jsonEncode(customRecurringLabels),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _deviceRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _autoFetchHealthData() async {
    DailyHealthEntry newHealth = health;
    try {
      newHealth = await _deviceDataService.readHealthConnect(fallback: health);
    } catch (e) {
      debugPrint('Health Connect refresh failed: $e');
    }
    try {
      final newUsage = await _deviceDataService.readAppUsage();
      appUsage = newUsage;
      await database.replaceScreenTimeApps(user.userId, newUsage);
      newHealth = DailyHealthEntry(
        sleepHours: newHealth.sleepHours,
        steps: newHealth.steps,
        screenTimeHours: newUsage.totalHours,
        source: 'device_sync',
        date: newUsage.updatedAt,
      );
    } catch (e) {
      debugPrint('Screen-time refresh failed: $e');
    }
    final today = DateTime.now();
    if (!_isSameDay(newHealth.date, today)) {
      newHealth = DailyHealthEntry(
        sleepHours: newHealth.sleepHours,
        steps: newHealth.steps,
        screenTimeHours: newHealth.screenTimeHours,
        source: newHealth.source,
        date: today,
      );
    }
    health = newHealth;
    await database.insertHealth(user.userId, health);
    await recordLocalScoreSnapshot();
    await _persistDailyEntry();
    await _showRiskAlerts(_calculateLocalScores());
    notifyListeners();
    await syncWithBackend();
  }

  void _startDeviceRefreshLoop() {
    _deviceRefreshTimer?.cancel();
    // Usage Stats and Health Connect are re-read while the app is open, so the
    // Trends page no longer depends on the manual refresh buttons.
    _deviceRefreshTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _autoFetchHealthData();
    });
  }

  void _startConnectivityLoop() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 15), (
      timer,
    ) async {
      if (isSyncing) return;
      try {
        final result = await InternetAddress.lookup('google.com');
        final nowOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        final wasOffline = !isOnline;
        isOnline = nowOnline;
        if (nowOnline && (wasOffline || lastSyncedAt == null)) {
          syncWithBackend();
        }
        notifyListeners();
      } on SocketException catch (_) {
        if (isOnline) {
          isOnline = false;
          notifyListeners();
        }
      }
    });
  }

  String _normalizeBackendUrl(String? savedUrl) {
    final url = savedUrl?.trim().replaceAll(RegExp(r'/+$'), '');
    if (url == null || url.isEmpty) return defaultBackendUrl;
    if (url == 'http://172.20.10.2:8000' ||
        url == 'http://172.20.10.3:8000' ||
        url == 'http://127.0.0.1:8000' ||
        url == 'http://localhost:8000') {
      return defaultBackendUrl;
    }
    // Sensitive health and account data must never be sent over cleartext.
    return Uri.tryParse(url)?.scheme == 'https' ? url : defaultBackendUrl;
  }

  Future<void> addExpense(ExpenseEntry entry, {bool showAlerts = true}) async {
    remoteScores = null;
    final id = await database.insertExpense(user.userId, entry);
    expenses.insert(0, entry.copyWith(id: id));
    await recordLocalScoreSnapshot();
    await _persistDailyEntry();
    if (showAlerts) await _showRiskAlerts(_calculateLocalScores());
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

  Future<void> addTask(
    PlannerEntry entry, {
    bool addToGoogleCalendar = false,
    bool showAlerts = true,
  }) async {
    remoteScores = null;
    final id = await database.insertTask(user.userId, entry);
    var savedEntry = entry.copyWith(id: id);
    tasks.insert(0, savedEntry);
    await recordLocalScoreSnapshot();
    await _persistDailyEntry();
    if (showAlerts) await _showRiskAlerts(_calculateLocalScores());
    if (addToGoogleCalendar) {
      try {
        final eventId = await _googleCalendarService.addTask(savedEntry);
        await database.updateTaskCalendarEventId(id, eventId);
        savedEntry = savedEntry.copyWith(googleCalendarEventId: eventId);
        tasks[0] = savedEntry;
      } catch (error) {
        await database.enqueueSync(
          userId: user.userId,
          entityType: 'calendar_task',
          entityId: id,
          operation: 'create',
          payload: entry.title,
          error: error.toString(),
        );
      }
    }
    await _scheduleTaskReminder(savedEntry);
    pendingSyncItems = await database.pendingSyncItems(user.userId);
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

  Future<void> updateTask(PlannerEntry entry) async {
    if (entry.id == null) return;
    final index = tasks.indexWhere((task) => task.id == entry.id);
    if (index == -1) return;
    await database.updateTask(entry);
    tasks[index] = entry;
    if (entry.googleCalendarEventId != null) {
      try {
        await _googleCalendarService.updateTask(entry);
      } catch (error) {
        await database.enqueueSync(
          userId: user.userId,
          entityType: 'calendar_task',
          entityId: entry.id,
          operation: 'update',
          payload: entry.title,
          error: error.toString(),
        );
      }
    }
    if (entry.reminderMinutes == null) {
      await notificationService.cancelTaskReminder(entry.id!);
    } else {
      await _scheduleTaskReminder(entry);
    }
    await recordLocalScoreSnapshot();
    await _persistDailyEntry();
    notifyListeners();
  }

  Future<void> deleteTask(PlannerEntry entry) async {
    if (entry.id == null) return;
    if (entry.googleCalendarEventId != null) {
      try {
        await _googleCalendarService.deleteEvent(entry.googleCalendarEventId!);
      } catch (error) {
        await database.enqueueSync(
          userId: user.userId,
          entityType: 'calendar_task',
          entityId: entry.id,
          operation: 'delete',
          payload: entry.googleCalendarEventId!,
          error: error.toString(),
        );
      }
    }
    await notificationService.cancelTaskReminder(entry.id!);
    tasks.remove(entry);
    await database.softDeleteTask(entry.id!);
    await recordLocalScoreSnapshot();
    await _persistDailyEntry();
    pendingSyncItems = await database.pendingSyncItems(user.userId);
    notifyListeners();
  }

  Future<void> toggleTask(PlannerEntry entry) async {
    if (entry.id == null) return;
    final index = tasks.indexOf(entry);
    if (index == -1) return;
    final updated = entry.copyWith(isCompleted: !entry.isCompleted);
    tasks[index] = updated;
    await database.toggleTaskComplete(entry.id!, done: updated.isCompleted);
    if (updated.googleCalendarEventId != null) {
      try {
        await _googleCalendarService.updateTaskCompletion(updated);
      } catch (error) {
        debugPrint('Calendar completion update failed: $error');
      }
    }
    // Auto-delete completed task after a delay (15 seconds)
    if (updated.isCompleted) {
      Timer(const Duration(seconds: 15), () async {
        // Verify task still exists and is completed before deleting
        final matches = tasks.where((t) => t.id == updated.id && t.isCompleted);
        if (matches.isNotEmpty) {
          await deleteTask(matches.first);
        }
      });
    }
    notifyListeners();
  }

  Future<void> updateHealth(DailyHealthEntry entry) async {
    remoteScores = null;
    health = entry;
    await database.insertHealth(user.userId, entry);
    await recordLocalScoreSnapshot();
    await _persistDailyEntry();
    await _showRiskAlerts(calculateScores());
    notifyListeners();
    await syncWithBackend();
  }

  void refreshScores() {
    notifyListeners();
  }

  Future<void> syncWithBackend() async {
    if (isSyncing) return;
    if (!backendSyncConsent) {
      syncError = null;
      return;
    }

    isSyncing = true;
    syncError = null;
    notifyListeners();

    try {
      final accessToken = await _secureStorage.token();
      if (accessToken == null)
        throw Exception('Sign in again to enable protected backend sync.');
      final api = PredictionApiService(baseUrl: backendUrl);
      final isUp = await api.healthCheck();
      if (!isUp) throw Exception('Backend is down');
      final payload = PredictionPayload(
        health: health,
        dailySpending: spendingForDay(health.date),
        calendarEvents: taskCountForDay(health.date),
        highPriorityTasks: highPriorityTasksForDay(health.date),
        totalWorkload: totalWorkloadForDay(health.date),
        monthlyBudget: monthlySpendingBudget > 0 ? monthlySpendingBudget : null,
      );
      try {
        remoteScores = await api.predict(payload, accessToken: accessToken);
      } on HttpException catch (error) {
        if (!error.message.contains('401')) rethrow;
        final refreshToken = await _secureStorage.refreshToken();
        if (refreshToken == null) rethrow;
        final refreshed =
            jsonDecode(await api.refreshAccessToken(refreshToken: refreshToken))
                as Map<String, dynamic>;
        final refreshedAccessToken = refreshed['access'] as String;
        await _secureStorage.saveToken(refreshedAccessToken);
        await _secureStorage.saveRefreshToken(refreshed['refresh'] as String);
        remoteScores = await api.predict(
          payload,
          accessToken: refreshedAccessToken,
        );
      }
      lastSyncedAt = DateTime.now();
      await _persistScore(remoteScores!);
      await _persistDailyEntry();
      await _showRiskAlerts(remoteScores!);
    } catch (error) {
      syncError = error.toString();
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> saveBackendUrl(String value) async {
    final normalized = value.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized.isEmpty || Uri.tryParse(normalized)?.scheme != 'https') {
      backendStatus = 'Only secure HTTPS backend URLs are allowed.';
      notifyListeners();
      return;
    }
    backendUrl = normalized;
    await database.saveSetting('backend_url', backendUrl);
    backendStatus = null;
    notifyListeners();
  }

  Future<void> saveBackendSyncConsent(bool value) async {
    backendSyncConsent = value;
    await database.saveSetting('backend_sync_consent', value.toString());
    notifyListeners();
  }

  Future<void> saveNotificationPreferences(
    NotificationPreferences value,
  ) async {
    notificationPreferences = value;
    await Future.wait([
      database.saveSetting(
        'notify_stress_enabled',
        value.stressEnabled.toString(),
      ),
      database.saveSetting(
        'notify_spending_enabled',
        value.spendingEnabled.toString(),
      ),
      database.saveSetting(
        'notify_screen_enabled',
        value.screenTimeEnabled.toString(),
      ),
      database.saveSetting(
        'notify_sleep_enabled',
        value.sleepEnabled.toString(),
      ),
      database.saveSetting(
        'notify_stress_threshold',
        value.stressThreshold.toString(),
      ),
      database.saveSetting(
        'notify_financial_threshold',
        value.financialHealthThreshold.toString(),
      ),
      database.saveSetting(
        'notify_screen_threshold',
        value.screenTimeThreshold.toString(),
      ),
      database.saveSetting(
        'notify_sleep_threshold',
        value.sleepThreshold.toString(),
      ),
      database.saveSetting(
        'notify_quiet_start',
        value.quietStartMinutes?.toString() ?? '',
      ),
      database.saveSetting(
        'notify_quiet_end',
        value.quietEndMinutes?.toString() ?? '',
      ),
    ]);
    notifyListeners();
  }

  Future<void> saveCheckIn(DailyCheckIn value) async {
    await database.saveCheckIn(user.userId, value);
    checkIns = await database.checkIns(user.userId);
    await database.enqueueSync(
      userId: user.userId,
      entityType: 'checkin',
      operation: 'upsert',
      payload: 'daily check-in',
    );
    pendingSyncItems = await database.pendingSyncItems(user.userId);
    await recordLocalScoreSnapshot();
    await _persistDailyEntry();
    notifyListeners();
  }

  Future<void> saveGoals(UserGoals value) async {
    goals = value;
    await Future.wait([
      database.saveSetting('goal_sleep_hours', value.sleepHours.toString()),
      database.saveSetting('goal_steps', value.steps.toString()),
      database.saveSetting(
        'goal_screen_hours',
        value.screenTimeHours.toString(),
      ),
      database.saveSetting(
        'goal_monthly_budget',
        value.monthlyBudget.toString(),
      ),
    ]);
    notifyListeners();
  }

  Future<void> retryPendingSync() async {
    final pending = await database.pendingSyncItems(user.userId);
    for (final item in pending) {
      final id = item['id'] as int;
      final entityId = item['entity_id'] as int?;
      try {
        if (item['entity_type'] == 'calendar_task') {
          final task = entityId == null
              ? null
              : tasks
                    .where((x) => x.id == entityId)
                    .cast<PlannerEntry?>()
                    .firstOrNull;
          if (item['operation'] == 'delete') {
            await _googleCalendarService.deleteEvent(
              item['payload_json'] as String,
            );
          } else if (task != null && entityId != null) {
            if (item['operation'] == 'create') {
              final eventId = await _googleCalendarService.addTask(task);
              await database.updateTaskCalendarEventId(entityId, eventId);
              final index = tasks.indexWhere((x) => x.id == entityId);
              tasks[index] = task.copyWith(googleCalendarEventId: eventId);
            } else if (item['operation'] == 'update') {
              await _googleCalendarService.updateTask(task);
            }
          }
        } else if (item['entity_type'] == 'checkin') {
          // Check-ins are deliberately local-only; mark their local save done.
        }
        await database.markSyncItemDone(id);
      } catch (_) {}
    }
    pendingSyncItems = await database.pendingSyncItems(user.userId);
    notifyListeners();
  }

  WeeklyReport get weeklyReport {
    final history = scoreHistory;
    final sleep = history.isEmpty
        ? health.sleepHours
        : history.map((x) => x.sleepHours).reduce((a, b) => a + b) /
              history.length;
    final screenChange = history.length < 2
        ? 0.0
        : history.last.screenTimeHours - history.first.screenTimeHours;
    final completed = tasks.where((t) => t.isCompleted).length;
    final rate = tasks.isEmpty ? 0.0 : completed / tasks.length * 100;
    final advice = sleep < goals.sleepHours
        ? 'Protect a consistent bedtime this week.'
        : screenChange > 1
        ? 'Your screen time is rising—plan a phone-free break.'
        : 'Your routine is moving in a healthy direction.';
    return WeeklyReport(
      sleepAverage: sleep,
      screenTimeChange: screenChange,
      spending: expenses
          .where(
            (e) => e.date.isAfter(
              DateTime.now().subtract(const Duration(days: 7)),
            ),
          )
          .fold<double>(0, (a, b) => a + b.amount),
      completionRate: rate,
      recommendation: advice,
    );
  }

  int get sleepGoalStreak => scoreHistory.reversed
      .takeWhile((x) => x.sleepHours >= goals.sleepHours)
      .length;
  int get screenTimeGoalStreak => scoreHistory.reversed
      .takeWhile((x) => x.screenTimeHours <= goals.screenTimeHours)
      .length;

  Future<void> _scheduleTaskReminder(PlannerEntry task) async {
    if (task.id == null || task.reminderMinutes == null) return;
    final when = DateTime(
      task.date.year,
      task.date.month,
      task.date.day,
    ).add(Duration(minutes: task.timeMinutes - task.reminderMinutes!));
    await notificationService.scheduleTaskReminder(
      id: task.id!,
      when: when,
      title: task.title,
    );
  }

  Future<void> deleteAllData() async {
    final token = await _secureStorage.token();
    if (token != null) {
      await PredictionApiService(
        baseUrl: backendUrl,
      ).deleteMyData(accessToken: token);
    }
    await database.deleteAllLocalData();
    await _secureStorage.clearToken();
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
        showAlerts: false,
      );
      await addTask(
        PlannerEntry(
          title: 'Finish urgent project review',
          date: now,
          priority: TaskPriority.high,
          workload: 5,
        ),
        showAlerts: false,
      );
      await addTask(
        PlannerEntry(
          title: 'Prepare presentation changes',
          date: now,
          priority: TaskPriority.high,
          workload: 4,
        ),
        showAlerts: false,
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
        showAlerts: false,
      );
      await addTask(
        PlannerEntry(
          title: 'Review notes calmly',
          date: now,
          priority: TaskPriority.medium,
          workload: 2,
        ),
        showAlerts: false,
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
      totalWorkload: totalWorkload,
    );
    scoreHistory = await database.scoreHistory(user.userId, 7);
  }

  List<String> get predictionExplanations {
    final today = DateTime.now();
    final previous = scoreHistory
        .where(
          (snapshot) =>
              snapshot.date.year != today.year ||
              snapshot.date.month != today.month ||
              snapshot.date.day != today.day,
        )
        .lastOrNull;
    final explanations = <String>[];
    if (previous != null) {
      final sleepChange = health.sleepHours - previous.sleepHours;
      if (sleepChange <= -0.25) {
        explanations.add(
          'Sleep decreased by ${sleepChange.abs().toStringAsFixed(1)}h since your previous recorded day.',
        );
      }
      final workloadChange = totalWorkload - previous.totalWorkload;
      if (workloadChange >= 1) {
        explanations.add(
          'Planned workload increased by $workloadChange point${workloadChange == 1 ? '' : 's'}.',
        );
      }
      final screenChange = health.screenTimeHours - previous.screenTimeHours;
      if (screenChange >= 0.25) {
        explanations.add(
          'Screen time increased by ${screenChange.toStringAsFixed(1)}h.',
        );
      }
    }
    if (highPriorityTasks > 0) {
      explanations.add(
        '$highPriorityTasks high-priority task${highPriorityTasks == 1 ? ' is' : 's are'} still due today.',
      );
    }
    final checkIn = checkIns
        .where(
          (x) =>
              x.date.year == today.year &&
              x.date.month == today.month &&
              x.date.day == today.day,
        )
        .lastOrNull;
    if (checkIn != null && checkIn.stress >= 4) {
      explanations.add(
        'Your check-in reported elevated stress (${checkIn.stress}/5).',
      );
    }
    if (explanations.isEmpty) {
      explanations.add(
        'No major negative change was detected from your available history.',
      );
    }
    return explanations.take(3).toList();
  }

  Future<void> _persistDailyEntry() async {
    await database.upsertDailyEntry(
      userId: user.userId,
      health: health,
      dailySpending: spendingForDay(health.date),
      calendarEvents: taskCountForDay(health.date),
      highPriorityTasks: highPriorityTasksForDay(health.date),
      totalWorkload: totalWorkloadForDay(health.date),
    );
  }

  Future<void> _showRiskAlerts(LifestyleScores scores) {
    return notificationService.showRiskAlerts(
      scores: scores,
      health: health,
      shouldShow: _claimAlertForToday,
      preferences: notificationPreferences,
    );
  }

  Future<bool> _claimAlertForToday(String alertType) async {
    final day =
        '${health.date.year.toString().padLeft(4, '0')}-${health.date.month.toString().padLeft(2, '0')}-${health.date.day.toString().padLeft(2, '0')}';
    final key = 'risk_alert_${user.userId}_${alertType}_$day';
    if (await database.setting(key) == 'sent') return false;
    await database.saveSetting(key, 'sent');
    return true;
  }

  double get todaySpending {
    return spendingForDay(DateTime.now());
  }

  double spendingForDay(DateTime day) {
    return expenses
        .where((entry) => _isSameDay(entry.date, day))
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

  int get highPriorityTasks => highPriorityTasksForDay(DateTime.now());

  int highPriorityTasksForDay(DateTime day) => tasks
      .where(
        (task) =>
            !task.isCompleted &&
            task.priority == TaskPriority.high &&
            _isSameDay(task.date, day),
      )
      .length;

  int get totalWorkload => totalWorkloadForDay(DateTime.now());

  int taskCountForDay(DateTime day) => tasks
      .where((task) => !task.isCompleted && _isSameDay(task.date, day))
      .length;

  int totalWorkloadForDay(DateTime day) => tasks
      .where((task) => !task.isCompleted && _isSameDay(task.date, day))
      .fold(0, (total, task) => total + task.workload);

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

    final todayCheckIn = checkIns.where((checkIn) {
      final now = DateTime.now();
      return checkIn.date.year == now.year &&
          checkIn.date.month == now.month &&
          checkIn.date.day == now.day;
    }).firstOrNull;
    final checkInRiskAdjustment = todayCheckIn == null
        ? 0
        : (todayCheckIn.stress - 3) * 7 +
              (3 - todayCheckIn.energy) * 4 +
              (3 - todayCheckIn.mood) * 3;
    final stressRisk =
        ((100 - sleepScore) * .35 +
                health.screenTimeHours * 5 +
                highPriorityTasks * 10 +
                totalWorkload * 2 +
                checkInRiskAdjustment)
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
}
