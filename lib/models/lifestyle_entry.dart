class ExpenseEntry {
  ExpenseEntry({
    this.id,
    required this.amount,
    required this.category,
    required this.date,
    required this.note,
    this.recurringLabel,
  });

  final int? id;
  final double amount;
  final String category;
  final DateTime date;
  final String note;
  final String? recurringLabel;

  ExpenseEntry copyWith({
    int? id,
    double? amount,
    String? category,
    DateTime? date,
    String? note,
    String? recurringLabel,
    bool clearRecurringLabel = false,
  }) {
    return ExpenseEntry(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      recurringLabel: clearRecurringLabel
          ? null
          : recurringLabel ?? this.recurringLabel,
    );
  }
}

class PlannerEntry {
  PlannerEntry({
    this.id,
    required this.title,
    required this.date,
    required this.priority,
    required this.workload,
    this.isCompleted = false,
  });

  final int? id;
  final String title;
  final DateTime date;
  final TaskPriority priority;
  final int workload;
  final bool isCompleted;

  PlannerEntry copyWith({bool? isCompleted}) {
    return PlannerEntry(
      id: id,
      title: title,
      date: date,
      priority: priority,
      workload: workload,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

enum TaskPriority { low, medium, high }

class DailyHealthEntry {
  DailyHealthEntry({
    this.id,
    required this.sleepHours,
    required this.steps,
    required this.screenTimeHours,
    this.source = 'manual',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  final int? id;
  final double sleepHours;
  final int steps;
  final double screenTimeHours;
  final String source;
  final DateTime date;
}
