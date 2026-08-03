class ExpenseEntry {
  ExpenseEntry({
    required this.amount,
    required this.category,
    required this.date,
    required this.note,
  });

  final double amount;
  final String category;
  final DateTime date;
  final String note;
}

class PlannerEntry {
  PlannerEntry({
    required this.title,
    required this.date,
    required this.priority,
    required this.workload,
  });

  final String title;
  final DateTime date;
  final TaskPriority priority;
  final int workload;
}

enum TaskPriority { low, medium, high }

class DailyHealthEntry {
  DailyHealthEntry({
    required this.sleepHours,
    required this.steps,
    required this.screenTimeHours,
  });

  final double sleepHours;
  final int steps;
  final double screenTimeHours;
}
