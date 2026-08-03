import 'package:flutter/foundation.dart';

import '../models/lifestyle_entry.dart';
import '../models/lifestyle_scores.dart';

class LifeLensStore extends ChangeNotifier {
  final List<ExpenseEntry> expenses = [
    ExpenseEntry(
      amount: 180,
      category: 'Food',
      date: DateTime.now(),
      note: 'Lunch',
    ),
    ExpenseEntry(
      amount: 120,
      category: 'Travel',
      date: DateTime.now(),
      note: 'Bus',
    ),
  ];

  final List<PlannerEntry> tasks = [
    PlannerEntry(
      title: 'Minor project UI',
      date: DateTime.now(),
      priority: TaskPriority.high,
      workload: 4,
    ),
    PlannerEntry(
      title: 'ML API discussion',
      date: DateTime.now(),
      priority: TaskPriority.medium,
      workload: 2,
    ),
  ];

  DailyHealthEntry health = DailyHealthEntry(
    sleepHours: 6.5,
    steps: 4300,
    screenTimeHours: 6.8,
  );

  void addExpense(ExpenseEntry entry) {
    expenses.insert(0, entry);
    notifyListeners();
  }

  void addTask(PlannerEntry entry) {
    tasks.insert(0, entry);
    notifyListeners();
  }

  void updateHealth(DailyHealthEntry entry) {
    health = entry;
    notifyListeners();
  }

  void refreshScores() {
    notifyListeners();
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
