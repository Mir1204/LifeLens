import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:share_plus/share_plus.dart';

import '../models/wellbeing_models.dart';
import '../models/lifestyle_entry.dart';
import 'lifelens_store.dart';

class DataPortabilityService {
  final _cipher = AesGcm.with256bits();
  final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 210000,
    bits: 256,
  );

  Future<void> shareExport(LifeLensStore store, String passphrase) async {
    if (passphrase.length < 12) {
      throw const FormatException(
        'Use an export passphrase with at least 12 characters.',
      );
    }
    final plainText = jsonEncode({
      'format': 'lifelens-export-v1',
      'created_at': DateTime.now().toIso8601String(),
      'goals': {
        'sleep_hours': store.goals.sleepHours,
        'steps': store.goals.steps,
        'screen_time_hours': store.goals.screenTimeHours,
        'monthly_budget': store.goals.monthlyBudget,
      },
      'checkins': store.checkIns
          .map(
            (x) => {
              'date': x.date.toIso8601String(),
              'mood': x.mood,
              'energy': x.energy,
              'stress': x.stress,
              'note': x.note,
            },
          )
          .toList(),
      'tasks': store.tasks
          .map(
            (x) => {
              'title': x.title,
              'date': x.date.toIso8601String(),
              'priority': x.priority.name,
              'workload': x.workload,
              'note': x.note,
            },
          )
          .toList(),
      'expenses': store.expenses
          .map(
            (x) => {
              'amount': x.amount,
              'category': x.category,
              'date': x.date.toIso8601String(),
              'note': x.note,
            },
          )
          .toList(),
    });
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final key = await _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    final encrypted = await _cipher.encrypt(
      utf8.encode(plainText),
      secretKey: key,
      nonce: nonce,
    );
    final export = jsonEncode({
      'format': 'lifelens-encrypted-export-v1',
      'cipher': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': 210000,
      'salt': base64Encode(salt),
      'nonce': base64Encode(encrypted.nonce),
      'ciphertext': base64Encode(encrypted.cipherText),
      'tag': base64Encode(encrypted.mac.bytes),
    });
    await SharePlus.instance.share(
      ShareParams(text: export, title: 'LifeLens encrypted data export'),
    );
  }

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => Random.secure().nextInt(256));

  Future<void> importCheckInsAndGoals(
    LifeLensStore store,
    String raw,
    String passphrase,
  ) async {
    var data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['format'] == 'lifelens-encrypted-export-v1') {
      final salt = base64Decode(data['salt'] as String);
      final key = await _kdf.deriveKey(
        secretKey: SecretKey(utf8.encode(passphrase)),
        nonce: salt,
      );
      final clearBytes = await _cipher.decrypt(
        SecretBox(
          base64Decode(data['ciphertext'] as String),
          nonce: base64Decode(data['nonce'] as String),
          mac: Mac(base64Decode(data['tag'] as String)),
        ),
        secretKey: key,
      );
      data = jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>;
    }
    if (data['format'] != 'lifelens-export-v1')
      throw const FormatException('This is not a LifeLens export.');
    final rawGoals = data['goals'] as Map<String, dynamic>?;
    if (rawGoals != null)
      await store.saveGoals(
        UserGoals(
          sleepHours: (rawGoals['sleep_hours'] as num?)?.toDouble() ?? 7.5,
          steps: (rawGoals['steps'] as num?)?.toInt() ?? 8000,
          screenTimeHours:
              (rawGoals['screen_time_hours'] as num?)?.toDouble() ?? 5,
          monthlyBudget: (rawGoals['monthly_budget'] as num?)?.toDouble() ?? 0,
        ),
      );
    for (final item in (data['checkins'] as List<dynamic>? ?? const [])) {
      final x = item as Map<String, dynamic>;
      await store.saveCheckIn(
        DailyCheckIn(
          date: DateTime.parse(x['date'] as String),
          mood: x['mood'] as int,
          energy: x['energy'] as int,
          stress: x['stress'] as int,
          note: x['note'] as String? ?? '',
        ),
      );
    }
    for (final item in (data['tasks'] as List<dynamic>? ?? const [])) {
      final x = item as Map<String, dynamic>;
      final priorityName = x['priority'] as String? ?? 'medium';
      await store.addTask(
        PlannerEntry(
          title: x['title'] as String? ?? 'Imported task',
          date: DateTime.parse(x['date'] as String),
          priority: TaskPriority.values.firstWhere(
            (value) => value.name == priorityName,
            orElse: () => TaskPriority.medium,
          ),
          workload: (x['workload'] as num?)?.toInt() ?? 2,
          note: x['note'] as String? ?? '',
        ),
        showAlerts: false,
      );
    }
    for (final item in (data['expenses'] as List<dynamic>? ?? const [])) {
      final x = item as Map<String, dynamic>;
      await store.addExpense(
        ExpenseEntry(
          amount: (x['amount'] as num?)?.toDouble() ?? 0,
          category: x['category'] as String? ?? 'Other',
          date: DateTime.parse(x['date'] as String),
          note: x['note'] as String? ?? '',
        ),
        showAlerts: false,
      );
    }
  }
}
