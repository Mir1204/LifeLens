class DailyCheckIn {
  const DailyCheckIn({
    required this.date,
    required this.mood,
    required this.energy,
    required this.stress,
    required this.note,
  });

  final DateTime date;
  final int mood, energy, stress;
  final String note;
}

class UserGoals {
  const UserGoals({
    this.sleepHours = 7.5,
    this.steps = 8000,
    this.screenTimeHours = 5,
    this.monthlyBudget = 0,
  });

  final double sleepHours, screenTimeHours, monthlyBudget;
  final int steps;

  UserGoals copyWith({
    double? sleepHours,
    int? steps,
    double? screenTimeHours,
    double? monthlyBudget,
  }) => UserGoals(
    sleepHours: sleepHours ?? this.sleepHours,
    steps: steps ?? this.steps,
    screenTimeHours: screenTimeHours ?? this.screenTimeHours,
    monthlyBudget: monthlyBudget ?? this.monthlyBudget,
  );
}

class WeeklyReport {
  const WeeklyReport({
    required this.sleepAverage,
    required this.screenTimeChange,
    required this.spending,
    required this.completionRate,
    required this.recommendation,
  });
  final double sleepAverage, screenTimeChange, spending, completionRate;
  final String recommendation;
}
