import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/app_usage_summary.dart';
import '../models/app_user.dart';
import '../models/lifestyle_entry.dart';
import '../models/lifestyle_scores.dart';

class LocalDatabaseService {
  static const databaseName = 'lifelens.db';
  static const databaseVersion = 3;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    _database = await openDatabase(
      path.join(dbPath, databaseName),
      version: databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    return _database!;
  }

  Future<void> _upgradeSchema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _tryExecute(db, 'ALTER TABLE expenses ADD COLUMN updated_at TEXT');
      await _tryExecute(db, 'ALTER TABLE expenses ADD COLUMN deleted_at TEXT');
      await _tryExecute(
        db,
        'ALTER TABLE planner_tasks ADD COLUMN updated_at TEXT',
      );
      await _tryExecute(
        db,
        'ALTER TABLE planner_tasks ADD COLUMN deleted_at TEXT',
      );
      await _tryExecute(
        db,
        'CREATE UNIQUE INDEX idx_screen_time_unique_app ON screen_time_apps(user_id, usage_date, package_name)',
      );
      await _tryExecute(
        db,
        'CREATE INDEX idx_screen_time_user_date ON screen_time_apps(user_id, usage_date)',
      );
      await _tryExecute(db, '''
        CREATE TABLE sync_outbox (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          entity_id INTEGER,
          operation TEXT NOT NULL,
          payload_json TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          attempts INTEGER NOT NULL DEFAULT 0,
          last_error TEXT,
          created_at TEXT NOT NULL,
          synced_at TEXT
        )
      ''');
      await _tryExecute(
        db,
        'CREATE INDEX idx_outbox_status ON sync_outbox(status, created_at)',
      );
    }
    if (oldVersion < 3) {
      await _createDailyEntries(db);
      await _createRecommendations(db);
      await _tryExecute(
        db,
        'CREATE UNIQUE INDEX idx_daily_entries_unique_date ON daily_entries(user_id, entry_date)',
      );
      await _tryExecute(
        db,
        'CREATE UNIQUE INDEX idx_scores_unique_date ON score_snapshots(user_id, score_date)',
      );
      await _tryExecute(
        db,
        'CREATE INDEX idx_recommendations_user_date ON recommendations(user_id, recommendation_date)',
      );
    }
  }

  Future<void> _tryExecute(Database db, String sql) async {
    try {
      await db.execute(sql);
    } catch (_) {
      // Development migration helper: ignore objects/columns already present.
    }
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE local_users (
        user_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        signed_in INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        note TEXT NOT NULL,
        expense_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT,
        FOREIGN KEY(user_id) REFERENCES local_users(user_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE planner_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        priority TEXT NOT NULL,
        workload INTEGER NOT NULL,
        task_date TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT,
        FOREIGN KEY(user_id) REFERENCES local_users(user_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE health_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        record_date TEXT NOT NULL,
        sleep_hours REAL NOT NULL,
        steps INTEGER NOT NULL,
        screen_time_hours REAL NOT NULL,
        source TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES local_users(user_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE screen_time_apps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        usage_date TEXT NOT NULL,
        app_name TEXT NOT NULL,
        package_name TEXT NOT NULL,
        usage_hours REAL NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(user_id, usage_date, package_name),
        FOREIGN KEY(user_id) REFERENCES local_users(user_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE score_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        score_date TEXT NOT NULL,
        productivity INTEGER NOT NULL,
        financial_health INTEGER NOT NULL,
        stress_risk INTEGER NOT NULL,
        burnout_risk TEXT NOT NULL,
        overspending_risk TEXT NOT NULL,
        spending REAL NOT NULL,
        sleep_hours REAL NOT NULL,
        screen_time_hours REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES local_users(user_id) ON DELETE CASCADE
      )
    ''');

    await _createDailyEntries(db);
    await _createRecommendations(db);

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id INTEGER,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        synced_at TEXT,
        FOREIGN KEY(user_id) REFERENCES local_users(user_id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_expenses_user_date ON expenses(user_id, expense_date)',
    );
    await db.execute(
      'CREATE INDEX idx_tasks_user_date ON planner_tasks(user_id, task_date)',
    );
    await db.execute(
      'CREATE INDEX idx_health_user_date ON health_records(user_id, record_date)',
    );
    await db.execute(
      'CREATE INDEX idx_scores_user_date ON score_snapshots(user_id, score_date)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_daily_entries_unique_date ON daily_entries(user_id, entry_date)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_scores_unique_date ON score_snapshots(user_id, score_date)',
    );
    await db.execute(
      'CREATE INDEX idx_recommendations_user_date ON recommendations(user_id, recommendation_date)',
    );
    await db.execute(
      'CREATE INDEX idx_screen_time_user_date ON screen_time_apps(user_id, usage_date)',
    );
    await db.execute(
      'CREATE INDEX idx_outbox_status ON sync_outbox(status, created_at)',
    );
  }

  Future<void> _createDailyEntries(Database db) async {
    await db.execute('''
      CREATE TABLE daily_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        entry_date TEXT NOT NULL,
        sleep_hours REAL NOT NULL,
        steps INTEGER NOT NULL,
        screen_time_hours REAL NOT NULL,
        daily_spending REAL NOT NULL,
        calendar_events INTEGER NOT NULL,
        high_priority_tasks INTEGER NOT NULL,
        total_workload INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(user_id, entry_date),
        FOREIGN KEY(user_id) REFERENCES local_users(user_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createRecommendations(Database db) async {
    await db.execute('''
      CREATE TABLE recommendations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        recommendation_date TEXT NOT NULL,
        message TEXT NOT NULL,
        category TEXT NOT NULL,
        severity TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES local_users(user_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> upsertUser({
    required AppUser user,
    required String passwordHash,
    required bool signedIn,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      if (signedIn) {
        await txn.update('local_users', {'signed_in': 0});
      }
      final values = {
        'user_id': user.userId,
        'name': user.name,
        'email': user.email,
        'password_hash': passwordHash,
        'signed_in': signedIn ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      };
      final inserted = await txn.insert(
        'local_users',
        values,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (inserted == 0) {
        await txn.update(
          'local_users',
          {
            'name': user.name,
            'password_hash': passwordHash,
            'signed_in': signedIn ? 1 : 0,
          },
          where: 'user_id = ?',
          whereArgs: [user.userId],
        );
      }
    });
  }

  Future<AppUser?> signedInUser() async {
    final db = await database;
    final rows = await db.query(
      'local_users',
      where: 'signed_in = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _userFromRow(rows.first);
  }

  Future<Map<String, Object?>?> userByEmail(String email) async {
    final db = await database;
    final rows = await db.query(
      'local_users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> markSignedIn(String userId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('local_users', {'signed_in': 0});
      await txn.update(
        'local_users',
        {'signed_in': 1},
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    });
  }

  Future<void> signOutAll() async {
    final db = await database;
    await db.update('local_users', {'signed_in': 0});
  }

  Future<void> insertExpense(String userId, ExpenseEntry entry) async {
    final db = await database;
    await db.insert('expenses', {
      'user_id': userId,
      'amount': entry.amount,
      'category': entry.category,
      'note': entry.note,
      'expense_date': _dayKey(entry.date),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<ExpenseEntry>> expenses(String userId) async {
    final db = await database;
    final rows = await db.query(
      'expenses',
      where: 'user_id = ? AND deleted_at IS NULL',
      whereArgs: [userId],
      orderBy: 'expense_date DESC, id DESC',
    );
    return rows.map(_expenseFromRow).toList();
  }

  Future<void> softDeleteExpense(int id) async {
    final db = await database;
    await db.update(
      'expenses',
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertTask(String userId, PlannerEntry entry) async {
    final db = await database;
    await db.insert('planner_tasks', {
      'user_id': userId,
      'title': entry.title,
      'priority': entry.priority.name,
      'workload': entry.workload,
      'task_date': _dayKey(entry.date),
      'is_completed': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<PlannerEntry>> tasks(String userId) async {
    final db = await database;
    final rows = await db.query(
      'planner_tasks',
      where: 'user_id = ? AND deleted_at IS NULL',
      whereArgs: [userId],
      orderBy: 'task_date DESC, id DESC',
    );
    return rows.map(_taskFromRow).toList();
  }

  Future<void> softDeleteTask(int id) async {
    final db = await database;
    await db.update(
      'planner_tasks',
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> toggleTaskComplete(int id, {required bool done}) async {
    final db = await database;
    await db.update(
      'planner_tasks',
      {
        'is_completed': done ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertHealth(String userId, DailyHealthEntry entry) async {
    final db = await database;
    await db.insert('health_records', {
      'user_id': userId,
      'record_date': _dayKey(entry.date),
      'sleep_hours': entry.sleepHours,
      'steps': entry.steps,
      'screen_time_hours': entry.screenTimeHours,
      'source': entry.source,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<DailyHealthEntry?> latestHealth(String userId) async {
    final db = await database;
    final rows = await db.query(
      'health_records',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'record_date DESC, id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _healthFromRow(rows.first);
  }

  Future<List<DailyHealthEntry>> recentHealth(String userId, int days) async {
    final db = await database;
    final rows = await db.query(
      'health_records',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'record_date DESC, id DESC',
      limit: days,
    );
    return rows.map(_healthFromRow).toList().reversed.toList();
  }

  Future<void> replaceScreenTimeApps(
    String userId,
    AppUsageSummary summary,
  ) async {
    final db = await database;
    final usageDate = _dayKey(summary.updatedAt);
    await db.transaction((txn) async {
      await txn.delete(
        'screen_time_apps',
        where: 'user_id = ? AND usage_date = ?',
        whereArgs: [userId, usageDate],
      );
      for (final app in summary.apps) {
        await txn.insert('screen_time_apps', {
          'user_id': userId,
          'usage_date': usageDate,
          'app_name': app.name,
          'package_name': app.packageName,
          'usage_hours': app.hours,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<AppUsageSummary?> latestAppUsage(String userId) async {
    final db = await database;
    final dates = await db.query(
      'screen_time_apps',
      columns: ['usage_date'],
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'usage_date DESC, id DESC',
      limit: 1,
    );
    if (dates.isEmpty) return null;

    final usageDate = dates.first['usage_date'] as String;
    final rows = await db.query(
      'screen_time_apps',
      where: 'user_id = ? AND usage_date = ?',
      whereArgs: [userId, usageDate],
      orderBy: 'usage_hours DESC',
    );
    final apps = rows.map(_usedAppFromRow).toList();
    final totalHours = apps.fold<double>(
      0,
      (total, app) => total + app.hours,
    );
    final updatedAt = rows.isEmpty
        ? DateTime.parse(usageDate)
        : DateTime.tryParse(rows.first['created_at'] as String) ??
            DateTime.parse(usageDate);
    return AppUsageSummary(
      totalHours: totalHours,
      apps: apps,
      updatedAt: updatedAt,
    );
  }

  Future<void> upsertDailyEntry({
    required String userId,
    required DailyHealthEntry health,
    required double dailySpending,
    required int calendarEvents,
    required int highPriorityTasks,
    required int totalWorkload,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'daily_entries',
      {
        'user_id': userId,
        'entry_date': _dayKey(DateTime.now()),
        'sleep_hours': health.sleepHours,
        'steps': health.steps,
        'screen_time_hours': health.screenTimeHours,
        'daily_spending': dailySpending,
        'calendar_events': calendarEvents,
        'high_priority_tasks': highPriorityTasks,
        'total_workload': totalWorkload,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertScoreSnapshot({
    required String userId,
    required LifestyleScores scores,
    required double spending,
    required double sleepHours,
    required double screenTimeHours,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'score_snapshots',
      {
        'user_id': userId,
        'score_date': _dayKey(scores.date),
        'productivity': scores.productivity,
        'financial_health': scores.financialHealth,
        'stress_risk': scores.stressRisk,
        'burnout_risk': scores.burnoutRisk,
        'overspending_risk': scores.overspendingRisk,
        'spending': spending,
        'sleep_hours': sleepHours,
        'screen_time_hours': screenTimeHours,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await replaceRecommendations(userId, scores);
  }

  Future<void> replaceRecommendations(
    String userId,
    LifestyleScores scores,
  ) async {
    final db = await database;
    final recommendationDate = _dayKey(scores.date);
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(
        'recommendations',
        where: 'user_id = ? AND recommendation_date = ?',
        whereArgs: [userId, recommendationDate],
      );
      for (final message in scores.recommendations) {
        await txn.insert('recommendations', {
          'user_id': userId,
          'recommendation_date': recommendationDate,
          'message': message,
          'category': _recommendationCategory(message),
          'severity': _recommendationSeverity(scores),
          'created_at': now,
        });
      }
    });
  }

  Future<List<ScoreSnapshot>> scoreHistory(String userId, int limit) async {
    final db = await database;
    final rows = await db.query(
      'score_snapshots',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'score_date DESC, id DESC',
      limit: limit,
    );
    return rows.map(_scoreFromRow).toList().reversed.toList();
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> setting(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  AppUser _userFromRow(Map<String, Object?> row) {
    return AppUser(
      userId: row['user_id'] as String,
      name: row['name'] as String,
      email: row['email'] as String,
    );
  }

  ExpenseEntry _expenseFromRow(Map<String, Object?> row) {
    return ExpenseEntry(
      id: row['id'] as int,
      amount: (row['amount'] as num).toDouble(),
      category: row['category'] as String,
      date: DateTime.parse(row['expense_date'] as String),
      note: row['note'] as String,
    );
  }

  PlannerEntry _taskFromRow(Map<String, Object?> row) {
    return PlannerEntry(
      id: row['id'] as int,
      title: row['title'] as String,
      date: DateTime.parse(row['task_date'] as String),
      priority: TaskPriority.values.firstWhere(
        (item) => item.name == row['priority'],
        orElse: () => TaskPriority.medium,
      ),
      workload: row['workload'] as int,
      isCompleted: (row['is_completed'] as int? ?? 0) == 1,
    );
  }

  DailyHealthEntry _healthFromRow(Map<String, Object?> row) {
    return DailyHealthEntry(
      id: row['id'] as int,
      sleepHours: (row['sleep_hours'] as num).toDouble(),
      steps: row['steps'] as int,
      screenTimeHours: (row['screen_time_hours'] as num).toDouble(),
      source: row['source'] as String,
      date: DateTime.parse(row['record_date'] as String),
    );
  }

  UsedApp _usedAppFromRow(Map<String, Object?> row) {
    return UsedApp(
      id: row['id'] as int,
      name: row['app_name'] as String,
      packageName: row['package_name'] as String,
      hours: (row['usage_hours'] as num).toDouble(),
      date: DateTime.parse(row['usage_date'] as String),
    );
  }

  ScoreSnapshot _scoreFromRow(Map<String, Object?> row) {
    return ScoreSnapshot(
      date: DateTime.parse(row['score_date'] as String),
      productivity: row['productivity'] as int,
      financialHealth: row['financial_health'] as int,
      stressRisk: row['stress_risk'] as int,
      spending: (row['spending'] as num).toDouble(),
      sleepHours: (row['sleep_hours'] as num).toDouble(),
      screenTimeHours: (row['screen_time_hours'] as num).toDouble(),
    );
  }

  String _dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _recommendationCategory(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('sleep')) return 'health';
    if (lower.contains('screen')) return 'screen_time';
    if (lower.contains('spending') || lower.contains('expense')) {
      return 'finance';
    }
    if (lower.contains('task') || lower.contains('stress')) return 'planner';
    return 'general';
  }

  String _recommendationSeverity(LifestyleScores scores) {
    if (scores.stressRisk >= 70 || scores.financialHealth <= 60) return 'high';
    if (scores.stressRisk >= 45 || scores.financialHealth <= 75) {
      return 'medium';
    }
    return 'low';
  }
}
